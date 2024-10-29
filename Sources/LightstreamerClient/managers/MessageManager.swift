import Foundation

class MessageManager: Encodable, CustomStringConvertible {
    
    enum State_m: Int, State {
        case s1 = 1
        case s10 = 10, s11 = 11, s12 = 12, s13 = 13, s14 = 14, s15 = 15
        case s20 = 20, s21 = 21, s22 = 22, s23 = 23, s24 = 24
        case s30 = 30, s31 = 31, s32 = 32, s33 = 33, s34 = 34, s35 = 35
        
        var id: Int {
            self.rawValue
        }
    }
    
    let txt: String
    let sequence: String
    let prog: Int
    let maxWait: Int
    let delegate: ClientMessageDelegate?
    let enqueueWhileDisconnected: Bool
    unowned let client: LightstreamerClient
    var lastReqId: Int!
    var s_m: State_m
    
    init(txt: String, sequence: String, maxWait: Int, delegate: ClientMessageDelegate?, enqueueWhileDisconnected: Bool, client: LightstreamerClient) {
        self.txt = txt
        self.sequence = sequence
        let isOrdered = sequence != "UNORDERED_MESSAGES"
        let hasListener = delegate != nil
        if isOrdered || hasListener {
            self.prog = client.getAndSetNextMsgProg(sequence)
        } else {
            // fire-and-forget
            self.prog = -1
        }
        self.maxWait = maxWait
        self.delegate = delegate
        self.enqueueWhileDisconnected = enqueueWhileDisconnected
        self.client = client
        if delegate != nil {
            s_m = .s10
        } else if sequence != "UNORDERED_MESSAGES" {
            s_m = .s20
        } else {
            s_m = .s30
        }
        client.relate(to: self)
    }
    
    private func finalize() {
        client.unrelate(from: self)
    }
    
    func evtExtSendMessage() {
        let evt = "sendMessage"
        switch s_m {
        case .s10:
            trace(evt, State_m.s10, State_m.s11)
            s_m = .s11
            client.evtSendMessage(self)
        case .s20:
            trace(evt, State_m.s20, State_m.s21)
            s_m = .s21
            client.evtSendMessage(self)
        case .s30:
            trace(evt, State_m.s30, State_m.s31)
            s_m = .s31
            client.evtSendMessage(self)
        default:
            break
        }
    }
    
    func evtMSGDONE(_ response: String) {
        let evt = "MSGDONE"
        switch s_m {
        case .s10:
            trace(evt, State_m.s10, State_m.s13)
            finalize()
            s_m = .s13
        case .s11:
            trace(evt, State_m.s11, State_m.s13)
            doMSGDONE(response)
            finalize()
            s_m = .s13
        case .s12:
            trace(evt, State_m.s12, State_m.s13)
            doMSGDONE(response)
            finalize()
            s_m = .s13
        default:
            break
        }
    }
    
    func evtMSGFAIL(_ code: Int, _ msg: String) {
        let evt = "MSGFAIL"
        switch s_m {
        case .s10:
            trace(evt, State_m.s10, State_m.s13)
            finalize()
            s_m = .s13
        case .s11:
            trace(evt, State_m.s11, State_m.s14)
            doMSGFAIL(code, msg)
            finalize()
            s_m = .s14
        case .s12:
            trace(evt, State_m.s12, State_m.s14)
            doMSGFAIL(code, msg)
            finalize()
            s_m = .s14
        default:
            break
        }
    }
    
