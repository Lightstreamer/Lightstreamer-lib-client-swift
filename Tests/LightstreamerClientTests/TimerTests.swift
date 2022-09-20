import Foundation
import XCTest
@testable import LightstreamerClient

final class TimerTests: BaseTestCase {
    
    func testTransportError_InCreateWS() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_STREAMING
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.advanceTime(500)
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 3500
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_InCreateHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_STREAMING
        client.addDelegate(delegate)
        client.connect()
        
        scheduler.advanceTime(500)
        http.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                http.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 3500
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_InBindWS() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_STREAMING
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        scheduler.advanceTime(500)
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 3500
                """, self.scheduler.trace)
        }
    }
    
    func testCtrlTimeout_InSending() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        scheduler.advanceTime(4001)
        scheduler.fireCtrlTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 0
                """, self.scheduler.trace)
        }
    }

    func testCtrlError_InPause() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        scheduler.advanceTime(2000)
        ctrl.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 2000
                """, self.scheduler.trace)
        }
    }
}
