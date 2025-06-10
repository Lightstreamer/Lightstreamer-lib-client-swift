/*
 * Copyright (C) 2025 Lightstreamer Srl
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

class ClientTestsBase: XCTestCase {
    let host = "http://localtest.me:8080"
    let hostUrl = URL(string: "http://localtest.me:8080")!
    var client: LightstreamerClient!
    let clientDelegate = CTBClientDelegate()
    let msgDelegate = CTBMsgDelegate()
    let subDelegate = CTBSubDelegate()
    let expectation = XCTestExpectation()
    var transport: TransportSelection?
    
    override func setUp() {
//        LightstreamerClient.setLoggerProvider(ConsoleLoggerProvider(level: .debug))
        client = LightstreamerClient(serverAddress: host, adapterSet: "TEST")
        client.addDelegate(clientDelegate)
        client.connectionOptions.forcedTransport = transport
        if (transport == .WS_POLLING || transport == .HTTP_POLLING) {
            client.connectionOptions.idleTimeout = 0
            client.connectionOptions.pollingInterval = 100
        }
    }
    
    override func tearDown() {
        client.disconnect()
        // Clean up cookies
        if let cookies = HTTPCookieStorage.shared.cookies(for: hostUrl) {
            cookies.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
    }
    
    func connectedStatus() -> LightstreamerClient.Status {
        switch transport {
        case .WS:
            return .CONNECTED_WS_STREAMING
        case .WS_STREAMING:
            return .CONNECTED_WS_STREAMING
        case .WS_POLLING:
            return .CONNECTED_WS_POLLING
        case .HTTP:
            return .CONNECTED_HTTP_STREAMING
        case .HTTP_STREAMING:
            return .CONNECTED_HTTP_STREAMING
        case .HTTP_POLLING:
            return .CONNECTED_HTTP_POLLING
        case nil:
            return .CONNECTED_WS_STREAMING
        }
    }
    
    func testJsonPatch() {
      expectation.expectedFulfillmentCount = 2
      
      let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
      sub.requestedSnapshot = .no
      sub.dataAdapter = "JSON_COUNT"
      let subListener = TestSubDelegate()
      subListener.onItemUpdate = { _ in
        self.expectation.fulfill()
      }
      sub.addDelegate(subListener)
      client.subscribe(sub)
      client.connect()
      
      wait(for: [expectation], timeout: 3)
      let u = subListener.updates[1]
      let patch = u.valueAsJSONPatchIfAvailable(withFieldPos: 1)!
      XCTAssertTrue(patch.contains(#""op":"replace""#))
      XCTAssertTrue(patch.contains(#""path":"\/value""#))
        if #available(iOS 16.0, *), #available(tvOS 16.0, *), #available(watchOS 9.0, *) {
        XCTAssertTrue(patch.contains(try! Regex(#""value":\d+"#)))
      }
      XCTAssertNotNil(u.value(withFieldPos: 1))
    }
    
    func testCookies() {
        XCTAssertEqual(0, LightstreamerClient.getCookiesForURL(hostUrl)?.count)
        
        let cookie = HTTPCookie(properties: [.name: "X-Client", .value: "client", .path: "/", .originURL: host])!
        LightstreamerClient.addCookies([ cookie ], forURL: hostUrl)
        
        clientDelegate.onStatusChange = { status in
            if status == self.connectedStatus() {
                self.expectation.fulfill()
            }
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
        
        let cookies = LightstreamerClient.getCookiesForURL(hostUrl)!.map { "\($0.name)=\($0.value)" }
        XCTAssertEqual(2, cookies.count)
        XCTAssertTrue(cookies.contains("X-Client=client"))
        XCTAssertTrue(cookies.contains("X-Server=server"))
    }
    
    func testConnect() {
        clientDelegate.onStatusChange = { status in
            if status == self.connectedStatus() {
                self.expectation.fulfill()
            }
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testOnlineServer() {
        client.connectionDetails.serverAddress = "https://push.lightstreamer.com"
        client.connectionDetails.adapterSet = "DEMO"
        clientDelegate.onStatusChange = { status in
            if status == self.connectedStatus() {
                self.expectation.fulfill()
            }
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testError() {
        client.connectionDetails.adapterSet = "XXX"
        clientDelegate.onServerError = { code, msg in
            XCTAssertEqual("2 Requested Adapter Set not available", "\(code) \(msg)")
            self.expectation.fulfill()
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testDisconnect() {
        clientDelegate.onStatusChange = { status in
            if status == self.connectedStatus() {
                self.client.disconnect()
            } else if status == .DISCONNECTED {
                XCTAssertEqual(LightstreamerClient.Status.DISCONNECTED, self.client.status)
                self.expectation.fulfill()
            }
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testSubscribe() {
        let sub = Subscription(subscriptionMode: .MERGE, item: "count", fields: ["count"])
        sub.dataAdapter = "COUNT"
        sub.addDelegate(subDelegate)
        subDelegate.onSubscription = {
            XCTAssertTrue(sub.isSubscribed)
            self.expectation.fulfill()
        }
        client.subscribe(sub)
        let subs = client.subscriptions
        XCTAssertEqual(1, subs.count)
        XCTAssertTrue(sub === subs[0])
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testSubscriptionError() {
        let sub = Subscription(subscriptionMode: .RAW, item: "count", fields: ["count"])
        sub.dataAdapter = "COUNT"
        sub.addDelegate(subDelegate)
        subDelegate.onSubscriptionError = { code, msg in
            XCTAssertEqual("24 Invalid mode for these items", "\(code) \(msg ?? "")")
            self.expectation.fulfill()
        }
        client.subscribe(sub)
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testUnsuscribe() {
        let sub = Subscription(subscriptionMode: .MERGE, item: "count", fields: ["count"])
        sub.dataAdapter = "COUNT"
        sub.addDelegate(subDelegate)
        subDelegate.onSubscription = {
            XCTAssertTrue(sub.isSubscribed)
            self.client.unsubscribe(sub)
        }
        subDelegate.onUnsubscription = {
            XCTAssertFalse(sub.isSubscribed)
            XCTAssertFalse(sub.isActive)
            self.expectation.fulfill()

        }
        client.subscribe(sub)
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testSubscribeNonAscii() {
        let sub = Subscription(subscriptionMode: .MERGE, item: "strange:àìùòlè", fields: ["value🌐-", "value&+=\r\n%"])
        sub.dataAdapter = "STRANGE_NAMES"
        sub.addDelegate(subDelegate)
        subDelegate.onSubscription = {
            XCTAssertTrue(sub.isSubscribed)
            self.expectation.fulfill()
        }
        client.subscribe(sub)
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testClearSnapshot() {
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "clear_snapshot", fields: ["dummy"])
        sub.dataAdapter = "CLEAR_SNAPSHOT"
        sub.addDelegate(subDelegate)
        subDelegate.onClearSnapshot = { name, pos in
            XCTAssertEqual("clear_snapshot", name);
            XCTAssertEqual(1, pos);
            self.expectation.fulfill()
        }
        client.subscribe(sub)
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testRoundTrip() {
        expectation.expectedFulfillmentCount = 8
        var values = [String]()
        clientDelegate.onPropertyChange = { (prop) in
            switch prop {
            case "clientIp":
                values.append("clientIp: " + (self.client.connectionDetails.clientIp ?? "null"))
                self.expectation.fulfill()
            case "serverSocketName":
                values.append("serverSocketName: " + (self.client.connectionDetails.serverSocketName ?? "null"))
                self.expectation.fulfill()
            case "sessionId":
                values.append("sessionId: " + (self.client.connectionDetails.sessionId == nil ? "null" : "not null"))
                self.expectation.fulfill()
            case "realMaxBandwidth":
                values.append("realMaxBandwidth: " + (self.client.connectionOptions.realMaxBandwidth?.description ?? "null"))
                self.expectation.fulfill()
            default:
                break
            }
            if values.count == 4 {
                self.client.disconnect()
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
        XCTAssertEqual([
            "sessionId: not null",
            "serverSocketName: Lightstreamer HTTP Server",
            "clientIp: 127.0.0.1",
            "realMaxBandwidth: 40.0 kilobits/sec",
            "sessionId: null",
            "serverSocketName: null",
            "clientIp: null",
            "realMaxBandwidth: null"
        ], values)
    }
    
    func testBandwidth() {
        var cnt = 0;
        clientDelegate.onPropertyChange = { (prop) in
            if ("realMaxBandwidth" == prop) {
                cnt += 1;
                let bw = self.client.connectionOptions.realMaxBandwidth?.description
                switch cnt {
                case 1:
                    // after the connection, the server sends the default bandwidth
                    XCTAssertEqual("40.0 kilobits/sec", bw)
                    // request a bandwidth equal to 20.1: the request is accepted
                    self.client.connectionOptions.requestedMaxBandwidth = .limited(20.1)
                case 2:
                    XCTAssertEqual("20.1 kilobits/sec", bw)
                    // request a bandwidth equal to 70.1: the meta-data adapter cuts it to 40 (which is the configured limit)
                    self.client.connectionOptions.requestedMaxBandwidth = .limited(70.1)
                case 3:
                    XCTAssertEqual("40.0 kilobits/sec", bw)
                    // request a bandwidth equal to 39: the request is accepted
                    self.client.connectionOptions.requestedMaxBandwidth = .limited(39)
                case 4:
                    XCTAssertEqual("39.0 kilobits/sec", bw)
                    // request an unlimited bandwidth: the meta-data adapter cuts it to 40 (which is the configured limit)
                    self.client.connectionOptions.requestedMaxBandwidth = .unlimited
                case 5:
                    XCTAssertEqual("40.0 kilobits/sec", bw)
                    self.expectation.fulfill()
                default:
                    break
                }
            }
        }
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testLongMessage() {
        let msg = "{\"n\":\"MESSAGE_SEND\",\"c\":{\"u\":\"GEiIxthxD-1gf5Tk5O1NTw\",\"s\":\"S29120e92e162c244T2004863\",\"p\":\"localhost:3000/html/widget-responsive.html\",\"t\":\"2017-08-08T10:20:05.665Z\"},\"d\":\"{\\\"p\\\":\\\"🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐🌐\\\"}\"}";
        msgDelegate.onProcess = { (msg, resp) in
            self.expectation.fulfill()
        }
        client.connect()
        client.sendMessage(msg, delegate: msgDelegate, enqueueWhileDisconnected: true)
        wait(for: [expectation], timeout: 3)
    }
    
    func testMessageWithReturnValue() {
        msgDelegate.onProcess = { (msg, resp) in
            XCTAssertEqual("give me a result", msg)
            XCTAssertEqual("result:ok", resp)
            self.expectation.fulfill()
        }
        client.sendMessage("give me a result", delegate: msgDelegate, enqueueWhileDisconnected: true)
        client.connect()
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testMessageError() {
        msgDelegate.onDeny = { (msg, code, error) in
            XCTAssertEqual("throw me an error", msg)
            XCTAssertEqual(-123, code)
            XCTAssertEqual("test error", error)
            self.expectation.fulfill()
        }
        client.connect()
        client.sendMessage("throw me an error", withSequence: "test_seq", delegate: msgDelegate, enqueueWhileDisconnected: false)
        wait(for: [expectation], timeout: 3)
    }
    
    func testEndOfSnapshot() {
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "end_of_snapshot", fields: ["value"])
        sub.requestedSnapshot = .yes
        sub.dataAdapter = "END_OF_SNAPSHOT"
        sub.addDelegate(subDelegate)
        subDelegate.onEndOfSnapshot = { name, pos in
            XCTAssertEqual("end_of_snapshot", name);
            XCTAssertEqual(1, pos);
            self.expectation.fulfill()
        }
        client.subscribe(sub)
        client.connect()
        wait(for: [expectation], timeout: 3)
    }
    
    func testHeaders() {
        client.connectionOptions.HTTPExtraHeaders = ["hello": "header"]
        clientDelegate.onStatusChange = { status in
            if status == self.connectedStatus() {
                self.expectation.fulfill()
            }
        }
        client.connect()
        wait(for: [expectation], timeout: 3)
        let hs = client.connectionOptions.HTTPExtraHeaders!
        XCTAssertEqual("header", hs["hello"])
    }
}

class CTBClientDelegate: ClientDelegate {
    var onPropertyChange: ((String) -> Void)!
    var onStatusChange: ((LightstreamerClient.Status) -> Void)!
    var onServerError: ((Int, String) -> Void)!
    
    func clientDidRemoveDelegate(_ client: LightstreamerClient) {}
    
    func clientDidAddDelegate(_ client: LightstreamerClient) {}
    
    func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {
        onServerError?(errorCode, errorMessage)
    }
    
    func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {
        onStatusChange?(status)
    }
    
    func client(_ client: LightstreamerClient, didChangeProperty property: String) {
        onPropertyChange?(property)
    }
    
    func client(_ client: LightstreamerClient, willSendRequestForAuthenticationChallenge challenge: URLAuthenticationChallenge) {}
}

class CTBMsgDelegate: ClientMessageDelegate {
    var onProcess: ((String, String) -> Void)!
    var onDeny: ((String, Int, String) -> Void)!
    
    func client(_ client: LightstreamerClient, didAbortMessage originalMessage: String, sentOnNetwork: Bool) {
    }
    
    func client(_ client: LightstreamerClient, didDenyMessage originalMessage: String, withCode code: Int, error: String) {
        onDeny?(originalMessage, code, error)
    }
    
    func client(_ client: LightstreamerClient, didDiscardMessage originalMessage: String) {
    }
    
    func client(_ client: LightstreamerClient, didFailMessage originalMessage: String) {
    }
    
    func client(_ client: LightstreamerClient, didProcessMessage originalMessage: String, withResponse response: String) {
        onProcess?(originalMessage, response)
    }
}

class CTBSubDelegate: SubscriptionDelegate {
    var onSubscription: (() -> Void)!
    var onSubscriptionError: ((Int, String?) -> Void)!
    var onUnsubscription: (() -> Void)!
    var onClearSnapshot: ((String?, UInt) -> Void)!
    var onEndOfSnapshot: ((String?, UInt) -> Void)!
    
    func subscription(_ subscription: Subscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {
        onClearSnapshot?(itemName, itemPos)
    }
    
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forCommandSecondLevelItemWithKey key: String) {
        
    }
    
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String) {
        
    }
    
    func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {
        onEndOfSnapshot?(itemName, itemPos)
    }
    
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        
    }
    
    func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: any ItemUpdate) {
        
    }
    
    func subscriptionDidRemoveDelegate(_ subscription: Subscription) {
        
    }
    
    func subscriptionDidAddDelegate(_ subscription: Subscription) {
        
    }
    
    func subscriptionDidSubscribe(_ subscription: Subscription) {
        onSubscription?()
    }
    
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?) {
        onSubscriptionError?(code, message)
    }
    
    func subscriptionDidUnsubscribe(_ subscription: Subscription) {
        onUnsubscription?()
    }
    
    func subscription(_ subscription: Subscription, didReceiveRealFrequency frequency: RealMaxFrequency?) {
        
    }
}
