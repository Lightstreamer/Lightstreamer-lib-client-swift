import Foundation
import XCTest
import JSONPatch
@testable import LightstreamerClient

final class ClientTests: XCTestCase {
    var client: LightstreamerClient!
    let clientDelegate = TestClientDelegate()
    let msgDelegate = MsgDelegate()
    let expectation = XCTestExpectation()
    
    override func setUp() {
        client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        client.addDelegate(clientDelegate)
    }
    
    override func tearDown() {
        client.disconnect()
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
      XCTAssertTrue(patch.contains(try! Regex(#""value":\d+"#)))
      XCTAssertNotNil(u.value(withFieldPos: 1))
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
}

class TestClientDelegate: ClientDelegate {
    var onPropertyChange: ((String) -> Void)!
    
    func clientDidRemoveDelegate(_ client: LightstreamerClient) {}
    
    func clientDidAddDelegate(_ client: LightstreamerClient) {}
    
    func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {}
    
    func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {}
    
    func client(_ client: LightstreamerClient, didChangeProperty property: String) {
        onPropertyChange?(property)
    }
    
    func client(_ client: LightstreamerClient, willSendRequestForAuthenticationChallenge challenge: URLAuthenticationChallenge) {}
}

class MsgDelegate: ClientMessageDelegate {
    var onProcess: ((String, String) -> Void)!
    
    func client(_ client: LightstreamerClient, didAbortMessage originalMessage: String, sentOnNetwork: Bool) {
    }
    
    func client(_ client: LightstreamerClient, didDenyMessage originalMessage: String, withCode code: Int, error: String) {
    }
    
    func client(_ client: LightstreamerClient, didDiscardMessage originalMessage: String) {
    }
    
    func client(_ client: LightstreamerClient, didFailMessage originalMessage: String) {
    }
    
    func client(_ client: LightstreamerClient, didProcessMessage originalMessage: String, withResponse response: String) {
        onProcess?(originalMessage, response)
    }
}
