/*
 * Copyright (C) 2021 Lightstreamer Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation

class SubscriptionManagerZombie: SubscriptionManager {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3
        
        var id: Int {
            self.rawValue
        }
    }
    
    let m_subId: Int
    var s_m: State_m = .s1
    let lock: NSRecursiveLock
    var m_lastDeleteReqId: Int?
    unowned let m_client: LightstreamerClient
    
    init(_ subId: Int, _ client: LightstreamerClient) {
        self.m_subId = subId
        self.lock = client.lock
        self.m_client = client
        client.relate(to: self)
    }
    
    private func finalize() {
        m_client.unrelate(from: self)
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    var subId: Int {
        synchronized {
            m_subId
        }
    }
    
    func evtExtAbort() {
        let evt = "abort"
        if s_m == .s2 {
            trace(evt, State_m.s2, State_m.s3)
            finalize()
            s_m = .s3
        }
    }
    
    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String) {
        let evt = "REQERR"
        if s_m == .s2 && reqId == m_lastDeleteReqId {
            trace(evt, State_m.s2, State_m.s3)
            finalize()
            s_m = .s3
        }
    }
    
    func evtREQOK(_ reqId: Int) {
        let evt = "REQOK"
        if s_m == .s2 && reqId == m_lastDeleteReqId {
            trace(evt, State_m.s2, State_m.s3)
            finalize()
            s_m = .s3
        }
    }
    
    func evtSUBOK(nItems: Int, nFields: Int) {
        let evt = "SUBOK"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtSUBCMD(nItems: Int, nFields: Int, keyIdx: Int, cmdIdx: Int) {
        let evt = "SUBCMD"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtUNSUB() {
        let evt = "UNSUB"
        if s_m == .s2 {
            trace(evt, State_m.s2, State_m.s3)
            finalize()
            s_m = .s3
        }
    }
    
    func evtU(_ itemIdx: Int, _ values: [Pos : FieldValue]) {
        let evt = "U"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtEOS(_ itemIdx: Int) {
        let evt = "EOS"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtCS(_ itemIdx: Int) {
        let evt = "CS"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtOV(_ itemIdx: Int, _ lostUpdates: Int) {
        let evt = "OV"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func evtCONF(_ freq: RealMaxFrequency) {
        let evt = "CONF"
        if s_m == .s1 {
            trace(evt, State_m.s1, State_m.s2)
            s_m = .s2
            genSendControl()
        }
    }
    
    func isPending() -> Bool {
        synchronized {
            s_m == .s2
        }
    }
    
    func encode(isWS: Bool) -> String {
        synchronized {
            if isPending() {
                return encodeDelete(isWS: isWS)
            } else {
                fatalError()
            }
        }
    }
    
    func encodeWS() -> String {
        synchronized {
            "control\r\n\(encode(isWS: true))"
        }
    }
    
    private func genSendControl() {
        m_client.evtSendControl(self)
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
        req.LS_cause("zombie")
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending Subscription delete: \(req)")
        }
        return req.encodedString
    }
    
    private func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("zsub#\(evt):\(subId) \(from.id)->\(to.id)")
        }
    }
}
