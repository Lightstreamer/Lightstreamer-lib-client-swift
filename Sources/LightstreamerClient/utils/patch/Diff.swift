import Foundation

private let a_CODE = code("a")
private let A_CODE = code("A")
private let VARINT_RADIX = code("z") - code("a") + 1

private func code(_ c: Character) -> Int {
    let points = c.unicodeScalars
    let point = points[points.startIndex].value
    return Int(point)
}

typealias DiffPatch = String

class DiffDecoder {
    let diff: String
    let base: String
    var diffPos: String.Index
    var basePos: String.Index
    var buf = ""
    
    public static func apply(_ base: String, _ diff: String) -> String {
        return DiffDecoder(base, diff).decode()
    }
    
    public init(_ base: String, _ diff: String) {
        self.diff = diff
        self.base = base
        self.diffPos = diff.startIndex
        self.basePos = base.startIndex
    }
    
    public func decode() -> String {
        while (true) {
            if (diffPos == diff.endIndex) {
                break
            }
            applyCopy()
            if (diffPos == diff.endIndex) {
                break
            }
            applyAdd()
            if (diffPos == diff.endIndex) {
                break
            }
            applyDel()
        }
        return buf
    }
    
    func applyCopy() {
        let count = decodeVarint()
        if (count > 0) {
            appendToBuf(base, basePos, count)
            basePos = base.index(basePos, offsetBy: count)
        }
    }
    
    func applyAdd() {
        let count = decodeVarint()
        if (count > 0) {
            appendToBuf(diff, diffPos, count)
            diffPos = diff.index(diffPos, offsetBy: count)
        }
    }
    
    func applyDel() {
        let count = decodeVarint()
        if (count > 0) {
            basePos = base.index(basePos, offsetBy: count)
        }
    }
    
    func decodeVarint() -> Int {
        // the number is encoded with letters as digits
        var n = 0;
        while (true) {
            let c = code(diff[diffPos])
            diffPos = diff.index(diffPos, offsetBy: 1)
            if (c >= a_CODE && c < (a_CODE + VARINT_RADIX)) {
                // small letters used to mark the end of the number
                return n * VARINT_RADIX + (c - a_CODE)
            } else {
                //assert (c >= A_CODE && c < (A_CODE + VARINT_RADIX))
                n = n * VARINT_RADIX + (c - A_CODE)
            }
        }
    }
    
    func appendToBuf(_ s: String, _ startIndex: String.Index, _ count: Int) {
        let endIndex = s.index(startIndex, offsetBy: count)
        buf.append(contentsOf: s[startIndex..<endIndex])
    }
}
