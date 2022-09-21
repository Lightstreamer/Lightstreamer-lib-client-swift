import Foundation
import XCTest
@testable import LightstreamerClient

final class ReachabilityTests: BaseTestCase {
   
    func test1() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        reachability.onUpdatePerforming(.notReachable)
        reachability.onUpdatePerforming(.reachable)
        reachability.onUpdatePerforming(.notReachable)
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                stopListening
                """, self.reachability.trace)
        }
    }
    
    func test2() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        reachability.onUpdatePerforming(.reachable)
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                stopListening
                """, self.reachability.trace)
        }
    }
    
    func test3() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                stopListening
                """, self.reachability.trace)
        }
    }
    
    func testInterruptRetryDelay1() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        reachability.onUpdatePerforming(.notReachable)
        ws.onError()
        reachability.onUpdatePerforming(.reachable)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                ws.init http://www.example.com/fido/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                """, self.reachability.trace)
        }
    }
    
    func testInterruptRetryDelay2() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        reachability.onUpdatePerforming(.notReachable)
        reachability.onUpdatePerforming(.reachable)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                ws.init http://www.example.com/fido/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                """, self.reachability.trace)
        }
    }
    
    func testInterruptRecovery() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        reachability.onUpdatePerforming(.notReachable)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onError()
        reachability.onUpdatePerforming(.reachable)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://www.example.com/fido/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                http.dispose
                http.send http://www.example.com/fido/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                """, self.reachability.trace)
        }
    }
    
    func testAddressChanged1() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        client.connectionDetails.serverAddress = "https://www.foobar.net:8080"
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                new reachability service: www.foobar.net
                stopListening
                startListening
                """, self.reachability.trace)
        }
    }
    
    func testAddressChanged2() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        reachability.onUpdatePerforming(.notReachable)
        client.connectionDetails.serverAddress = "https://www.foobar.net:8080"
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                new reachability service: www.foobar.net
                stopListening
                startListening
                """, self.reachability.trace)
        }
    }
    
    func testAddressChanged3() {
        client = newClient("http://www.example.com/fido")
        client.addDelegate(delegate)
        client.connect()
        
        reachability.onUpdatePerforming(.reachable)
        client.connectionDetails.serverAddress = "https://www.foobar.net:8080"
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://www.example.com/fido/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                """, self.scheduler.trace)
            XCTAssertEqual("""
                new reachability service: www.example.com
                startListening
                new reachability service: www.foobar.net
                stopListening
                startListening
                """, self.reachability.trace)
        }
    }
}
