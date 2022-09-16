import Foundation
import JSONPatch

enum FieldValue: Equatable {
    case unchanged
    case changed(String?)
    case jsonPatch(LsJsonPatch)
}

typealias Pos = Int

enum CurrFieldVal {
    case stringVal(String)
    case jsonVal(LsJson)
}

func currFieldValToString(_ val: CurrFieldVal?) -> String? {
    switch val {
    case .none:
        return nil
    case .stringVal(let str):
        return str
    case .jsonVal(let json):
        return jsonToString(json)
    }
}

func applyUpatesToCurrentFields(_ currentValues: [Pos:CurrFieldVal?]?, _ incomingValues: [Pos:FieldValue]) -> [Pos:CurrFieldVal?] {
    if let currentValues = currentValues {
        var newValues = [Pos:CurrFieldVal?]()
        for (f, fieldValue) in incomingValues {
            switch fieldValue {
            case .unchanged:
                newValues.updateValue(currentValues[f] ?? nil, forKey: f)
            case .changed(let value):
                if value == nil {
                    newValues.updateValue(nil, forKey: f)
                } else {
                    newValues.updateValue(.stringVal(value!), forKey: f)
                }
            case .jsonPatch(let patch):
                switch currentValues[f]! {
                case .jsonVal(let json):
                    newValues.updateValue(.jsonVal(try! applyPatch(json, patch)), forKey: f)
                    // TODO catch and rethrow exception
                case .stringVal(let str):
                    let json = try! newJson(str)
                    // TODO catch and rethrow exception
                    newValues.updateValue(.jsonVal(try! applyPatch(json, patch)), forKey: f)
                    // TODO catch and rethrow exception
                case .none:
                    break
                    // TODO throw exception
                }
            }
        }
        return newValues
    } else {
        var newValues = [Pos:CurrFieldVal?]()
        for (f, fieldValue) in incomingValues {
            switch fieldValue {
            case .changed(let value):
                if value == nil {
                    newValues.updateValue(nil, forKey: f)
                } else {
                    newValues.updateValue(.stringVal(value!), forKey: f)
                }
            case .unchanged:
                break
                // TODO throw exception
            case .jsonPatch(_):
                break
                // TODO throw exception
            }
        }
        return newValues
    }
}

func findChangedFields(prev: [Pos:CurrFieldVal?]?, curr: [Pos:CurrFieldVal?]) -> Set<Pos> {
    if let prev = prev {
        var changedFields = Set<Pos>()
        for i in curr.keys {
            if currFieldValToString(prev[i]!) != currFieldValToString(curr[i]!) {
                changedFields.insert(i)
            }
        }
        return changedFields
    } else {
        return Set(curr.keys)
    }
}

func computeJsonPatches(_ currentValues: [Pos:CurrFieldVal?]?, _ incomingValues: [Pos:FieldValue]) -> [Pos:LsJsonPatch] {
    if let currentValues = currentValues {
        var res = [Pos:LsJsonPatch]()
        for (f, value) in incomingValues {
            switch value {
            case .jsonPatch(let patch):
                res.updateValue(patch, forKey: f)
            case .unchanged:
                let curr = currentValues[f]!
                if let curr = curr {
                    switch curr {
                    case .jsonVal(_):
                        res.updateValue(try! newJsonPatch("[]"), forKey: f)
                    default:
                        break
                    }
                }
            default:
                break
            }
        }
        return res
    } else {
        return [:]
    }
}
