import Foundation
import XCTest
@testable import LightstreamerClient

final class Tests: XCTestCase {
    
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
        XCTAssertEqual(100, DispatchTime(uptimeNanoseconds: start.uptimeNanoseconds + 100).uptimeNanoseconds)
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
        let log = ConsoleLogger(.warn, category: "foo")
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
}
