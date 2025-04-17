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

protocol ItemKey {
    func evtUpdate(_ keyValue: [Pos:CurrFieldVal?], _ snapshot: Bool)
    func evtSetRequestedMaxFrequency()
    func evtDispose()
    func getCommandValue(_ fieldIdx: Pos) -> String?
}

class Key1Level: ItemKey {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3
        
        var id: Int {
            self.rawValue
        }
    }
    
    let keyName: String
    unowned let item: ItemCommand1Level
    var currKeyValues: [Pos:CurrFieldVal?]!
    var s_m: State_m = .s1
    let lock: NSRecursiveLock
    
    init(_ keyName: String, _ item: ItemCommand1Level) {
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
        item.unrelate(from: keyName)
    }
    
    func evtUpdate(_ keyValues: [Pos:CurrFieldVal?], _ snapshot: Bool) {
        synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                if !isDelete(keyValues) {
                    trace(evt, s_m, State_m.s2)
                    doFirstUpdate(keyValues, snapshot)
                    s_m = .s2
                } else {
                    trace(evt, s_m, State_m.s3)
                    doLightDelete(keyValues, snapshot)
                    finalize()
                    s_m = .s3
                }
            case .s2:
                if !isDelete(keyValues) {
                    trace(evt, s_m, State_m.s2)
                    doUpdate(keyValues, snapshot)
                    s_m = .s2
                } else {
                    trace(evt, s_m, State_m.s3)
                    doDelete(keyValues, snapshot)
                    finalize()
                    s_m = .s3
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
            case .s1, .s2:
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
            default:
                break
            }
        }
    }
    
    func evtSetRequestedMaxFrequency() {
        synchronized {
            // nothing to do
        }
    }
    
    func getCommandValue(_ fieldIdx: Pos) -> String? {
        synchronized {
            currKeyValues != nil ? toString(currKeyValues[fieldIdx] ?? nil) : nil
        }
    }
    
    private func doFirstUpdate(_ keyValues: [Pos:CurrFieldVal?], _ snapshot: Bool) {
        let nFields = item.subscription.nFields!
        let cmdIdx = item.subscription.commandPosition!
        currKeyValues = keyValues
        currKeyValues[cmdIdx] = .stringVal("ADD")
        let changedFields = Set(1...nFields)
        let update = ItemUpdateBase(item.itemIdx, item.subscription, currKeyValues, changedFields, snapshot, [:])
        
        fireOnItemUpdate(update)
    }
    
    private func doUpdate(_ keyValues: [Pos:CurrFieldVal?], _ snapshot: Bool) {
        let cmdIdx = item.subscription.commandPosition!
        let prevKeyValues = currKeyValues
        currKeyValues = keyValues
        currKeyValues[cmdIdx] = .stringVal("UPDATE")
        let changedFields = findChangedFields(prev: prevKeyValues, curr: currKeyValues)
        let update = ItemUpdateBase(item.itemIdx, item.subscription, currKeyValues, changedFields, snapshot, [:])
        
        fireOnItemUpdate(update)
    }
    
    private func doLightDelete(_ keyValues: [Pos:CurrFieldVal?], _ snapshot: Bool) {
        currKeyValues = nil
        let changedFields = Set(keyValues.keys)
        let update = ItemUpdateBase(item.itemIdx, item.subscription, nullify(keyValues), changedFields, snapshot, [:])
        item.unrelate(from: keyName)
        
        fireOnItemUpdate(update)
    }
    
    private func doDelete(_ keyValues: [Pos:CurrFieldVal?], _ snapshot: Bool) {
        currKeyValues = nil
        let changedFields = Set(keyValues.keys).subtracting([item.subscription.keyPosition!])
        let update = ItemUpdateBase(item.itemIdx, item.subscription, nullify(keyValues), changedFields, snapshot, [:])
        item.unrelate(from: keyName)
        
        fireOnItemUpdate(update)
    }
    
    private func nullify(_ keyValues: [Pos:CurrFieldVal?]) -> [Pos:CurrFieldVal?] {
        var values = [Pos:CurrFieldVal?]()
        for (p, val) in keyValues {
            let newVal = p == item.subscription.commandPosition || p == item.subscription.keyPosition ? val : nil
            values.updateValue(newVal, forKey: p)
        }
        return values
    }
    
    private func isDelete(_ keyValues: [Pos:CurrFieldVal?]) -> Bool {
        toString(keyValues[item.subscription.commandPosition!] ?? nil) == "DELETE"
    }
    
    private func fireOnItemUpdate(_ update: ItemUpdate) {
        item.subscription.fireOnItemUpdate(update, subId: item.m_subId)
    }
    
    func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            let subId = item.m_subId
            let itemIdx = item.itemIdx
            internalLogger.trace("sub#key#\(evt):\(subId):\(itemIdx):\(keyName) \(from.id)->\(to.id)")
        }
    }
}
