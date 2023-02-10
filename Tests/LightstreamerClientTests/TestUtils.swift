import Foundation
@testable import LightstreamerClient

class Trace {
    var trace = ""
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
}

class TestDelegate: ClientDelegate {
    var trace = ""
    var logPropertyChange = false
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func clientDidRemoveDelegate(_ client: LightstreamerClient) {}
    
    func clientDidAddDelegate(_ client: LightstreamerClient) {}
    
    func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {
        addTrace("onServerError \(errorCode) \(errorMessage)")
    }
    
    func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {
        addTrace(status.rawValue)
    }
    
    func client(_ client: LightstreamerClient, didChangeProperty property: String) {
        if logPropertyChange {
            addTrace("onPropertyChange \(property)")
        }
    }
    
    func client(_ client: LightstreamerClient, willSendRequestForAuthenticationChallenge challenge: URLAuthenticationChallenge) {}
}

class TestWSFactory: LsWebsocketClient {
    var m_trace: Trace
    var disposed: Bool = false
    var m_onOpen: (() -> Void)!
    var m_onText: ((String) -> Void)!
    var m_onError: (() -> Void)!
    var showExtraHeaders = false
    
    var trace: String {
        m_trace.trace
    }
    
    init() {
        m_trace = Trace()
    }
    
    func onOpen() {
        m_onOpen()
    }
    
    func onText(_ s: String) {
        m_onText(s)
    }
    
    func onError() {
        m_onError()
    }
    
    func addTrace(_ s: String) {
        m_trace.addTrace(s)
    }
    
    func send(_ text: String) {
        addTrace(text)
    }
    
    func dispose() {
        addTrace("ws.dispose")
    }
    
    func createWS(_ lock: NSRecursiveLock, _ url: String, _ protocols: String, _ headers: [String:String],
                   _ onOpen: @escaping (LsWebsocketClient) -> Void,
                   _ onText: @escaping (LsWebsocketClient, String) -> Void,
                   _ onError: @escaping (LsWebsocketClient, String) -> Void) -> LsWebsocketClient {
        addTrace("ws.init \(url)")
        if showExtraHeaders {
            for (key, val) in headers {
                addTrace("\(key)=\(val)")
            }
        }
        self.m_onOpen = { onOpen(self) }
        self.m_onText = { txt in
            self.addTrace(txt)
            onText(self, txt)
        }
        self.m_onError = { onError(self, "ws.error") }
        return self
    }
}

class TestHTTPFactory: LsHttpClient {
    var m_trace: Trace
    var disposed: Bool = false
    var m_onText: ((String) -> Void)!
    var m_onError: (() -> Void)!
    var m_onDone: (() -> Void)!
    let prefix: String
    var showExtraHeaders = false
    
    var trace: String {
        m_trace.trace
    }
    
    init(_ prefix: String = "http") {
        m_trace = Trace()
        self.prefix = prefix
    }
    
    func onDone() {
        m_onDone()
    }
    
    func onText(_ s: String) {
        m_onText(s)
    }
    
    func onError() {
        m_onError()
    }
    
    func addTrace(_ s: String) {
        m_trace.addTrace(s)
    }
    
    func dispose() {
        addTrace("\(prefix).dispose")
    }
    
    func createHTTP(_ lock: NSRecursiveLock, _ url: String, _ body: String, _ headers: [String:String],
                     onText: @escaping (LsHttpClient, String) -> Void,
                     onError: @escaping (LsHttpClient, String) -> Void,
                     onDone: @escaping (LsHttpClient) -> Void) -> LsHttpClient {
        addTrace("\(prefix).send \(url)")
        if showExtraHeaders {
            for (key, val) in headers {
                addTrace("\(key)=\(val)")
            }
        }
        addTrace(body)
        self.m_onText = { txt in
            self.addTrace(txt)
            onText(self, txt)
        }
        self.m_onError = { onError(self, "\(self.prefix).error") }
        self.m_onDone = { onDone(self) }
        return self
    }
}

class TestScheduler: ScheduleService {
    var now: Timestamp = 0
    var timeouts = [String:ScheduledTask]()
    var trace = ""
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func advanceTime(_ ms: Timestamp) {
        now += ms
    }
    
    func setTime(_ ms: Timestamp) {
        assert( ms > now)
        now = ms
    }
    
    func schedule(_ id: String, _ timeout: Millis, _ task: ScheduledTask) {
        addTrace("\(id) \(timeout)")
        assert(timeouts[id] == nil)
        timeouts[id] = task
    }
    
    func cancel(_ id: String, _ task: ScheduledTask) {
        addTrace("cancel \(id)")
        assert(timeouts[id] != nil)
        timeouts[id] = nil
    }
    
    func fireRetryTimeout() {
        timeouts["retry.timeout"]!.item!.perform()
    }
    
    func fireTransportTimeout() {
        timeouts["transport.timeout"]!.item!.perform()
    }
    
    func fireRecoveryTimeout() {
        timeouts["recovery.timeout"]!.item!.perform()
    }
    
    func fireIdleTimeout() {
        timeouts["idle.timeout"]!.item!.perform()
    }
    
    func firePollingTimeout() {
        timeouts["polling.timeout"]!.item!.perform()
    }
    
    func fireCtrlTimeout() {
        timeouts["ctrl.timeout"]!.item!.perform()
    }
    
    func fireKeepaliveTimeout() {
        timeouts["keepalive.timeout"]!.item!.perform()
    }
    
    func fireStalledTimeout() {
        timeouts["stalled.timeout"]!.item!.perform()
    }
    
    func fireReconnectTimeout() {
        timeouts["reconnect.timeout"]!.item!.perform()
    }
    
    func fireRhbTimeout() {
        timeouts["rhb.timeout"]!.item!.perform()
    }
}

class TestReachabilityFactory: ReachabilityService {
    let m_trace = Trace()
    var onUpdatePerforming: ((ReachabilityStatus) -> Void)!
    
    var trace: String {
        m_trace.trace
    }
    
    func startListening(_ onUpdatePerforming: @escaping (ReachabilityStatus) -> Void) {
        self.onUpdatePerforming = onUpdatePerforming
        m_trace.addTrace("startListening")
    }
    
    func stopListening() {
        m_trace.addTrace("stopListening")
    }
    
    func create(host: String) -> ReachabilityService {
        m_trace.addTrace("new reachability service: \(host)")
        return self
    }
}
