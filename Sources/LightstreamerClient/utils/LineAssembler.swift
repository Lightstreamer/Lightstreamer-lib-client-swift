import Foundation

// not thread-safe
class LineAssembler {
    
    var buf = ""
    
    func process(_ chunk: String) -> [String] {
        var lines = [String]()
        buf += chunk
        var cur = buf.startIndex
        let end = buf.endIndex
        while let range = buf.range(of: "\r\n", range: cur..<end) {
            lines.append(String(buf[cur..<range.lowerBound]))
            cur = range.upperBound
        }
        buf = String(buf[cur..<end])
        return lines
    }
}
