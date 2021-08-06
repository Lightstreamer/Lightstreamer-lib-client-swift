import Foundation

class Key2Level: ItemKey {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3, s4 = 4, s5 = 5
        case s10 = 10, s11 = 11, s12 = 12
        
        var id: Int {
            self.rawValue
        }
    }
    
    let keyName: String
    unowned let item: ItemCommand2Level
    var currKeyValues: [Pos:String?]!
    var currKey2Values: [Pos:String?]!
    var listener2Level: Mpn2LevelDelegate?
    var subscription2Level: Subscription?
    var realMaxFrequency: RealMaxFrequency?
    var s_m: State_m = .s1
    let lock: NSRecursiveLock
    
    init(_ keyName: String, _ item: ItemCommand2Level) {
        self.keyName = keyName
        self.item = item
        self.lock = item.lock
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    private func finalize() {
        currKeyValues = nil
        currKey2Values = nil
        item.unrelate(from: keyName)
    }
    
    func evtUpdate(_ keyValues: [Pos:String?], _ snapshot: Bool) {
        synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                if !isDelete(keyValues) {
                    if let sub = create2LevelSubscription() {
                        trace(evt, s_m, State_m.s4)
                        doFirstUpdate(keyValues, snapshot: snapshot)
                        subscription2Level = sub
                        s_m = .s4
                        item.strategy.client.subscribeExt(sub, isInternal: true)
                    } else {
                        trace(evt, s_m, State_m.s3)
                        doFirstUpdate(keyValues, snapshot: snapshot)
                        notify2LevelIllegalArgument()
                        s_m = .s3
                    }
                } else {
                    trace(evt, s_m, State_m.s11)
                    doLightDelete(keyValues, snapshot: snapshot)
                    finalize()
                    s_m = .s11
                    genOnRealMaxFrequency2LevelRemoved()
                }
            case .s3:
                if !isDelete(keyValues) {
                    trace(evt, s_m, State_m.s3)
                    doUpdate(keyValues, snapshot: snapshot)
                    s_m = .s3
                } else {
                    trace(evt, s_m, State_m.s11)
                    doDelete1LevelOnly(keyValues, snapshot: snapshot)
                    finalize()
                    s_m = .s11
                    genOnRealMaxFrequency2LevelRemoved()
                }
            case .s4:
                if !isDelete(keyValues) {
                    trace(evt, s_m, State_m.s4)
                    doUpdate(keyValues, snapshot: snapshot)
                    s_m = .s4
                } else {
                    trace(evt, s_m, State_m.s11)
                    doDelete(keyValues, snapshot: snapshot)
                    finalize()
                    s_m = .s11
                    genOnRealMaxFrequency2LevelRemoved()
                }
            case .s5:
                if !isDelete(keyValues) {
                    trace(evt, s_m, State_m.s5)
                    doUpdate1Level(keyValues, snapshot: snapshot)
                    s_m = .s5
                } else {
                    trace(evt, s_m, State_m.s11)
                    doDeleteExt(keyValues, snapshot: snapshot)
                    finalize()
                    s_m = .s11
                    genOnRealMaxFrequency2LevelRemoved()
                }
            default:
                break
            }
        }
    }
    
    func evtDispose() {
        synchronized {
            let evt = "dispose"
            switch s_m {
            case .s1, .s2, .s3:
                trace(evt, s_m, State_m.s10)
                finalize()
                s_m = .s10
            case .s4, .s5:
                trace(evt, s_m, State_m.s12)
                doUnsubscribe()
                finalize()
                s_m = .s12
            default:
                break
            }
        }
    }
    
    func evtOnSubscriptionError2Level(_ code: Int, _ msg: String) {
        synchronized {
            let evt = "onSubscriptionError2Level"
            if s_m == .s4 {
                trace(evt, s_m, State_m.s3)
                notify2LevelSubscriptionError(code, msg)
                s_m = .s3
            }
        }
    }
    
    func evtUpdate2Level(_ update: ItemUpdate) {
        synchronized {
            let evt = "update2Level"
            switch s_m {
            case .s4:
                trace(evt, s_m, State_m.s5)
                doUpdate2Level(update)
                s_m = .s5
            case .s5:
                trace(evt, s_m, State_m.s5)
                doUpdate2Level(update)
                s_m = .s5
            default:
                break
            }
        }
    }
    
    func evtOnUnsubscription2Level() {
        synchronized {
            let evt = "onUnsubscription2Level"
            switch s_m {
            case .s4, .s5:
                trace(evt, s_m, s_m)
                doUnsetRealMaxFrequency()
                genOnRealMaxFrequency2LevelRemoved()
            default:
                break
            }
        }
    }
    
    func evtOnItemLostUpdates2Level(_ lostUpdates: Int) {
        synchronized {
            let evt = "onItemLostUpdates2Level"
            switch s_m {
            case .s4, .s5:
                trace(evt, s_m, s_m)
                notify2LevelLostUpdates(lostUpdates)
            default:
                break
            }
        }
    }
    
    func evtOnRealMaxFrequency2Level(_ maxFrequency: RealMaxFrequency?) {
        synchronized {
            let evt = "onRealMaxFrequency2Level"
            switch s_m {
            case .s4, .s5:
                trace(evt, s_m, s_m)
                doSetRealMaxFrequency(maxFrequency)
                genOnRealMaxFrequency2LevelAdded()
            default:
                break
            }
        }
    }
    
    func evtSetRequestedMaxFrequency() {
        synchronized {
            let evt = "setRequestedMaxFrequency"
            switch s_m {
            case .s4, .s5:
                trace(evt, s_m, s_m)
                doChangeRequestedMaxFrequency()
            default:
                break
            }
        }
    }
    
    func getCommandValue(_ fieldIdx: Pos) -> String? {
        synchronized {
            if let values = currKeyValues, let val = values[fieldIdx] {
                return val
            } else if let values = currKey2Values,
                      let nFields = item.subscription.nFields,
                      let val = values[fieldIdx - nFields] {
                return val
            } else {
                return nil
            }
        }
    }
    
    private func doFirstUpdate(_ keyValues: [Pos:String?], snapshot: Bool) {
        let cmdIdx = item.subscription.commandPosition!
        currKeyValues = keyValues
        currKeyValues[cmdIdx] = "ADD"
        let changedFields = findChangedFields(prev: nil, curr: currKeyValues)
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, currKeyValues, changedFields, snapshot)
        
        fireOnItemUpdate(update)
    }
    
    private func doUpdate(_ keyValues: [Pos:String?], snapshot: Bool) {
        let cmdIdx = item.subscription.commandPosition!
        let prevKeyValues = currKeyValues
        currKeyValues = keyValues
        currKeyValues[cmdIdx] = "UPDATE"
        let changedFields = findChangedFields(prev: prevKeyValues, curr: currKeyValues)
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, currKeyValues, changedFields, snapshot)
        
        fireOnItemUpdate(update)
    }
    
    private func doUpdate2Level(_ update: ItemUpdate) {
        let cmdIdx = item.subscription.commandPosition!
        let nFields = item.subscription.nFields!
        let prevKeyValues = currKeyValues!
        currKeyValues[cmdIdx] = "UPDATE"
        currKey2Values = update.fieldsByPositions
        var extKeyValues = currKeyValues!
        for (f, v) in currKey2Values {
            extKeyValues[f + nFields] = v
        }
        var changedFields = Set<Int>()
        if prevKeyValues[cmdIdx] != currKeyValues[cmdIdx] {
            changedFields.insert(cmdIdx)
        }
        for (f, _) in update.changedFieldsByPositions {
            changedFields.insert(f + nFields)
        }
        let snapshot = update.isSnapshot
        let extUpdate = ItemUpdate2Level(item.itemIdx, item.subscription, extKeyValues, changedFields, snapshot)
        
        fireOnItemUpdate(extUpdate)
    }
    
    private func doUpdate1Level(_ keyValues: [Pos:String?], snapshot: Bool) {
        let cmdIdx = item.subscription.commandPosition!
        let nFields = item.subscription.nFields!
        let prevKeyValues = currKeyValues!
        currKeyValues =  keyValues
        currKeyValues[cmdIdx] = "UPDATE"
        var extKeyValues = currKeyValues!
        for (f, v) in currKey2Values {
            extKeyValues[f + nFields] = v
        }
        var changedFields = Set<Int>()
        for f in 1...nFields {
            if prevKeyValues[f] != extKeyValues[f] {
                changedFields.insert(f)
            }
        }
        let extUpdate = ItemUpdate2Level(item.itemIdx, item.subscription, extKeyValues, changedFields, snapshot)
        
        fireOnItemUpdate(extUpdate)
    }
    
    private func doDelete(_ keyValues: [Pos:String?], snapshot: Bool) {
        let n = item.subscription.nFields!
        let keyIdx = item.subscription.keyPosition!
        let cmdIdx = item.subscription.commandPosition!
        currKeyValues = nil
        let changedFields = Set(1...n).subtracting([keyIdx])
        var extKeyValues = [Pos:String?]()
        for f in 1...n {
            extKeyValues.updateValue(nil, forKey: f)
        }
        extKeyValues[keyIdx] = keyName
        extKeyValues[cmdIdx] = "DELETE"
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, extKeyValues, changedFields, snapshot)
        
        item.unrelate(from: keyName)
        
        let sub = subscription2Level!
        sub.removeDelegate(listener2Level!)
        listener2Level!.disable()
        subscription2Level = nil
        listener2Level = nil
        
        item.strategy.client.unsubscribe(sub)
        fireOnItemUpdate(update)
    }
    
    private func doDeleteExt(_ keyValues: [Pos:String?], snapshot: Bool) {
        let nFields = item.subscription.nFields!
        let keyIdx = item.subscription.keyPosition!
        let cmdIdx = item.subscription.commandPosition!
        let n = nFields + currKey2Values.count
        currKeyValues = nil
        currKey2Values = nil
        let changedFields = Set(1...n).subtracting([keyIdx])
        var extKeyValues = [Pos:String?]()
        for f in 1...n {
            extKeyValues.updateValue(nil, forKey: f)
        }
        extKeyValues[keyIdx] = keyName
        extKeyValues[cmdIdx] = "DELETE"
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, extKeyValues, changedFields, snapshot)
        
        item.unrelate(from: keyName)
        
        let sub = subscription2Level!
        sub.removeDelegate(listener2Level!)
        listener2Level!.disable()
        subscription2Level = nil
        listener2Level = nil
        
        item.strategy.client.unsubscribe(sub)
        fireOnItemUpdate(update)
    }
    
    private func doLightDelete(_ keyValues: [Pos:String?], snapshot: Bool) {
        let nFields = item.subscription.nFields!
        let keyIdx = item.subscription.keyPosition!
        let cmdIdx = item.subscription.commandPosition!
        currKeyValues = nil
        let changedFields = Set(1...nFields)
        var values = [Pos:String?]()
        for f in 1...nFields {
            values.updateValue(nil, forKey: f)
        }
        values[keyIdx] = keyValues[keyIdx]
        values[cmdIdx] = keyValues[cmdIdx]
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, values, changedFields, snapshot)
        
        fireOnItemUpdate(update)
    }
    
    private func doDelete1LevelOnly(_ keyValues: [Pos:String?], snapshot: Bool) {
        let nFields = item.subscription.nFields!
        let keyIdx = item.subscription.keyPosition!
        let cmdIdx = item.subscription.commandPosition!
        currKeyValues = nil
        let changedFields = Set(1...nFields).subtracting([keyIdx])
        var values = [Pos:String?]()
        for f in 1...nFields {
            values.updateValue(nil, forKey: f)
        }
        values[keyIdx] = keyValues[keyIdx]
        values[cmdIdx] = keyValues[cmdIdx]
        let update = ItemUpdate2Level(item.itemIdx, item.subscription, values, changedFields, snapshot)
        
        fireOnItemUpdate(update)
    }
    
    private func doChangeRequestedMaxFrequency() {
        subscription2Level!.requestedMaxFrequency = item.strategy.requestedMaxFrequency
    }
    
    private func doSetRealMaxFrequency(_ maxFrequency: RealMaxFrequency?) {
        realMaxFrequency = maxFrequency
    }
    
    private func doUnsetRealMaxFrequency() {
        realMaxFrequency = nil
    }
    
    private func genOnRealMaxFrequency2LevelAdded() {
        item.strategy.evtOnRealMaxFrequency2LevelAdded(realMaxFrequency)
    }
    
    private func genOnRealMaxFrequency2LevelRemoved() {
        item.strategy.evtOnRealMaxFrequency2LevelRemoved()
    }
    
    private func doUnsubscribe() {
        let sub = subscription2Level!
        sub.removeDelegate(listener2Level!)
        listener2Level!.disable()
        subscription2Level = nil
        listener2Level = nil
        
        item.strategy.client.unsubscribe(sub)
    }
    
    private func notify2LevelIllegalArgument() {
        listener2Level = nil
        subscription2Level = nil
        
        item.subscription.fireOnSubscriptionError2Level(keyName, 14, "The received key value is not a valid name for an Item", subId: item.m_subId, itemIdx: item.itemIdx)
    }
    
    private func notify2LevelSubscriptionError(_ code: Int, _ msg: String) {
        listener2Level = nil
        subscription2Level = nil
        
        item.subscription.fireOnSubscriptionError2Level(keyName, code, msg, subId: item.m_subId, itemIdx: item.itemIdx)
    }
    
    private func notify2LevelLostUpdates(_ lostUpdates: Int) {
        item.subscription.fireOnLostUpdates2Level(keyName, lostUpdates, subId: item.m_subId, itemIdx: item.itemIdx)
    }
    
    private func fireOnItemUpdate(_ update: ItemUpdate) {
        item.subscription.fireOnItemUpdate(update, subId: item.m_subId)
    }
    
    class Mpn2LevelDelegate: SubscriptionDelegate {
        weak var key: Key2Level?
        var m_disabled = false
        
        init(_ key: Key2Level) {
            self.key = key
        }
        
        func disable() {
            key?.synchronized {
                m_disabled = true
            }
        }
        
        func synchronized(block: () -> Void) {
            key?.synchronized {
                guard !m_disabled else {
                    return
                }
                block()
            }
        }
        
        func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String) {
            synchronized {
                key?.evtOnSubscriptionError2Level(code, message)
            }
        }
        
        func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
            synchronized {
                key?.evtUpdate2Level(itemUpdate)
            }
        }
        
        func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: Int, forItemName itemName: String?, itemPos: Int) {
            synchronized {
                key?.evtOnItemLostUpdates2Level(lostUpdates)
            }
        }
        
        func subscription(_ subscription: Subscription, didReceiveRealFrequency frequency: RealMaxFrequency?) {
            synchronized {
                key?.evtOnRealMaxFrequency2Level(frequency)
            }
        }
        
        func subscriptionDidUnsubscribe(_ subscription: Subscription) {
            synchronized {
                key?.evtOnUnsubscription2Level()
            }
        }
        
        func subscription(_ subscription: Subscription, didClearSnapshotForItemName itemName: String?, itemPos: Int) {}
        func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: Int, forCommandSecondLevelItemWithKey key: String) {}
        func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String, forCommandSecondLevelItemWithKey key: String) {}
        func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: Int) {}
        func subscriptionDidRemoveDelegate(_ subscription: Subscription) {}
        func subscriptionDidAddDelegate(_ subscription: Subscription) {}
        func subscriptionDidSubscribe(_ subscription: Subscription) {}
    }
    
    private func create2LevelSubscription() -> Subscription? {
        listener2Level = Mpn2LevelDelegate(self)
        let sub = item.subscription
        let sub2 = Subscription(.MERGE)
        let items = [keyName]
        guard allValidItems(items) else {
            return nil
        }
        sub2.items = items
        if let fields2 = sub.commandSecondLevelFields {
            sub2.fields = fields2
        } else {
            sub2.fieldSchema = sub.commandSecondLevelFieldSchema
        }
        sub2.dataAdapter = sub.commandSecondLevelDataAdapter
        sub2.requestedSnapshot = .yes
        sub2.requestedMaxFrequency = item.strategy.requestedMaxFrequency
        sub2.addDelegate(listener2Level!)
        sub2.setInternal()
        return sub2
    }
    
    private func isDelete(_ keyValues: [Pos:String?]) -> Bool {
        keyValues[item.subscription.commandPosition!] == "DELETE"
    }
    
    func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            let subId = item.m_subId
            let itemIdx = item.itemIdx
            internalLogger.trace("sub#key#\(evt):\(subId):\(itemIdx):\(keyName) \(from.id)->\(to.id)")
        }
    }
}
