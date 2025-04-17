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

let LS_TEST_CID = LS_CID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

class BaseTestCase: XCTestCase {
    let io = Trace()
    let ws = TestWSFactory()
    let http = TestHTTPFactory()
    let ctrl = TestHTTPFactory("ctrl")
    let delegate = TestDelegate()
    let msgDelegate = TestMsgDelegate()
    let subDelegate = TestSubDelegate()
    let mpnDevDelegate = TestMpnDeviceDelegate()
    let mpnSubDelegate = TestMpnSubDelegate()
    let scheduler = TestScheduler()
    let reachability = TestReachabilityFactory()
    let expectation = XCTestExpectation()
    var client: LightstreamerClient!
    
    override class func setUp() {
        LightstreamerClient.setLoggerProvider(ConsoleLoggerProvider(level: .warn))
    }
    
    func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        ws.m_trace = io
        http.m_trace = io
        ctrl.m_trace = io
        return LightstreamerClient(url, adapterSet: adapterSet,
                                   wsFactory: ws.createWS,
                                   httpFactory: http.createHTTP,
                                   ctrlFactory: ctrl.createHTTP,
                                   scheduler: scheduler,
                                   randomGenerator: { n in n },
                                   reachabilityFactory: reachability.create)
    }
    
    func asyncAssert(block: @escaping () -> Void) {
        client.callbackQueue.async {
            block()
            self.expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func asyncAssert(after delay: TimeInterval, _ block: @escaping () -> Void) {
        client.callbackQueue.asyncAfter(deadline: .now() + delay) {
            block()
            self.expectation.fulfill()
        }
        wait(for: [expectation], timeout: max(1, delay) + 0.5)
    }
    
    func async(after delay: TimeInterval, _ block: @escaping () -> Void) {
        client.callbackQueue.asyncAfter(deadline: .now() + delay) {
            block()
        }
    }
}
