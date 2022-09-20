import Foundation
import XCTest
@testable import LightstreamerClient

class NetTests: XCTestCase {
   
    func testHTTP() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        
        let client = LsHttp(
            "http://push.lightstreamer.com/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)",
            body: "LS_polling=true&LS_polling_millis=0&LS_adapter_set=DEMO&LS_cid=mgQkwtwdysogQz2BJ4Ji%20kOj2Bg",
            onText: { http, text in
                if text.contains("CONOK") {
                    expectation.fulfill()
                }
            },
            onError: { http, error in
                assertionFailure()
            },
            onDone: { http in
                expectation.fulfill()
            })
        
        wait(for: [expectation], timeout: 2)
        
        client.dispose()
    }
    
    func testWS() {
        let expectation = XCTestExpectation()
        
        let client = LsWebsocket(
            "http://push.lightstreamer.com/lightstreamer",
            protocols: "\(TLCP_VERSION).lightstreamer.com",
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
                assertionFailure()
            })
        
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
