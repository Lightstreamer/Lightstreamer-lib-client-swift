import Foundation
import XCTest
@testable import LightstreamerClient

final class Update2LevelTests: BaseTestCase {
    
    func state(_ client: LightstreamerClient, subId: Int, itemPos: Pos, keyName: String) -> Key2Level.State_m {
      let sm = client.subscriptionManagers.value(forKey:subId) as! SubscriptionManagerLiving
        let item = sm.m_strategy.items[itemPos] as! ItemCommand2Level
        let key = item.keys[keyName] as! Key2Level
        return key.s_m
    }
    
    func state(_ client: LightstreamerClient, subId: Int) -> SubscriptionManagerLiving.State_m {
      let sm = client.subscriptionManagers.value(forKey:subId) as! SubscriptionManagerLiving
        return sm.s_m
    }
    
    func testCOMMAND2Level_ADD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
            
            XCTAssertEqual(1, self.subDelegate.updates.count)
            
            XCTAssertEqual(1, self.client.subscriptions.count)
            XCTAssertIdentical(sub, self.client.subscriptions[0])
            XCTAssertEqual(2, self.client.subscriptionManagers.count)
            
            let u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            XCTAssertEqual("a", sub.valueWithItemPos(1, fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldPos: 2))
            XCTAssertEqual("a", sub.valueWithItemPos(1, fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldName: "f2"))
            XCTAssertEqual("a", sub.valueWithItemName("i1", fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldPos: 2))
            XCTAssertEqual("a", sub.valueWithItemName("i1", fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldName: "f2"))
            
