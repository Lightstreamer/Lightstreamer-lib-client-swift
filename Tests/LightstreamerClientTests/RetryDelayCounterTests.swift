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
