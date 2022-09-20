import Foundation
import XCTest
@testable import LightstreamerClient

final class ConstrainTests: BaseTestCase {
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        delegate.logPropertyChange = false
        return super.newClient(url, adapterSet: adapterSet)
    }
    
    func testConstrain_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ws.onText("REQOK,1")
        ws.onText("CONS,12.3")
        XCTAssertEqual(.limited(12.3), client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                CONS,12.3
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_BindWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ws.onText("REQOK,1")
        ws.onText("CONS,12.3")
        XCTAssertEqual(.limited(12.3), client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                CONS,12.3
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_BindWSPolling() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ws.onText("REQOK,1")
        ws.onText("CONS,12.3")
        XCTAssertEqual(.limited(12.3), client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                CONS,12.3
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        http.onText("CONS,12.3")
        XCTAssertEqual(.limited(12.3), client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                CONS,12.3
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
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_BindHTTPPolling() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        http.onText("CONS,12.3")
        XCTAssertEqual(.limited(12.3), client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                CONS,12.3
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                ctrl.timeout 4000
                cancel ctrl.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_unlimited() {
        client = newClient("http://server")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.3)
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        ws.onText("REQOK,1")
        ws.onText("CONS,unlimited")
        XCTAssertEqual(.unlimited, client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_requested_max_bandwidth=12.3&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=unlimited
                REQOK,1
                CONS,unlimited
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_dontSendIfUnchanged() {
        client = newClient("http://server")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.3)
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.3)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_requested_max_bandwidth=12.3&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_dontSendIfUnmanaged() {
        client = newClient("http://server")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.3)
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CONS,unmanaged")
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        XCTAssertEqual(.unmanaged, client.connectionOptions.realMaxBandwidth)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_requested_max_bandwidth=12.3&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                CONS,unmanaged
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        ws.onText("REQERR,1,-10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQERR,1,-10,error
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_MultipleChanges() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        ws.onText("REQOK,1")
        ws.onText("REQOK,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                control\r\nLS_reqId=2&LS_op=constrain&LS_requested_max_bandwidth=unlimited
                REQOK,2
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
                """, self.scheduler.trace)
        }
    }
    
    func testConstrain_MultipleChanges_HTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        ctrl.onText("REQOK,2")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=2&LS_op=constrain&LS_requested_max_bandwidth=unlimited
                REQOK,2
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                """, self.scheduler.trace)
        }
    }
}