            XCTAssertEqual("a", sub.commandValueWithItemPos(1, key: "item1", fieldPos: 1))
            XCTAssertEqual("b", sub.commandValueWithItemPos(1, key: "item1", fieldPos: 2))
            XCTAssertEqual("a", sub.commandValueWithItemPos(1, key: "item1", fieldName: "f1"))
            XCTAssertEqual("b", sub.commandValueWithItemPos(1, key: "item1", fieldName: "f2"))
            XCTAssertEqual("a", sub.commandValueWithItemName("i1", key: "item1", fieldPos: 1))
            XCTAssertEqual("b", sub.commandValueWithItemName("i1", key: "item1", fieldPos: 2))
            XCTAssertEqual("a", sub.commandValueWithItemName("i1", key: "item1", fieldName: "f1"))
            XCTAssertEqual("b", sub.commandValueWithItemName("i1", key: "item1", fieldName: "f2"))
        }
    }
    
    func testCOMMAND2Level_EarlyUPD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|UPDATE")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|UPDATE
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
            
            XCTAssertEqual(1, self.subDelegate.updates.count)
            
            let u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_EarlyDEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|DELETE")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
            
            XCTAssertEqual(1, self.subDelegate.updates.count)
            
            let u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_BadItemName() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|123|ADD")
        XCTAssertEqual(.s3, state(client, subId: 1, itemPos: 1, keyName: "123"))
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|123|ADD
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onError2Level 123 14 The received key value is not a valid name for an Item
                """, self.subDelegate.trace)
            
            XCTAssertEqual(1, self.subDelegate.updates.count)
            
            let u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("123", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("123", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_BadItemName_UPD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|123|ADD")
        XCTAssertEqual(.s3, state(client, subId: 1, itemPos: 1, keyName: "123"))
        ws.onText("U,1,1,A|B||UPDATE")
        XCTAssertEqual(.s3, state(client, subId: 1, itemPos: 1, keyName: "123"))
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|123|ADD
                U,1,1,A|B||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onError2Level 123 14 The received key value is not a valid name for an Item
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("123", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("123", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A","f2":"B","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([1:"A",2:"B",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"B","key":"123","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"A",2:"B",3:"123",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("123", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("123", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_BadItemName_DEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|123|ADD")
        XCTAssertEqual(.s3, state(client, subId: 1, itemPos: 1, keyName: "123"))
        ws.onText("U,1,1,A|B||DELETE")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|123|ADD
                U,1,1,A|B||DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onError2Level 123 14 The received key value is not a valid name for an Item
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"123","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"123",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("123", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("123", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"123","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"123",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("123", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("123", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_UPD1Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("U,1,1,|||UPDATE")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                U,1,1,|||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["command":"UPDATE"], u.changedFields)
            XCTAssertEqual([4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("REQERR,2,-5,error")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                REQERR,2,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onError2Level item1 -5 error
                """, self.subDelegate.trace)
            
            XCTAssertEqual(1, self.subDelegate.updates.count)
            
            let u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_REQERR_UPD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("REQERR,2,-5,error")
        client.callbackQueue.async {
            XCTAssertEqual(.s3, self.state(self.client, subId: 1, itemPos: 1, keyName: "item1"))
            self.ws.onText("U,1,1,A|B||UPDATE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                REQERR,2,-5,error
                U,1,1,A|B||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onError2Level item1 -5 error
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A","f2":"B","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([1:"A",2:"B",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"B","key":"item1","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"A",2:"B",3:"item1",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_DEL1Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        ws.onText("U,1,1,|||DELETE")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                U,1,1,|||DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_UPD1Level_UPD2Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("U,2,1,c|d")
        client.callbackQueue.async {
            XCTAssertEqual(.s5, self.state(self.client, subId: 1, itemPos: 1, keyName: "item1"))
            self.ws.onText("U,1,1,A|||UPDATE")
            self.ws.onText("U,2,1,C|")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                U,2,1,c|d
                U,1,1,A|||UPDATE
                U,2,1,C|
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onU 2
                onU 3
                """, self.subDelegate.trace)
            
            XCTAssertEqual(4, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(nil, u.value(withFieldName: "f5"))
            XCTAssertEqual(nil, u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f5":"c","f6":"d","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([5:"c",6:"d",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"UPDATE","f5":"c","f6":"d"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"UPDATE",5:"c",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("c", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f6"))
            
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b","key":"item1","command":"UPDATE","f5":"c","f6":"d"], u.fields)
            XCTAssertEqual([1:"A",2:"b",3:"item1",4:"UPDATE",5:"c",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("c", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f5":"C"], u.changedFields)
            XCTAssertEqual([5:"C"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b","key":"item1","command":"UPDATE","f5":"C","f6":"d"], u.fields)
            XCTAssertEqual([1:"A",2:"b",3:"item1",4:"UPDATE",5:"C",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("C", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("C", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
        }
    }
    
    func testCOMMAND2Level_ADD_UPD1Level_UPD2Level_OutOfOrder() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("U,2,1,c|d")
        async(after: 0.2) {
            self.ws.onText("U,1,1,A|||UPDATE")
            XCTAssertEqual(.s5, self.state(self.client, subId: 1, itemPos: 1, keyName: "item1"))
        }
       
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                U,2,1,c|d
                U,1,1,A|||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onU 2
                """, self.subDelegate.trace)
            
            XCTAssertEqual(3, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(nil, u.value(withFieldName: "f5"))
            XCTAssertEqual(nil, u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f5":"c","f6":"d","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([4:"UPDATE",5:"c",6:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"UPDATE","f5":"c","f6":"d"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"UPDATE",5:"c",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("c", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b","key":"item1","command":"UPDATE","f5":"c","f6":"d"], u.fields)
            XCTAssertEqual([1:"A",2:"b",3:"item1",4:"UPDATE",5:"c",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("c", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
        }
    }
    
    func testCOMMAND2Level_ADD_UPD1Level_DEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        ws.onText("U,1,1,A|||DELETE")
        ws.onText("UNSUB,2")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                U,1,1,A|||DELETE
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                UNSUB,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(nil, u.value(withFieldName: "f5"))
            XCTAssertEqual(nil, u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_ADD_UPD2Level_DEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("U,2,1,c|d")
        client.callbackQueue.async {
            XCTAssertEqual(.s5, self.state(self.client, subId: 1, itemPos: 1, keyName: "item1"))
            self.ws.onText("U,1,1,|||DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                U,2,1,c|d
                U,1,1,|||DELETE
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onU 2
                """, self.subDelegate.trace)
            
            XCTAssertEqual(3, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(nil, u.value(withFieldName: "f5"))
            XCTAssertEqual(nil, u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f5":"c","f6":"d","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([5:"c",6:"d",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"UPDATE","f5":"c","f6":"d"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"UPDATE",5:"c",6:"d"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldPos: 5))
            XCTAssertEqual("d", u.value(withFieldPos: 6))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("c", u.value(withFieldName: "f5"))
            XCTAssertEqual("d", u.value(withFieldName: "f6"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f6"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"f5":nil,"f6":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,5:nil,6:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE","f5":nil,"f6":nil], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE",5:nil,6:nil], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(nil, u.value(withFieldName: "f5"))
            XCTAssertEqual(nil, u.value(withFieldName: "f6"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 5))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 6))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f5"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f6"))
        }
    }
    
    func testCOMMAND2Level_EOS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .yes
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("EOS,1,1")
        ws.onText("U,1,1,c|d|item2|ADD")
        ws.onText("U,1,2,e|f|item3|ADD")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                EOS,1,1
                U,1,1,c|d|item2|ADD
                control\r
                LS_reqId=3&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=item2&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                U,1,2,e|f|item3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=item3&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onEOS i1 1
                onU 1
                onU 2
                """, self.subDelegate.trace)
            
            XCTAssertEqual(3, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d","key":"item2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"item2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"item2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"item2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("item2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("item2", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"e","f2":"f","key":"item3","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"e",2:"f",3:"item3",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"e","f2":"f","key":"item3","command":"ADD"], u.fields)
            XCTAssertEqual([1:"e",2:"f",3:"item3",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("e", u.value(withFieldPos: 1))
            XCTAssertEqual("f", u.value(withFieldPos: 2))
            XCTAssertEqual("item3", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("e", u.value(withFieldName: "f1"))
            XCTAssertEqual("f", u.value(withFieldName: "f2"))
            XCTAssertEqual("item3", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_CS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("U,1,2,c|d|item2|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("SUBOK,3,1,2")
        ws.onText("CS,1,1")
        ws.onText("U,1,1,|||UPDATE")
        ws.onText("U,1,2,|||UPDATE")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                U,1,2,c|d|item2|ADD
                control\r
                LS_reqId=3&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=item2&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                SUBOK,3,1,2
                CS,1,1
                control\r
                LS_reqId=4&LS_subId=2&LS_op=delete&LS_ack=false
                U,1,1,|||UPDATE
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                U,1,2,|||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onCS i1 1
                onU 2
                onU 3
                """, self.subDelegate.trace)
            
            XCTAssertEqual(4, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d","key":"item2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"item2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"item2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"item2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("item2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("item2", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["command":"UPDATE"], u.changedFields)
            XCTAssertEqual([4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"item2","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"item2",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("item2", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("item2", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_UNSUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f3", "f4"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        XCTAssertEqual(.s4, state(client, subId: 1, itemPos: 1, keyName: "item1"))
        ws.onText("SUBOK,2,1,2")
        XCTAssertEqual(.s4, state(client, subId: 2))
        ws.onText("UNSUB,2")
        ws.onText("U,1,1,|||DELETE")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f3%20f4&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                UNSUB,2
                U,1,1,|||DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("ADD", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":nil,"f2":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"item1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"item1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND2Level_OV1Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("OV,1,1,5")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                OV,1,1,5
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onOV i1 1 5
                """, self.subDelegate.trace)
            
            XCTAssertEqual(0, self.subDelegate.updates.count)
        }
    }
    
    func testCOMMAND2Level_OV2Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.commandSecondLevelDataAdapter = "adapter2"
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        XCTAssertEqual(3, sub.keyPosition)
        XCTAssertEqual(4, sub.commandPosition)
        XCTAssertEqual(2, sub.nItems)
        XCTAssertEqual(4, sub.nFields)
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("U,2,1,c|d")
        ws.onText("OV,2,1,5")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,2,1,2
                U,2,1,c|d
                OV,2,1,5
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onOV2Level item1 5
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
        }
    }
    
    func testCOMMAND2Level_CONF() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("CONF,1,111,filtered")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                CONF,1,111,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF2Level() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,2,111,filtered")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,2,111,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_eq() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,111,filtered")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,111,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_lt() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,110,filtered")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,110,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_gt() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,112,filtered")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,112,filtered
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                onCONF 112.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF_Changed() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        sub.requestedMaxFrequency = .limited(456)
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                control\r
                LS_reqId=3&LS_subId=2&LS_op=reconf&LS_requested_max_frequency=456.0
                control\r
                LS_reqId=4&LS_subId=1&LS_op=reconf&LS_requested_max_frequency=456.0
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_DEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,unlimited,filtered")
        client.callbackQueue.async {
            self.ws.onText("U,1,1,a|b|item1|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,unlimited,filtered
                U,1,1,a|b|item1|DELETE
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                onCONF unlimited
                onU 1
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_DEL_lt() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,unlimited,filtered")
        ws.onText("CONF,2,111,filtered")
        client.callbackQueue.async {
            self.ws.onText("U,1,1,a|b|item1|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,unlimited,filtered
                CONF,2,111,filtered
                U,1,1,a|b|item1|DELETE
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF unlimited
                onU 1
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_UNSUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,unlimited,filtered")
        ws.onText("UNSUB,2")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,unlimited,filtered
                UNSUB,2
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                onCONF unlimited
                onCONF 111.0 updates/sec
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF1And2Level_CS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,1,111,filtered")
        ws.onText("CONF,2,unlimited,filtered")
        client.callbackQueue.async {
            self.ws.onText("CS,1,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,1,111,filtered
                CONF,2,unlimited,filtered
                CS,1,1
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF 111.0 updates/sec
                onCONF unlimited
                onCONF 111.0 updates/sec
                onCS i1 1
                """, self.subDelegate.trace)
        }
    }
    
    func testCOMMAND2Level_CONF2Level_DEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedMaxFrequency = .limited(123)
        sub.commandSecondLevelFields = ["f5", "f6"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("CONF,2,unlimited,filtered")
        client.callbackQueue.async {
            self.ws.onText("U,1,1,a|b|item1|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,a|b|item1|ADD
                control\r
                LS_reqId=2&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_snapshot=true&LS_requested_max_frequency=123.0&LS_ack=false
                SUBOK,2,1,2
                CONF,2,unlimited,filtered
                U,1,1,a|b|item1|DELETE
                control\r
                LS_reqId=3&LS_subId=2&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCONF unlimited
                onU 1
                onCONF nil
                """, self.subDelegate.trace)
        }
    }
}
