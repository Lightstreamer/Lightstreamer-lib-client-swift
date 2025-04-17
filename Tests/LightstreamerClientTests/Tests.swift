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
import XCTest
@testable import LightstreamerClient

final class Tests: XCTestCase {
    
    func testItemNames() {
        let sub = Subscription(subscriptionMode: .MERGE)
        sub.items = ["i123"]
        sub.items = ["123i"]
        
        let mpn = MPNSubscription(subscriptionMode: .MERGE)
        mpn.items = ["i123"]
        mpn.items = ["123i"]
    }
    
    func testUnquote() {
        func unquote(_ s: String) -> String {
            return s.removingPercentEncoding!
        }
        XCTAssertEqual("", unquote(""))
        XCTAssertEqual("☺", unquote("☺")) // unicode code point U+263A
        XCTAssertEqual("☺", unquote("%E2%98%BA"))
        XCTAssertEqual("baràè", unquote("baràè"))
        XCTAssertEqual("baràè%", unquote("bar%c3%a0%C3%A8%25"))
        XCTAssertEqual("http://via.placeholder.com/256/cbf1a2/61c73f?text=nick+242+Iñtërnâtiônàlizætiøn☃", unquote("http://via.placeholder.com/256/cbf1a2/61c73f?text=nick+242+I%C3%B1t%C3%ABrn%C3%A2ti%C3%B4n%C3%A0liz%C3%A6ti%C3%B8n%E2%98%83"))
    }
    
    func testCompleteControlLink() {
        XCTAssertEqual("http://foo.com", completeControlLink("foo.com", baseAddress: "http://base.it"))
        XCTAssertEqual("https://foo.com", completeControlLink("foo.com", baseAddress: "https://base.it"))
        XCTAssertEqual("http://foo.com:80", completeControlLink("foo.com", baseAddress: "http://base.it:80"))
        XCTAssertEqual("http://foo.com:80", completeControlLink("foo.com", baseAddress: "http://base.it:80/path"))
        
        XCTAssertEqual("https://foo.com", completeControlLink("https://foo.com", baseAddress: "http://base.it"))
        XCTAssertEqual("http://foo.com", completeControlLink("http://foo.com", baseAddress: "https://base.it"))
        XCTAssertEqual("http://foo.com:8080", completeControlLink("foo.com:8080", baseAddress: "http://base.it:80"))
        XCTAssertEqual("http://foo.com:80/bar", completeControlLink("foo.com/bar", baseAddress: "http://base.it:80/path"))
    }
    
    func testURL() {
        XCTAssertEqual("foo/bar", URL(string: "foo")!.appendingPathComponent("bar").absoluteString)
        XCTAssertEqual("foo/bar", URL(string: "foo/")!.appendingPathComponent("bar").absoluteString)
        XCTAssertEqual("foo//bar", URL(string: "foo/")!.appendingPathComponent("/bar").absoluteString)
    }
    
    func testUrlBuilder() {
        var comps = URLComponents(string: "http://host/path")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: "foo")
        ]
        XCTAssertEqual("http://host/path?q=foo", comps.string!)
    }
    
    func testQuery() {
        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "a", value: "f&=o"),
            URLQueryItem(name: "b", value: "b +r")
        ]
        XCTAssertEqual("a=f&=o&b=b +r", comps.query!)
        XCTAssertEqual("a=f%26%3Do&b=b%20+r", comps.percentEncodedQuery!)
    }
    
    func testTimeArithmetic() {
        let start = DispatchTime(uptimeNanoseconds: 0)
        XCTAssertEqual(0, start.uptimeNanoseconds)
        XCTAssertEqual(125, DispatchTime(uptimeNanoseconds: start.uptimeNanoseconds + 125).uptimeNanoseconds)
    }
    
    func testDict() {
        var d = [Int:Int?]()
        d[1] = nil
        XCTAssertTrue(d[1] == nil)
        XCTAssertEqual([:], d)
        d.updateValue(nil, forKey: 1)
        XCTAssertEqual([1:nil], d)
        XCTAssertEqual(nil, d[1]!)
    }
    
    func testEq() {
        XCTAssertEqual(RealMaxFrequency.limited(12.3), RealMaxFrequency.limited(12.3))
        XCTAssertNotEqual(RealMaxFrequency.limited(12.3), RealMaxFrequency.limited(12.4))
    }
    
    func testLog() {
        let log = ConsoleLogger(level: .warn, category: "foo")
        log.debug("log at debug")
        log.info("log at info")
        log.warn("log at warn")
        log.error("log at error")
        log.fatal("log at fatal")
        
        enum MyError: Error {
            case error
        }
        
        do {
            throw MyError.error
        } catch {
            log.error("log exception", withException: error)
        }
    }
    
    func testRemovalDuringIteration() {
        var ls = [0, 1, 2, 3]
        var visited = [Int]()
        for e in ls {
            visited.append(e)
            if e == 1 {
                ls.remove(at: 1)
            }
        }
        XCTAssertEqual([0, 1, 2, 3], visited)
        XCTAssertEqual([0, 2, 3], ls)
    }
    
    func testRemovalFromMapDuringIteration() {
        var ls = OrderedDictionary(uniqueKeysWithValues: [0:"zero", 1:"one", 2:"two", 3:"three"])
        var visited = [Int:String]()
        for (i, e) in ls {
            visited[i] = e
            if i == 1 {
                ls.removeValue(forKey: 1)
            }
        }
        XCTAssertEqual([0:"zero", 1:"one", 2:"two", 3:"three"], visited)
        XCTAssertEqual([0:"zero", 2:"two", 3:"three"], ls.unorderedDictionary)
    }
}
