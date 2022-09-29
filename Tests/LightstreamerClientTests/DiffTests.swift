import Foundation
import XCTest
@testable import LightstreamerClient

final class DiffTests: XCTestCase {
    func testDecode() {
        XCTAssertEqual("", DiffDecoder.apply("", ""));
        XCTAssertEqual("foo", DiffDecoder.apply("foo", "d")); // copy(3)
        XCTAssertEqual("foo", DiffDecoder.apply("foobar", "d")); // copy(3)
        XCTAssertEqual("fzap", DiffDecoder.apply("foobar", "bdzap")); // copy(1)add(3,zap)
        XCTAssertEqual("fzapbar", DiffDecoder.apply("foobar", "bdzapcd")); // copy(1)add(3,zap)del(2)copy(3)
        XCTAssertEqual("zapfoo", DiffDecoder.apply("foobar", "adzapad")); // copy(0)add(3,zap)del(0)copy(3)
        XCTAssertEqual("foo", DiffDecoder.apply("foobar", "aaad")); // copy(0)add(0)del(0)copy(3)
        XCTAssertEqual("1", DiffDecoder.apply("abcdefghijklmnopqrstuvwxyz1", "aaBab")); // copy(0)add(0)del(26)copy(1)
      }
}
