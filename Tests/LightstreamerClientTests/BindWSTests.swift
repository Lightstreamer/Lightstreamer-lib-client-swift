/*
 * Copyright (C) 2021 Lightstreamer Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation
import XCTest
@testable import LightstreamerClient

final class BindWSTests: BaseTestCase {
    let preamble = """
ws.init http://server/lightstreamer
wsok
create_session\r\nLS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
WSOK
CONOK,sid,70000,5000,*
LOOP,0
ws.dispose

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

"""
    
    func simulateCreation() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testHeaders() {
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
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                create_session\r\nLS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testHeadersOnCreationOnly() {
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
                ws.init http://server/lightstreamer
                Foo=bar
                wsok
                create_session\r\nLS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
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
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONERR,4,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.conerr.4
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                END,41,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.end.41
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("END,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                END,41,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.end.41
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("ERROR,10,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                ERROR,10,error
                ws.dispose
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 10 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
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
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,67,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                REQERR,1,67,error
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
                DISCONNECTED
                onServerError 67 error
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                REQERR,1,20,error
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.reqerr.20
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
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
    
    func testLOOP() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r\nLS_reqId=1&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
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
    
    func testTransportTimeout_in_500() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        scheduler.fireTransportTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.unavailable
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }

    func testTransportTimeout_in_501() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        scheduler.fireTransportTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.unavailable
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

    func testTransportTimeout_in_502() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireTransportTimeout()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.timeout
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
    
    func testTransportTimeout_in_501_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.unavailable
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

    func testTransportTimeout_in_502_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        scheduler.fireTransportTimeout()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.timeout
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
    
    func testTransportError_in_500() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.unavailable
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual(self.schedulerPreamble + """
                transport.timeout 4000
                cancel transport.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }

    func testTransportError_in_501() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=0&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.unavailable
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

    func testTransportError_in_502() {
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
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
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_503() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        scheduler.fireRecoveryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
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
                keepalive.timeout 5000
                cancel keepalive.timeout
                recovery.timeout 100
                cancel recovery.timeout
                transport.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testTransportError_in_501_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onError()
        scheduler.fireRetryTimeout()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_cause=ws.unavailable
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

    func testTransportError_in_502_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
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
    
    func testTransportError_in_503_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                """, self.io.trace)
            XCTAssertEqual(self.delegatePreamble + """
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
    
    func testSERVNAME() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
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
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                PROG,100
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=prog.mismatch.100.0
                """, self.ws.trace)
            XCTAssertEqual(self.delegatePreamble + """
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
        scheduler.fireTransportTimeout()
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                ws.dispose
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
