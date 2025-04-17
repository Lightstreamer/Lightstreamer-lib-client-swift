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

class TestSubDelegate: SubscriptionDelegate {
    var trace = ""
    var updates = [ItemUpdate]()
    var onItemUpdate: ((ItemUpdate) -> Void)?
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func subscription(_ subscription: Subscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {
        addTrace("onCS \(itemName ?? "nil") \(itemPos)")
    }
    
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forCommandSecondLevelItemWithKey key: String) {
        addTrace("onOV2Level \(key) \(lostUpdates)")
    }
    
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String) {
        addTrace("onError2Level \(key) \(code) \(message ?? "")")
    }
    
    func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {
        addTrace("onEOS \(itemName ?? "nil") \(itemPos)")
    }
    
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        addTrace("onOV \(itemName ?? "nil") \(itemPos) \(lostUpdates)")
    }
    
    func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
        addTrace("onU \(updates.count)")
        updates.append(itemUpdate)
        onItemUpdate?(itemUpdate)
    }
    
    func subscriptionDidRemoveDelegate(_ subscription: Subscription) {
    }
    
    func subscriptionDidAddDelegate(_ subscription: Subscription) {
    }
    
    func subscriptionDidSubscribe(_ subscription: Subscription) {
        addTrace("onSUB")
    }
    
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?) {
        addTrace("onError \(code) \(message ?? "")")
    }
    
    func subscriptionDidUnsubscribe(_ subscription: Subscription) {
        addTrace("onUNSUB")
    }
    
    func subscription(_ subscription: Subscription, didReceiveRealFrequency frequency: RealMaxFrequency?) {
        switch frequency {
        case .some(let f):
            addTrace("onCONF \(f)")
        case .none:
            addTrace("onCONF nil")
        }
        
    }
}

final class UpdateTests: BaseTestCase {
    
    func testDecodingAlgorithm() {
        XCTAssertEqual(3, try! parseUpdate("U,3,1,abc").subId)
        XCTAssertEqual(1, try! parseUpdate("U,3,1,abc").itemIdx)
        
        XCTAssertEqual([1:.changed("abc")], try! parseUpdate("U,3,1,abc").values)
        XCTAssertEqual([1:.changed("😀")], try! parseUpdate("U,3,1,😀").values)
        XCTAssertEqual([1:.changed("baràè%#$^")], try! parseUpdate("U,3,1,bar%c3%a0%C3%A8%25%23%24%5E").values)

        XCTAssertEqual([
            1 : .changed("20:00:33"),
            2 : .changed("3.04"),
            3 : .changed("0.0"),
            4 : .changed("2.41"),
            5 : .changed("3.67"),
            6 : .changed("3.03"),
            7 : .changed("3.04"),
            8 : .changed(nil),
            9 : .changed(nil),
            10 : .changed(""),
        ], try! parseUpdate("U,3,1,20:00:33|3.04|0.0|2.41|3.67|3.03|3.04|#|#|$").values)
        
        XCTAssertEqual([
            1 : .changed("20:00:54"),
            2 : .changed("3.07"),
            3 : .changed("0.98"),
            4 : .unchanged,
            5 : .unchanged,
            6 : .changed("3.06"),
            7 : .changed("3.07"),
            8 : .unchanged,
            9 : .unchanged,
            10 : .changed("Suspended"),
        ], try! parseUpdate("U,3,1,20:00:54|3.07|0.98|||3.06|3.07|||Suspended").values)
        
        XCTAssertEqual([
            1 : .changed("20:04:16"),
            2 : .changed("3.02"),
            3 : .changed("-0.65"),
            4 : .unchanged,
            5 : .unchanged,
            6 : .changed("3.01"),
            7 : .changed("3.02"),
            8 : .unchanged,
            9 : .unchanged,
            10 : .changed(""),
        ], try! parseUpdate("U,3,1,20:04:16|3.02|-0.65|||3.01|3.02|||$").values)
        
        XCTAssertEqual([
            1 : .changed("20:06:10"),
            2 : .changed("3.05"),
            3 : .changed("0.32"),
            4 : .unchanged,
            5 : .unchanged,
            6 : .unchanged,
            7 : .unchanged,
            8 : .unchanged,
            9 : .unchanged,
            10 : .unchanged,
        ], try! parseUpdate("U,3,1,20:06:10|3.05|0.32|^7").values)
        
        XCTAssertEqual([
            1 : .changed("20:06:49"),
            2 : .changed("3.08"),
            3 : .changed("1.31"),
            4 : .unchanged,
            5 : .unchanged,
            6 : .changed("3.08"),
            7 : .changed("3.09"),
            8 : .unchanged,
            9 : .unchanged,
            10 : .unchanged,
        ], try! parseUpdate("U,3,1,20:06:49|3.08|1.31|||3.08|3.09|||").values)
    }
    
