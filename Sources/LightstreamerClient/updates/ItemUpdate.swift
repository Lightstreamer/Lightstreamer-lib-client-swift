import Foundation

fileprivate let NO_FIELDS = "The Subscription was initiated using a Field Schema: the field names are not available"
fileprivate let POS_OUT_BOUNDS = "The field position is out of bounds"
fileprivate let UNKNOWN_FIELD_NAME = "The field name is unknown"

fileprivate func toMap(_ array: [String]?) -> [Pos:String]? {
    if let array = array {
        var map = [Pos:String]()
        for (i, v) in array.enumerated() {
            map[i + 1] = v
        }
        return map
    }
    return nil
}

fileprivate func findFirstIndex(_ map: [Pos:String], of value: String) -> Pos? {
    for i in 1...map.count {
        if map[i] == value {
            return i
        }
    }
    return nil
}

class ItemUpdateBase: ItemUpdate {
    let m_itemIdx: Pos
    let m_items: [Pos:String]?
    let m_nFields: Int
    let m_fields: [Pos:String]?
    let m_newValues: [Pos:String?]
    let m_changedFields: Set<Pos>
    let m_isSnapshot: Bool
    
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:String?], _ changedFields: Set<Pos>, _ isSnapshot: Bool) {
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(sub.fields)
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
    }
    
    var itemName: String? {
        m_items?[m_itemIdx]
    }
    
    var itemPos: Int {
        m_itemIdx
    }
    
    var isSnapshot: Bool {
        m_isSnapshot
    }
    
    var changedFields: [String : String?] {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for fieldPos in m_changedFields {
            res[fields[fieldPos]!] = m_newValues[fieldPos]
        }
        return res
    }
    
    var changedFieldsByPositions: [Int : String?] {
        var res = [Int:String?]()
        for fieldPos in m_changedFields {
            res[fieldPos] = m_newValues[fieldPos]
        }
        return res
    }
    
    var fields: [String : String?] {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for (fieldPos, fieldName) in fields {
            res[fieldName] = m_newValues[fieldPos]
        }
        return res
    }
    
    var fieldsByPositions: [Int : String?] {
        m_newValues
    }
    
    func value(withFieldPos fieldPos: Int) -> String? {
        precondition(1 <= fieldPos && fieldPos <= m_nFields, POS_OUT_BOUNDS)
        return m_newValues[fieldPos]!
    }
    
    func value(withFieldName fieldName: String) -> String? {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = findFirstIndex(fields, of: fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return m_newValues[fieldPos]!
    }
    
    func isValueChanged(withFieldPos fieldPos: Int) -> Bool {
        precondition(1 <= fieldPos && fieldPos <= m_nFields, POS_OUT_BOUNDS)
        return m_changedFields.contains(fieldPos)
    }
    
    func isValueChanged(withFieldName fieldName: String) -> Bool {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = findFirstIndex(fields, of: fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return m_changedFields.contains(fieldPos)
    }
    
    private func getFieldNameOrNilFromIdx(_ fieldIdx: Pos) -> String? {
        m_fields?[fieldIdx]
    }
    
    var description: String {
        var s = "["
        for i in 1...m_newValues.count {
            let val = m_newValues[i]!
            let fieldName = getFieldNameOrNilFromIdx(i) ?? "\(i)"
            let fieldVal = val == nil ? "nil" : String(reflecting: val!)
            if i > 1 {
                s += ","
            }
            s += "\(fieldName):\(fieldVal)"
        }
        s += "]"
        return s
    }
}

class ItemUpdate2Level: ItemUpdate {
    
    let m_itemIdx: Pos
    let m_items: [Pos:String]?
    let m_nFields: Int
    let m_fields: [Pos:String]?
    let m_fields2: [Pos:String]?
    let m_newValues: [Pos:String?]
    let m_changedFields: Set<Pos>
    let m_isSnapshot: Bool
    
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:String?], _ changedFields: Set<Pos>, _ isSnapshot: Bool) {
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(sub.fields)
        self.m_fields2 = toMap(sub.commandSecondLevelFields)
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
    }
    
    var itemName: String? {
        m_items?[m_itemIdx]
    }
    
    var itemPos: Int {
        m_itemIdx
    }
    
    var isSnapshot: Bool {
        m_isSnapshot
    }
    
    var changedFields: [String : String?] {
        guard m_fields != nil && m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for fieldPos in m_changedFields {
            res[getFieldNameFromIdx(fieldPos)] = m_newValues[fieldPos]
        }
        return res
    }
    
    var changedFieldsByPositions: [Int : String?] {
        var res = [Int:String?]()
        for fieldPos in m_changedFields {
            res[fieldPos] = m_newValues[fieldPos]
        }
        return res
    }
    
    var fields: [String : String?] {
        guard m_fields != nil && m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for (f, v) in m_newValues {
            res[getFieldNameFromIdx(f)] = v
        }
        return res
    }
    
    var fieldsByPositions: [Int : String?] {
        m_newValues
    }
    
    func value(withFieldPos fieldPos: Int) -> String? {
        m_newValues[fieldPos] ?? nil
    }
    
    func value(withFieldName fieldName: String) -> String? {
        guard m_fields != nil || m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = getFieldIdxFromName(fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return m_newValues[fieldPos] ?? nil
    }
    
    func isValueChanged(withFieldPos fieldPos: Int) -> Bool {
        return m_changedFields.contains(fieldPos)
    }
    
    func isValueChanged(withFieldName fieldName: String) -> Bool {
        guard m_fields != nil || m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = getFieldIdxFromName(fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return m_changedFields.contains(fieldPos)
    }
    
    private func getFieldNameFromIdx(_ fieldIdx: Pos) -> String {
        guard let fields = m_fields, let fields2 = m_fields2 else {
            preconditionFailure()
        }
        if fieldIdx <= m_nFields {
            return fields[fieldIdx]!
        } else {
            return fields2[fieldIdx - m_nFields]!
        }
    }
    
    private func getFieldIdxFromName(_ fieldName: String) -> Pos? {
        if let fields = m_fields, let fieldPos = findFirstIndex(fields, of: fieldName) {
            return fieldPos
        } else if let fields2 = m_fields2, let fieldPos = findFirstIndex(fields2, of: fieldName) {
            return m_nFields + fieldPos
        } else {
            return nil
        }
    }
    
    private func getFieldNameOrNilFromIdx(_ fieldIdx: Pos) -> String? {
        guard m_fields != nil && m_fields2 != nil else {
            return nil
        }
        return getFieldNameFromIdx(fieldIdx)
    }
    
    var description: String {
        var s = "["
        for i in 1...m_newValues.count {
            let val = m_newValues[i]!
            let fieldName = getFieldNameOrNilFromIdx(i) ?? "\(i)"
            let fieldVal = val == nil ? "nil" : String(reflecting: val!)
            if i > 1 {
                s += ","
            }
            s += "\(fieldName):\(fieldVal)"
        }
        s += "]"
        return s
    }
}
