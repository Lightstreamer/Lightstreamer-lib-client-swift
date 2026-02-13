/*
 * Copyright (C) 2026 Lightstreamer Srl
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
import LightstreamerClient

class CertificatePinning: XCTestCase {
    var client: LightstreamerClient!
    let listener = CTBClientDelegate()
    let expectation = XCTestExpectation()
    
    // Public key of leaf certificate for push.lightstreamer.com
    static var lsLeafKey: SecKey!
    // Public key of intermediate certificate for push.lightstreamer.com
    static var lsIntermediateKey: SecKey!
    // Other keys
    static var bogusKey: SecKey!
    static var bogusKey2: SecKey!
    
    override static func setUp() {
//        LightstreamerClient.setLoggerProvider(ConsoleLoggerProvider(level: .debug))
        
        lsLeafKey = loadPubKey(file: "lightstreamer.com")
        lsIntermediateKey = loadPubKey(file: "lightstreamer.comCA")
        bogusKey = loadPubKey(file: "google.com")
        bogusKey2 = loadPubKey(file: "example.com")
    }
    
    static func loadPubKey(file: String) -> SecKey {
        let filePath = Bundle.module.url(forResource: file, withExtension: "cer")!
        let derData = try! Data(contentsOf: filePath)
        let cert = SecCertificateCreateWithData(nil, derData as CFData)!
        return SecCertificateCopyKey(cert)!
    }
    
    override func setUp() {
    }
    
    override func tearDown() {
        client.disconnect()
    }
    
    func testOnPropertyChange() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.addDelegate(listener)
        listener.onPropertyChange = { prop in
            if prop == "certificatePins" {
                self.expectation.fulfill()
            }
        }
        client.connectionDetails.certificatePins = [ Self.lsLeafKey ]
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testNoCertificate() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testNoCertificate_NoTLS() {
        client = LightstreamerClient(serverAddress: "http://push.lightstreamer.com", adapterSet: "DEMO")
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when creating a WebSocket connection.
     */
    func testBadCertificate_WS() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [ Self.bogusKey ]
        setTransport(.WS)
        client.addDelegate(listener)
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when creating an HTTP connection.
     */
    func testBadCertificate_HTTP() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [ Self.bogusKey ]
        setTransport(.HTTP)
        client.addDelegate(listener)
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when sending an HTTP force_rebind request.
     */
    func testBadCertificate_ForceRebind() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        setTransport(.HTTP_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_HTTP_STREAMING) {
                self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
                self.setTransport(.WS)
            }
        }
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when sending a WS-STREAMING rebind request.
     */
    func testBadCertificate_SwitchToWSStreaming() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        setTransport(.WS_POLLING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_POLLING) {
                self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
                self.setTransport(.WS_STREAMING)
            }
        }
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when sending a WS-POLLING rebind request.
     */
    func testBadCertificate_SwitchToWSPolling() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        setTransport(.WS_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
                self.setTransport(.WS_POLLING)
            }
        }
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when sending an HTTP-STREAMING rebind request.
     */
    func testBadCertificate_SwitchToHttpStreaming() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        setTransport(.WS_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
                self.setTransport(.HTTP_STREAMING)
            }
        }
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    /**
     * Validates the certificates when sending an HTTP-POLLING rebind request.
     */
    func testBadCertificate_SwitchToHttpPolling() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        setTransport(.WS_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
                self.setTransport(.HTTP_POLLING)
            }
        }
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testBadCertificate_NoTLS() {
        client = LightstreamerClient(serverAddress: "http://push.lightstreamer.com", adapterSet: "DEMO")
        self.client.connectionDetails.certificatePins = [ Self.bogusKey ]
        setTransport(.HTTP_POLLING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_HTTP_POLLING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testGoodCertificate_WS() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        self.client.connectionDetails.certificatePins = [ Self.lsLeafKey ]
        setTransport(.WS_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testGoodCertificate_HTTP() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [ Self.lsLeafKey ]
        setTransport(.HTTP_STREAMING)
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_HTTP_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testGoodIntermediateCertificate() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [ Self.lsIntermediateKey ]
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testGoodAndBadCertificates() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [
            Self.bogusKey,
            Self.lsLeafKey
        ]
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testTwoGoodCertificates() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [
            Self.lsLeafKey,
            Self.lsIntermediateKey
        ]
        client.addDelegate(listener)
        listener.onStatusChange = { status in
            if (status == .CONNECTED_WS_STREAMING) {
                self.expectation.fulfill()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testTwoBadCertificates() {
        client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com", adapterSet: "DEMO")
        client.connectionDetails.certificatePins = [
            Self.bogusKey,
            Self.bogusKey2
        ]
        client.addDelegate(listener)
        listener.onServerError = { code, msg in
            XCTAssertEqual("62 Unrecognized server's identity", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    private func setTransport(_ transport: TransportSelection) {
        client.connectionOptions.forcedTransport = transport
        if (transport == .HTTP_POLLING || transport == .WS_POLLING) {
            client.connectionOptions.idleTimeout = 0
            client.connectionOptions.pollingInterval = 100
        }
    }
}
