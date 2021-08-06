import XCTest
@testable import LightstreamerClient

final class RetryDelayCounterTests: XCTestCase {
    
    func test() {
        let c = RetryDelayCounter()
        c.reset(4_000)
        XCTAssertEqual(4_000, c.currentRetryDelay)
        
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(4_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(8_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(16_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(32_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(60_000, c.currentRetryDelay)
        c.increase()
        XCTAssertEqual(60_000, c.currentRetryDelay)
        
        c.reset(4_000)
        XCTAssertEqual(4_000, c.currentRetryDelay)
        XCTAssertEqual(1, c.attempt)
    }
}
