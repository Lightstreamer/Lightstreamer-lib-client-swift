import Foundation
import XCTest
@testable import LightstreamerClient

final class SubscriptionBindWSTests: BaseTestCase {
    
    func testSubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                """, self.io.trace)
        }
    }
    
    func testSubscribe_Unsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                """, self.io.trace)
        }
    }
    
    func testREQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                REQERR,1,-5,error
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,2,1,2")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("CONF,1,unlimited,filtered")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,a,b")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,a,b")
        ws.onText("EOS,1,1")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,a,b")
        ws.onText("EOS,1,1")
        ws.onText("CS,1,1")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .DISTINCT, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,a,b")
        ws.onText("EOS,1,1")
        ws.onText("OV,1,1,33")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        client.disconnect()
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        ws.onText("UNSUB,1")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onUNSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testUnsubscribe_UNSUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        ws.onText("UNSUB,1")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                UNSUB,1
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        client.unsubscribe(sub)
        client.disconnect()
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                control\r
                LS_reqId=3&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .limited(12.3)
        ws.onText("REQOK,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,2
                control\r
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                SUBOK,1,1,2
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,2,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                SUBCMD,1,1,2,1,2
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testCONF_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CONF,1,unlimited,unfiltered")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                CONF,1,unlimited,unfiltered
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testU_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("U,1,1,a")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                U,1,1,a
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testEOS_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("EOS,1,1")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                EOS,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testCS_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("CS,1,1")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                CS,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testOV_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("OV,1,1,1")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                OV,1,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testREQERR_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("OV,1,1,1")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                OV,1,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                REQERR,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
    
    func testUNSUB_Zombie() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("OV,1,1,1")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ws.onText("UNSUB,1")
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                OV,1,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("LOOP,0")
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("OV,1,1,1")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_CID)&LS_send_sync=false&LS_cause=api
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
                OV,1,1,1
                control\r
                LS_reqId=1&LS_subId=1&LS_op=delete&LS_ack=false&LS_cause=zombie
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                
                """, self.subDelegate.trace)
        }
    }
}
