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

final class DiffPatchTests: BaseTestCase {
    class MySubDelegate: TestSubDelegate {
        override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
            addTrace("\(update.value(withFieldPos: 1) ?? "null")")
        }
    }
    
    let mySubDelegate = MySubDelegate()
    
    func updateTemplate(_ updates: [String], _ outputs: [String]) {
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        for upd in updates {
            ws.onText("U,1,1," + upd)
        }
        
        asyncAssert {
            XCTAssertEqual("onSUB\n" + outputs.joined(separator: "\n"), self.mySubDelegate.trace)
        }
    }
    
    func errorTemplate(_ updates: [String], _ expectedError: String) {
        class MySubDelegate: TestDelegate {
            override func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {}
            override func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {
                addTrace("\(errorCode) - \(errorMessage)")
            }
        }
        
        client = newClient("http://server")
        let delegate = MySubDelegate()
        client.addDelegate(delegate)
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        for upd in updates {
            ws.onText("U,1,1," + upd)
        }
        
        asyncAssert {
            XCTAssertEqual(expectedError, String(delegate.trace.prefix(expectedError.count)))
        }
    }
    
    func testRealServer() {
        client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .no
        sub.dataAdapter = "DIFF_COUNT"
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        asyncAssert(after: 3) {
            let u = self.subDelegate.updates[1]
            XCTAssertNotNil(u.value(withFieldPos: 1)!.range(of: #"value=\d+"#, options: .regularExpression))
        }
    }
    
    func testMultiplePatches() {
        updateTemplate([
            "foobar",
            "^Tbdzapcd", // copy(1)add(3,zap)del(2)copy(3)
            "^Taabg", // copy(0)add(0)del(1)copy(6)
            "^Tddxyz", // copy(3)add(3,xyz)
        ], [
            "foobar",
            "fzapbar",
            "zapbar",
            "zapxyz",
        ])
    }
    
    func testPercentEncoding() {
        updateTemplate([
            "foo",
            "^Tdg%25%24%3D%2C%2B%7C", // copy(3)add(6,%$=,+|)
        ], [
            "foo",
            "foo%$=,+|",
        ])
    }
    
    func testApplyToEmptyString() {
        updateTemplate([
            "$",
            "^Tadfoo", // copy(0)add(3,foo)
        ], [
            "",
            "foo",
        ])
    }
    
    func testApplyToString() {
        updateTemplate([
            "foobar",
            "^Tbaeb", // copy(1)add(0)del(4)copy(1)
        ], [
            "foobar",
            "fr",
        ])
    }
    
    func testApplyToNull() {
        errorTemplate([
            "#",
            "^Tbaeb", // copy(1)add(0)del(4)copy(1)
        ], "61 - Cannot apply the TLCP-diff to the field 1 because the field is null")
    }
    
    func testApplyToJson() {
        errorTemplate([
            "{}",
            #"^P[{"op":"add","path":"/foo","value":1}]"#,
            "^Tbaeb", // copy(1)add(0)del(4)copy(1)
        ], "61 - Cannot apply the TLCP-diff to the field 1 because the field is JSON")
    }
    
    func testFirstUpdateIsDiffPatch() {
        errorTemplate([
            "^Tbaeb", // copy(1)add(0)del(4)copy(1)
        ], "61 - Cannot set the field 1 because the first update is a TLCP-diff")
    }
    
    func testBadDiff_OutOfRange() {
        errorTemplate([
            "foo",
            "^Tz", // copy(25)
        ], "61 - Bad TLCP-diff: Index out of range")
    }
    
    func testBadDiff_InvalidChar() {
        errorTemplate([
            "foo",
            "^T!",
        ], "61 - Bad TLCP-diff: the code point 33 is not in the range A-Z")
    }
    
    func testIsChanged() {
        class MySubDelegate: TestSubDelegate {
            override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
                addTrace("value \(update.value(withFieldPos: 1) ?? "null")")
                addTrace("changed \(update.isValueChanged(withFieldPos: 1))")
            }
        }
        
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        let mySubDelegate = MySubDelegate()
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1," + "foo")
        ws.onText("U,1,1,")
        ws.onText("U,1,1," + #"^Tc"#)
        ws.onText("U,1,1," + "#")
        
        asyncAssert {
            XCTAssertEqual(["onSUB",
                            "value foo",
                            "changed true",
                            "value foo",
                            "changed false",
                            #"value fo"#,
                            "changed true",
                            "value null",
                            "changed true"].joined(separator: "\n"),
                           mySubDelegate.trace)
        }
    }
    
    func testGetFields() {
        class MySubDelegate: TestSubDelegate {
            override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
                let value = update.value(withFieldPos: 1) ?? "null"
                let changed = update.isValueChanged(withFieldPos: 1)
                addTrace("isChanged " + String(changed) + " value " + value)
                for (name, val) in update.fields {
                    addTrace("fields: " + name + " " + (val ?? "null"))
                }
                for (name, val) in update.changedFields {
                    addTrace("changed fields: " + name + " " + (val ?? "null"))
                }
            }
        }
        
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        let mySubDelegate = MySubDelegate()
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1," + "foo")
        ws.onText("U,1,1,")
        ws.onText("U,1,1," + #"^Tc"#)
        ws.onText("U,1,1," + "#")
        
        asyncAssert {
            XCTAssertEqual(["onSUB",
                            "isChanged true value foo",
                            "fields: count foo",
                            "changed fields: count foo",
                            "isChanged false value foo",
                            "fields: count foo",
                            #"isChanged true value fo"#,
                            #"fields: count fo"#,
                            #"changed fields: count fo"#,
                            "isChanged true value null",
                            "fields: count null",
                            "changed fields: count null"].joined(separator: "\n"),
                           mySubDelegate.trace)
        }
    }
    
    func testCOMMAND_Case1() {
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1"], fields: ["key", "command", "value"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,3,1,2")
        ws.onText(#"U,1,1,k1|ADD|foo"#)
        ws.onText(#"U,1,1,k2|ADD|^Tc"#)
        
        asyncAssert {
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"foo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[1]
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual(#"fo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
        }
    }
    
    func testCOMMAND_Case2() {
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1"], fields: ["key", "command", "value"])
        sub.requestedSnapshot = .no
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,3,1,2")
        ws.onText(#"U,1,1,k2|ADD|foo"#)
        ws.onText(#"U,1,1,k1|ADD|^Tc"#)
        ws.onText(#"U,1,1,k2|UPDATE|^Tb"#)
        
        asyncAssert {
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onU 2
                """, self.subDelegate.trace)
            
            XCTAssertEqual(3, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual(#"foo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[1]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"fo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[2]
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual(#"f"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
        }
    }
    
    func testCOMMAND2Level() {
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .COMMAND, items: ["i1"], fields: ["key", "command"])
        sub.requestedSnapshot = .no
        sub.commandSecondLevelFields = ["value"]
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBCMD,1,1,2,1,2")
        ws.onText("U,1,1,k1|ADD")
        ws.onText("SUBOK,2,1,1")
        ws.onText(#"U,2,1,foo"#)
        ws.onText(#"U,2,1,^Tc"#)
        
        async(after: 0.5) {
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                onU 2
                """, self.subDelegate.trace)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(nil, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[1]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"foo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[2]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"fo"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            
            self.ws.onText("U,1,1,k1|DELETE")
            self.async(after: 0.5) {
                u = self.subDelegate.updates[3]
                XCTAssertEqual("k1", u.value(withFieldName: "key"))
                XCTAssertEqual("DELETE", u.value(withFieldName: "command"))
                XCTAssertEqual(nil, u.value(withFieldName: "value"))
                XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
                
                self.expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }
}
