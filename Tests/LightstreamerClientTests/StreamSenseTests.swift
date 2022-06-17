import Foundation
import XCTest
@testable import LightstreamerClient

final class StreamSenseTests: BaseTestCase {
    
    func testForcePolling_HTTPStreamingNotAvailable() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        scheduler.fireTransportTimeout()
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
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
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testForcePolling_StreamingNotAvailable() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onError()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        XCTAssertEqual(.s240, client.s_tr) // ws-streaming
        scheduler.fireTransportTimeout() // disable ws
        XCTAssertEqual(.s710, client.s_h) // http-streaming
        scheduler.fireTransportTimeout()  // disable http-streaming
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        XCTAssertEqual(.s720, client.s_h) // http-polling
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.unavailable
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=ws.unavailable
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
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
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }

    func testControlLink() {
        client = newClient("http://server.com")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,host.it")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(10)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server.com/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,host.it
                LOOP,0
                http.dispose
                http.send http://host.it/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://host.it/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=10.0
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
        }
    }
}
