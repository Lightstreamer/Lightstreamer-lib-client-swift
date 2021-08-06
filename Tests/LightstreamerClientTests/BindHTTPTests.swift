import Foundation
import XCTest
@testable import LightstreamerClient

final class BindHTTPTests: BaseTestCase {
    let preamble = """
        http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
        LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
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
        client.connectionOptions.forcedTransport = .HTTP
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
        http.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testHeaders() {
        http.showExtraHeaders = true
        ctrl.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(10)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                Foo=bar
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                Foo=bar
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                Foo=bar
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=10.0
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testHeadersOnCreationOnly() {
        http.showExtraHeaders = true
        ctrl.showExtraHeaders = true
        
        client = newClient("http://server")
        client.connectionOptions.HTTPExtraHeaders = ["Foo":"bar"]
        client.connectionOptions.HTTPExtraHeadersOnSessionCreationOnly = true
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(10)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                Foo=bar
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=10.0
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONERR,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONERR,10,error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testCONERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONERR,4,error")
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONERR,4,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.conerr.4
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
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
    
    func testEND_Disconnect_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                END,10,error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED
                onServerError 39 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testEND_Retry_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("END,41,error")
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                END,41,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
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
    
    func testEND_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                END,10,error
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 39 error
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
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                END,41,error
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=http.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                CONNECTING
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
    
    func testERROR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        ctrl.onText("ERROR,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                ERROR,10,error
                http.dispose
                ctrl.dispose
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel ctrl.timeout
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Disconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        ctrl.onText("REQERR,1,11,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                REQERR,1,11,error
                http.dispose
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED
                onServerError 21 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel ctrl.timeout
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testREQERR_Retry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.forcedTransport = .WS
        ctrl.onText("REQERR,1,20,error")
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind
                REQERR,1,20,error
                http.dispose
                ctrl.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=http.reqerr.20
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                ctrl.timeout 4000
                cancel ctrl.timeout
                cancel keepalive.timeout
                retry.timeout 100
                cancel retry.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testDisconnect_in_Pushing() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_800() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_801() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        scheduler.fireTransportTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                ctrl.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.timeout
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportTimeout_in_801_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                retry.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_800() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_801() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                ctrl.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_802() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=http.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:TRYING-RECOVERY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
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
    
    func testTransportError_in_800_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_801_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        http.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=force_rebind&LS_cause=http.streaming.unavailable
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                ctrl.timeout 4000
                transport.timeout 4000
                cancel ctrl.timeout
                cancel transport.timeout
                retry.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_802_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:WILL-RETRY
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                retry.timeout 100
                """, self.scheduler.trace)
        }
    }
    
    func testSERVNAME() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        XCTAssertEqual(nil, client.connectionDetails.serverSocketName)
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SERVNAME,server")
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
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                PROG,100
                http.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_old_session=sid&LS_cause=prog.mismatch.100.0
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                CONNECTED:HTTP-STREAMING
                DISCONNECTED:WILL-RETRY
                CONNECTING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
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
        
        simulateCreation()
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("PROG,0")
    }
    
    func testDisconnect_in_Retry() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        http.onError()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                http.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED:WILL-RETRY
                DISCONNECTED
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                retry.timeout 4000
                cancel retry.timeout
                """, self.scheduler.trace)
        }
    }
}
