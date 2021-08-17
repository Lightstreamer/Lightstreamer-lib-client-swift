import Foundation
import XCTest
@testable import LightstreamerClient

final class SubscriptionHTTPTests: BaseTestCase {
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .HTTP
        return client
    }
    
    func testSubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                """, self.io.trace)
        }
    }
    
    func testSubscribe_Unsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        asyncAssert {
            XCTAssertEqual("""
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=TLCP-2.3.0
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=cid&LS_cause=api
                CONOK,sid,70000,5000,*
                LOOP,0
                http.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=TLCP-2.3.0
                LS_session=sid&LS_content_length=50000000&LS_send_sync=false&LS_cause=http.loop
                """, self.io.trace)
        }
    }
    
    func testREQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQERR,1,-5,error")
        ctrl.onDone()
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQERR,1,-5,error
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                onError -5 error
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBCMD,1,1,2,1,2")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBCMD,1,1,2,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testCONF() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("CONF,1,unlimited,filtered")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                CONF,1,unlimited,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onCONF unlimited
                """, self.subDelegate.trace)
        }
    }
    
    func testU() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("U,1,1,a,b")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                U,1,1,a,b
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
        }
    }
    
    func testEOS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("U,1,1,a,b")
        http.onText("EOS,1,1")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                U,1,1,a,b
                EOS,1,1
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS item 1
                """, self.subDelegate.trace)
        }
    }
    
    func testCS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("U,1,1,a,b")
        http.onText("EOS,1,1")
        http.onText("CS,1,1")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                U,1,1,a,b
                EOS,1,1
                CS,1,1
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS item 1
                onCS item 1
                """, self.subDelegate.trace)
        }
    }
    
    func testOV() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("U,1,1,a,b")
        http.onText("EOS,1,1")
        http.onText("OV,1,1,33")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                U,1,1,a,b
                EOS,1,1
                OV,1,1,33
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS item 1
                onOV item 1 33
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_Abort() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.disconnect()
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                http.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUNSUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        http.onText("UNSUB,1")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                UNSUB,1
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testREQOK_Unsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.subDelegate.trace)
        }
    }
    
    func testREQOK_Abort() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        client.disconnect()
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                http.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe_UNSUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        http.onText("UNSUB,1")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                UNSUB,1
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        ctrl.onText("REQOK,2")
        ctrl.onDone()
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                REQOK,2
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        ctrl.onText("REQERR,2,-5,error")
        ctrl.onDone()
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                REQERR,2,-5,error
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe_Abort() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        client.disconnect()
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=delete
                http.dispose
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .limited(12.3)
        http.onText("REQOK,2")
        http.onDone()
        
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true
                REQOK,1
                ctrl.dispose
                CONOK,sid,70000,5000,*
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=2&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=12.3
                REQOK,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBOK,1,1,2")
        
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
                SUBOK,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("SUBCMD,1,1,2,1,2")
        
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
                SUBCMD,1,1,2,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testCONF_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CONF,1,unlimited,unfiltered")
        
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
                CONF,1,unlimited,unfiltered
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testU_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("U,1,1,a")
        
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
                U,1,1,a
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testEOS_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("EOS,1,1")
        
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
                EOS,1,1
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testCS_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("CS,1,1")
        
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
                CS,1,1
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testOV_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("OV,1,1,2")
        
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
                OV,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testREQERR_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ctrl.onText("REQERR,1,-5,error")
        ctrl.onDone()
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                OV,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQERR,1,-5,error
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testREQOK_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ctrl.onText("REQOK,1")
        ctrl.onDone()
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                OV,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                REQOK,1
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testUNSUB_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        http.onText("UNSUB,1")
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                OV,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                UNSUB,1
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testAbort_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
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
                OV,1,1,2
                ctrl.send http://server/lightstreamer/control.txt?LS_protocol=TLCP-2.3.0&LS_session=sid
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_cause=zombie
                http.dispose
                ctrl.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
}
