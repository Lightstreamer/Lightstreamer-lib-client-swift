import Foundation

let defaultQueue = DispatchQueue(label: "com.lightstreamer", qos: .userInteractive)

func parseUpdate(_ message: String) -> (subId: Int, itemIdx: Int, values: [Pos:FieldValue]) {
    // message is either U,<table>,<item>,<filed_1>|...|<field_N>
    // or U,<table>,<item>,<field_1>|^<number of unchanged fields>|...|<field_N>
    
    func index(of c: String.Element) -> String.Index {
        message.firstIndex(of: c) ?? message.endIndex
    }
    
    func index(of c: String.Element, from fromIndex: String.Index) -> String.Index {
        message.suffix(from: fromIndex).firstIndex(of: c) ?? message.endIndex
    }
    
    func substring(from fromIndex: String.Index, to toIndex: String.Index) -> Substring {
        message[fromIndex..<toIndex]
    }
    
    func after(_ i: String.Index) -> String.Index {
        message.index(i, offsetBy: 1)
    }
    
    func before(_ i: String.Index) -> String.Index {
        message.index(i, offsetBy: -1)
    }
    
    let tableIndex = after(index(of: ","))
    let itemIndex = after(index(of: ",", from: tableIndex))
    let fieldsIndex = after(index(of: ",", from: itemIndex))
    let table = Int(substring(from: tableIndex, to: before(itemIndex)))!
    let item = Int(substring(from: itemIndex, to: before(fieldsIndex)))!
    
    var values = [Pos:FieldValue]()
    var fieldStart = before(fieldsIndex) // index of the separator introducing the next field
    var nextFieldIndex = 1
    while fieldStart < message.endIndex {
        let fieldEnd = index(of: "|", from: after(fieldStart))
        /*
          Decoding algorithm:
              1) Set a pointer to the first field of the schema.
              2) Look for the next pipe “|” from left to right and take the substring to it, or to the end of the line if no pipe is there.
              3) Evaluate the substring:
                     A) If its value is empty, the pointed field should be left unchanged and the pointer moved to the next field.
                     B) Otherwise, if its value corresponds to a single “#” (UTF-8 code 0x23), the pointed field should be set to a null value and the pointer moved to the next field.
                     C) Otherwise, If its value corresponds to a single “$” (UTF-8 code 0x24), the pointed field should be set to an empty value (“”) and the pointer moved to the next field.
                     D) Otherwise, if its value begins with a caret “^” (UTF-8 code 0x5E):
                             - take the substring following the caret and convert it to an integer number;
                             - for the corresponding count, leave the fields unchanged and move the pointer forward;
                             - e.g. if the value is “^3”, leave unchanged the pointed field and the following two fields, and move the pointer 3 fields forward;
                     E) Otherwise, the value is an actual content: decode any percent-encoding and set the pointed field to the decoded value, then move the pointer to the next field.
                        Note: “#”, “$” and “^” characters are percent-encoded if occurring at the beginning of an actual content.
              4) Return to the second step, unless there are no more fields in the schema.
         */
        let value = substring(from: after(fieldStart), to: fieldEnd)
        if value.isEmpty { // step A
            values[nextFieldIndex] = .unchanged
            nextFieldIndex += 1
        } else if value == "#" { // step B
            values[nextFieldIndex] = .changed(nil)
            nextFieldIndex += 1
        } else if value == "$" { // step C
            values[nextFieldIndex] = .changed("")
            nextFieldIndex += 1
        } else if value.first == "^" { // step D
            let count = Int(value.dropFirst())!
            for _ in 1...count {
                values[nextFieldIndex] = .unchanged
                nextFieldIndex += 1
            }
        } else { // step E
            values[nextFieldIndex] = .changed(value.removingPercentEncoding)
            nextFieldIndex += 1
        }
        fieldStart = fieldEnd
    }
    return (table, item, values)
}

func completeControlLink(_ clink: String, baseAddress: String) -> String {
    let clink = clink.starts(with: "http://") || clink.starts(with: "https://") ? clink : "//\(clink)"
    let cUrl = URL(string: clink)!
    let baseUrl = URL(string: baseAddress)!
    var fullUrl = URLComponents()
    fullUrl.scheme = cUrl.scheme ?? baseUrl.scheme
    fullUrl.host = cUrl.host
    fullUrl.port = cUrl.port ?? baseUrl.port
    fullUrl.path = cUrl.path
    return fullUrl.string!
}
