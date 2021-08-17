import Foundation
import XCTest
@testable import LightstreamerClient

struct Req: Encodable {
    
    let req: String
    
    init(_ req: String) {
        self.req = req
    }
    
    func isPending() -> Bool {
        true
    }
    
    func encode(isWS: Bool) -> String {
        req
    }
    
    func encodeWS() -> String {
        ""
    }
}

final class BatchTests: BaseTestCase {
    
    override func setUpWithError() throws {
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
    }
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        delegate.logPropertyChange = false
        return super.newClient(url, adapterSet: adapterSet)
    }
    
    func testHTTPBatch() {
        XCTAssertEqual("""
            LS_a=10&LS_b=20
            """, prepareBatchHTTP([Req("LS_a=10&LS_b=20")], 100))
        XCTAssertEqual("""
            LS_a=10&LS_b=%26
            """, prepareBatchHTTP([Req("LS_a=10&LS_b=%26")], 100))
        XCTAssertEqual("""
            LS_a=10&LS_b=20\r
            LS_a=11&LS_b=22
            """, prepareBatchHTTP([
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 100))
        XCTAssertEqual("""
            LS_a=10&LS_b=20
            """, prepareBatchHTTP([
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 1))
        XCTAssertEqual("""
            LS_a=10&LS_b=20
            """, prepareBatchHTTP([
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 20))
        XCTAssertEqual("""
            a
            """, prepareBatchHTTP([
                                    Req("a"),
                                    Req("b"),
                                    Req("c")], 3))
        XCTAssertEqual("""
            a\r
            b
            """, prepareBatchHTTP([
                                    Req("a"),
                                    Req("b"),
                                    Req("c")], 6))
        XCTAssertEqual("""
            a\r
            b\r
            c
            """, prepareBatchHTTP([
                                    Req("a"),
                                    Req("b"),
                                    Req("c")], 9))
    }
    
    func testWSBatch() {
        XCTAssertEqual(["""
            control\r
            LS_a=10&LS_b=20
            """], prepareBatchWS("control", [Req("LS_a=10&LS_b=20")], 100))
        XCTAssertEqual(["""
            control\r
            LS_a=10&LS_b=%26
            """], prepareBatchWS("control", [Req("LS_a=10&LS_b=%26")], 100))
        XCTAssertEqual(["""
            control\r
            LS_a=10&LS_b=20\r
            LS_a=11&LS_b=22
            """], prepareBatchWS("control", [
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 100))
        XCTAssertEqual(["""
            control\r
            LS_a=10&LS_b=20
            """,
            """
            control\r
            LS_a=11&LS_b=22
            """], prepareBatchWS("control", [
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 1))
        XCTAssertEqual(["""
            control\r
            LS_a=10&LS_b=20
            """,
            """
            control\r
            LS_a=11&LS_b=22
            """], prepareBatchWS("control", [
                                    Req("LS_a=10&LS_b=20"),
                                    Req("LS_a=11&LS_b=22")], 20))
        XCTAssertEqual(["""
            control\r
            a
            """,
            """
            control\r
            b
            """,
            """
            control\r
            c
            """], prepareBatchWS("control", [
                                    Req("a"),
                                    Req("b"),
                                    Req("c")], 3))
        XCTAssertEqual(["""
            control\r
            a
            """,
            """
            control\r
            b
            """,
            """
            control\r
            c
            """], prepareBatchWS("control", [
                                    Req("a"),
                                    Req("b"),
                                    Req("c")], 6))
        XCTAssertEqual(["""
            control\r
            a\r
            b
            """,
            """
            control\r
            c\r
            d
            """], prepareBatchWS("control", [
                                    Req("a"),
                                    Req("b"),
                                    Req("c"),
                                    Req("d")], 13))
    }
    
    func testBindWS_SwitchAndConstrain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.forcedTransport = .HTTP
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("REQOK,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true\r
                LS_reqId=2&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                REQOK,2
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                cancel keepalive.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWSPolling_SwitchAndConstrain() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.forcedTransport = .HTTP
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("REQOK,2")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                control\r
                LS_reqId=1&LS_op=force_rebind&LS_close_socket=true\r
                LS_reqId=2&LS_op=constrain&LS_requested_max_bandwidth=12.5
                CONOK,sid,70000,5000,*
                REQOK,1
                REQOK,2
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
    
    func testBindHTTP_SwitchAndConstrain() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        client.connectionOptions.forcedTransport = .WS
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_op=force_rebind\r
                LS_reqId=3&LS_op=constrain&LS_requested_max_bandwidth=unlimited
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_SwitchAndConstrain() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.connectionOptions.requestedMaxBandwidth = .unlimited
        client.connectionOptions.forcedTransport = .WS
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_op=force_rebind\r
                LS_reqId=3&LS_op=constrain&LS_requested_max_bandwidth=unlimited
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_Msg() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        client.sendMessage("foo")
        client.sendMessage("bar")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_ack=false\r
                LS_reqId=2&LS_message=bar&LS_outcome=false&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_Msg() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        client.sendMessage("foo")
        client.sendMessage("bar")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r\nLS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r\nLS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_ack=false\r
                LS_reqId=2&LS_message=bar&LS_outcome=false&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
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
    
    func testBindWSPolling_Msg() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        client.sendMessage("foo")
        client.sendMessage("bar")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                msg\r
                LS_reqId=1&LS_message=foo&LS_outcome=false&LS_ack=false\r
                LS_reqId=2&LS_message=bar&LS_outcome=false&LS_ack=false
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
    
    func testBindHTTP_Msg() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.sendMessage("foo")
        client.sendMessage("bar")
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_message=foo&LS_outcome=false\r
                LS_reqId=3&LS_message=bar&LS_outcome=false
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_Msg() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        client.sendMessage("foo")
        client.sendMessage("bar")
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/msg.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_message=foo&LS_outcome=false\r
                LS_reqId=3&LS_message=bar&LS_outcome=false
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_Subscription() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        let sub1 = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        let sub2 = Subscription(subscriptionMode: .DISTINCT, item: "itm2", fields: ["f2"])
        client.subscribe(sub1)
        client.subscribe(sub2)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=DISTINCT&LS_group=itm2&LS_schema=f2&LS_snapshot=true&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
                transport.timeout 4000
                cancel transport.timeout
                keepalive.timeout 5000
                """, self.scheduler.trace)
        }
    }
    
    func testBindWS_Subscription() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        let sub1 = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        let sub2 = Subscription(subscriptionMode: .DISTINCT, item: "itm2", fields: ["f2"])
        client.subscribe(sub1)
        client.subscribe(sub2)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=DISTINCT&LS_group=itm2&LS_schema=f2&LS_snapshot=true&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
            XCTAssertEqual("""
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
    
    func testBindWSPolling_Subscription() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        let sub1 = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        let sub2 = Subscription(subscriptionMode: .DISTINCT, item: "itm2", fields: ["f2"])
        client.subscribe(sub1)
        client.subscribe(sub2)
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=DISTINCT&LS_group=itm2&LS_schema=f2&LS_snapshot=true&LS_ack=false
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
    
    func testBindHTTP_Subscription() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        let sub1 = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        let sub2 = Subscription(subscriptionMode: .DISTINCT, item: "itm2", fields: ["f2"])
        client.subscribe(sub1)
        client.subscribe(sub2)
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=DISTINCT&LS_group=itm2&LS_schema=f2&LS_snapshot=true
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testBindHTTPPolling_Subscription() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()

        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        http.onText("CONOK,sid,70000,5000,*")
        client.connectionOptions.requestedMaxBandwidth = .limited(12.5)
        let sub1 = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        let sub2 = Subscription(subscriptionMode: .DISTINCT, item: "itm2", fields: ["f2"])
        client.subscribe(sub1)
        client.subscribe(sub2)
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                CONOK,sid,70000,5000,*
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=constrain&LS_requested_max_bandwidth=12.5
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=DISTINCT&LS_group=itm2&LS_schema=f2&LS_snapshot=true
                """, self.io.trace)
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
                ctrl.timeout 4000
                cancel ctrl.timeout
                ctrl.timeout 4000
                """, self.scheduler.trace)
        }
    }
    
    func testCreateWS_Mpn() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        let sub = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        client.subscribe(sub)
        let dev = MPNDevice(deviceToken: "tok")
        client.register(forMPN: dev)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
        }
    }
    
    func testBindWS_Mpn() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()

        let sub = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        client.subscribe(sub)
        let dev = MPNDevice(deviceToken: "tok")
        client.register(forMPN: dev)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        ws.onText("REQOK,1")
        ws.onText("REQOK,2")
        ws.onText("REQOK,3")
        ws.onText("REQOK,4")
        ws.onText("LOOP,0")
       
        let sub1 = MPNSubscription(subscription: sub)
        sub1.notificationFormat = "fmt1"
        let sub2 = MPNSubscription(subscription: sub)
        sub2.notificationFormat = "fmt2"
        client.subscribeMPN(sub1, coalescing: false)
        client.subscribeMPN(sub2, coalescing: false)
        client.unsubscribeMultipleMPN(.TRIGGERED)
        client.resetMPNBadge()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,5")
        ws.onText("REQOK,6")
        ws.onText("REQOK,7")
        ws.onText("REQOK,8")
        ws.onText("MPNOK,4,sub4")
        ws.onText("MPNOK,5,sub5")
        ws.onText("LOOP,0")
        
        client.unsubscribeMPN(sub1)
        client.unsubscribeMPN(sub2)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                REQOK,1
                REQOK,2
                REQOK,3
                REQOK,4
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt1\r
                LS_reqId=6&LS_op=activate&LS_subId=5&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt2\r
                LS_reqId=7&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=TRIGGERED\r
                LS_reqId=8&LS_op=reset_badge&PN_deviceId=devid
                REQOK,5
                REQOK,6
                REQOK,7
                REQOK,8
                MPNOK,4,sub4
                MPNOK,5,sub5
                LOOP,0
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=ws.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=9&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub4\r
                LS_reqId=10&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub5
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-STREAMING
                """, self.delegate.trace)
        }
    }
    
    func testBindWSPolling_Mpn() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .WS_POLLING
        client.addDelegate(delegate)
        client.connect()

        let sub = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        client.subscribe(sub)
        let dev = MPNDevice(deviceToken: "tok")
        client.register(forMPN: dev)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true&LS_ack=false\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                CONOK,sid,70000,5000,*
                MPNREG,devid,adapter
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:WS-POLLING
                """, self.delegate.trace)
        }
    }
    
    func testBindHTTP_Mpn() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP
        client.addDelegate(delegate)
        client.connect()

        let sub = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        client.subscribe(sub)
        let dev = MPNDevice(deviceToken: "tok")
        client.register(forMPN: dev)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("MPNREG,devid,adapter")
        ctrl.onText("REQOK,1")
        ctrl.onText("REQOK,2")
       
        let sub1 = MPNSubscription(subscription: sub)
        sub1.notificationFormat = "fmt1"
        let sub2 = MPNSubscription(subscription: sub)
        sub2.notificationFormat = "fmt2"
        client.subscribeMPN(sub1, coalescing: false)
        client.subscribeMPN(sub2, coalescing: false)
        client.unsubscribeMultipleMPN(.TRIGGERED)
        client.resetMPNBadge()
        
        ctrl.onDone()
        ctrl.onText("REQOK,3")
        ctrl.onText("REQOK,4")
        ctrl.onText("REQOK,5")
        ctrl.onText("REQOK,6")
        ctrl.onText("REQOK,7")
        ctrl.onText("REQOK,8")
        http.onText("MPNOK,4,sub4")
        http.onText("MPNOK,5,sub5")

        client.unsubscribeMPN(sub1)
        client.unsubscribeMPN(sub2)
        
        ctrl.onDone()

        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                CONOK,sid,70000,5000,*
                MPNREG,devid,adapter
                REQOK,1
                REQOK,2
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt1\r
                LS_reqId=6&LS_op=activate&LS_subId=5&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt2\r
                LS_reqId=7&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=TRIGGERED\r
                LS_reqId=8&LS_op=reset_badge&PN_deviceId=devid
                REQOK,3
                REQOK,4
                REQOK,5
                REQOK,6
                REQOK,7
                REQOK,8
                MPNOK,4,sub4
                MPNOK,5,sub5
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=9&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub4\r
                LS_reqId=10&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub5
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-STREAMING
                """, self.delegate.trace)
        }
    }
    
    func testBindHTTPPolling_Mpn() {
        client = newClient("http://server")
        client.connectionOptions.forcedTransport = .HTTP_POLLING
        client.addDelegate(delegate)
        client.connect()

        let sub = Subscription(subscriptionMode: .MERGE, item: "itm1", fields: ["f1"])
        client.subscribe(sub)
        let dev = MPNDevice(deviceToken: "tok")
        client.register(forMPN: dev)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("MPNREG,devid,adapter")
        ctrl.onText("REQOK,1")
        ctrl.onText("REQOK,2")
       
        let sub1 = MPNSubscription(subscription: sub)
        sub1.notificationFormat = "fmt1"
        let sub2 = MPNSubscription(subscription: sub)
        sub2.notificationFormat = "fmt2"
        client.subscribeMPN(sub1, coalescing: false)
        client.subscribeMPN(sub2, coalescing: false)
        client.unsubscribeMultipleMPN(.TRIGGERED)
        client.resetMPNBadge()
        
        ctrl.onDone()
        ctrl.onText("REQOK,3")
        ctrl.onText("REQOK,4")
        ctrl.onText("REQOK,5")
        ctrl.onText("REQOK,6")
        ctrl.onText("REQOK,7")
        ctrl.onText("REQOK,8")
        http.onText("MPNOK,4,sub4")
        http.onText("MPNOK,5,sub5")

        client.unsubscribeMPN(sub1)
        client.unsubscribeMPN(sub2)
        
        ctrl.onDone()
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&LS_snapshot=true\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                CONOK,sid,70000,5000,*
                MPNREG,devid,adapter
                REQOK,1
                REQOK,2
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt1\r
                LS_reqId=6&LS_op=activate&LS_subId=5&LS_mode=MERGE&LS_group=itm1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt2\r
                LS_reqId=7&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=TRIGGERED\r
                LS_reqId=8&LS_op=reset_badge&PN_deviceId=devid
                REQOK,3
                REQOK,4
                REQOK,5
                REQOK,6
                REQOK,7
                REQOK,8
                MPNOK,4,sub4
                MPNOK,5,sub5
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=9&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub4\r
                LS_reqId=10&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub5
                """, self.io.trace)
            XCTAssertEqual("""
                CONNECTING
                CONNECTED:STREAM-SENSING
                CONNECTED:HTTP-POLLING
                """, self.delegate.trace)
        }
    }
}
