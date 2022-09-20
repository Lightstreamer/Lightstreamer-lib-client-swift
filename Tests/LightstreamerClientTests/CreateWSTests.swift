import Foundation
import XCTest
@testable import LightstreamerClient

final class CreateWSTests: BaseTestCase {
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        return LightstreamerClient(url, adapterSet: adapterSet,
                                   wsFactory: ws.createWS,
                                   httpFactory: http.createHTTP,
                                   ctrlFactory: http.createHTTP,
                                   scheduler: scheduler,
                                   randomGenerator: { n in n },
                                   reachabilityFactory: reachability.create)
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,10,error
                ws.dispose
                """, self.ws.trace)
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,4,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=ws.conerr.4
                """, self.ws.trace)
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONERR,5,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONERR,5,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
            http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
            LS_ttl_millis=unlimited&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=ws.conerr.5
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                """, self.ws.trace)
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

    func testEND_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                END,10,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED
                onServerError 39 error
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("END,41,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                END,41,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.end.41
                """, self.ws.trace)
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
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }

    func testERROR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("ERROR,10,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ERROR,10,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,65,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                REQERR,1,65,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED
                onServerError 65 error
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,20,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                REQERR,1,20,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.reqerr.20
                """, self.ws.trace)
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROBE")
    }

    func testNOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("NOOP,foobar")
    }
    
    func testPROG_Mismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROG,100")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                PROG,100
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=prog.mismatch.100.0
                """, self.ws.trace)
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("PROG,0")
    }
    
    func testLOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        
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
                """, self.ws.trace)
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
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_120_Opening() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=ws.unavailable
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_121_Open() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=ws.unavailable
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_122_Creating() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=ws.timeout
                """, self.ws.trace)
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
    
    func testTransportError_in_120_Opening() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=ws.unavailable
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_121_Open() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=ws.unavailable
                """, self.http.trace)
            XCTAssertEqual("""
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_122_Creating() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=ws.error
                """, self.ws.trace)
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
    
    func testTransportError_in_210() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                """, self.http.trace)
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
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_210_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                """, self.ws.trace)
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
                retry.timeout 100
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_120_Opening() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.ws.trace)
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
    
    func testDisconnect_in_121_Open() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                ws.dispose
                """, self.ws.trace)
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
    
    func testDisconnect_in_122_Creating() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                """, self.ws.trace)
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
    
    func testDisconnect_in_210() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireTransportTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                """, self.ws.trace)
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
        ws.showExtraHeaders = true

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
        
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                h1=v1
                wsok
                create_session\r
                LS_keepalive_millis=10&LS_inactivity_millis=20&LS_requested_max_bandwidth=30.3&LS_adapter_set=adapter&LS_user=user&LS_cid=\(LS_CID)&LS_cause=api&LS_password=pwd
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
