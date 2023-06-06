import Foundation
import XCTest
@testable import LightstreamerClient

final class SendMessageWSPollingTests: BaseTestCase {
    let preamble = """
        http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
        LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_cause=api
        CONOK,sid,70000,5000,*
        LOOP,0
        http.dispose
        ws.init http://server/lightstreamer
        wsok
        WSOK
        bind_session\r
        LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
        CONOK,sid,70000,5000,*

        """
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .WS_POLLING
        return client
    }
    
    func simulateCreation() {
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
    }

    func testMSGDONE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("MSGDONE,seq,1,")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                MSGDONE,seq,1,
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
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("MSGFAIL,seq,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                MSGFAIL,seq,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                didDenyMessage foo -5 error
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL_error39() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo1", withSequence: "seq", delegate: msgDelegate)
        client.sendMessage("foo2", withSequence: "seq", delegate: msgDelegate)
        client.sendMessage("foo3", withSequence: "seq", delegate: msgDelegate)
        ws.onText("MSGFAIL,seq,3,39,2")

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo1&LS_sequence=seq&LS_msg_prog=1
                msg\r
                LS_reqId=2&LS_message=foo2&LS_sequence=seq&LS_msg_prog=2
                msg\r
                LS_reqId=3&LS_message=foo3&LS_sequence=seq&LS_msg_prog=3
                MSGFAIL,seq,3,39,2
                """, self.io.trace)
            XCTAssertEqual("""
                didDiscardMessage foo2
                didDiscardMessage foo3
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGDONE_AfterREQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("REQOK,1")
        XCTAssertEqual(.s12, client.messageManagers[0].s_m)
        ws.onText("MSGDONE,seq,1,")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                MSGDONE,seq,1,
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL_AfterREQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("REQOK,1")
        XCTAssertEqual(.s12, client.messageManagers[0].s_m)
        ws.onText("MSGFAIL,seq,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                MSGFAIL,seq,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                didDenyMessage foo -5 error
                """, self.msgDelegate.trace)
        }
    }
    
    func testAbort() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        client.disconnect()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                didAbortMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testAbort_NoOutcome() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq")
        XCTAssertEqual(1, client.messageManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testAbort_NoAck() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        client.sendMessage("foo")
        XCTAssertEqual(1, client.messageManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_TEST_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testREQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        XCTAssertEqual(1, client.messageManagers.count)
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQERR,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                didFailMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testREQERR_NoOutcome() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq")
        XCTAssertEqual(1, client.messageManagers.count)
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                REQERR,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testWS_NoAck() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testREQOK_NoOutcome() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq")
        XCTAssertEqual(1, client.messageManagers.count)
        ws.onText("REQOK,1")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
}