    func evtREQOK(_ reqId: Int) {
        let evt = "REQOK"
        switch s_m {
        case .s11 where reqId == lastReqId:
            trace(evt, State_m.s11, State_m.s12)
            s_m = .s12
        case .s21 where reqId == lastReqId:
            trace(evt, State_m.s21, State_m.s22)
            finalize()
            s_m = .s22
        case .s31 where reqId == lastReqId:
            trace(evt, State_m.s31, State_m.s33)
            finalize()
            s_m = .s33
        default:
            break
        }
    }
    
    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String) {
        let evt = "REQERR"
        switch s_m {
        case .s11 where reqId == lastReqId:
            trace(evt, State_m.s11, State_m.s14)
            doREQERR(code, msg)
            finalize()
            s_m = .s14
        case .s21 where reqId == lastReqId:
            trace(evt, State_m.s21, State_m.s23)
            finalize()
            s_m = .s23
        case .s31 where reqId == lastReqId:
            trace(evt, State_m.s31, State_m.s34)
            finalize()
            s_m = .s34
        default:
            break
        }
    }
    
    func evtAbort() {
        let evt = "abort"
        switch s_m {
        case .s11:
            trace(evt, State_m.s11, State_m.s15)
            doAbort()
            finalize()
            s_m = .s15
        case .s12:
            trace(evt, State_m.s12, State_m.s15)
            doAbort()
            finalize()
            s_m = .s15
        case .s21:
            trace(evt, State_m.s21, State_m.s24)
            if messageLogger.isWarnEnabled {
                messageLogger.warn("Message \(sequence):\(prog) aborted")
            }
            finalize()
            s_m = .s24
        case .s31:
            trace(evt, State_m.s31, State_m.s35)
            if messageLogger.isWarnEnabled {
                messageLogger.warn("Message \(sequence):\(prog) aborted")
            }
            finalize()
            s_m = .s35
        default:
            break
        }
    }
    
    func evtWSSent() {
        let evt = "ws.sent"
        if s_m == .s31 {
            trace(evt, State_m.s31, State_m.s32)
            finalize()
            s_m = .s32
        }
    }
    
    func isPending() -> Bool {
        s_m == .s11 || s_m == .s21 || s_m == .s31
    }
    
    func encode(isWS: Bool) -> String {
        encodeMsg(isWS: isWS)
    }
    
    func encodeWS() -> String {
        "msg\r\n" + encode(isWS: true)
    }
    
    var description: String {
        var map = OrderedDictionary<String, CustomStringConvertible>()
        map["text"] = String(reflecting: txt)
        map["sequence"] = sequence
        map["prog"]  = prog
        map["timeout"] = maxWait >= 0 ? maxWait : nil
        map["enqueueWhileDisconnected"] = enqueueWhileDisconnected ? true : nil
        return String(describing: map)
    }
    
    private func doMSGDONE(_ response: String) {
        fireOnProcessed(response)
    }
    
    private func doMSGFAIL(_ code: Int, _ msg: String) {
        if code == 38 || code == 39 {
            fireOnDiscarded()
        } else if code <= 0 {
            fireOnDeny(code, msg)
        } else if code != 32 && code != 33 {
            /*
                errors 32 and 33 must not be notified to the user
                because they are due to late responses of the server
             */
            fireOnError()
        }
    }
    
    private func doREQERR(_ code: Int, _ msg: String) {
        if code != 32 && code != 33 {
            /*
                errors 32 and 33 must not be notified to the user
                because they are due to late responses of the server
             */
            fireOnError()
        }
    }
    
    private func doAbort() {
        fireOnAbort()
    }
    
    private func encodeMsg(isWS: Bool) -> String {
        let isOrdered = sequence != "UNORDERED_MESSAGES"
        let hasListener = delegate != nil
        let req = LsRequestBuilder()
        lastReqId = client.generateFreshReqId()
        req.LS_reqId(lastReqId)
        req.LS_message(txt)
        if isOrdered && hasListener {
            // LS_outcome=true is the default
            // LS_ack=true is the default
            req.LS_sequence(sequence)
            req.LS_msg_prog(prog)
            if maxWait >= 0 {
                req.LS_max_wait(maxWait)
            }
        } else if !isOrdered && hasListener {
            // LS_outcome=true is the default
            // LS_ack=true is the default
            // LS_sequence=UNORDERED_MESSAGES is the default
            req.LS_msg_prog(prog)
            // LS_max_wait is ignored
        } else if isOrdered && !hasListener {
            req.LS_outcome(false)
            // LS_ack=true is the default
            req.LS_sequence(sequence)
            req.LS_msg_prog(prog)
            if maxWait >= 0 {
                req.LS_max_wait(maxWait)
            }
        } else if !isOrdered && !hasListener { // fire-and-forget
            req.LS_outcome(false)
            if isWS {
                req.LS_ack(false)
            } // else ack is always sent in HTTP
            // LS_sequence=UNORDERED_MESSAGES is the default
            // LS_prog is ignored
            // LS_max_wait is ignored
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending message: \(req)")
        }
        return req.encodedString
    }
    
    private func fireOnProcessed(_ response: String) {
        if messageLogger.isInfoEnabled {
            messageLogger.info("Message \(sequence):\(prog) processed")
        }
        client.callbackQueue.async {
            self.delegate?.client(self.client, didProcessMessage: self.txt, withResponse: response)
        }
    }
    
    private func fireOnDiscarded() {
        if messageLogger.isWarnEnabled {
            messageLogger.warn("Message \(sequence):\(prog) discarded")
        }
        client.callbackQueue.async {
            self.delegate?.client(self.client, didDiscardMessage: self.txt)
        }
    }
    
    private func fireOnDeny(_ code: Int, _ msg: String) {
        if messageLogger.isWarnEnabled {
            messageLogger.warn("Message \(sequence):\(prog) denied: \(code) - \(msg)")
        }
        client.callbackQueue.async {
            self.delegate?.client(self.client, didDenyMessage: self.txt, withCode: code, error: msg)
        }
    }
    
    private func fireOnError() {
        if messageLogger.isWarnEnabled {
            messageLogger.warn("Message \(sequence):\(prog) failed")
        }
        client.callbackQueue.async {
            self.delegate?.client(self.client, didFailMessage: self.txt)
        }
    }
    
    private func fireOnAbort() {
        if messageLogger.isWarnEnabled {
            messageLogger.warn("Message \(sequence):\(prog) aborted")
        }
        client.callbackQueue.async {
            self.delegate?.client(self.client, didAbortMessage: self.txt, sentOnNetwork: false)
        }
    }
    
    private func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("msg#\(evt):\(sequence):\(prog) \(from.id)->\(to.id)")
        }
    }
}
