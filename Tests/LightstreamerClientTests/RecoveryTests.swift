import Foundation
import XCTest
@testable import LightstreamerClient

final class RecoveryTests: BaseTestCase {
    let preamble = """
ws.init http://server/lightstreamer
wsok
create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
WSOK
CONOK,sid,70000,5000,*
ws.dispose
http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error

"""
    let delegatePreamble = """
CONNECTING
CONNECTED:WS-STREAMING

"""
    let schedulerPreamble = """
transport.timeout 4000
cancel transport.timeout
keepalive.timeout 5000
cancel keepalive.timeout
recovery.timeout 100
cancel recovery.timeout

"""
    
    func simulateCreation() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        scheduler.fireRecoveryTimeout()
    }
    
    func testRecover_CreateWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:WS-STREAMING
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
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_Headers() {
        http.showExtraHeaders = true
        ws.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                Foo=bar
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:WS-STREAMING
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
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_HeadersOnCreationOnly() {
        http.showExtraHeaders = true
        ws.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.connectionOptions.HTTPExtraHeadersOnSessionCreationOnly = true
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:WS-STREAMING
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
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_BindWS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_BindWSPolling() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
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
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=5000&LS_cause=recovery.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                DISCONNECTED:TRYING-RECOVERY
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
                cancel idle.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 9000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_BindHTTP() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
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
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:TRYING-RECOVERY
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
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testRecover_BindHTTPPolling() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
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
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=5000&LS_cause=recovery.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-POLLING
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:HTTP-POLLING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 9000
                """, self.scheduler.trace)
        }
    }
   
    func testSERVNAME() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionDetails.serverSocketName)
        ws.onText("SERVNAME,server")
        XCTAssertEqual("server", self.client.connectionDetails.serverSocketName)
    }
    
    func testCLIENTIP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionDetails.clientIp)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CLIENTIP,127.0.0.1")
        XCTAssertEqual("127.0.0.1", self.client.connectionDetails.clientIp)
    }
    
    func testCONS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,12.34")
        XCTAssertEqual(.limited(12.34), self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unlimited")
        XCTAssertEqual(.unlimited, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unmanaged() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unmanaged")
        XCTAssertEqual(.unmanaged, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testPROBE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROBE")
    }

    func testNOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("NOOP,foobar")
    }
    
    func testPROG_Mismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,100")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                CONOK,sid,70000,5000,*
                PROG,100
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=prog.mismatch.100.0
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testPROG() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
    }
    
    func testCONERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                CONERR,4,error
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=recovery.conerr.4
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONERR,-4,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                CONERR,-4,error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED
                onServerError -4 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("END,41,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                END,41,error
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=recovery.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("END,-4,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                END,-4,error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED
                onServerError -4 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testRecoveryTimeout() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 7_000
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(0, client.connectTs)
        scheduler.advanceTime(4_000)
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(4_000, client.connectTs)
        scheduler.advanceTime(4_000)
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=recovery.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 0
                cancel retry.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testRecovery_OnSecondAttempt() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 7_000
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(0, client.connectTs)
        scheduler.advanceTime(1_000)
        http.onError()
        scheduler.advanceTime(3_000)
        scheduler.fireRetryTimeout()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(4_000, client.connectTs)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 3000
                cancel retry.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testMSGDONE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onText("MSGDONE,*,1")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                MSGDONE,*,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=1&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGDONE_InRecovery() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(0, client.rec_clientProg)
        http.onText("MSGDONE,*,1")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MSGDONE,*,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGDONE_Skip() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onText("MSGDONE,*,1")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("MSGDONE,*,1")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                MSGDONE,*,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=1&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MSGDONE,*,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onText("MSGFAIL,*,1,10,error")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                MSGFAIL,*,1,10,error
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=1&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual("""
                didFailMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL_InRecovery() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(0, client.rec_clientProg)
        http.onText("MSGFAIL,*,1,10,error")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MSGFAIL,*,1,10,error
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                didFailMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL_Skip() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        ws.onText("MSGFAIL,*,1,10,error")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("MSGFAIL,*,1,10,error")
        XCTAssertEqual(1, client.rec_serverProg)
        XCTAssertEqual(1, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                MSGFAIL,*,1,10,error
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=1&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MSGFAIL,*,1,10,error
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                didFailMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testSubscription() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=itm&LS_schema=fld&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,1
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=7&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSubscription_InRecovery() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(0, client.rec_clientProg)
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=itm&LS_schema=fld&LS_snapshot=true&LS_ack=false
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                SUBOK,1,1,1
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSubscription_Skip() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=itm&LS_schema=fld&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,1
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=7&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                SUBOK,1,1,1
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSubscription_CMD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "itm", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onText("SUBCMD,1,1,2,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=itm&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                SUBCMD,1,1,2,1,2
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=7&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSubscription_CMD_InRecovery() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "itm", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(0, client.rec_clientProg)
        ws.onText("SUBCMD,1,1,2,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=itm&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                SUBCMD,1,1,2,1,2
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSubscription_CMD_Skip() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "itm", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.subscribe(sub)
        ws.onText("SUBCMD,1,1,2,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        ws.onText("SUBCMD,1,1,2,1,2")
        ws.onText("U,1,1,a")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        ws.onText("OV,1,1,1")
        ws.onText("CONF,1,unlimited,unfiltered")
        ws.onText("UNSUB,1")
        XCTAssertEqual(7, client.rec_serverProg)
        XCTAssertEqual(7, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=itm&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                SUBCMD,1,1,2,1,2
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=7&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                SUBCMD,1,1,2,1,2
                U,1,1,a
                EOS,1,1
                CS,1,1
                OV,1,1,1
                CONF,1,unlimited,unfiltered
                UNSUB,1
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS itm 1
                onCS itm 1
                onOV itm 1 1
                onCONF unlimited
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testDisconnect_in_Retry() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 7_000
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(0, client.connectTs)
        scheduler.advanceTime(4_000)
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        XCTAssertEqual(0, client.recoverTs)
        XCTAssertEqual(4_000, client.connectTs)
        scheduler.advanceTime(4_000)
        scheduler.fireTransportTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=recovery.error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                DISCONNECTED:WILL-RETRY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 0
                cancel retry.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 100
                cancel retry.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testMpnSubscription() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
        
        let devDelegate = TestMpnDeviceDelegate()
        let subDelegate = TestMpnSubDelegate()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(devDelegate)
        let sub = MPNSubscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.register(forMPN: dev)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,sub1")
        ws.onText("MPNCONF,sub1")
        ws.onText("MPNDEL,sub1")
        ws.onText("MPNZERO,devid")
        XCTAssertEqual(5, client.rec_serverProg)
        XCTAssertEqual(5, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=activate&LS_subId=1&LS_mode=DISTINCT&LS_group=itm&LS_schema=fld&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                MPNOK,1,sub1
                MPNCONF,sub1
                MPNDEL,sub1
                MPNZERO,devid
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=5&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onResetBadge
                """, devDelegate.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, subDelegate.trace)
        }
    }
    
    func testMpnSubscription_InRecovery() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
        
        let devDelegate = TestMpnDeviceDelegate()
        let subDelegate = TestMpnSubDelegate()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(devDelegate)
        let sub = MPNSubscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.register(forMPN: dev)
        client.subscribeMPN(sub, coalescing: false)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(0, client.rec_clientProg)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,sub1")
        ws.onText("MPNCONF,sub1")
        ws.onText("MPNDEL,sub1")
        ws.onText("MPNZERO,devid")
        XCTAssertEqual(5, client.rec_serverProg)
        XCTAssertEqual(5, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MPNREG,devid,adapter
                MPNOK,1,sub1
                MPNCONF,sub1
                MPNDEL,sub1
                MPNZERO,devid
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onResetBadge
                """, devDelegate.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, subDelegate.trace)
        }
    }
    
    func testMpnSubscription_Skip() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
        
        let devDelegate = TestMpnDeviceDelegate()
        let subDelegate = TestMpnSubDelegate()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(devDelegate)
        let sub = MPNSubscription(subscriptionMode: .DISTINCT, item: "itm", fields: ["fld"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(subDelegate)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.register(forMPN: dev)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,sub1")
        ws.onText("MPNCONF,sub1")
        ws.onText("MPNDEL,sub1")
        ws.onText("MPNZERO,devid")
        XCTAssertEqual(5, client.rec_serverProg)
        XCTAssertEqual(5, client.rec_clientProg)
        ws.onError()
        scheduler.fireRecoveryTimeout()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        XCTAssertEqual(0, client.rec_serverProg)
        XCTAssertEqual(5, client.rec_clientProg)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("MPNOK,1,sub1")
        ws.onText("MPNCONF,sub1")
        ws.onText("MPNDEL,sub1")
        ws.onText("MPNZERO,devid")
        XCTAssertEqual(5, client.rec_serverProg)
        XCTAssertEqual(5, client.rec_clientProg)
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=activate&LS_subId=1&LS_mode=DISTINCT&LS_group=itm&LS_schema=fld&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                MPNOK,1,sub1
                MPNCONF,sub1
                MPNDEL,sub1
                MPNZERO,devid
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=5&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,0
                MPNREG,devid,adapter
                MPNOK,1,sub1
                MPNCONF,sub1
                MPNDEL,sub1
                MPNZERO,devid
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onResetBadge
                """, devDelegate.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, subDelegate.trace)
        }
    }
}
