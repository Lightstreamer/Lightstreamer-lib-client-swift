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
