import Foundation
import XCTest
@testable import LightstreamerClient

final class ClientTests: XCTestCase {
    var client: LightstreamerClient!
    let msgDelegate = MsgDelegate()
    let expectation = XCTestExpectation()
    
    override func setUp() {
        client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
    }
    
    override func tearDown() {
        client.disconnect()
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
