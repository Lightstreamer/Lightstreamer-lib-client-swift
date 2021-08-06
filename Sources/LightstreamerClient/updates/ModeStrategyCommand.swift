import Foundation

class ModeStrategyCommand: ModeStrategy {
    
    override func evtOnSUB(_ nItems: Int, _ nFields: Int, cmdIdx: Int? = nil, keyIdx: Int? = nil, _ currentFreq: Subscription.RequestedMaxFrequency? = nil) {
        synchronized {
            let evt = "onSUB"
            if s_m == .s1 {
                trace(evt, s_m, State_m.s2)
                doSUB(nItems, nFields, cmdIdx, keyIdx)
                s_m = .s2
            }
        }
    }
    
    override func getCommandValue(_ itemPos: Int, _ key: String, _ fieldPos: Int) -> String? {
        synchronized {
            if let item = items[itemPos] {
                return item.getCommandValue(key, fieldPos)
            } else {
                return nil
            }
        }
    }
    
    private func doSUB(_ nItems: Int, _ nFields: Int, _ cmdIdx: Int?, _ keyIdx: Int?) {
        assert(subscription.items != nil ? nItems == subscription.items!.count : true)
        assert(subscription.fields != nil ? nFields == subscription.fields!.count : true)
        assert(subscription.fields != nil ? cmdIdx! - 1 == subscription.fields!.firstIndex(of: "command")! : true)
        assert(subscription.fields != nil ? keyIdx! - 1 == subscription.fields!.firstIndex(of: "key")! : true)
    }
}

class ModeStrategyCommand1Level: ModeStrategyCommand {
    
    override func createItem(_ itemIdx: Int) -> ItemBase {
        ItemCommand1Level(itemIdx, subscription, client, subId: m_subId)
    }
}

class ModeStrategyCommand2Level: ModeStrategyCommand {
    var requestedMaxFrequency: Subscription.RequestedMaxFrequency?
    var aggregateRealMaxFrequency: RealMaxFrequency?
    
    override func evtOnSUB(_ nItems: Int, _ nFields: Int, cmdIdx: Int? = nil, keyIdx: Int? = nil, _ currentFreq: Subscription.RequestedMaxFrequency? = nil) {
        synchronized {
            let evt = "onSUB"
            if s_m == .s1 {
                trace(evt, s_m, State_m.s2)
                doSUB(nItems, nFields, cmdIdx, keyIdx, currentFreq)
                s_m = .s2
            }
        }
    }
    
    override func evtSetRequestedMaxFrequency(_ freq: Subscription.RequestedMaxFrequency?) {
        synchronized {
            let evt = "setRequestedMaxFrequency"
            switch s_m {
            case .s1, .s2:
                trace(evt, s_m, s_m)
                doSetRequestedMaxFrequency(freq)
                genSetRequestedMaxFrequency()
            default:
                break
            }
        }
    }
    
    func evtOnRealMaxFrequency2LevelAdded(_ freq: RealMaxFrequency?) {
        synchronized {
            let evt = "onRealMaxFrequency2LevelAdded"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doAggregateFrequenciesWhenFreqIsAdded(freq)
                s_m = .s2
            }
        }
    }
    
    func evtOnRealMaxFrequency2LevelRemoved() {
        synchronized {
            let evt = "onRealMaxFrequency2LevelRemoved"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doAggregateFrequenciesWhenFreqIsRemoved()
                s_m = .s2
            }
        }
    }
    
    override func evtOnCONF(_ freq: RealMaxFrequency) {
        synchronized {
            let evt = "onCONF"
            if s_m == .s2 {
                trace(evt, s_m, State_m.s2)
                doCONF(freq)
                doAggregateFrequenciesWhenFreqIsAdded(freq)
                s_m = .s2
            }
        }
    }
    
    override func createItem(_ itemIdx: Int) -> ItemBase {
        ItemCommand2Level(itemIdx, subscription, self, client, subId: m_subId)
    }
    
    private func doSUB(_ nItems: Int, _ nFields: Int, _ cmdIdx: Int?, _ keyIdx: Int?, _ currentFreq: Subscription.RequestedMaxFrequency?) {
        assert(subscription.items != nil ? nItems == subscription.items?.count : true)
        assert(subscription.fields != nil ? nFields == subscription.fields?.count : true)
        assert(subscription.fields != nil ? cmdIdx! - 1 == subscription.fields?.firstIndex(of: "command")! : true)
        assert(subscription.fields != nil ? keyIdx! - 1 == subscription.fields?.firstIndex(of: "key")! : true)
        requestedMaxFrequency = currentFreq
    }
    
    private func doSetRequestedMaxFrequency(_ maxFrequency: Subscription.RequestedMaxFrequency?) {
        requestedMaxFrequency = maxFrequency
    }
    
    private func genSetRequestedMaxFrequency() {
        for (_, item) in items {
            (item as! ItemCommand2Level).evtSetRequestedMaxFrequency()
        }
    }
    
    private func doCONF(_ maxFrequency: RealMaxFrequency) {
        realMaxFrequency = maxFrequency
    }
    
    private func maxFreq(cumulated: RealMaxFrequency?, new freq: RealMaxFrequency?) -> RealMaxFrequency? {
        /*
         +----------------+-----------+----------------------+-----------+
         | MAX(curr, freq)| null      | Number               | unlimited |
         | curr/freq      |           |                      |           |
         +----------------+-----------+----------------------+-----------+
         | null           | freq      | freq                 | freq      |
         +----------------+-----------+----------------------+-----------+
         | Number         | curr      | MAX(curr, freq)      | freq      |
         +----------------+-----------+----------------------+-----------+
         | unlimited      | curr      | curr                 | curr      |
         +----------------+-----------+----------------------+-----------+
         */
        var newMax: RealMaxFrequency?
        switch cumulated {
        case .limited(let dc):
            switch freq {
            case .limited(let df):
                newMax = .limited(max(dc, df))
            case .unlimited:
                newMax = freq
            case .none:
                newMax = cumulated
            }
        case .unlimited:
            newMax = cumulated
        case .none:
            newMax = freq
        }
        return newMax
    }
    
    private func doAggregateFrequenciesWhenFreqIsAdded(_ freq: RealMaxFrequency?) {
        let newMax = maxFreq(cumulated: aggregateRealMaxFrequency, new: freq)
        let prevMax = aggregateRealMaxFrequency
        aggregateRealMaxFrequency = newMax
        
        if prevMax != newMax {
            subscription.fireOnRealMaxFrequency(newMax, subId: m_subId)
        }
    }
    
    private func doAggregateFrequenciesWhenFreqIsRemoved() {
        var newMax = realMaxFrequency
        main:
        for (_, item) in items {
            for (_, key) in (item as! ItemCommand2Level).keys {
                let freq = (key as! Key2Level).realMaxFrequency
                newMax = maxFreq(cumulated: newMax, new: freq)
                if newMax == .unlimited {
                    break main
                }
            }
        }
        let prevMax = aggregateRealMaxFrequency
        aggregateRealMaxFrequency = newMax
        
        if prevMax != newMax {
            subscription.fireOnRealMaxFrequency(newMax, subId: m_subId)
        }
    }
}
