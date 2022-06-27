import Foundation
import XCTest
@testable import LightstreamerClient

final class SlowingTests: BaseTestCase {
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.slowingEnabled = true
        return client
    }
    
    func testCreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        ws.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        ws.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([.WS_STREAMING, .HTTP_STREAMING], client.disabledTransports)
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        XCTAssertNil(client.s_slw)
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true&LS_cause=slow
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=ws.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        ws.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        ws.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([.WS_STREAMING, .HTTP_STREAMING], client.disabledTransports)
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        XCTAssertNil(client.s_slw)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true&LS_cause=slow
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=ws.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        http.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        http.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([.WS_STREAMING, .HTTP_STREAMING], client.disabledTransports)
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        XCTAssertNil(client.s_slw)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=slow
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                CONNECTED:HTTP-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_SlowingDisabled() {
        client = newClient("http://server")
        client.connectionOptions.slowingEnabled = false
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        ws.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        ws.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([], client.disabledTransports)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_SlowingDisabled() {
        client = newClient("http://server")
        client.connectionOptions.slowingEnabled = false
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        ws.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        ws.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([], client.disabledTransports)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTP_SlowingDisabled() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.connectionOptions.slowingEnabled = false
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SYNC,0")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        XCTAssertEqual(0, client.slw_refTime)
        scheduler.setTime(30_000)
        http.onText("SYNC,1")
        XCTAssertEqual(0, client.slw_avgDelayMs)
        scheduler.setTime(60_000)
        http.onText("SYNC,2")
        XCTAssertEqual(29000, client.slw_avgDelayMs)
        XCTAssertEqual([], client.disabledTransports)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                SYNC,0
                SYNC,1
                SYNC,2
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
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
}
