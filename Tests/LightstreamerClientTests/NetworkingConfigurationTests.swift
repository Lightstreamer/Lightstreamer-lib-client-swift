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

final class NetworkingConfigurationTests: XCTestCase {
    var client: LightstreamerClient!
    let host = "http://localtest.me:8080"
    
    override func tearDown() {
        client.disconnect()
    }
    
    func testFirstConnectUsesSharedSessionAndRetainsIt() {
        client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        XCTAssertNil(client.m_session)

        client.connect()
        XCTAssertTrue(client.m_session === LsSession.shared)

        client.disconnect()
        XCTAssertTrue(client.m_session === LsSession.shared)
        XCTAssertThrowsError(try client.connectionOptions.configureNetworking(configuration: .ephemeral)) {
            XCTAssertEqual($0 as? NetworkingError, .sessionAlreadyInitialized)
        }

        client.connect()
        XCTAssertTrue(client.m_session === LsSession.shared)
    }

    func testPrivateSessionCannotBeReconfiguredEvenAfterDisconnect() throws {
        client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        XCTAssertNil(client.m_session)

        try client.connectionOptions.configureNetworking(configuration: .ephemeral)
        let session = try XCTUnwrap(client.m_session)
        XCTAssertFalse(session === LsSession.shared)
        XCTAssertThrowsError(try client.connectionOptions.configureNetworking(configuration: .default)) {
            XCTAssertEqual($0 as? NetworkingError, .sessionAlreadyInitialized)
        }

        client.connect()
        XCTAssertTrue(client.m_session === session)
        
        client.disconnect()
        XCTAssertTrue(client.m_session === session)
        XCTAssertThrowsError(try client.connectionOptions.configureNetworking(configuration: .ephemeral)) {
            XCTAssertEqual($0 as? NetworkingError, .sessionAlreadyInitialized)
        }

        client.connect()
        XCTAssertTrue(client.m_session === session)
    }

    func testSessionSelectionIsPerClient() throws {
        client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        let first = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        let second = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        XCTAssertNil(first.m_session)
        XCTAssertNil(second.m_session)
        XCTAssertNil(client.m_session)

        try first.connectionOptions.configureNetworking(configuration: .ephemeral)
        try second.connectionOptions.configureNetworking(configuration: .ephemeral)
        let firstSession = try XCTUnwrap(first.m_session)
        let secondSession = try XCTUnwrap(second.m_session)
        XCTAssertFalse(firstSession === secondSession)
        XCTAssertFalse(firstSession === LsSession.shared)
        XCTAssertFalse(secondSession === LsSession.shared)
        XCTAssertNil(client.m_session)

        client.connect()
        XCTAssertTrue(client.m_session === LsSession.shared)
    }
}
