import Foundation

class ItemCommand: ItemBase {
    enum State_m: Int, State {
        case s1 = 1, s2 = 2, s3 = 3, s4 = 4, s5 = 5
        
        var id: Int {
            self.rawValue
        }
    }
    
    var keys = [String:ItemKey]()
    var s_m: State_m
    
    override init(_ itemIdx: Int, _ sub: Subscription, _ client: LightstreamerClient, subId: Int) {
        s_m = sub.hasSnapshot() ? .s3 : .s1
        super.init(itemIdx, sub, client, subId: subId)
    }
    
    override func finalize() {
        // nothing to do
    }
    
    func unrelate(from keyName: String) {
        keys.removeValue(forKey: keyName)
    }
    
    override func evtUpdate(_ values: [Pos:FieldValue]) {
        synchronized {
            let evt = "update"
            switch s_m {
            case .s1:
                trace(evt, s_m, State_m.s2)
                doFirstUpdate(values)
                s_m = .s2
            case .s2:
                trace(evt, s_m, State_m.s2)
                doUpdate(values)
                s_m = .s2
            case .s3:
                trace(evt, s_m, State_m.s4)
                doFirstSnapshot(values)
                s_m = .s4
            case .s4:
                trace(evt, s_m, State_m.s4)
                doSnapshot(values)
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
        fatalError()
    }
    
    override func evtDispose(_ strategy: ModeStrategy) {
        synchronized {
            let evt = "dispose"
            switch s_m {
            case .s1, .s2, .s3, .s4:
                trace(evt, s_m, State_m.s5)
                finalize()
                s_m = .s5
                genDisposeKeys()
                strategy.unrelate(itemIdx)
            default:
                break
            }
        }
    }
    
    override func getCommandValue(_ keyName: String, _ fieldIdx: Pos) -> String? {
        synchronized {
            if let key = keys[keyName] {
                return key.getCommandValue(fieldIdx)
            } else {
                return nil
            }
        }
    }
    
    func createKey(_ keyName: String) -> ItemKey {
        fatalError()
    }
    
    override func doUpdate(_ values: [Pos:FieldValue], snapshot: Bool) {
        let prevValues = currValues
        currValues = mapUpdateValues(prevValues, values)
        let key = selectKey()
        
        key.evtUpdate(currValues, snapshot)
    }
    
    func genDisposeKeys() {
        for (_, key) in keys {
            key.evtDispose()
        }
    }
    
    private func selectKey() -> ItemKey {
        let keyName = currValues[subscription.keyPosition!]!!
        var key = keys[keyName]
        if key == nil {
            key = createKey(keyName)
            keys[keyName] = key
        }
        return key!
    }
}

class ItemCommand1Level: ItemCommand {
    
    override func evtOnCS() {
        synchronized {
            let evt = "onCS"
            switch s_m {
            case .s1, .s2, .s3, .s4:
                trace(evt, s_m, s_m)
                genDisposeKeys()
            default:
                break
            }
        }
    }
    
    override func createKey(_ keyName: String) -> ItemKey {
        Key1Level(keyName, self)
    }
}


class ItemCommand2Level: ItemCommand {
    unowned let strategy: ModeStrategyCommand2Level
    
    init(_ itemIdx: Int, _ sub: Subscription, _ strategy: ModeStrategyCommand2Level, _ client: LightstreamerClient, subId: Int) {
        self.strategy = strategy
        super.init(itemIdx, sub, client, subId: subId)
    }
    
    override func evtOnCS() {
        synchronized {
            let evt = "onCS"
            switch s_m {
            case .s1, .s2, .s3, .s4:
                trace(evt, s_m, s_m)
                genDisposeKeys()
                genOnRealMaxFrequency2LevelRemoved()
            default:
                break
            }
        }
    }
    
    func evtSetRequestedMaxFrequency() {
        synchronized {
            let evt = "setRequestedMaxFrequency"
            switch s_m {
            case .s1, .s2, .s3, .s4:
                trace(evt, s_m, s_m)
                genSetRequestedMaxFrequency()
            default:
                break
            }
        }
    }
    
    override func createKey(_ keyName: String) -> ItemKey {
        Key2Level(keyName, self)
    }
    
    private func genSetRequestedMaxFrequency() {
        for (_, key) in keys {
            key.evtSetRequestedMaxFrequency()
        }
    }
    
    private func genOnRealMaxFrequency2LevelRemoved() {
        strategy.evtOnRealMaxFrequency2LevelRemoved()
    }
}
