import Foundation

class ModeStrategy {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3
        
        var id: Int {
            self.rawValue
        }
    }
    
    let subscription: Subscription
    var realMaxFrequency: RealMaxFrequency?
    var s_m: State_m = .s1
    var items: [Int:ItemBase] = [Int:ItemBase]()
    let lock: NSRecursiveLock
    unowned let client: LightstreamerClient
    let m_subId: Int
    
    init(_ sub: Subscription, _ client: LightstreamerClient, subId: Int) {
        self.lock = client.lock
        self.client = client
        self.subscription = sub
        self.m_subId = subId
    }
    
    func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    private func finalize() {
        // nothing to do
    }
    
    func evtAbort() {
        synchronized {
            let evt = "abort"
            if s_m == .s1 {
                trace(evt, s_m, State_m.s1)
                doAbort()
            } else if s_m == .s2 {
                trace(evt, s_m, State_m.s1)
                doAbort()
                s_m = .s1
                genDisposeItems()
            }
        }
    }
    
    func evtOnSUB(_ nItems: Int, _ nFields: Int, cmdIdx: Int? = nil, keyIdx: Int? = nil, _ currentFreq: Subscription.RequestedMaxFrequency? = nil) {
        synchronized {
            let evt = "onSUB"
            if s_m == .s1 {
                trace(evt, s_m, State_m.s2)
                doSUB(nItems, nFields)
                s_m = .s2
            }
        }
    }
    
    func evtOnCONF(_ freq: RealMaxFrequency) {
        synchronized {
            let evt = "onCONF"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doCONF(freq)
            }
        }
    }
    
    func evtOnCS(_ itemIdx: Int) {
        synchronized {
            let evt = "onCS"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doCS(itemIdx)
            }
        }
    }
    
    func evtOnEOS(_ itemIdx: Int) {
        synchronized {
            let evt = "onEOS"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doEOS(itemIdx)
            }
        }
    }
    
    func evtUpdate(_ itemIdx: Int, _ values: [Pos:FieldValue]) {
        synchronized {
            let evt = "update"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doUpdate(itemIdx, values)
            }
        }
    }
    
    func evtUnsubscribe() {
        synchronized {
            let evt = "unsubscribe"
            if s_m == .s1 {
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
            } else if s_m == .s2 {
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
                genDisposeItems()
            }
        }
    }
    
    func evtOnUNSUB() {
        synchronized {
            let evt = "onUNSUB"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
                genDisposeItems()
            }
        }
    }
    
    func evtDispose() {
        synchronized {
            let evt = "dispose"
            if s_m == .s1 || s_m == .s2 {
                trace(evt, s_m, State_m.s3)
                finalize()
                s_m = .s3
                genDisposeItems()
            }
        }
    }
    
    func evtSetRequestedMaxFrequency(_ freq: Subscription.RequestedMaxFrequency?) {
        synchronized {
            // ignore: only needed by 2-level COMMAND
        }
    }
    
    func getValue(_ itemPos: Pos, _ fieldPos: Pos) -> String? {
        synchronized {
            if let item = items[itemPos] {
                return item.getValue(fieldPos)
            } else {
                return nil
            }
        }
    }
    
    func getCommandValue(_ itemPos: Int, _ key: String, _ fieldPos: Int) -> String? {
        fatalError("Unsupported operation")
    }
    
    func createItem(_ itemIdx: Int) -> ItemBase {
        fatalError()
    }
    
    private func doSUB(_ nItems: Int, _ nFields: Int) {
        assert(subscription.items != nil ? nItems == subscription.items!.count : true)
        assert(subscription.fields != nil ? nFields == subscription.fields!.count : true)
    }
    
    private func doUpdate(_ itemIdx: Int, _ values: [Pos:FieldValue]) {
        let item = selectItem(itemIdx)
        item.evtUpdate(values)
    }
    
    private func doEOS(_ itemIdx: Int) {
        let item = selectItem(itemIdx)
        item.evtOnEOS()
    }
    
    private func doCS(_ itemIdx: Int) {
        let item = selectItem(itemIdx)
        item.evtOnCS()
    }
    
    private func doCONF(_ freq: RealMaxFrequency) {
        realMaxFrequency = freq
        subscription.fireOnRealMaxFrequency(freq, subId: m_subId)
    }
    
    private func doAbort() {
        realMaxFrequency = nil
    }
    
    private func genDisposeItems() {
        for item in items.values {
            item.evtDispose(self)
        }
    }
    
    private func selectItem(_ itemIdx: Int) -> ItemBase {
        var item = items[itemIdx]
        if item == nil {
            item = createItem(itemIdx)
            items[itemIdx] = item
        }
        return item!
    }
    
    func unrelate(_ itemIdx: Int) {
        items.removeValue(forKey: itemIdx)
    }
    
    func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("sub#mod#\(evt):\(m_subId) \(from.id)->\(to.id)")
        }
    }
}

class ModeStrategyRaw: ModeStrategy {
    
    override func createItem(_ itemIdx: Int) -> ItemBase {
        ItemRaw(itemIdx, subscription, client, subId: m_subId)
    }
}

class ModeStrategyMerge: ModeStrategy {
    
    override func createItem(_ itemIdx: Int) -> ItemBase {
        ItemMerge(itemIdx, subscription, client, subId: m_subId)
    }
}

class ModeStrategyDistinct: ModeStrategy {
    
    override func createItem(_ itemIdx: Int) -> ItemBase {
        ItemDistinct(itemIdx, subscription, client, subId: m_subId)
    }
}
