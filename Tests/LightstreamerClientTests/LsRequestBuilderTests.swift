import XCTest
@testable import LightstreamerClient

final class LsRequestBuilderTests: XCTestCase {
    
    func test() {
        let req = LsRequestBuilder()
        req.addParam("a", "f&=o")
        req.addParam("b", "b +r")
        XCTAssertEqual("a=f%26%3Do&b=b%20+r", req.encodedString)
    }
}
