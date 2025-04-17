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

class ItemBase {
    let m_subId: Int
    let itemIdx: Int
    var currValues: [Pos:CurrFieldVal?]!
    let subscription: Subscription
    unowned let client: LightstreamerClient
    let lock: NSRecursiveLock
    
    init(_ itemIdx: Int, _ sub: Subscription, _ client: LightstreamerClient, subId: Int) {
        self.m_subId = subId
        self.itemIdx = itemIdx
        self.subscription = sub
        self.client = client
        self.lock = client.lock
    }
    
    func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    func synchronized<T>(_ block: () throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try block()
    }
    
    func finalize() {
        // nothing to do
    }
    
    func evtUpdate(_ values: [Pos:FieldValue]) throws {
        fatalError()
    }
    
    func evtOnEOS() {
        fatalError()
    }
    
    func evtOnCS() {
        fatalError()
    }
    
    func evtDispose(_ strategy: ModeStrategy) {
        fatalError()
    }
    
    func getValue(_ fieldIdx: Int) -> String? {
        synchronized {
            currValues != nil ? toString(currValues[fieldIdx] ?? nil) : nil
        }
    }
    
    func getCommandValue(_ keyName: String, _ fieldIdx: Pos) -> String? {
        fatalError("Unsupported operation")
    }
    
    func doFirstUpdate(_ values: [Pos:FieldValue]) throws {
        try doUpdate(values, snapshot: false)
    }
    
    func doUpdate(_ values: [Pos:FieldValue]) throws {
        try doUpdate(values, snapshot: false)
    }
    
    func doFirstSnapshot(_ values: [Pos:FieldValue]) throws {
        try doUpdate(values, snapshot: true)
    }
    
    func doSnapshot(_ values: [Pos:FieldValue]) throws {
        try doUpdate(values, snapshot: true)
    }
    
    func doUpdate(_ values: [Pos:FieldValue], snapshot: Bool) throws {
        let prevValues = currValues
        currValues = try applyUpatesToCurrentFields(prevValues, values)
        let changedFields = findChangedFields(prev: prevValues, curr: currValues)
        let jsonPatches = computeJsonPatches(prevValues, values)
        let update = ItemUpdateBase(itemIdx, subscription, currValues, changedFields, snapshot, jsonPatches)
        subscription.fireOnItemUpdate(update, subId: m_subId)
    }
    
    func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("sub#itm#\(evt):\(m_subId):\(itemIdx) \(from.id)->\(to.id)")
        }
    }
}

class ItemRaw: ItemBase {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3
        
        var id: Int {
            self.rawValue
        }
    }
    
    var s_m: State_m = .s1

    override func evtUpdate(_ values: [Pos:FieldValue]) throws {
        try synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                trace(evt, s_m, State_m.s2)
                try doFirstUpdate(values)
                s_m = .s2
            case .s2:
                trace(evt, s_m, State_m.s2)
                try doUpdate(values)
                s_m = .s2
            default:
                break
            }
        }
    }
    
    override func evtDispose(_ strategy: ModeStrategy) {
        synchronized {
            let evt = "dispose"
            switch s_m {
            case .s1, .s2:
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
                strategy.unrelate(itemIdx)
            default:
                break
            }
        }
    }
}

class ItemMerge: ItemBase {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3, s4 = 4
        
        var id: Int {
            self.rawValue
        }
    }
    
    var s_m: State_m = .s1

    override func evtUpdate(_ values: [Pos:FieldValue]) throws {
        try synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                if subscription.hasSnapshot() {
                    trace(evt, s_m, State_m.s2)
                    try doSnapshot(values)
                    s_m = .s2
                } else {
                    trace(evt, s_m, State_m.s3)
                    try doFirstUpdate(values)
                    s_m = .s3
                }
            case .s2:
                trace(evt, s_m, State_m.s3)
                try doUpdate(values)
                s_m = .s3
            case .s3:
                trace(evt, s_m, State_m.s3)
                try doUpdate(values)
                s_m = .s3
            default:
                break
            }
        }
    }
    
    override func evtDispose(_ strategy: ModeStrategy) {
        synchronized {
            let evt = "dispose"
            switch s_m {
            case .s1, .s2, .s3:
                trace(evt, s_m, State_m.s4)
                finalize()
                s_m = .s4
                strategy.unrelate(itemIdx)
            default:
                break
            }
        }
    }
}

class ItemDistinct: ItemBase {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3, s4 = 4, s5 = 5
        
        var id: Int {
            self.rawValue
        }
    }
    
    var s_m: State_m
    
    override init(_ itemIdx: Int, _ sub: Subscription, _ client: LightstreamerClient, subId: Int) {
        self.s_m = sub.hasSnapshot() ? .s3 : .s1
        super.init(itemIdx, sub, client, subId: subId)
    }
    
    override func evtUpdate(_ values: [Pos:FieldValue]) throws {
        try synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                trace(evt, s_m, State_m.s2)
                try doFirstUpdate(values)
                s_m = .s2
            case .s2:
                trace(evt, s_m, State_m.s2)
                try doUpdate(values)
                s_m = .s2
            case .s3:
                trace(evt, s_m, State_m.s4)
                try doFirstSnapshot(values)
                s_m = .s4
            case .s4:
                trace(evt, s_m, State_m.s4)
                try doSnapshot(values)
                s_m = .s4
            default:
                break
            }
        }
    }
    
    override func evtOnEOS() {
        synchronized {
            let evt = "onEOS"
            switch s_m {
            case .s3:
                trace(evt, s_m, State_m.s1)
                s_m = .s1
            case .s4:
                trace(evt, s_m, State_m.s2)
                s_m = .s2
            default:
                break
            }
        }
    }
    
    override func evtOnCS() {
        synchronized {
            // nothing to do
        }
    }
    
    override func evtDispose(_ strategy: ModeStrategy) {
        synchronized {
            let evt = "dispose"
            switch s_m {
            case .s1, .s2, .s3, .s4:
                trace(evt, s_m, State_m.s5)
                finalize()
                s_m = .s5
                strategy.unrelate(itemIdx)
            default:
                break
            }
        }
    }
}
