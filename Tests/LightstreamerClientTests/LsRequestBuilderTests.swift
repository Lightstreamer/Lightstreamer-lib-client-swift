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
import XCTest
@testable import LightstreamerClient

final class LsRequestBuilderTests: XCTestCase {
    
    func test() {
        let req = LsRequestBuilder()
        req.addParam("a", "f&=o")
        req.addParam("b", "b +r")
        XCTAssertEqual("a=f%26%3Do&b=b%20%2Br", req.encodedString)
    }

    func testCompactedListsPreserveOrderAndScalarEncoding() {
        let req = LsRequestBuilder()
        req.LS_reqId(1)
        req.LS_item(["a b", "x&y", "123"])
        req.LS_field(["f=1", "f+2", "%26"])
        req.LS_data_adapter("a&b +c")
        XCTAssertEqual("LS_reqId=1&LS_item=a%20b&x%26y&123&LS_field=f%3D1&f%2B2&%2526&LS_data_adapter=a%26b%20%2Bc", req.encodedString)
        XCTAssertEqual(req.encodedString, req.encodedString)
    }

    func testNamesEncodeUTF8BytesExactlyOnce() {
        let cases: [(String, String)] = [
            ("AZaz09-._~", "AZaz09-._~"),
            (" ", "%20"), ("\t", "%09"), ("\r\n\0", "%0D%0A%00"),
            ("&=%+?#/", "%26%3D%25%2B%3F%23%2F"),
            ("%26", "%2526"), ("é", "%C3%A9"),
            ("e\u{301}", "e%CC%81"), ("東京", "%E6%9D%B1%E4%BA%AC"),
            ("😀", "%F0%9F%98%80"),
            ("x&LS_group=y", "x%26LS_group%3Dy"),
            ("LS_field=z", "LS_field%3Dz")
        ]
        for (name, encoded) in cases {
            let req = LsRequestBuilder()
            req.LS_item([name])
            req.LS_field([name])
            XCTAssertEqual("LS_item=\(encoded)&LS_field=\(encoded)", req.encodedString, String(reflecting: name))
        }
    }

    func testDuplicateAndCanonicallyEquivalentNamesAreNotNormalized() {
        let req = LsRequestBuilder()
        req.LS_item(["é", "e\u{301}", "é"])
        req.LS_field(["z", "a", "z"])
        XCTAssertEqual("LS_item=%C3%A9&e%CC%81&%C3%A9&LS_field=z&a&z", req.encodedString)
    }

    func testEncodedListsSurviveBatchingAndRequestLimits() {
        let req = LsRequestBuilder()
        req.LS_item(["東", "x&y"])
        req.LS_field(["f g\r\n"])
        let expected = "LS_item=%E6%9D%B1&x%26y&LS_field=f%20g%0D%0A"
        XCTAssertEqual(expected, req.encodedString)
        let requests = [Req(req.encodedString), Req(req.encodedString)]
        let size = expected.utf8.count
        XCTAssertEqual(expected, prepareBatchHTTP(requests, size * 2 + 1))
        XCTAssertEqual(expected + "\r\n" + expected, prepareBatchHTTP(requests, size * 2 + 2))
        XCTAssertEqual(expected, prepareBatchHTTP(requests, 1))
        XCTAssertEqual(["control\r\n" + expected, "control\r\n" + expected],
                       prepareBatchWS("control", requests, 9 + size * 2 + 1))
        XCTAssertEqual(["control\r\n" + expected + "\r\n" + expected],
                       prepareBatchWS("control", requests, 9 + size * 2 + 2))
        XCTAssertEqual(["control\r\n" + expected, "control\r\n" + expected],
                       prepareBatchWS("control", requests, 1))
    }
}
