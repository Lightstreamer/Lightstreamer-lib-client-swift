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

func applyUpatesToCurrentFields(_ currentValues: [Pos:CurrFieldVal?]?, _ incomingValues: [Pos:FieldValue]) throws -> [Pos:CurrFieldVal?] {
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
                    do {
                        newValues.updateValue(.jsonVal(try applyPatch(json, patch)), forKey: f)
                    } catch {
                        sessionLogger.error(error.localizedDescription)
                        throw InternalException.IllegalStateException("Cannot apply the JSON Patch to the field \(f)")
                    }
                case .stringVal(let str):
                    let json: LsJson
                    do {
                        json = try newJson(str)
                    } catch {
                        sessionLogger.error(error.localizedDescription)
                        throw InternalException.IllegalStateException("Cannot convert the field \(f) to JSON")
                    }
                    do {
                        newValues.updateValue(.jsonVal(try applyPatch(json, patch)), forKey: f)
                    } catch {
                        sessionLogger.error(error.localizedDescription)
                        throw InternalException.IllegalStateException("Cannot apply the JSON Patch to the field \(f)")
                    }
                case .none:
                    throw InternalException.IllegalStateException("Cannot apply the JSON patch to the field \(f) because the field is null")
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
                throw InternalException.IllegalStateException("Cannot set the field \(f) because the first update is UNCHANGED")
            case .jsonPatch(_):
                throw InternalException.IllegalStateException("Cannot set the field \(f) because the first update is a JSONPatch")
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
