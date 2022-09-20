import Foundation
import XCTest
@testable import LightstreamerClient

final class HeartbeatTests: BaseTestCase {
    
    func testCreateWS_Constrain() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(1)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=1.0
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_Constrain() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(1)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=1.0
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel keepalive.timeout
                cancel rhb.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTP_Constrain() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(1)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=1.0
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_Constrain() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(1)
        
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
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=1.0
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_Switch() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .HTTP
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_Switch() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .HTTP
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel keepalive.timeout
                cancel rhb.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTP_Switch() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_Switch() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        
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
                LS_reqId=1&LS_op=force_rebind
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_Timeout() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireRhbTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                heartbeat\r
                \r\n
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_Timeout() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireRhbTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_inactivity_millis=1000&LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                heartbeat\r
                \r\n
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel keepalive.timeout
                cancel rhb.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTP_Timeout() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireRhbTimeout()
        http.onText("REQOK")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_inactivity_millis=1000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/heartbeat.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                \r\n
                REQOK
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_Timeout() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.connectionOptions.reverseHeartbeatInterval = 1000
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireRhbTimeout()
        http.onText("REQOK")
        
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
                ctrl.send http://server/lightstreamer/heartbeat.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                \r\n
                REQOK
                """, self.ws.trace)
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
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testSelectRhb_To321() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(.s321, client.s_rhb)
    }
    
    func testSelectRhb_To322() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s322, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testSelectRhb_To323() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testSelectRhb_To323_NewEq0() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 0
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testSelectRhb_To323_NewTooHigh() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 2500
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testSetHeartbeat_In321() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(.s321, client.s_rhb)
        XCTAssertEqual(0, client.rhb_grantedInterval)
        client.connectionOptions.reverseHeartbeatInterval = 1000
        XCTAssertEqual(.s322, client.s_rhb)
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                """, self.scheduler.trace)
        }
    }
    
    func testSetHeartbeat_In322_NewEq0() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s322, client.s_rhb)
        client.connectionOptions.reverseHeartbeatInterval = 0
        XCTAssertEqual(.s321, client.s_rhb)
        XCTAssertEqual(0, client.rhb_grantedInterval)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTimeout_In322_NewGt0() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s322, client.s_rhb)
        client.connectionOptions.reverseHeartbeatInterval = 1500
        XCTAssertEqual(.s322, client.s_rhb)
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1500, client.rhb_currentInterval)
        scheduler.fireRhbTimeout()
        XCTAssertEqual(.s322, client.s_rhb)
        XCTAssertEqual(0, client.rhb_grantedInterval)
        XCTAssertEqual(1500, client.rhb_currentInterval)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 1500
                """, self.scheduler.trace)
        }
    }
    
    func testTimeout_In323() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        client.connectionOptions.reverseHeartbeatInterval = 700
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(700, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        scheduler.fireRhbTimeout()
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(700, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 700
                """, self.scheduler.trace)
        }
    }
    
    func testTimeout_In323_NewEq0() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        client.connectionOptions.reverseHeartbeatInterval = 0
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        scheduler.fireRhbTimeout()
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testTimeout_In323_NewTooHigh() {
        client = newClient("http://server")
        client.connectionOptions.reverseHeartbeatInterval = 2000
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        client.connectionOptions.reverseHeartbeatInterval = 1000
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(1000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        client.connectionOptions.reverseHeartbeatInterval = 2500
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        scheduler.fireRhbTimeout()
        XCTAssertEqual(2000, client.rhb_grantedInterval)
        XCTAssertEqual(2000, client.rhb_currentInterval)
        XCTAssertEqual(.s323, client.s_rhb)
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                rhb.timeout 1000
                cancel rhb.timeout
                rhb.timeout 2000
                """, self.scheduler.trace)
        }
    }
}
