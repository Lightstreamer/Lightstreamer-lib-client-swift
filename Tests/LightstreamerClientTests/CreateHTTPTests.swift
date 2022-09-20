import Foundation
import XCTest
@testable import LightstreamerClient

final class CreateHTTPTests: BaseTestCase {
   
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .HTTP
        return client
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONERR,10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONERR,10,error
                http.dispose
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONERR,4,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=http.conerr.4
                """, self.http.trace)
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
        }
    }
    
    func testCONERR_RetryTTL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONERR,5,error")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONERR,5,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=http.conerr.5
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 60000
                """, self.scheduler.trace)
        }
    }
    
    func testCONOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
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
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SERVNAME,server")
        XCTAssertEqual("server", self.client.connectionDetails.serverSocketName)
    }
    
    func testCLIENTIP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionDetails.clientIp)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CLIENTIP,127.0.0.1")
        XCTAssertEqual("127.0.0.1", self.client.connectionDetails.clientIp)
    }
    
    func testCONS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,12.34")
        XCTAssertEqual(.limited(12.34), self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unlimited")
        XCTAssertEqual(.unlimited, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testCONS_unmanaged() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionOptions.realMaxBandwidth)
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONS,unmanaged")
        XCTAssertEqual(.unmanaged, self.client.connectionOptions.realMaxBandwidth)
    }
    
    func testPROBE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROBE")
    }

    func testNOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("NOOP,foobar")
    }
    
    func testPROG_Mismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,100")
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                PROG,100
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=prog.mismatch.100.0
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
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
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                PROG,0
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_HTTP_Streaming() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
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
                """, self.http.trace)
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
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_HTTP_Polling() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.http.trace)
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
                """, self.scheduler.trace)
        }
    }
    
    func testLOOP_WS_Streaming() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS_STREAMING
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_send_sync=false&LS_cause=http.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
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
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
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
    
    func testTransportTimeout_in_130() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=http.timeout
                """, self.http.trace)
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
        }
    }
    
    func testTransportTimeout_in_220_Created_no_Recovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.timeout
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_220_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        scheduler.fireTransportTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.timeout
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_130() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=http.error
                """, self.http.trace)
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
        }
    }
    
    func testTransportError_in_220_Created_no_Recovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.error
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_220_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_130() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                http.dispose
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_220_Created() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                http.dispose
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
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
        
        scheduler.fireTransportTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                http.dispose
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                DISCONNECTED:WILL-RETRY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testWithOptions() {
        http.showExtraHeaders = true

        client = newClient("http://server", adapterSet: "adapter")
        client.connectionOptions.keepaliveInterval = 10
        client.connectionOptions.reverseHeartbeatInterval = 20
        client.connectionOptions.requestedMaxBandwidth = .limited(30.3)
        client.connectionOptions.slowingEnabled = true
        client.connectionOptions.HTTPExtraHeaders = ["h1":"v1"]
        client.connectionDetails.user = "user"
        client.connectionDetails.setPassword("pwd")
        client.addDelegate(delegate)
        client.connect()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                h1=v1
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_requested_max_bandwidth=30.3&LS_adapter_set=adapter&LS_user=user&LS_cid=cid&LS_cause=api&LS_password=pwd
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
}
