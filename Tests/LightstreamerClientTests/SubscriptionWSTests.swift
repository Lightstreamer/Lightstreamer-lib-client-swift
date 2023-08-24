import Foundation
import XCTest
@testable import LightstreamerClient

final class SubscriptionWSTests: BaseTestCase {
    
    func testSubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                """, self.io.trace)
        }
    }
  
  func testSubscribeFieldWithPlus() {
      client = newClient("http://server")
      client.addDelegate(delegate)
      client.connect()
      
      let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1+f2"])
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
              LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
              WSOK
              CONOK,sid,70000,5000,*
              control\r
              LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%2Bf2&LS_ack=false
              """, self.io.trace)
      }
  }
    
    func testSubscribe_adapter_schema_group_selector_buffer() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW)
        sub.dataAdapter = "adapter"
        sub.fieldSchema = "schema"
        sub.itemGroup = "group"
        sub.selector = "selector"
        sub.requestedBufferSize = .limited(123)
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=group&LS_schema=schema&LS_data_adapter=adapter&LS_selector=selector&LS_requested_buffer_size=123&LS_ack=false
                """, self.io.trace)
        }
    }
    
    func testSubscribe_buffer_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW)
        sub.fieldSchema = "schema"
        sub.itemGroup = "group"
        sub.requestedBufferSize = .unlimited
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=group&LS_schema=schema&LS_requested_buffer_size=unlimited&LS_ack=false
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
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
    
    func testSUBOK_ItemMismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,10,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,10,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 1 items but got 10
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_ItemMismatch_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("SUBOK,1,10,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                REQOK,1
                SUBOK,1,10,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 1 items but got 10
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_FieldMismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,20")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,1,20
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 2 fields but got 20
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_FieldMismatch_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("SUBOK,1,1,20")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=item&LS_schema=f1%20f2&LS_ack=false
                REQOK,1
                SUBOK,1,1,20
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 2 fields but got 20
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBOK_ItemGroupAndFieldSchema() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.itemGroup = "ig"
        sub.fieldSchema = "fs"
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,10,20")
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(true, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=ig&LS_schema=fs&LS_ack=false
                SUBOK,1,10,20
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
    
    func testSUBCMD_ItemMismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptions.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,10,2,1,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                SUBCMD,1,10,2,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 1 items but got 10
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD_ItemMismatch_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptions.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("SUBCMD,1,10,2,1,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                REQOK,1
                SUBCMD,1,10,2,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 1 items but got 10
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD_FieldMismatch() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptions.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,20,1,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                SUBCMD,1,1,20,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 2 fields but got 20
                """, self.subDelegate.trace)
        }
    }
    
    func testSUBCMD_FieldMismatch_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptions.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("REQOK,1")
        ws.onText("SUBCMD,1,1,20,1,2")
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=item&LS_schema=key%20command&LS_snapshot=true&LS_ack=false
                REQOK,1
                SUBCMD,1,1,20,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onError 61 Expected 2 fields but got 20
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        
        let sub = Subscription(subscriptionMode: .RAW, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        XCTAssertEqual(true, sub.isActive)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        XCTAssertEqual(1, client.subscriptions.count)
        client.unsubscribe(sub)
        XCTAssertEqual(false, sub.isActive)
        XCTAssertEqual(false, sub.isSubscribed)
        XCTAssertEqual(1, client.subscriptionManagers.count)
        XCTAssertEqual(0, client.subscriptions.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
    
    func testReconf_limited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        sub.requestedMaxFrequency = .limited(12.3)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_requested_max_frequency=12.3&LS_ack=false
                SUBOK,1,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_unlimited() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        sub.requestedMaxFrequency = .unlimited
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_requested_max_frequency=unlimited&LS_ack=false
                SUBOK,1,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_unfiltered() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        sub.requestedMaxFrequency = .unfiltered
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,1,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_Twice() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .limited(12.3)
        sub.requestedMaxFrequency = .unlimited
        ws.onText("REQOK,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=12.3
                REQOK,2
                control\r
                LS_reqId=3&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_DontSendIfUnchanged() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        sub.requestedMaxFrequency = .unlimited
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .unlimited
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_requested_max_frequency=unlimited&LS_ack=false
                SUBOK,1,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_Twice_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .limited(12.3)
        sub.requestedMaxFrequency = .unlimited
        ws.onText("REQERR,2,-5,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=12.3
                REQERR,2,-5,error
                control\r
                LS_reqId=3&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                """, self.subDelegate.trace)
        }
    }
    
    func testReconf_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, item: "item", fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,2")
        sub.requestedMaxFrequency = .limited(12.3)
        ws.onText("REQERR,2,-5,error")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=item&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,1,2
                control\r
                LS_reqId=2&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=12.3
                REQERR,2,-5,error
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
        ws.onText("SUBOK,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("SUBCMD,1,1,2,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("CONF,1,unlimited,unfiltered")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("U,1,1,a")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("EOS,1,1")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("CS,1,1")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
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
        ws.onText("OV,1,1,2")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                OV,1,1,2
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
        ws.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                OV,1,1,2
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
        ws.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        ws.onText("UNSUB,1")
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                OV,1,1,2
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
        ws.onText("OV,1,1,2")
        XCTAssertEqual(1, client.subscriptionManagers.count)
        client.disconnect()
        XCTAssertEqual(0, client.subscriptionManagers.count)
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                OV,1,1,2
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