    func testNil() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, items: ["i1", "i2"], fields: ["f1", "f2", "f3", "f4"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,4")
        ws.onText("U,1,1,#|#|$|z")
        ws.onText("U,1,1,|n|#|#")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=i1%20i2&LS_schema=f1%20f2%20f3%20f4&LS_ack=false
                SUBOK,1,2,4
                U,1,1,#|#|$|z
                U,1,1,|n|#|#
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
            XCTAssertEqual(["f1":nil,"f2":nil,"f3":"","f4":"z"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,3:"",4:"z"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"f3":"","f4":"z"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"",4:"z"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("", u.value(withFieldPos: 3))
            XCTAssertEqual("z", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("", u.value(withFieldName: "f3"))
            XCTAssertEqual("z", u.value(withFieldName: "f4"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f3"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f4"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"n","f3":nil,"f4":nil], u.changedFields)
            XCTAssertEqual([2:"n",3:nil,4:nil], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":"n","f3":nil,"f4":nil], u.fields)
            XCTAssertEqual([1:nil,2:"n",3:nil,4:nil], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual("n", u.value(withFieldPos: 2))
            XCTAssertEqual(nil, u.value(withFieldPos: 3))
            XCTAssertEqual(nil, u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual("n", u.value(withFieldName: "f2"))
            XCTAssertEqual(nil, u.value(withFieldName: "f3"))
            XCTAssertEqual(nil, u.value(withFieldName: "f4"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f3"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f4"))
        }
    }
    
    func testRAW() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=i1%20i2&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                U,1,1,A|
                U,1,2,|D
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
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldName: "f2"))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldName: "f2"))
        }
    }
    
    func testMERGE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                U,1,1,A|
                U,1,2,|D
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
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldName: "f2"))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldName: "f2"))
        }
    }
    
    func testMERGE_NoSnapshot() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=false&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                U,1,1,A|
                U,1,2,|D
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
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testDISTINCT() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("EOS,1,1")
        ws.onText("EOS,1,2")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                EOS,1,1
                EOS,1,2
                U,1,1,A|
                U,1,2,|D
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onEOS i1 1
                onEOS i2 2
                onU 2
                onU 3
                """, self.subDelegate.trace)
            
            XCTAssertEqual(4, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemPos(1, fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemPos(1, fieldName: "f2"))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldPos: 1))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldPos: 2))
            XCTAssertEqual("A", sub.valueWithItemName("i1", fieldName: "f1"))
            XCTAssertEqual("b", sub.valueWithItemName("i1", fieldName: "f2"))
        }
    }
    
    func testDISTINCT_Snapshot() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.requestedSnapshot = .length(33)
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("EOS,1,1")
        ws.onText("EOS,1,2")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=33&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                EOS,1,1
                EOS,1,2
                U,1,1,A|
                U,1,2,|D
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onEOS i1 1
                onEOS i2 2
                onU 2
                onU 3
                """, self.subDelegate.trace)
            
            XCTAssertEqual(4, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testDISTINCT_NoSnapshot() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=false&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                U,1,1,A|
                U,1,2,|D
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
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testDISTINCT_ClearSnapshot() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        ws.onText("U,1,2,c|d")
        ws.onText("EOS,1,1")
        ws.onText("EOS,1,2")
        ws.onText("U,1,1,A|")
        ws.onText("U,1,2,|D")
        ws.onText("CS,1,1")
        ws.onText("U,1,1,A|B")
        ws.onText("U,1,2,C|")
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                U,1,2,c|d
                EOS,1,1
                EOS,1,2
                U,1,1,A|
                U,1,2,|D
                CS,1,1
                U,1,1,A|B
                U,1,2,C|
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onEOS i1 1
                onEOS i2 2
                onU 2
                onU 3
                onCS i1 1
                onU 4
                onU 5
                """, self.subDelegate.trace)
            
            XCTAssertEqual(6, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[1]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[2]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"A"], u.changedFields)
            XCTAssertEqual([1:"A"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"b"], u.fields)
            XCTAssertEqual([1:"A",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"D"], u.changedFields)
            XCTAssertEqual([2:"D"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"D"], u.fields)
            XCTAssertEqual([1:"c",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[4]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f2":"B"], u.changedFields)
            XCTAssertEqual([2:"B"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"B"], u.fields)
            XCTAssertEqual([1:"A",2:"B"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            
            u = self.subDelegate.updates[5]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"C"], u.changedFields)
            XCTAssertEqual([1:"C"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"C","f2":"D"], u.fields)
            XCTAssertEqual([1:"C",2:"D"], u.fieldsByPositions)
            XCTAssertEqual("C", u.value(withFieldPos: 1))
            XCTAssertEqual("D", u.value(withFieldPos: 2))
            XCTAssertEqual("C", u.value(withFieldName: "f1"))
            XCTAssertEqual("D", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testCOMMAND_ADD() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,a|b|k1|ADD")
        ws.onText("U,1,2,c|d|k2|ADD")
        ws.onText("U,1,1,|B|k3|")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
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
                U,1,1,a|b|k1|ADD
                U,1,2,c|d|k2|ADD
                U,1,1,|B|k3|
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
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("k2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":"a","f2":"B","key":"k3","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"B",3:"k3",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"B","key":"k3","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"B",3:"k3",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("k3", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("k3", u.value(withFieldName: "key"))
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
            XCTAssertEqual("B", sub.valueWithItemPos(1, fieldPos: 2))
            XCTAssertEqual("a", sub.valueWithItemPos(1, fieldName: "f1"))
            XCTAssertEqual("B", sub.valueWithItemPos(1, fieldName: "f2"))
            XCTAssertEqual("a", sub.valueWithItemName("i1", fieldPos: 1))
            XCTAssertEqual("B", sub.valueWithItemName("i1", fieldPos: 2))
            XCTAssertEqual("a", sub.valueWithItemName("i1", fieldName: "f1"))
            XCTAssertEqual("B", sub.valueWithItemName("i1", fieldName: "f2"))
            
            XCTAssertEqual("a", sub.commandValueWithItemPos(1, key: "k3", fieldPos: 1))
            XCTAssertEqual("B", sub.commandValueWithItemPos(1, key: "k3", fieldPos: 2))
            XCTAssertEqual("a", sub.commandValueWithItemPos(1, key: "k3", fieldName: "f1"))
            XCTAssertEqual("B", sub.commandValueWithItemPos(1, key: "k3", fieldName: "f2"))
            XCTAssertEqual("a", sub.commandValueWithItemName("i1", key: "k3", fieldPos: 1))
            XCTAssertEqual("B", sub.commandValueWithItemName("i1", key: "k3", fieldPos: 2))
            XCTAssertEqual("a", sub.commandValueWithItemName("i1", key: "k3", fieldName: "f1"))
            XCTAssertEqual("B", sub.commandValueWithItemName("i1", key: "k3", fieldName: "f2"))
        }
    }
    
    func testCOMMAND_UPDATE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,a|b|k1|ADD")
        ws.onText("U,1,1,c||k2|")
        ws.onText("U,1,1,a|B|k1|UPDATE")
        
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
                U,1,1,a|b|k1|ADD
                U,1,1,c||k2|
                U,1,1,a|B|k1|UPDATE
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
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":"c","f2":"b","key":"k2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"b",3:"k2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"b","key":"k2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"b",3:"k2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f2":"B","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([2:"B",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"B","key":"k1","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"a",2:"B",3:"k1",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND_DELETE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,a|b|k1|ADD")
        ws.onText("U,1,1,c|d|k2|")
        ws.onText("U,1,1,x||k1|DELETE")
        ws.onText("U,1,1,c|D|k2|UPDATE")
        
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
                U,1,1,a|b|k1|ADD
                U,1,1,c|d|k2|
                U,1,1,x||k1|DELETE
                U,1,1,c|D|k2|UPDATE
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
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("k2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":nil,"f2":nil,"command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"k1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"k1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
    
    func testCOMMAND_EarlyDELETE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,x|y|k1|DELETE")
        
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
                U,1,1,x|y|k1|DELETE
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
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"k1","command":"DELETE"], u.changedFields)
            XCTAssertEqual([1:nil,2:nil,3:"k1",4:"DELETE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":nil,"f2":nil,"key":"k1","command":"DELETE"], u.fields)
            XCTAssertEqual([1:nil,2:nil,3:"k1",4:"DELETE"], u.fieldsByPositions)
            XCTAssertEqual(nil, u.value(withFieldPos: 1))
            XCTAssertEqual(nil, u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("DELETE", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldName: "f1"))
            XCTAssertEqual(nil, u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
    
    func testCOMMAND_EOS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,a|b|k1|ADD")
        ws.onText("U,1,2,c|d|k2|ADD")
        ws.onText("EOS,1,1")
        ws.onText("EOS,1,2")
        ws.onText("U,1,1,|B||UPDATE")
        ws.onText("U,1,2,C|||UPDATE")
        
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
                U,1,1,a|b|k1|ADD
                U,1,2,c|d|k2|ADD
                EOS,1,1
                EOS,1,2
                U,1,1,|B||UPDATE
                U,1,2,C|||UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onEOS i1 1
                onEOS i2 2
                onU 2
                onU 3
                """, self.subDelegate.trace)
            
            XCTAssertEqual(4, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"k2","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"k2",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("k2", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f2":"B","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([2:"B",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"B","key":"k1","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"a",2:"B",3:"k1",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
            
            u = self.subDelegate.updates[3]
            XCTAssertEqual("i2", u.itemName)
            XCTAssertEqual(2, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"C","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([1:"C",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"C","f2":"d","key":"k2","command":"UPDATE"], u.fields)
            XCTAssertEqual([1:"C",2:"d",3:"k2",4:"UPDATE"], u.fieldsByPositions)
            XCTAssertEqual("C", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("k2", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("C", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(false, u.isValueChanged(withFieldPos: 3))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 4))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "f2"))
            XCTAssertEqual(false, u.isValueChanged(withFieldName: "key"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "command"))
        }
    }
    
    func testCOMMAND_CS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
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
        ws.onText("U,1,1,a|b|k1|ADD")
        ws.onText("CS,1,1")
        ws.onText("U,1,1,|||")
        
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
                U,1,1,a|b|k1|ADD
                CS,1,1
                U,1,1,|||
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onCS i1 1
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
    
    func testRAW_DisconnectAndReconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .RAW, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        client.disconnect()
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,c|d")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=i1%20i2&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=3&LS_op=add&LS_subId=1&LS_mode=RAW&LS_group=i1%20i2&LS_schema=f1%20f2&LS_ack=false
                SUBOK,1,2,2
                U,1,1,c|d
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onUNSUB
                onSUB
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))

            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testMERGE_DisconnectAndReconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .MERGE, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        client.disconnect()
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,c|d")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=3&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=true&LS_ack=false
                SUBOK,1,2,2
                U,1,1,c|d
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onUNSUB
                onSUB
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))

            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testDISTINCT_DisconnectAndReconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .DISTINCT, items: ["i1", "i2"], fields: ["f1", "f2"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,a|b")
        client.disconnect()
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,2,2")
        ws.onText("U,1,1,c|d")
        XCTAssertEqual(1, client.subscriptions.count)
        XCTAssertIdentical(sub, client.subscriptions[0])
        
        asyncAssert {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=false&LS_ack=false
                SUBOK,1,2,2
                U,1,1,a|b
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=3&LS_op=add&LS_subId=1&LS_mode=DISTINCT&LS_group=i1%20i2&LS_schema=f1%20f2&LS_snapshot=false&LS_ack=false
                SUBOK,1,2,2
                U,1,1,c|d
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onUNSUB
                onSUB
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b"], u.fields)
            XCTAssertEqual([1:"a",2:"b"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))

            u = self.subDelegate.updates[1]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"c","f2":"d"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d"], u.fields)
            XCTAssertEqual([1:"c",2:"d"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 1))
            XCTAssertEqual(true, u.isValueChanged(withFieldPos: 2))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f1"))
            XCTAssertEqual(true, u.isValueChanged(withFieldName: "f2"))
        }
    }
    
    func testCOMMAND_DisconnectAndConnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1", "i2"], fields: ["f1", "f2", "key", "command"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,a|b|k1|UPDATE")
        client.disconnect()
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,2,4,3,4")
        ws.onText("U,1,1,c|d|k1|UPDATE")
        
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
                U,1,1,a|b|k1|UPDATE
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=3&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,c|d|k1|UPDATE
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onUNSUB
                onSUB
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(false, u.isSnapshot)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"a","f2":"b","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"a",2:"b",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("a", u.value(withFieldPos: 1))
            XCTAssertEqual("b", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("a", u.value(withFieldName: "f1"))
            XCTAssertEqual("b", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
            XCTAssertEqual(["f1":"c","f2":"d","key":"k1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"c",2:"d",3:"k1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"c","f2":"d","key":"k1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"c",2:"d",3:"k1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("c", u.value(withFieldPos: 1))
            XCTAssertEqual("d", u.value(withFieldPos: 2))
            XCTAssertEqual("k1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual("c", u.value(withFieldName: "f1"))
            XCTAssertEqual("d", u.value(withFieldName: "f2"))
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
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
    
    func testCOMMAND2Level_ConnectAndDisconnect() {
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
        ws.onText("U,1,1,a|b|item1|ADD")
        ws.onText("SUBOK,2,1,2")
        ws.onText("U,2,1,c|d")
        
        async(after: 0.2) {
            self.client.disconnect()
            
            self.client.connect()
            self.ws.onOpen()
            self.ws.onText("WSOK")
            self.ws.onText("CONOK,sid,70000,5000,*")
            self.ws.onText("SUBCMD,1,2,4,3,4")
            self.ws.onText("U,1,1,A|B|item1|ADD")
            self.ws.onText("SUBOK,3,1,2")
            self.ws.onText("U,3,1,C|D")
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
                control\r
                LS_reqId=3&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=4&LS_op=add&LS_subId=1&LS_mode=COMMAND&LS_group=i1%20i2&LS_schema=f1%20f2%20key%20command&LS_snapshot=false&LS_ack=false
                SUBCMD,1,2,4,3,4
                U,1,1,A|B|item1|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=item1&LS_schema=f5%20f6&LS_data_adapter=adapter2&LS_snapshot=true&LS_ack=false
                SUBOK,3,1,2
                U,3,1,C|D
                """, self.io.trace)
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onUNSUB
                onSUB
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
            XCTAssertEqual(["f1":"A","f2":"B","key":"item1","command":"ADD"], u.changedFields)
            XCTAssertEqual([1:"A",2:"B",3:"item1",4:"ADD"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"B","key":"item1","command":"ADD"], u.fields)
            XCTAssertEqual([1:"A",2:"B",3:"item1",4:"ADD"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("ADD", u.value(withFieldPos: 4))
            XCTAssertEqual(nil, u.value(withFieldPos: 5))
            XCTAssertEqual(nil, u.value(withFieldPos: 6))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
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

            u = self.subDelegate.updates[3]
            XCTAssertEqual("i1", u.itemName)
            XCTAssertEqual(1, u.itemPos)
            XCTAssertEqual(true, u.isSnapshot)
            XCTAssertEqual(["f5":"C","f6":"D","command":"UPDATE"], u.changedFields)
            XCTAssertEqual([5:"C",6:"D",4:"UPDATE"], u.changedFieldsByPositions)
            XCTAssertEqual(["f1":"A","f2":"B","key":"item1","command":"UPDATE","f5":"C","f6":"D"], u.fields)
            XCTAssertEqual([1:"A",2:"B",3:"item1",4:"UPDATE",5:"C",6:"D"], u.fieldsByPositions)
            XCTAssertEqual("A", u.value(withFieldPos: 1))
            XCTAssertEqual("B", u.value(withFieldPos: 2))
            XCTAssertEqual("item1", u.value(withFieldPos: 3))
            XCTAssertEqual("UPDATE", u.value(withFieldPos: 4))
            XCTAssertEqual("C", u.value(withFieldPos: 5))
            XCTAssertEqual("D", u.value(withFieldPos: 6))
            XCTAssertEqual("A", u.value(withFieldName: "f1"))
            XCTAssertEqual("B", u.value(withFieldName: "f2"))
            XCTAssertEqual("item1", u.value(withFieldName: "key"))
            XCTAssertEqual("UPDATE", u.value(withFieldName: "command"))
            XCTAssertEqual("C", u.value(withFieldName: "f5"))
            XCTAssertEqual("D", u.value(withFieldName: "f6"))
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
        }
    }
}
