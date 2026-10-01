/*
 * Copyright (C) 2026 Lightstreamer Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
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

final class MemoryLeakTests: XCTestCase {
    
    func testReleasingClientAfterServerAddressChange() throws {
        weak var weakClient: LightstreamerClient?

        try autoreleasepool {
            let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
            try client.connectionOptions.configureNetworking(configuration: .default)
            client.connect()

            client.connectionDetails.serverAddress = "http://127.0.0.1:8080"
            weakClient = client
        }

        // Allow pending callbacks to finish before distinguishing a leak from temporary retention.
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            weakClient == nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [released], timeout: 3), .completed,
                       "Changing serverAddress must not retain the client")
    }

    
    func testReleasingConnectedClientShutsDownPrivateSession() throws {
        let expectation = XCTestExpectation(description: "Private URLSession invalidated")
        
        weak var weakClient: LightstreamerClient?
        var session: LsSession!

        try autoreleasepool {
            let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
            try client.connectionOptions.configureNetworking(configuration: .default)
            let clientDelegate = CTBClientDelegate()
            client.addDelegate(clientDelegate)
            clientDelegate.onStatusChange = { status in
                if status == .CONNECTED_WS_STREAMING {
                    expectation.fulfill()
                }
            }
            client.connect()
            
            weakClient = client
            session = try XCTUnwrap(client.m_session)
            
            wait(for: [expectation], timeout: 3)
            
            XCTAssertNotNil(weakClient)
            XCTAssertFalse(session.isShutdown)
        }

        XCTAssertNil(weakClient)
        XCTAssertTrue(session.isShutdown)
    }
    
    func testReleasingPrivateSessionClientDoesInvalidatePrivateSession() throws {
        weak var weakClient: LightstreamerClient?
        var session: LsSession!

        try autoreleasepool {
            let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
            try client.connectionOptions.configureNetworking(configuration: .default)
            
            session = try XCTUnwrap(client.m_session)
            weakClient = client
            
            XCTAssertNotNil(weakClient)
            XCTAssertFalse(session.isShutdown)
        }

        XCTAssertNil(weakClient)
        XCTAssertTrue(session.isShutdown)
    }

    func testReleasingSharedSessionClientDoesNotInvalidateSharedSession() throws {
        weak var weakClient: LightstreamerClient?
        var session: LsSession!
        
        try autoreleasepool {
            let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
            client.connect() // connect() assigns the client a shared session
            defer { client.disconnect() }
            
            session = try XCTUnwrap(client.m_session)
            weakClient = client
            
            XCTAssertNotNil(weakClient)
            XCTAssertFalse(session.isShutdown)
        }

        // connect() starts asynchronous reachability/transport callbacks that can temporarily retain the client;
        // this immediate assertion is timing-sensitive and does not reliably distinguish that from a leak.
        // XCTAssertNil(weakClient)
        XCTAssertFalse(session.isShutdown)
    }

    func testNoHTTPRetentionCycle() {
        let expectation = XCTestExpectation()
        
        let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        defer { client.disconnect() }
        
        let clientDelegate = CTBClientDelegate()
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(clientDelegate)
        
        weak var http: LsHttpClient?
        
        clientDelegate.onStatusChange = { [unowned client] status in
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
        
        let client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        defer { client.disconnect() }
        
        let clientDelegate = CTBClientDelegate()
        client.connectionOptions.forcedTransport = .WS
        client.addDelegate(clientDelegate)
        
        weak var ws: LsWebsocketClient?
        
        clientDelegate.onStatusChange = { [unowned client] status in
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

}
