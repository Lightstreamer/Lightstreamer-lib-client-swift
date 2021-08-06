import Foundation
import XCTest
@testable import LightstreamerClient

class TestMsgDelegate: ClientMessageDelegate {
    var trace = ""
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func client(_ client: LightstreamerClient, didAbortMessage originalMessage: String, sentOnNetwork: Bool) {
        addTrace("didAbortMessage \(originalMessage)")
    }
    
    func client(_ client: LightstreamerClient, didDenyMessage originalMessage: String, withCode code: Int, error: String) {
        addTrace("didDenyMessage \(originalMessage) \(code) \(error)")
    }
    
    func client(_ client: LightstreamerClient, didDiscardMessage originalMessage: String) {
        addTrace("didDiscardMessage \(originalMessage)")
    }
    
    func client(_ client: LightstreamerClient, didFailMessage originalMessage: String) {
        addTrace("didFailMessage \(originalMessage)")
    }
    
    func client(_ client: LightstreamerClient, didProcessMessage originalMessage: String) {
        addTrace("didProcessMessage \(originalMessage)")
    }
}

final class SendMessageBaseTests: BaseTestCase {
    let preamble = """
        ws.init http://server/lightstreamer
        wsok
        create_session\r
        LS_cid=cid&LS_send_sync=false&LS_cause=api
        WSOK
        CONOK,sid,70000,5000,*
        
        """
    
