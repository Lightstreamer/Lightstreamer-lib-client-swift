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
    let m_newValues: [Pos:CurrFieldVal?]
    let m_changedFields: Set<Pos>
    let m_isSnapshot: Bool
#if LS_JSON_PATCH
    let m_jsonPatches: [Pos:LsJsonPatch]
#endif
    
#if LS_JSON_PATCH
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:CurrFieldVal?], _ changedFields: Set<Pos>, _ isSnapshot: Bool, _ jsonPatches: [Pos:LsJsonPatch]) {
        let fields = sub.fields
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(fields)
        if let fields = fields, fields.count != m_nFields {
             subscriptionLogger.error("Expected \(m_nFields) field names but got \(fields.count): \(fields)");
           }
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
        self.m_jsonPatches = jsonPatches
    }
#else
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:CurrFieldVal?], _ changedFields: Set<Pos>, _ isSnapshot: Bool) {
        let fields = sub.fields
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(fields)
        if let fields = fields, fields.count != m_nFields {
             subscriptionLogger.error("Expected \(m_nFields) field names but got \(fields.count): \(fields)");
           }
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
    }
#endif
    
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
            if let fieldName = fields[fieldPos] {
                res[fieldName] = toString(m_newValues[fieldPos] ?? nil)
            } // else branch should never happen: see the check in the ctor
        }
        return res
    }
    
    var changedFieldsByPositions: [Int : String?] {
        var res = [Int:String?]()
        for fieldPos in m_changedFields {
            res[fieldPos] = toString(m_newValues[fieldPos] ?? nil)
        }
        return res
    }
    
    var fields: [String : String?] {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for (fieldPos, fieldName) in fields {
            res[fieldName] = toString(m_newValues[fieldPos] ?? nil)
        }
        return res
    }
    
    var fieldsByPositions: [Int : String?] {
        m_newValues.mapValues { val in toString(val) }
    }
    
    func value(withFieldPos fieldPos: Int) -> String? {
        precondition(1 <= fieldPos && fieldPos <= m_nFields, POS_OUT_BOUNDS)
        return toString(m_newValues[fieldPos] ?? nil)
    }
    
    func value(withFieldName fieldName: String) -> String? {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = findFirstIndex(fields, of: fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return toString(m_newValues[fieldPos] ?? nil)
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
    
#if LS_JSON_PATCH
    func valueAsJSONPatchIfAvailable(withFieldName fieldName: String) -> String? {
        guard let fields = m_fields else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = findFirstIndex(fields, of: fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        let val = m_jsonPatches[fieldPos]
        return val != nil ? jsonPatchToString(val!) : nil
    }
    
    func valueAsJSONPatchIfAvailable(withFieldPos fieldPos: Int) -> String? {
        let val = m_jsonPatches[fieldPos]
        return val != nil ? jsonPatchToString(val!) : nil
    }
#endif
    
    private func getFieldNameOrNilFromIdx(_ fieldIdx: Pos) -> String? {
        m_fields?[fieldIdx]
    }
    
    var description: String {
        var s = "["
        for i in 1...m_newValues.count {
            let val = m_newValues[i]!
            let fieldName = getFieldNameOrNilFromIdx(i) ?? "\(i)"
            let fieldVal = toString(val) ?? "nil"
            if i > 1 {
                s += ","
            }
            s += "\(fieldName):\(fieldVal)"
        }
        s += "]"
        return s
    }
}

#if LS_JSON_PATCH
typealias JsonPatchTypeAsReturnedByGetPatch = String
#endif

class ItemUpdate2Level: ItemUpdate {
    
    let m_itemIdx: Pos
    let m_items: [Pos:String]?
    let m_nFields: Int
    let m_fields: [Pos:String]?
    let m_fields2: [Pos:String]?
    let m_newValues: [Pos:CurrFieldVal?]
    let m_changedFields: Set<Pos>
    let m_isSnapshot: Bool
#if LS_JSON_PATCH
    let m_jsonPatches: [Pos:JsonPatchTypeAsReturnedByGetPatch]
#endif
    
#if LS_JSON_PATCH
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:CurrFieldVal?], _ changedFields: Set<Pos>, _ isSnapshot: Bool, _ jsonPatches: [Pos:JsonPatchTypeAsReturnedByGetPatch]) {
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(sub.fields)
        self.m_fields2 = toMap(sub.commandSecondLevelFields)
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
        self.m_jsonPatches = jsonPatches
    }
#else
    init(_ itemIdx: Pos, _ sub: Subscription, _ newValues: [Pos:CurrFieldVal?], _ changedFields: Set<Pos>, _ isSnapshot: Bool) {
        self.m_itemIdx = itemIdx
        self.m_items = toMap(sub.items)
        self.m_nFields = sub.nFields!
        self.m_fields = toMap(sub.fields)
        self.m_fields2 = toMap(sub.commandSecondLevelFields)
        self.m_newValues = newValues
        self.m_changedFields = changedFields
        self.m_isSnapshot = isSnapshot
    }
#endif
    
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
            if let fieldName = getFieldNameFromIdx(fieldPos) {
                res[fieldName] = toString(m_newValues[fieldPos] ?? nil)
            } // else branch should never happen
        }
        return res
    }
    
    var changedFieldsByPositions: [Int : String?] {
        var res = [Int:String?]()
        for fieldPos in m_changedFields {
            res[fieldPos] = toString(m_newValues[fieldPos] ?? nil)
        }
        return res
    }
    
    var fields: [String : String?] {
        guard m_fields != nil && m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        var res = [String:String?]()
        for (f, v) in m_newValues {
            if let fieldName = getFieldNameFromIdx(f) {
                res[fieldName] = toString(v)
            } // else branch should never happen
        }
        return res
    }
    
    var fieldsByPositions: [Int : String?] {
        m_newValues.mapValues { val in toString(val) }
    }
    
    func value(withFieldPos fieldPos: Int) -> String? {
        toString(m_newValues[fieldPos] ?? nil)
    }
    
    func value(withFieldName fieldName: String) -> String? {
        guard m_fields != nil || m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = getFieldIdxFromName(fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        return toString(m_newValues[fieldPos] ?? nil)
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
    
#if LS_JSON_PATCH
    func valueAsJSONPatchIfAvailable(withFieldName fieldName: String) -> String? {
        guard m_fields != nil || m_fields2 != nil else {
            preconditionFailure(NO_FIELDS)
        }
        guard let fieldPos = getFieldIdxFromName(fieldName) else {
            preconditionFailure(UNKNOWN_FIELD_NAME)
        }
        let val = m_jsonPatches[fieldPos]
        return val != nil ? val! : nil
    }
    
    func valueAsJSONPatchIfAvailable(withFieldPos fieldPos: Int) -> String? {
        let val = m_jsonPatches[fieldPos]
        return val != nil ? val! : nil
    }
#endif
    
    private func getFieldNameFromIdx(_ fieldIdx: Pos) -> String? {
        guard let fields = m_fields, let fields2 = m_fields2 else {
            preconditionFailure()
        }
        if fieldIdx <= m_nFields {
            return fields[fieldIdx]
        } else {
            return fields2[fieldIdx - m_nFields]
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
            let fieldVal = toString(val) ?? "nil"
            if i > 1 {
                s += ","
            }
            s += "\(fieldName):\(fieldVal)"
        }
        s += "]"
        return s
    }
}
