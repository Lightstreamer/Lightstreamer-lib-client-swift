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
    override func setUp() {
        super.setUp()
        LsSession.resetForTesting()
    }

    override func tearDown() {
        LsSession.resetForTesting()
        super.tearDown()
    }

    func testDefaultConfigurationIsUsedWhenNotConfigured() {
        let session = LsSession.shared
        XCTAssertEqual(session.configurationForTesting.timeoutIntervalForRequest,
                       URLSessionConfiguration.default.timeoutIntervalForRequest)
    }

    func testCustomConfigurationIsUsedBySharedSessionAndCannotBeChangedAfterInitialization() throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 23

        try LightstreamerClient.configureNetworking(configuration: configuration)
        let session = LsSession.shared

        XCTAssertTrue(session === LsSession.shared)
        XCTAssertEqual(session.configurationForTesting.timeoutIntervalForRequest, 23)
        XCTAssertThrowsError(try LightstreamerClient.configureNetworking(configuration: .default)) { error in
            XCTAssertTrue(error is LightstreamerClient.NetworkingError)
        }
    }

    func testConfigurationCanBeProvidedAfterClientCreationButBeforeSessionInitialization() throws {
        let client = LightstreamerClient(serverAddress: nil)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 31

        try LightstreamerClient.configureNetworking(configuration: configuration)
        XCTAssertEqual(LsSession.shared.configurationForTesting.timeoutIntervalForRequest, 31)
        withExtendedLifetime(client) {
            // no-op; just keeping `client` alive to this point
        }
    }

    func testTestResetCreatesFreshSessionWithNewConfiguration() throws {
        let firstConfiguration = URLSessionConfiguration.ephemeral
        firstConfiguration.timeoutIntervalForRequest = 19
        try LightstreamerClient.configureNetworking(configuration: firstConfiguration)
        let firstSession = LsSession.shared

        let secondConfiguration = URLSessionConfiguration.ephemeral
        secondConfiguration.timeoutIntervalForRequest = 41
        LsSession.resetForTesting(configuration: secondConfiguration)

        let secondSession = LsSession.shared
        XCTAssertFalse(firstSession === secondSession)
        XCTAssertEqual(secondSession.configurationForTesting.timeoutIntervalForRequest, 41)
    }
}