    func testRequest_SequenceAndListener() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                """, self.io.trace)
        }
    }
    
    func testRequest_SequenceAndNoListener() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                """, self.io.trace)
        }
    }
    
    func testRequest_NoSequenceAndNoListener() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_ack=false
                """, self.io.trace)
        }
    }
    
    func testRequest_NoSequenceAndListener() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", delegate: msgDelegate)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                """, self.io.trace)
        }
    }

    func testEnqueueWhileDisconnected_eq_false_InDisconnected() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.sendMessage("foo", delegate: msgDelegate, enqueueWhileDisconnected: false)
        
        
        asyncAssert {
            XCTAssertEqual("""
                
                """, self.io.trace)
            XCTAssertEqual("""
                didAbortMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testEnqueueWhileDisconnected_eq_false_InRetry() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onError()
        client.sendMessage("foo", delegate: msgDelegate, enqueueWhileDisconnected: false)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                didAbortMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testEnqueueWhileDisconnected_eq_false() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.sendMessage("m1")
        client.sendMessage("m2", delegate: msgDelegate)
        client.sendMessage("m3", withSequence: "seq")
        client.sendMessage("m4", withSequence: "seq", delegate: msgDelegate)
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        client.sendMessage("m10")
        client.sendMessage("m20", delegate: msgDelegate)
        client.sendMessage("m30", withSequence: "seq")
        client.sendMessage("m40", withSequence: "seq", delegate: msgDelegate)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=m10&LS_outcome=false&LS_ack=false
                msg\r
                LS_reqId=2&LS_message=m20&LS_msg_prog=1
                msg\r
                LS_reqId=3&LS_message=m30&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                msg\r
                LS_reqId=4&LS_message=m40&LS_sequence=seq&LS_msg_prog=2
                """, self.io.trace)
            XCTAssertEqual("""
                didAbortMessage m2
                didAbortMessage m4
                """, self.msgDelegate.trace)
        }
    }
    
    func testEnqueueWhileDisconnected_eq_true() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.sendMessage("m1", enqueueWhileDisconnected: true)
        client.sendMessage("m2", delegate: msgDelegate, enqueueWhileDisconnected: true)
        client.sendMessage("m3", withSequence: "seq", enqueueWhileDisconnected: true)
        client.sendMessage("m4", withSequence: "seq", delegate: msgDelegate, enqueueWhileDisconnected: true)
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        client.sendMessage("m10", enqueueWhileDisconnected: true)
        client.sendMessage("m20", delegate: msgDelegate, enqueueWhileDisconnected: true)
        client.sendMessage("m30", withSequence: "seq", enqueueWhileDisconnected: true)
        client.sendMessage("m40", withSequence: "seq", delegate: msgDelegate, enqueueWhileDisconnected: true)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=m1&LS_outcome=false&LS_ack=false\r
                LS_reqId=2&LS_message=m2&LS_msg_prog=1\r
                LS_reqId=3&LS_message=m3&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1\r
                LS_reqId=4&LS_message=m4&LS_sequence=seq&LS_msg_prog=2
                msg\r
                LS_reqId=5&LS_message=m10&LS_outcome=false&LS_ack=false
                msg\r
                LS_reqId=6&LS_message=m20&LS_msg_prog=2
                msg\r
                LS_reqId=7&LS_message=m30&LS_outcome=false&LS_sequence=seq&LS_msg_prog=3
                msg\r
                LS_reqId=8&LS_message=m40&LS_sequence=seq&LS_msg_prog=4
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testSequence() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq1")
        client.sendMessage("bar", withSequence: "seq2")
        client.sendMessage("zap")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq1&LS_msg_prog=1
                msg\r
                LS_reqId=2&LS_message=bar&LS_outcome=false&LS_sequence=seq2&LS_msg_prog=1
                msg\r
                LS_reqId=3&LS_message=zap&LS_outcome=false&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testProg() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq")
        client.sendMessage("zap")
        client.sendMessage("bar", withSequence: "seq")

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1
                msg\r
                LS_reqId=2&LS_message=zap&LS_outcome=false&LS_ack=false
                msg\r
                LS_reqId=3&LS_message=bar&LS_outcome=false&LS_sequence=seq&LS_msg_prog=2
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testTimeout() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq", timeout: 100)
        client.sendMessage("zap", withSequence: nil, timeout: 100)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_sequence=seq&LS_msg_prog=1&LS_max_wait=100
                msg\r
                LS_reqId=2&LS_message=zap&LS_outcome=false&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGDONE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("MSGDONE,seq,1")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                MSGDONE,seq,1
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGDONE_NoSequence() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: nil, delegate: msgDelegate)
        client.sendMessage("bar", withSequence: nil, delegate: msgDelegate)
        ws.onText("MSGDONE,*,1")
        ws.onText("MSGDONE,*,2")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                msg\r
                LS_reqId=2&LS_message=bar&LS_msg_prog=2
                MSGDONE,*,1
                MSGDONE,*,2
                """, self.io.trace)
            XCTAssertEqual("""
                didProcessMessage foo
                didProcessMessage bar
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
    
    func testMSGFAIL_NoSequence() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: nil, delegate: msgDelegate)
        client.sendMessage("bar", withSequence: nil, delegate: msgDelegate)
        ws.onText("MSGFAIL,*,1,10,error")
        ws.onText("MSGFAIL,*,2,10,error")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_msg_prog=1
                msg\r
                LS_reqId=2&LS_message=bar&LS_msg_prog=2
                MSGFAIL,*,1,10,error
                MSGFAIL,*,2,10,error
                """, self.io.trace)
            XCTAssertEqual("""
                didFailMessage foo
                didFailMessage bar
                """, self.msgDelegate.trace)
        }
    }
    
    func testMSGFAIL_error39() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onText("REQOK,1")
        XCTAssertEqual(.s12, client.messageManagers[0].s_m)
        ws.onText("MSGDONE,seq,1")
        XCTAssertEqual(0, client.messageManagers.count)

        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                REQOK,1
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
    
    func testAbort_Terminate() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
    
    func testAbort_Retry_InSession() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                msg\r
                LS_reqId=1&LS_message=foo&LS_sequence=seq&LS_msg_prog=1
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                didAbortMessage foo
                """, self.msgDelegate.trace)
        }
    }
    
    func testAbort_Retry_InCreate() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        client.sendMessage("foo", withSequence: "seq", delegate: msgDelegate)
        ws.onError()
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
        
        client.sendMessage("foo")
        XCTAssertEqual(1, client.messageManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.messageManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
