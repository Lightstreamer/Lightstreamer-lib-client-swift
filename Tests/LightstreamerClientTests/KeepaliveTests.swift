import Foundation
import XCTest
@testable import LightstreamerClient

final class KeepaliveTests: BaseTestCase {
    
    func testKeepaliveTimeout_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testStalledTimeout_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.stalled
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
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_NoRecovery_CreateWS() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.stalled
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testKeepaliveTimeout_BindWS() {
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
        scheduler.fireKeepaliveTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testStalledTimeout_BindWS() {
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
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_BindWS() {
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
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRecoveryTimeout()
        
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
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.stalled
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
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_NoRecovery_BindWS() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
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
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.stalled
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
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
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testKeepaliveTimeout_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                """, self.scheduler.trace)
        }
    }
    
    func testStalledTimeout_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRecoveryTimeout()
        
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
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.stalled
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:TRYING-RECOVERY
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
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testReconnectTimeout_NoRecovery_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        scheduler.fireReconnectTimeout()
        scheduler.fireRetryTimeout()
        
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
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.stalled
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
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
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InFine_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalling_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        ws.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalled_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        ws.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InFine_BindWS() {
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
        ws.onText("PROBE")
        
        asyncAssert {
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
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalling_BindWS() {
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
        scheduler.fireKeepaliveTimeout()
        ws.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalled_BindWS() {
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
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        ws.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InFine_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROBE")
        
        asyncAssert {
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
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalling_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        http.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_InStalled_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireKeepaliveTimeout()
        scheduler.fireStalledTimeout()
        http.onText("PROBE")
        
        asyncAssert {
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                stalled.timeout 2000
                cancel stalled.timeout
                reconnect.timeout 3000
                cancel reconnect.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRestartTimeout_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        ws.onText("SERVNAME,name")
        ws.onText("CLIENTIP,123")
        ws.onText("CONS,unlimited")
        ws.onText("PROG,0")
        ws.onText("PROBE")
        ws.onText("NOOP,foo")
        ws.onText("SYNC,0")
        ws.onText("REQOK,1")
        ws.onText("REQERR,1,-5,error")
        
        ws.onText("MSGDONE,seq,1")
        ws.onText("MSGFAIL,seq,1,-5,error")
        
        ws.onText("SUBOK,1,1,1")
        ws.onText("SUBCMD,1,1,1,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,m1")
        ws.onText("MPNCONF,m1")
        ws.onText("MPNDEL,m1")
        ws.onText("MPNZERO,devid")
        
        asyncAssert {
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
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
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
    
    func testRestartTimeout_BindWS() {
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
        
        ws.onText("SERVNAME,name")
        ws.onText("CLIENTIP,123")
        ws.onText("CONS,unlimited")
        ws.onText("PROG,0")
        ws.onText("PROBE")
        ws.onText("NOOP,foo")
        ws.onText("SYNC,0")
        ws.onText("REQOK,1")
        ws.onText("REQERR,1,-5,error")
        
        ws.onText("MSGDONE,seq,1")
        ws.onText("MSGFAIL,seq,1,-5,error")
        
        ws.onText("SUBOK,1,1,1")
        ws.onText("SUBCMD,1,1,1,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,m1")
        ws.onText("MPNCONF,m1")
        ws.onText("MPNDEL,m1")
        ws.onText("MPNZERO,devid")
        
        asyncAssert {
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
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
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
    
    func testRestartTimeout_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        
        http.onText("SERVNAME,name")
        http.onText("CLIENTIP,123")
        http.onText("CONS,unlimited")
        http.onText("PROG,0")
        http.onText("PROBE")
        http.onText("NOOP,foo")
        http.onText("SYNC,0")
        
        http.onText("MSGDONE,seq,1")
        http.onText("MSGFAIL,seq,1,-5,error")
        
        http.onText("SUBOK,1,1,1")
        http.onText("SUBCMD,1,1,1,1,2")
        http.onText("U,1,1,a")
        http.onText("EOS,1,1")
        http.onText("CS,1,1")
        http.onText("OV,1,1,1")
        http.onText("CONF,1,unlimited,unfiltered")
        http.onText("UNSUB,1")
        
        http.onText("MPNREG,devid,adapter")
        http.onText("MPNOK,1,m1")
        http.onText("MPNCONF,m1")
        http.onText("MPNDEL,m1")
        http.onText("MPNZERO,devid")
        
        asyncAssert {
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
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
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
