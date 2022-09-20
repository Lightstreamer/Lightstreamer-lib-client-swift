import Foundation

protocol SubscriptionManager: AnyObject, Encodable {
    var subId: Int {get}
    func evtExtAbort()
    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String)
    func evtREQOK(_ reqId: Int)
    func evtSUBOK(nItems: Int, nFields: Int)
    func evtSUBCMD(nItems: Int, nFields: Int, keyIdx: Int, cmdIdx: Int)
    func evtUNSUB()
    func evtU(_ itemIdx: Int, _ values: [Pos:FieldValue]) throws 
    func evtEOS(_ itemIdx: Int)
    func evtCS(_ itemIdx: Int)
    func evtOV(_ itemIdx: Int, _ lostUpdates: Int)
    func evtCONF(_ freq: RealMaxFrequency)
}

class SubscriptionManagerLiving: SubscriptionManager {
    
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3, s4 = 4, s5 = 5
        case s30 = 30, s31 = 31, s32 = 32
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_s: Int, State {
        case s10 = 10
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_c: Int, State {
        case s20 = 20, s21 = 21, s22 = 22
        
        var id: Int {
            self.rawValue
        }
    }
    
    let m_subId: Int
    let m_subscription: Subscription
    let m_strategy: ModeStrategy
    var m_lastAddReqId: Int?
    var m_lastDeleteReqId: Int?
    var m_lastReconfReqId: Int?
    var m_currentMaxFrequency: Subscription.RequestedMaxFrequency?
    var m_reqMaxFrequency: Subscription.RequestedMaxFrequency?
    unowned let m_client: LightstreamerClient
    var s_m: State_m
    var s_s: State_s?
    var s_c: State_c?
    let lock: NSRecursiveLock
    
    init(_ sub: Subscription, _ client: LightstreamerClient) {
        lock = client.lock
        m_subId = client.generateFreshSubId()
        switch sub.mode {
        case .MERGE:
            m_strategy = ModeStrategyMerge(sub, client, subId: m_subId)
        case .COMMAND:
            if is2LevelCommand(sub) {
                m_strategy = ModeStrategyCommand2Level(sub, client, subId: m_subId)
            } else {
                m_strategy = ModeStrategyCommand1Level(sub, client, subId: m_subId)
            }
        case .DISTINCT:
            m_strategy = ModeStrategyDistinct(sub, client, subId: m_subId)
        case .RAW:
            m_strategy = ModeStrategyRaw(sub, client, subId: m_subId)
        }
        s_m = .s1
        m_client = client
        m_subscription = sub
        m_client.relate(to: self)
        m_subscription.relate(to: self)
    }
    
    private func finalize() {
        m_strategy.evtDispose()
        m_client.unrelate(from: self)
        m_subscription.unrelate(from: self)
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    private func synchronized<T>(_ block: () throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try block()
    }
    
    var subId: Int {
        synchronized {
            m_subId
        }
    }
    
    var subscription: Subscription {
        synchronized {
            m_subscription
        }
    }
    
    func evtExtSubscribe() {
        synchronized {
            let evt = "subscribe"
            if s_m == .s1 {
                trace(evt, State_m.s1, State_m.s2)
                doSetActive()
                doSubscribe()
                s_m = .s2
                genSendControl()
            }
        }
    }
    
    func evtExtUnsubscribe() {
        synchronized {
            let evt = "unsubscribe"
            if s_m == .s2 {
                trace(evt, State_m.s2, State_m.s30)
                doSetInactive()
                finalize()
                s_m = .s30
            } else if s_m == .s3 {
                trace(evt, State_m.s3, State_m.s5)
                doUnsubscribe()
                doSetInactive()
                s_m = .s5
                genSendControl()
            } else if s_s == .s10 {
                trace(evt, State_s.s10, State_m.s5)
                doUnsubscribe()
                m_subscription.setInactive()
                notifyOnUnsubscription()
                s_m = .s5
                s_s = nil
                s_c = nil
                genSendControl()
            }
        }
    }
    
    func evtExtAbort() {
        synchronized {
            let evt = "abort"
            if s_m == .s2 {
                trace(evt, State_m.s2, State_m.s2)
                s_m = .s2
            } else if s_m == .s3 {
                trace(evt, State_m.s3, State_m.s2)
                doAbort()
                doSetActive()
                s_m = .s2
            } else if s_s == .s10 {
                trace(evt, State_s.s10, State_m.s2)
                doAbort()
                doSetActive()
                notifyOnUnsubscription()
                s_s = nil
                s_c = nil
                s_m = .s2
            } else if s_m == .s5 {
                trace(evt, State_m.s5, State_m.s32)
                finalize()
                s_m = .s32
            }
        }
    }
    
    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String) {
        synchronized {
            let evt = "REQERR"
            if s_m == .s2 && reqId == m_lastAddReqId {
                trace(evt, State_m.s2, State_m.s30)
                doSetInactive()
                notifyOnSubscriptionError(code, msg)
                finalize()
                s_m = .s30
            } else if s_m == .s5 && reqId == m_lastDeleteReqId {
                trace(evt, State_m.s5, State_m.s32)
                finalize()
                s_m = .s32
            } else if s_c == .s22 && reqId == m_lastReconfReqId {
                if m_reqMaxFrequency == m_subscription.requestedMaxFrequency {
                    trace(evt, State_c.s22, State_c.s21)
                    s_c = .s21
                } else {
                    trace(evt, State_c.s22, State_c.s20)
                    s_c = .s20
                    evtCheckFrequency()
                }
            }
        }
    }
    
    func evtREQOK(_ reqId: Int) {
        synchronized {
            let evt = "REQOK"
            if s_m == .s2 && reqId == m_lastAddReqId {
                trace(evt, State_m.s2, State_m.s3)
                s_m = .s3
            } else if s_m == .s5 && reqId == m_lastDeleteReqId {
                trace(evt, State_m.s5, State_m.s32)
                finalize()
                s_m = .s32
            } else if s_c == .s22 && reqId == m_lastReconfReqId {
                trace(evt, State_c.s22, State_c.s20)
                doREQOKConfigure()
                s_c = .s20
                evtCheckFrequency()
            }
        }
    }
    
    func evtSUBOK(nItems: Int, nFields: Int) {
        synchronized {
            let evt = "SUBOK"
            if s_m == .s2 {
                trace(evt, State_m.s2, State_m.s4)
                doSUBOK(nItems, nFields)
                notifyOnSubscription()
                s_m = .s4
                s_s = .s10
                s_c = .s20
                evtCheckFrequency()
            } else if s_m == .s3 {
                trace(evt, State_m.s3, State_m.s4)
                doSUBOK(nItems, nFields)
                notifyOnSubscription()
                s_m = .s4
                s_s = .s10
                s_c = .s20
                evtCheckFrequency()
            }
        }
    }
    
    func evtSUBCMD(nItems: Int, nFields: Int, keyIdx: Int, cmdIdx: Int) {
        synchronized {
            let evt = "SUBCMD"
            if s_m == .s2 {
                trace(evt, State_m.s2, State_m.s4)
                doSUBCMD(nItems, nFields, cmdIdx: cmdIdx, keyIdx: keyIdx)
                notifyOnSubscription()
                s_m = .s4
                s_s = .s10
                s_c = .s20
                evtCheckFrequency()
            } else if s_m == .s3 {
                trace(evt, State_m.s3, State_m.s4)
                doSUBCMD(nItems, nFields, cmdIdx: cmdIdx, keyIdx: keyIdx)
                notifyOnSubscription()
                s_m = .s4
                s_s = .s10
                s_c = .s20
                evtCheckFrequency()
            }
        }
    }
    
    func evtUNSUB() {
        synchronized {
            let evt = "UNSUB"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_m.s31)
                doUNSUB()
                doSetInactive()
                notifyOnUnsubscription()
                finalize()
                s_m = .s31
                s_s = nil
                s_c = nil
            } else if s_m == .s5 {
                trace(evt, State_m.s5, State_m.s32)
                finalize()
                s_m = .s32
            }
        }
    }
    
    func evtU(_ itemIdx: Int, _ values: [Pos:FieldValue]) throws {
        try synchronized {
            let evt = "U"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_s.s10)
                try doU(itemIdx, values)
                s_s = .s10
            }
        }
    }
    
    func evtEOS(_ itemIdx: Int) {
        synchronized {
            let evt = "EOS"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_s.s10)
                doEOS(itemIdx)
                s_s = .s10
            }
        }
    }
    
    func evtCS(_ itemIdx: Int) {
        synchronized {
            let evt = "CS"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_s.s10)
                doCS(itemIdx)
                s_s = .s10
            }
        }
    }
    
    func evtOV(_ itemIdx: Int, _ lostUpdates: Int) {
        synchronized {
            let evt = "OV"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_s.s10)
                doOV(itemIdx, lostUpdates)
                s_s = .s10
            }
        }
    }
    
    func evtCONF(_ freq: RealMaxFrequency) {
        synchronized {
            let evt = "CONF"
            if s_s == .s10 {
                trace(evt, State_s.s10, State_s.s10)
                doCONF(freq)
                s_s = .s10
            }
        }
    }
    
    func evtCheckFrequency() {
        synchronized {
            let evt = "check.frequency"
            if s_c == .s20 {
                if m_subscription.requestedMaxFrequency != m_currentMaxFrequency {
                    trace(evt, State_c.s20, State_c.s22)
                    doConfigure()
                    s_c = .s22
                    genSendControl()
                } else {
                    trace(evt, State_c.s20, State_c.s21)
                    s_c = .s21
                }
            }
        }
    }
    
    func evtExtConfigure() {
        synchronized {
            let evt = "configure"
            if s_c == .s21 {
                trace(evt, State_c.s21, State_c.s20)
                s_c = .s20
                evtCheckFrequency()
            }
        }
    }
    
    func isPending() -> Bool {
        synchronized {
            s_m == .s2 || s_m == .s5 || s_c == .s22
        }
    }
    
    func encode(isWS: Bool) -> String {
        synchronized {
            if s_m == .s2 {
                return encodeAdd(isWS: isWS)
            } else if s_m == .s5 {
                return encodeDelete(isWS: isWS)
            } else if s_c == .s22 {
                return encodeReconf(isWS: isWS)
            } else {
                preconditionFailure()
            }
        }
    }
    
    func encodeWS() -> String {
        synchronized {
            "control\r\n\(encode(isWS: true))"
        }
    }
    
    func getValue(_ itemPos: Pos, _ fieldPos: Pos) -> String? {
        synchronized {
            m_strategy.getValue(itemPos, fieldPos)
        }
    }
    
    func getCommandValue(_ itemPos: Int, _ key: String, _ fieldPos: Int) -> String? {
        synchronized {
            m_strategy.getCommandValue(itemPos, key, fieldPos)
        }
    }
    
    private func encodeAdd(isWS: Bool) -> String {
        let req = LsRequestBuilder()
        m_lastAddReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastAddReqId!)
        req.LS_op("add")
        req.LS_subId(m_subId)
        req.LS_mode(m_subscription.mode.rawValue)
        if let group = m_subscription.itemGroup {
            req.LS_group(group)
        } else if let items = m_subscription.items {
            req.LS_group(items.joined(separator: " "))
        }
        if let schema = m_subscription.fieldSchema {
            req.LS_schema(schema)
        } else if let fields = m_subscription.fields {
            req.LS_schema(fields.joined(separator: " "))
        }
        if let adapter = m_subscription.dataAdapter {
            req.LS_data_adapter(adapter)
        }
        if let selector = m_subscription.selector {
            req.LS_selector(selector)
        }
        if let snapshot = m_subscription.requestedSnapshot {
            switch snapshot {
            case .yes:
                req.LS_snapshot(true)
            case .no:
                req.LS_snapshot(false)
            case .length(let len):
                req.LS_snapshot(len)
            }
        }
        if let freq = m_currentMaxFrequency {
            switch freq {
            case .limited(let limit):
                req.LS_requested_max_frequency(limit)
            case .unlimited:
                req.LS_requested_max_frequency("unlimited")
            case .unfiltered:
                req.LS_requested_max_frequency("unfiltered")
            }
        }
        if let buff = m_subscription.requestedBufferSize {
            switch buff {
            case .limited(let limit):
                req.LS_requested_buffer_size(limit)
            case .unlimited:
                req.LS_requested_buffer_size("unlimited")
            }
        }
        if isWS {
            req.LS_ack(false)
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending Subscription add: \(req)")
        }
        return req.encodedString
    }
    
    private func encodeDelete(isWS: Bool) -> String {
        let req = LsRequestBuilder()
        m_lastDeleteReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastDeleteReqId!)
        req.LS_subId(m_subId)
        req.LS_op("delete")
        if isWS {
            req.LS_ack(false)
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending Subscription delete: \(req)")
        }
        return req.encodedString
    }
    
    private func encodeReconf(isWS: Bool) -> String {
        let req = LsRequestBuilder()
        m_lastReconfReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastReconfReqId!)
        req.LS_subId(m_subId)
        req.LS_op("reconf")
        if let freq = m_reqMaxFrequency {
            switch freq {
            case .limited(let limit):
                req.LS_requested_max_frequency(limit)
            case .unlimited:
                req.LS_requested_max_frequency("unlimited")
            case .unfiltered:
                req.LS_requested_max_frequency("unfiltered")
            }
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending Subscription configuration: \(req)")
        }
        return req.encodedString
    }
    
    private func doSetActive() {
        m_subscription.setActive()
    }
    
    private func doSetInactive() {
        m_subscription.setInactive()
    }
    
    private func doSubscribe() {
        m_currentMaxFrequency = m_subscription.requestedMaxFrequency
    }
    
    private func doUnsubscribe() {
        m_strategy.evtUnsubscribe()
        m_subscription.unrelate(from: self)
    }
    
    private func doAbort() {
        m_lastAddReqId = nil
        m_lastDeleteReqId = nil
        m_lastReconfReqId = nil
        m_reqMaxFrequency = nil
        m_currentMaxFrequency = m_subscription.requestedMaxFrequency
        m_strategy.evtAbort()
    }
    
    private func genSendControl() {
        m_client.evtSendControl(self)
    }
    
    private func notifyOnSubscription() {
        m_subscription.fireOnSubscription(subId: m_subId)
    }
    
    private func notifyOnUnsubscription() {
        m_subscription.fireOnUnsubscription(subId: m_subId)
    }
    
    private func notifyOnSubscriptionError(_ code: Int, _ msg: String) {
        m_subscription.fireOnSubscriptionError(subId: m_subId, code, msg)
    }
    
    private func doConfigure() {
        m_reqMaxFrequency = m_subscription.requestedMaxFrequency
        m_strategy.evtSetRequestedMaxFrequency(m_reqMaxFrequency)
    }
    
    private func doREQOKConfigure() {
        m_currentMaxFrequency = m_reqMaxFrequency
    }
    
    private func doSUBOK(_ nItems: Int, _ nFields: Int) {
        m_subscription.setSubscribed(subId: m_subId, nItems: nItems, nFields: nFields)
        m_strategy.evtOnSUB(nItems, nFields)
    }
    
    private func doSUBCMD(_ nItems: Int, _ nFields: Int, cmdIdx: Int, keyIdx: Int) {
        m_subscription.setSubscribed(subId: m_subId, nItems: nItems, nFields: nFields, cmdIdx: cmdIdx, keyIdx: keyIdx)
        m_strategy.evtOnSUB(nItems, nFields, cmdIdx: cmdIdx, keyIdx: keyIdx, m_currentMaxFrequency)
    }
    
    private func doUNSUB() {
        m_strategy.evtOnUNSUB()
    }
    
    private func doU(_ itemIdx: Int, _ values: [Pos:FieldValue]) throws {
        assert(itemIdx <= m_subscription.nItems)
        try m_strategy.evtUpdate(itemIdx, values)
    }
    
    private func doEOS(_ itemIdx: Int) {
        m_strategy.evtOnEOS(itemIdx)
        m_subscription.fireOnEndOfSnapshot(itemIdx, subId: m_subId)
    }
    
    private func doCS(_ itemIdx: Int) {
        m_strategy.evtOnCS(itemIdx)
        m_subscription.fireOnClearSnapshot(itemIdx, subId: m_subId)
    }
    
    private func doOV(_ itemIdx: Int, _ lostUpdates: Int) {
        m_subscription.fireOnLostUpdates(itemIdx, lostUpdates, subId: m_subId)
    }
    
    private func doCONF(_ freq: RealMaxFrequency) {
        m_strategy.evtOnCONF(freq)
    }
    
    private func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("sub#\(evt):\(subId) \(from.id)->\(to.id)")
        }
    }
}

private func is2LevelCommand(_ sub: Subscription) -> Bool {
    sub.mode == .COMMAND && (sub.commandSecondLevelFields != nil || sub.commandSecondLevelFieldSchema != nil)
}

