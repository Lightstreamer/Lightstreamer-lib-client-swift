import Foundation
import XCTest
@testable import LightstreamerClient

final class SendMessageHTTPTests: BaseTestCase {
    let preamble = """
        http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
        LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
        CONOK,sid,70000,5000,*
        LOOP,0
        http.dispose
        http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
        LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
        CONOK,sid,70000,5000,*
        
        """
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .HTTP
        return client
    }
    
    func simulateCreation() {
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
    }

    func testMSGDONE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        http.onText("MSGDONE,seq,1")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                MSGDONE,seq,1
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
        http.onText("MSGFAIL,seq,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
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
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        ctrl.onText("REQOK,2")
        ctrl.onText("REQOK,3")
        ctrl.onDone()
        http.onText("MSGFAIL,seq,3,39,2")

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo1&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=2&LS_message=foo2&LS_sequence=seq&LS_msg_prog=2\r
                LS_reqId=3&LS_message=foo3&LS_sequence=seq&LS_msg_prog=3
                REQOK,2
                REQOK,3
                ctrl.dispose
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
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        XCTAssertEqual(.s12, client.messageManagers[0].s_m)
        http.onText("MSGDONE,seq,1")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                ctrl.dispose
                MSGDONE,seq,1
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
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        XCTAssertEqual(.s12, client.messageManagers[0].s_m)
        http.onText("MSGFAIL,seq,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                ctrl.dispose
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
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                http.dispose
                ctrl.dispose
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
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                http.dispose
                ctrl.dispose
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
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false
                http.dispose
                ctrl.dispose
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
        http.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
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
        http.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                REQERR,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testREQERR_NoAck() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo")
        ctrl.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false
                REQERR,1,-5,error
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
        http.onText("REQOK,1")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testREQOK_NoAck() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        client.sendMessage("foo")
        XCTAssertEqual(1, client.messageManagers.count)
        ctrl.onText("REQOK,1")
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=\(TLCP_VERSION)&LS_session=sid
                LS_reqId=1&LS_message=foo&LS_outcome=false
                REQOK,1
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
}
