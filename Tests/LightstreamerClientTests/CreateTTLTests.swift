import Foundation
import XCTest
@testable import LightstreamerClient

final class CreateTTLTests: BaseTestCase {
    let delegatePreamble = """
CONNECTING
DISCONNECTED:WILL-RETRY

"""
    let schedulerPreamble = """
transport.timeout 4000
cancel transport.timeout

"""
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        return LightstreamerClient(url, adapterSet: adapterSet,
                                   wsFactory: ws.createWS,
                                   httpFactory: http.createHTTP,
                                   ctrlFactory: http.createHTTP,
                                   scheduler: scheduler,
                                   randomGenerator: { n in n },
                                   reachabilityFactory: reachability.create)
    }
    
    func newClientWithMergedTraces(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        ws.m_trace = io
        http.m_trace = io
        return LightstreamerClient(url, adapterSet: adapterSet,
                                   wsFactory: ws.createWS,
                                   httpFactory: http.createHTTP,
                                   ctrlFactory: http.createHTTP,
                                   scheduler: scheduler,
                                   randomGenerator: { n in n },
                                   reachabilityFactory: reachability.create)
    }
    
    func simulateError5() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,5,server busy")
        
        client.callbackQueue.async {
            XCTAssertEqual("""
            ws.init http://server/lightstreamer
            wsok
            create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
            WSOK
            CONERR,5,server busy
            ws.dispose
            """, self.ws.trace)
        }
    }
    
    func simulateError5WithoutCheckingTraces() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,5,server busy")
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONERR,10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONERR,10,error
                http.dispose
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Retry() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONERR,4,error
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=ttl.conerr.4
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_RetryTTL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONERR,5,error")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONERR,5,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ttl.conerr.5
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 60000
                """, self.scheduler.trace)
        }
    }
    
    func testCONOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testSERVNAME() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionDetails.serverSocketName)
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SERVNAME,server")
        XCTAssertEqual("server", self.client.connectionDetails.serverSocketName)
    }
    
    func testCLIENTIP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionDetails.clientIp)
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CLIENTIP,127.0.0.1")
        XCTAssertEqual("127.0.0.1", self.client.connectionDetails.clientIp)
    }
    
    func testCONS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,12.34")
        XCTAssertEqual(.limited(12.34), self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unlimited")
        XCTAssertEqual(.unlimited, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unmanaged() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unmanaged")
        XCTAssertEqual(.unmanaged, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testPROBE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROBE")
    }

    func testNOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("NOOP,foobar")
    }
    
    func testPROG_Mismatch() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,100")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                PROG,100
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=prog.mismatch.100.0
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
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
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                PROG,0
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_WS_Streaming() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_send_sync=false&LS_cause=ttl.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_WS_Polling() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS_POLLING
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r\nLS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=ttl.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_HTTP_Streaming() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .HTTP_STREAMING
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=ttl.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_HTTP_Polling() {
        client = newClientWithMergedTraces("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=ttl.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-POLLING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                idle.timeout 23000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_140() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ttl.timeout
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 60000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_230_Created_no_Recovery() {
        client = newClientWithMergedTraces("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ttl.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_230_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireTransportTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ttl.timeout
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_140() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ttl.error
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 60000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_230_Created_no_Recovery() {
        client = newClientWithMergedTraces("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5WithoutCheckingTraces()
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,server busy
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ttl.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_230_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ttl.error
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_140() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                http.dispose
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_230_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        http.onText("CONOK,sid,70000,5000,*")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                CONOK,sid,70000,5000,*
                http.dispose
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateError5()
        scheduler.fireTransportTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=ws.conerr.5
                http.dispose
                """, self.http.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTING
                DISCONNECTED:WILL-RETRY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 60000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                """, self.scheduler.trace)
        }
    }
}
