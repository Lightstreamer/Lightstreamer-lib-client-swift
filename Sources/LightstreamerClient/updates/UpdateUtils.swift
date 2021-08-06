import Foundation

enum FieldValue: Equatable {
    case unchanged
    case changed(String?)
}

typealias Pos = Int

func mapUpdateValues(_ oldValues: [Pos:String?]?, _ values: [Pos:FieldValue]) -> [Pos:String?] {
    if let oldValues = oldValues {
        var newValues = [Pos:String?]()
        for (i, fieldValue) in values {
            switch fieldValue {
            case .unchanged:
                newValues[i] = oldValues[i]
            case .changed(let value):
                newValues[i] = value
            }
        }
        return newValues
    } else {
        var newValues = [Pos:String?]()
        for (i, fieldValue) in values {
            switch fieldValue {
            case .changed(let value):
                newValues[i] = value
            default:
                assertionFailure()
            }
        }
        return newValues
    }
}

func findChangedFields(prev: [Pos:String?]?, curr: [Pos:String?]) -> Set<Pos> {
    if let prev = prev {
        var changedFields = Set<Pos>()
        for i in curr.keys {
            if prev[i] != curr[i] {
                changedFields.insert(i)
            }
        }
        return changedFields
    } else {
        return Set(curr.keys)
    }
}
