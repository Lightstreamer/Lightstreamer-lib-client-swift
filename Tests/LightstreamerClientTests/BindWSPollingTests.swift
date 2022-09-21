import Foundation
import XCTest
@testable import LightstreamerClient

final class BindWSPollingTests: BaseTestCase {
    let preamble = """
        http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
        LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_cause=api
        CONOK,sid,70000,5000,*
        LOOP,0
        http.dispose
        
        """
    let delegatePreamble = """
        CONNECTING
        CONNECTED:STREAM-SENSING
        
        """
    let schedulerPreamble = """
        transport.timeout 4000
        cancel transport.timeout
        transport.timeout 4000
        cancel transport.timeout
        
        """
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .WS_POLLING
        return client
    }
    
    func simulateCreation() {
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
    }
    
    func testCONOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testHeaders() {
        http.showExtraHeaders = true
        ws.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                Foo=bar
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testHeadersOnCreationOnly() {
        http.showExtraHeaders = true
        ws.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.connectionOptions.HTTPExtraHeadersOnSessionCreationOnly = true
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                Foo=bar
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONERR,10,error
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        http.onText("CONOK,sid2,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONERR,4,error
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.conerr.4
                CONOK,sid2,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid2&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 4000
                cancel retry.timeout
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
    
    func testEND_Disconnect_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                END,10,error
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED
                onServerError 39 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Retry_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("END,41,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                END,41,error
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                END,10,error
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 39 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("END,41,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                END,41,error
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testERROR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("ERROR,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ERROR,10,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,67,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                REQERR,1,67,error
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED
                onServerError 67 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,20,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                REQERR,1,20,error
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.reqerr.20
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,15000,*")
        ws.onText("LOOP,300")
        scheduler.firePollingTimeout()
        ws.onText("CONOK,sid,70000,25000,*")
        ws.onText("LOOP,600")
        scheduler.firePollingTimeout()
        ws.onText("CONOK,sid,70000,35000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,15000,*
                LOOP,300
                bind_session\r\nLS_polling=true&LS_polling_millis=300&LS_idle_millis=15000
                CONOK,sid,70000,25000,*
                LOOP,600
                bind_session\r\nLS_polling=true&LS_polling_millis=600&LS_idle_millis=25000
                CONOK,sid,70000,35000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                polling.timeout 300
                cancel polling.timeout
                idle.timeout 19000
                cancel idle.timeout
                polling.timeout 600
                cancel polling.timeout
                idle.timeout 29000
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_Opening() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_600() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_601() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_600() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_601() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_602() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_602_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testIdleTimeout_in_610() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireIdleTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.idle.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testIdleTimeout_in_611() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireIdleTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.idle.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testIdleTimeout_in_610_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireIdleTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.idle.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testIdleTimeout_in_611_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        scheduler.fireIdleTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.idle.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testSERVNAME() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionDetails.serverSocketName)
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SERVNAME,server")
        XCTAssertEqual("server", self.client.connectionDetails.serverSocketName)
    }
    
    func testCLIENTIP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionDetails.clientIp)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CLIENTIP,127.0.0.1")
        XCTAssertEqual("127.0.0.1", self.client.connectionDetails.clientIp)
    }
    
    func testCONS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CONS,12.34")
        XCTAssertEqual(.limited(12.34), self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CONS,unlimited")
        XCTAssertEqual(.unlimited, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unmanaged() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CONS,unmanaged")
        XCTAssertEqual(.unmanaged, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testPROBE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROBE")
    }

    func testNOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("NOOP,foobar")
    }
    
    func testPROG_Mismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROG,100")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                PROG,100
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=prog.mismatch.100.0
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:WS-POLLING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROG,0")
    }
    
    func testDisconnect_in_Retry() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireIdleTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                cancel idle.timeout
                retry.timeout 100
                cancel retry.timeout
                """, self.scheduler.trace)
        }
    }
}
