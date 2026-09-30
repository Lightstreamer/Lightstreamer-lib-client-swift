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

class NetTests: XCTestCase {
    
    func testNoHTTPRetentionCycle() {
        let expectation = XCTestExpectation()
        
        let host = "http://localtest.me:8080"
        let client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        defer { client.disconnect() }
        
        let clientDelegate = CTBClientDelegate()
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(clientDelegate)
        
        weak var http: LsHttpClient?
        
        clientDelegate.onStatusChange = { status in
            if status == .CONNECTED_HTTP_STREAMING {
                http = client.http
                XCTAssertNotNil(http)
                client.disconnect()
                
            } else if status == .DISCONNECTED {
                XCTAssertNil(client.http)
                XCTAssertNil(http)
                expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testNoWSRetentionCycle() {
        let expectation = XCTestExpectation()
        
        let host = "http://localtest.me:8080"
        let client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        defer { client.disconnect() }
        
        let clientDelegate = CTBClientDelegate()
        client.connectionOptions.forcedTransport = .WS
        client.addDelegate(clientDelegate)
        
        weak var ws: LsWebsocketClient?
        
        clientDelegate.onStatusChange = { status in
            if status == .CONNECTED_WS_STREAMING {
                ws = client.ws
                XCTAssertNotNil(ws)
                client.disconnect()
                
            } else if status == .DISCONNECTED {
                XCTAssertNil(client.ws)
                XCTAssertNil(ws)
                expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
   
    func testHTTP() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        
        let client = LsHttp(
            NSRecursiveLock(),
            LsSession.shared,
            "http://push.lightstreamer.com/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)",
            body: "LS_polling=true&LS_polling_millis=0&LS_adapter_set=DEMO&LS_cid=mgQkwtwdysogQz2BJ4Ji%20kOj2Bg",
            certificatePins: [],
            onText: { http, text in
                if text.contains("CONOK") {
                    expectation.fulfill()
                }
            },
            onError: { http, error in
//                assertionFailure()
            },
            onFatalError: {_, _, _ in },
            onDone: { http in
                expectation.fulfill()
            })
        
        wait(for: [expectation], timeout: 2)
        
        client.dispose()
    }
    
    func testWS() {
        let expectation = XCTestExpectation()
        
        let client = LsWebsocket(
            NSRecursiveLock(),
            LsSession.shared,
            "http://push.lightstreamer.com/lightstreamer",
            protocols: "\(TLCP_VERSION).lightstreamer.com",
            certificatePins: [],
            onOpen: { ws in
                ws.send("""
                    create_session\r
                    LS_polling=true&LS_polling_millis=0&LS_adapter_set=DEMO&LS_cid=mgQkwtwdysogQz2BJ4Ji%20kOj2Bg
                    """)
            },
            onText: { ws, text in
                if text.contains("CONOK") {
                    expectation.fulfill()
                }
            },
            onError: { ws, error in
//                assertionFailure()
            },
            onFatalError: {_,_,_ in })
        
        wait(for: [expectation], timeout: 2)
        
        client.dispose()
    }
    
    func testTimeout() {
        let expectation = XCTestExpectation()
        
        let lock = NSRecursiveLock()
        let task = Scheduler.Task(lock) {
            expectation.fulfill()
        }
        let scheduler = Scheduler()
        scheduler.schedule("test", 500, task)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testCancelTimeout() {
        let expectation = XCTestExpectation()
        expectation.isInverted = true
        
        let lock = NSRecursiveLock()
        let task = Scheduler.Task(lock) {
            expectation.fulfill()
        }
        let item = task.item
        let scheduler = Scheduler()
        scheduler.schedule("test", 500, task)
        task.cancel()
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssertTrue(item!.isCancelled)
    }
}
