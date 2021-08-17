import Foundation

class MpnSubscriptionManager: Encodable {
    
    enum State_uu: Int, State {
        case s10 = 10, s11 = 11, s12 = 12
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_fu: Int, State {
        case s20 = 20, s21 = 21, s22 = 22, s23 = 23
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_tu: Int, State {
        case s30 = 30, s31 = 31, s32 = 32, s33 = 33
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_m: Int, State {
        case s40 = 40, s41 = 41, s42 = 42, s43 = 43, s44 = 44, s45 = 45
        case s50 = 50, s51 = 51, s52 = 52
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_st: Int, State {
        case s60 = 60, s61 = 61
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_ab: Int, State {
        case s80 = 80, s81 = 81
        
        var id: Int {
            self.rawValue
        }
    }
    
    enum State_ct: Int, State {
        case s70 = 70, s71 = 71, s72 = 72, s73 = 73, s74 = 74, s75 = 75, s76 = 76
        
        var id: Int {
            self.rawValue
        }
    }
    
    let lock: NSRecursiveLock
    var s_m: State_m
    var s_uu: State_uu = .s10
    var s_fu: State_fu = .s20
    var s_tu: State_tu = .s30
    var s_st: State_st?
    var s_ab: State_ab?
    var s_ct: State_ct?
    let m_subId: Int!
    let m_coalescing: Bool
    var m_lastActivateReqId: Int?
    var m_lastConfigureReqId: Int?
    var m_lastDeactivateReqId: Int?
    let m_initFormat: String?
    let m_initTrigger: String?
    var m_currentFormat: String?
    var m_currentTrigger: String?
    let m_subscription: MPNSubscription
    unowned let m_client: LightstreamerClient
        
    init(_ sub: MPNSubscription, coalescing: Bool, _ client: LightstreamerClient) {
        self.lock = client.lock
        m_subId = client.generateFreshSubId()
        m_coalescing = coalescing
        m_initFormat = sub.requestedFormat
        m_initTrigger = sub.requestedTrigger
        m_subscription = sub
        m_client = client
        s_m = .s40
        m_subscription.relate(to: self)
        m_client.relate(to: self)
    }
    
    init(_ mpnSubId: String, _ client: LightstreamerClient) {
        self.lock = client.lock
        m_subId = nil
        m_coalescing = false
        m_initFormat = nil
        m_initTrigger = nil
        m_subscription = MPNSubscription(mpnSubId)
        m_client = client
        s_m = .s45
        m_subscription.relate(to: self)
        m_client.relate(to: self)
    }
    
    private func finalize() {
        m_subscription.reset()
        m_client.unrelate(from: self)
        m_subscription.unrelate(from: self)
    }
    
    var mpnSubId: String? {
        synchronized {
            m_subscription.m_mpnSubId
        }
    }
    
    var subId: Int {
        synchronized {
            m_subId
        }
    }
    
    func start() {}

    func evtExtMpnUnsubscribe() {
        synchronized {
            let evt = "unsubscribe"
            var forward = true
            if s_m == .s41 {
                trace(evt, State_m.s41, State_m.s50)
                notifyStatus(.UNKNOWN)
                notifyOnSubscriptionDiscarded()
                finalize()
                s_m = .s50
                forward = evtExtMpnUnsubscribe_UnsubRegion()
            } else if s_ct == .s71 {
                trace(evt, State_ct.s71, State_ct.s70)
                s_ct = .s70
                forward = evtExtMpnUnsubscribe_UnsubRegion()
                evtCheck()
            }
            if forward {
                forward = evtExtMpnUnsubscribe_UnsubRegion()
            }
        }
    }
    
    private func evtExtMpnUnsubscribe_UnsubRegion() -> Bool {
        let evt = "unsubscribe"
        if s_uu == .s10 {
            trace(evt, State_uu.s10, State_uu.s11)
            s_uu = .s11
        } else if s_uu == .s12 {
            trace(evt, State_uu.s12, State_uu.s11)
            s_uu = .s11
        }
        return false
    }
    
    func evtAbort() {
        synchronized {
            let evt = "abort"
            if s_m == .s41 {
                trace(evt, State_m.s41, State_m.s50)
                notifyStatus(.UNKNOWN)
                notifyOnSubscriptionDiscarded()
                finalize()
                s_m = .s50
            } else if s_m == .s42 || s_m == .s43 {
                trace(evt, s_m, State_m.s50)
                notifyStatus(.UNKNOWN)
                notifyOnSubscriptionAbort()
                finalize()
                s_m = .s50
            } else if s_m == .s44 {
                evtAbort_AbortRegion()
            }
        }
    }
    
    private func evtAbort_AbortRegion() {
        let evt = "abort"
        var forward = true
        if s_ab == .s80 {
            trace(evt, State_ab.s80, State_ab.s81)
            s_ab = .s81
            forward = evtAbort_ControlRegion()
        }
        if forward {
            forward = evtAbort_ControlRegion()
        }
    }
    
    private func evtAbort_ControlRegion() -> Bool {
        let evt = "abort"
        if s_ct == .s70 || s_ct == .s71 || s_ct == .s72 || s_ct == .s73 || s_ct == .s74 {
            trace(evt, s_ct!, State_ct.s76)
            s_ct = .s76
            evtAbortFormat()
            evtAbortTrigger()
            evtAbortUnsubscribe()
        }
        return false
    }
    
    func evtRestoreSession() {
        synchronized {
            let evt = "restore.session"
            if s_ct == .s76 {
                trace(evt, State_ct.s76, State_ct.s70)
                s_ct = .s70
                evtCheck()
            }
        }
    }
    
    func evtREQOK(_ reqId: Int) {
        synchronized {
            let evt = "REQOK"
            var forward = true
            if s_fu == .s22 && reqId == m_lastConfigureReqId {
                trace(evt, State_fu.s22, State_fu.s20)
                s_fu = .s20
                forward = evtREQOK_TriggerRegion(reqId)
            } else if s_fu == .s23 && reqId == m_lastConfigureReqId {
                trace(evt, State_fu.s23, State_fu.s21)
                s_fu = .s21
                forward = evtREQOK_TriggerRegion(reqId)
            }
            if forward {
                forward = evtREQOK_TriggerRegion(reqId)
            }
        }
    }
    
    private func evtREQOK_TriggerRegion(_ reqId: Int) -> Bool {
        let evt = "REQOK"
        var forward = true
        if s_tu == .s32 && reqId == m_lastConfigureReqId {
            trace(evt, State_tu.s32, State_tu.s30)
            s_tu = .s30
            forward = evtREQOK_MainRegion(reqId)
        } else if s_tu == .s33 && reqId == m_lastConfigureReqId {
            trace(evt, State_tu.s33, State_tu.s31)
            s_tu = .s31
            forward = evtREQOK_MainRegion(reqId)
        }
        if forward {
            forward = evtREQOK_MainRegion(reqId)
        }
        return false
    }
    
    private func evtREQOK_MainRegion(_ reqId: Int) -> Bool {
        let evt = "REQOK"
        if s_m == .s42 && reqId == m_lastActivateReqId {
            trace(evt, State_m.s42, State_m.s43)
            s_m = .s43
        } else if s_m == .s44 {
            evtREQOK_ControlRegion(reqId)
        }
        return false
    }
    
    private func evtREQOK_ControlRegion(_ reqId: Int) {
        let evt = "REQOK"
        if s_ct == .s72 && reqId == m_lastDeactivateReqId {
            trace(evt, State_ct.s72, State_m.s52)
            notifyStatus(.UNKNOWN)
            notifyOnUnsubscription()
            notifyOnSubscriptionsUpdated()
            finalize()
            s_m = .s52
            s_st = nil
            s_ct = nil
            s_ab = nil
        } else if (s_ct == .s73 || s_ct == .s74) && reqId == m_lastConfigureReqId {
            trace(evt, s_ct!, State_ct.s70)
            s_ct = .s70
            evtCheck()
        }
    }
    
    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String) {
        synchronized {
            let evt = "REQERR"
            var forward = true
            if s_uu == .s11 && reqId == m_lastDeactivateReqId {
                trace(evt, State_uu.s11, State_uu.s12)
                notifyOnUnsubscriptionError(code, msg)
                s_uu = .s12
                forward = evtREQERR_FormatRegion(reqId, code, msg)
            }
            if forward {
                forward = evtREQERR_FormatRegion(reqId, code, msg)
            }
        }
    }
    
    private func evtREQERR_FormatRegion(_ reqId: Int, _ code: Int, _ msg: String) -> Bool {
        let evt = "REQERR"
        var forward = true
        if s_fu == .s22 && reqId == m_lastConfigureReqId {
            trace(evt, State_fu.s22, State_fu.s20)
            notifyOnModificationError_Format(code, msg)
            s_fu = .s20
            forward = evtREQERR_TriggerRegion(reqId, code, msg)
        } else if s_fu == .s23 && reqId == m_lastConfigureReqId {
            trace(evt, State_fu.s23, State_fu.s21)
            s_fu = .s21
            forward = evtREQERR_TriggerRegion(reqId, code, msg)
        }
        if forward {
            forward = evtREQERR_TriggerRegion(reqId, code, msg)
        }
        return false
    }
    
    private func evtREQERR_TriggerRegion(_ reqId: Int, _ code: Int, _ msg: String) -> Bool {
        let evt = "REQERR"
        var forward = true
        if s_tu == .s32 && reqId == m_lastConfigureReqId {
            trace(evt, State_tu.s32, State_tu.s30)
            notifyOnModificationError_Trigger(code, msg)
            s_tu = .s30
            forward = evtREQERR_MainRegion(reqId, code, msg)
        } else if s_tu == .s33 && reqId == m_lastConfigureReqId {
            trace(evt, State_tu.s33, State_tu.s31)
            s_tu = .s31
            forward = evtREQERR_MainRegion(reqId, code, msg)
        }
        if forward {
            forward = evtREQERR_MainRegion(reqId, code, msg)
        }
        return false
    }
    
    private func evtREQERR_MainRegion(_ reqId: Int, _ code: Int, _ msg: String) -> Bool {
        let evt = "REQERR"
        if s_m == .s42 && reqId == m_lastActivateReqId {
            trace(evt, State_m.s42, State_m.s50)
            notifyStatus(.UNKNOWN)
            notifyOnSubscriptionError(code, msg)
            finalize()
            s_m = .s50
        } else if s_m == .s44 {
            evtREQERR_ControlRegion(reqId, code, msg)
        }
        return false
    }
    
    private func evtREQERR_ControlRegion(_ reqId: Int, _ code: Int, _ msg: String) {
        let evt = "REQERR"
        if s_ct == .s72 && reqId == m_lastDeactivateReqId {
            trace(evt, State_ct.s72, State_ct.s70)
            s_ct = .s70
            evtCheck()
        }  else if (s_ct == .s73 || s_ct == .s74) && reqId == m_lastConfigureReqId {
            trace(evt, s_ct!, State_ct.s70)
            s_ct = .s70
            evtCheck()
        }
    }
    
    func evtAbortUnsubscribe() {
        synchronized {
            let evt = "abort.unsubscribe"
            if s_uu == .s11 {
                trace(evt, State_uu.s11, State_uu.s12)
                notifyOnUnsubscriptionAbort()
                s_uu = .s12
            }
        }
    }
    
    func evtExtMpnSetFormat() {
        synchronized {
            let evt = "setFormat"
            var forward = true
            if s_fu == .s20 {
                trace(evt, State_fu.s20, State_fu.s21)
                s_fu = .s21
                forward = evtExtMpnSetFormat_ControlRegion()
            } else if s_fu == .s22 {
                trace(evt, State_fu.s22, State_fu.s23)
                s_fu = .s23
                forward = evtExtMpnSetFormat_ControlRegion()
            }
            if forward {
                forward = evtExtMpnSetFormat_ControlRegion()
            }
        }
    }
    
    private func evtExtMpnSetFormat_ControlRegion() -> Bool {
        let evt = "setFormat"
        if s_ct == .s71 {
            trace(evt, State_ct.s71, State_ct.s70)
            s_ct = .s70
            evtCheck()
        }
        return false
    }
    
    func evtExtMpnSetTrigger() {
        synchronized {
            let evt = "setTrigger"
            var forward = true
            if s_tu == .s30 {
                trace(evt, State_tu.s30, State_tu.s31)
                s_tu = .s31
                forward = evtExtMpnSetTrigger_ControlRegion()
            } else if s_tu == .s32 {
                trace(evt, State_tu.s32, State_tu.s33)
                s_tu = .s33
                forward = evtExtMpnSetTrigger_ControlRegion()
            }
            if forward {
                forward = evtExtMpnSetTrigger_ControlRegion()
            }
        }
    }
    
    private func evtExtMpnSetTrigger_ControlRegion() -> Bool {
        let evt = "setTrigger"
        if s_ct == .s71 {
            trace(evt, State_ct.s71, State_ct.s70)
            s_ct = .s70
            evtCheck()
        }
        return false
    }
    
    func evtChangeFormat() {
        synchronized {
            let evt = "change.format"
            if s_fu == .s21 {
                trace(evt, State_fu.s21, State_fu.s22)
                doSetCurrentFormat()
                s_fu = .s22
            }
        }
    }
    
    func evtChangeTrigger() {
        synchronized {
            let evt = "change.trigger"
            if s_tu == .s31 {
                trace(evt, State_tu.s31, State_tu.s32)
                doSetCurrentTrigger()
                s_tu = .s32
            }
        }
    }
    
    func evtAbortFormat() {
        synchronized {
            let evt = "abort.format"
            switch s_fu {
            case .s21, .s22, .s23:
                trace(evt, s_fu, State_fu.s20)
                notifyOnModificationAbort_Format()
                s_fu = .s20
            default:
                break
            }
        }
    }
    
    func evtAbortTrigger() {
        synchronized {
            let evt = "abort.trigger"
            switch s_tu {
            case .s31, .s32, .s33:
                trace(evt, s_tu, State_tu.s30)
                notifyOnModificationAbort_Trigger()
                s_tu = .s30
            default:
                break
            }
        }
    }
    
    func evtCheck() {
        synchronized {
            let evt = "check"
            if s_ct == .s70 {
                if s_uu == .s11 {
                    trace(evt, State_ct.s70, State_ct.s72)
                    s_ct = .s72
                    genSendUnsubscribe()
                } else if s_fu == .s21 {
                    trace(evt, State_ct.s70, State_ct.s74)
                    s_ct = .s74
                    evtChangeFormat()
                    genSendConfigure()
                } else if s_tu == .s31 {
                    trace(evt, State_ct.s70, State_ct.s73)
                    s_ct = .s73
                    evtChangeTrigger()
                    genSendConfigure()
                } else {
                    trace(evt, State_ct.s70, State_ct.s71)
                    s_ct = .s71
                }
            }
        }
    }
    
    func evtExtMpnSubscribe() {
        synchronized {
            let evt = "subscribe"
            if s_m == .s40 {
                if m_client.s_mpn.m == .s405 {
                    trace(evt, State_m.s40, State_m.s42)
                    notifyStatus(.ACTIVE)
                    s_m = .s42
                    genSendSubscribe()
                } else {
                    trace(evt, State_m.s40, State_m.s41)
                    notifyStatus(.ACTIVE)
                    s_m = .s41
                }
            }
        }
    }
    
    func evtDeviceActive() {
        synchronized {
            let evt = "device.active"
            if s_m == .s41 {
                trace(evt, State_m.s41, State_m.s42)
                s_m = .s42
                genSendSubscribe()
            }
        }
    }
    
    func evtMPNOK(_ mpnSubId: String) {
        synchronized {
            let evt = "MPNOK"
            if s_m == .s42 {
                trace(evt, State_m.s42, State_st.s60)
                doMPNOK(mpnSubId)
                notifyStatus(.SUBSCRIBED)
                notifyOnSubscription()
                notifyOnSubscriptionsUpdated()
                s_m = .s44
                s_st = .s60
                s_ct = .s70
                s_ab = .s80
                evtCheck()
            } else if s_m == .s43 {
                trace(evt, State_m.s43, State_st.s60)
                doMPNOK(mpnSubId)
                notifyStatus(.SUBSCRIBED)
                notifyOnSubscription()
                notifyOnSubscriptionsUpdated()
                s_m = .s44
                s_st = .s60
                s_ct = .s70
                s_ab = .s80
                evtCheck()
            }
        }
    }
    
    func evtMPNDEL() {
        synchronized {
            let evt = "MPNDEL"
            if s_ct == .s72 {
                trace(evt, State_ct.s72, State_m.s52)
                notifyStatus(.UNKNOWN)
                notifyOnUnsubscription()
                notifyOnSubscriptionsUpdated()
                finalize()
                s_m = .s52
                s_st = nil
                s_ct = nil
                s_ab = nil
            }
        }
    }
    
    func evtMpnUpdate(_ update: ItemUpdate) {
        synchronized {
            let evt = "update"
            let ts = update.value(withFieldName: "status_timestamp")
            let nextStatus = update.value(withFieldName: "status")?.uppercased()
            let command = update.value(withFieldName: "command")?.uppercased()
            if s_m == .s44 && command == "DELETE" {
                trace(evt, State_m.s44, State_m.s52)
                notifyStatus(.UNKNOWN)
                notifyOnUnsubscription()
                notifyOnSubscriptionsUpdated()
                finalize()
                s_m = .s52
                s_st = nil
                s_ct = nil
                s_ab = nil
            } else if s_m == .s45 {
                if nextStatus == "ACTIVE" {
                    trace(evt, State_m.s45, State_st.s60)
                    notifyStatus(.SUBSCRIBED, ts)
                    notifyOnSubscription()
                    notifyUpdate(update)
                    s_m = .s44
                    s_st = .s60
                    s_ct = .s70
                    s_ab = .s80
                    evtCheck()
                } else if nextStatus == "TRIGGERED" {
                    trace(evt, State_m.s45, State_st.s61)
                    notifyStatus(.TRIGGERED, ts)
                    notifyOnSubscription()
                    notifyOnTriggered()
                    notifyUpdate(update)
                    s_m = .s44
                    s_st = .s61
                    s_ct = .s70
                    s_ab = .s80
                    evtCheck()
                }
            } else if s_m == .s44 {
                evtMpnUpdate_AbortRegion(update)
            }
        }
    }
    
    private func evtMpnUpdate_AbortRegion(_ update: ItemUpdate) {
        let evt = "update"
        var forward = true
        if s_ab == .s81 {
            trace(evt, State_ab.s81, State_ab.s80)
            s_ab = .s80
            forward = evtMpnUpdate_StatusRegion(update)
            evtRestoreSession()
        }
        if forward {
            forward = evtMpnUpdate_StatusRegion(update)
        }
    }
    
    private func evtMpnUpdate_StatusRegion(_ update: ItemUpdate) -> Bool {
        let evt = "update"
        let ts = update.value(withFieldName: "status_timestamp")
        let nextStatus = update.value(withFieldName: "status")?.uppercased()
        if s_st == .s60 {
            if nextStatus == "ACTIVE" {
                trace(evt, State_st.s60, State_st.s60)
                notifyUpdate(update)
                s_st = .s60
            } else if nextStatus == "TRIGGERED" {
                trace(evt, State_st.s60, State_st.s61)
                notifyStatus(.TRIGGERED, ts)
                notifyOnTriggered()
                notifyUpdate(update)
                s_st = .s61
            }
        } else if s_st == .s61 {
            if nextStatus == "ACTIVE" {
                trace(evt, State_st.s61, State_st.s60)
                notifyStatus(.SUBSCRIBED, ts)
                notifyUpdate(update)
                s_st = .s60
            } else if nextStatus == "TRIGGERED" {
                trace(evt, State_st.s61, State_st.s61)
                notifyUpdate(update)
                s_st = .s61
            }
        }
        return false
    }
    
    func evtMpnEOS() {
        synchronized {
            let evt = "EOS"
            if s_ab == .s81 {
                trace(evt, State_ab.s81, State_m.s51)
                notifyStatus(.UNKNOWN)
                notifyOnUnsubscription()
                notifyOnSubscriptionsUpdated()
                finalize()
                s_m = .s51
                s_st = nil
                s_ct = nil
                s_ab = nil
            }
        }
    }
    
    func isPending() -> Bool {
        synchronized {
            s_m == .s42 || s_ct == .s72 || s_ct == .s73 || s_ct == .s74
        }
    }
    
    func encode(isWS: Bool) -> String {
        synchronized {
            if s_m == .s42 {
                return encodeActivate()
            } else if s_ct == .s72 {
                return encodeDeactivate()
            } else if s_ct == .s73 || s_ct == .s74 {
                return encodeConfigure()
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
    
    private func encodeActivate() -> String {
        let req = LsRequestBuilder()
        m_lastActivateReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastActivateReqId!)
        req.LS_op("activate")
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
        if let freq = m_subscription.requestedMaxFrequency {
            switch freq {
            case .limited(let limit):
                req.LS_requested_max_frequency(limit)
            case .unlimited:
                req.LS_requested_max_frequency("unlimited")
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
        req.PN_deviceId(m_client.mpn_deviceId)
        req.PN_notificationFormat(m_initFormat!)
        if let trigger = m_initTrigger {
            req.PN_trigger(trigger)
        }
        if m_coalescing {
            req.PN_coalescing(true)
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNSubscription activate: \(req)")
        }
        return req.encodedString
    }
    
    private func encodeDeactivate() -> String {
        let req = LsRequestBuilder()
        m_lastDeactivateReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastDeactivateReqId!)
        req.LS_op("deactivate")
        req.PN_deviceId(m_client.mpn_deviceId)
        req.PN_subscriptionId(m_subscription.subscriptionId!)
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNSubscription deactivate: \(req)")
        }
        return req.encodedString
    }
    
    private func encodeConfigure() -> String {
        let req = LsRequestBuilder()
        m_lastConfigureReqId = m_client.generateFreshReqId()
        req.LS_reqId(m_lastConfigureReqId!)
        req.LS_op("pn_reconf")
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
        req.PN_deviceId(m_client.mpn_deviceId)
        req.PN_subscriptionId(m_subscription.subscriptionId!)
        if s_ct == .s74 {
            req.PN_notificationFormat(m_currentFormat!)
        }
        if s_ct == .s73 {
            req.PN_trigger(m_currentTrigger ?? "")
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNSubscription configuration: \(req)")
        }
        return req.encodedString
    }
    
    private func genSendSubscribe() {
        m_client.evtSendControl(self)
    }
    
    private func genSendConfigure() {
        m_client.evtSendControl(self)
    }
    
    private func genSendUnsubscribe() {
        m_client.evtSendControl(self)
    }
    
    private func notifyStatus(_ status: MPNSubscription.Status, _ statusTs: String? = nil) {
        m_subscription.changeStatus(status, statusTs)
    }
    
    private func notifyOnSubscriptionError(_ code: Int, _ msg: String) {
        m_subscription.fireOnSubscriptionError(code, msg)
    }
    
    private func notifyOnSubscriptionAbort() {
        m_subscription.fireOnSubscriptionError(54, "The request was aborted because the operation could not be completed")
    }
    
    private func notifyOnSubscriptionDiscarded() {
        m_subscription.fireOnSubscriptionError(55, "The request was discarded because the operation could not be completed")
    }
    
    private func notifyOnUnsubscriptionError(_ code: Int, _ msg: String) {
        m_subscription.fireOnUnsubscriptionError(code, msg)
    }
    
    private func notifyOnUnsubscriptionAbort() {
        m_subscription.fireOnUnsubscriptionError(54, "The request was aborted because the operation could not be completed")
    }
    
    private func doMPNOK(_ mpnSubId: String) {
        m_subscription.setSubscriptionId(mpnSubId)
    }
    
    private func notifyOnSubscription() {
        m_subscription.fireOnSubscription()
    }
    
    private func notifyOnUnsubscription() {
        m_subscription.fireOnUnsubscription()
    }
    
    private func notifyOnTriggered() {
        m_subscription.fireOnTriggered()
    }
    
    private func notifyOnSubscriptionsUpdated() {
        m_client.mpn_device.fireOnSubscriptionsUpdated()
    }
    
    private func notifyUpdate(_ update: ItemUpdate) {
        m_subscription.changeStatusTs(update.value(withFieldName: "status_timestamp"))
        m_subscription.changeMode(update.value(withFieldName: "mode"))
        m_subscription.changeAdapter(update.value(withFieldName: "adapter"))
        m_subscription.changeGroup(update.value(withFieldName: "group"))
        m_subscription.changeSchema(update.value(withFieldName: "schema"))
        m_subscription.changeFormat(update.value(withFieldName: "notification_format"))
        m_subscription.changeTrigger(update.value(withFieldName: "trigger"))
        m_subscription.changeBufferSize(update.value(withFieldName: "requested_buffer_size"))
        m_subscription.changeMaxFrequency(update.value(withFieldName: "requested_max_frequency"))
    }
    
    private func doSetCurrentFormat() {
        m_currentFormat = m_subscription.requestedFormat
    }
    
    private func doSetCurrentTrigger() {
        m_currentTrigger = m_subscription.requestedTrigger
    }
    
    private func notifyOnModificationError_Format(_ code: Int, _ msg: String) {
        m_subscription.fireOnModificationError(code, message: msg, property: "notification_format")
    }
    
    private func notifyOnModificationAbort_Format() {
        m_subscription.fireOnModificationError(54, message: "The request was aborted because the operation could not be completed", property: "notification_format")
    }
    
    private func notifyOnModificationError_Trigger(_ code: Int, _ msg: String) {
        m_subscription.fireOnModificationError(code, message: msg, property: "trigger")
    }
    
    private func notifyOnModificationAbort_Trigger() {
        m_subscription.fireOnModificationError(54, message: "The request was aborted because the operation could not be completed", property: "trigger")
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    private func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            let subId = m_subId == nil ? "?" : "\(m_subId!)"
            let pnSubId = mpnSubId ?? "?"
            internalLogger.trace("mpn#sub#\(evt):\(subId):\(pnSubId) \(from.id)->\(to.id)")
        }
    }
}
