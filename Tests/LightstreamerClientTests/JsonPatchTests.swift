import Foundation
import XCTest
@testable import LightstreamerClient

final class JsonPatchTests: BaseTestCase {
    
    class MySubDelegate: TestSubDelegate {
        override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
            addTrace("value \(update.value(withFieldPos: 1) ?? "null")")
            addTrace("patch \(update.valueAsJSONPatchIfAvailable(withFieldPos: 1) ?? "null")")
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
        class JsonPatchDelegate: TestDelegate {
            override func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status) {}
            override func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String) {
                addTrace("\(errorCode) - \(errorMessage)")
            }
        }
        
        client = newClient("http://server")
        let delegate = JsonPatchDelegate()
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
            XCTAssertEqual(expectedError, delegate.trace)
        }
    }
    
    func testRealServer() {
        client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .no
        sub.dataAdapter = "JSON_COUNT"
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        asyncAssert(after: 3) {
            let u = self.subDelegate.updates[1]
            let patch = try! newJson(u.valueAsJSONPatchIfAvailable(withFieldPos: 1)!) as! [[String:Any]]
            XCTAssertEqual("replace", patch[0]["op"] as! String)
            XCTAssertEqual("/value", patch[0]["path"] as! String)
            XCTAssertNotNil(patch[0]["value"])
            let value = try! newJson(u.value(withFieldPos: 1)!) as! [String:Int]
            XCTAssertNotNil(value["value"])
        }
    }
    
    func testRealServer_JsonAndTxt() {
        client = LightstreamerClient(serverAddress: "http://localtest.me:8080", adapterSet: "TEST")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedMaxFrequency = .unfiltered
        sub.requestedSnapshot = .no
        sub.dataAdapter = "JSON_DIFF_COUNT"
        sub.addDelegate(subDelegate)
        client.subscribe(sub)
        client.connect()
        
        asyncAssert(after: 3) {
            let updates = self.subDelegate.updates
            XCTAssertNil(updates[0].valueAsJSONPatchIfAvailable(withFieldPos: 1))
            XCTAssertNotNil(updates[1].valueAsJSONPatchIfAvailable(withFieldPos: 1))
            XCTAssertNil(updates[2].valueAsJSONPatchIfAvailable(withFieldPos: 1))
        }
    }
    
    func testPatches() {
        updateTemplate([#"{"baz":"qux","foo":"bar"}"#,
                        #"^P[{ "op": "replace", "path": "/baz", "value": "boo" }]"#,
                        #"^P[{ "op": "add", "path": "/hello", "value": ["world"] }]"#,
                        #"^P[{ "op": "remove", "path": "/foo" }]"#
                       ],
                       [#"value {"baz":"qux","foo":"bar"}"#,
                        #"patch null"#,
                        #"value {"baz":"boo","foo":"bar"}"#,
                        #"patch [{"op":"replace","path":"\/baz","value":"boo"}]"#,
                        #"value {"baz":"boo","foo":"bar","hello":["world"]}"#,
                        #"patch [{"op":"add","path":"\/hello","value":["world"]}]"#,
                        #"value {"baz":"boo","hello":["world"]}"#,
                        #"patch [{"op":"remove","path":"\/foo"}]"#
                       ])
    }
    
    func testMultiplePatches() {
        updateTemplate([#"{"baz":"qux","foo":"bar"}"#,
                        #"^P[{ "op": "replace", "path": "/baz", "value": "boo" },{ "op": "add", "path": "/hello", "value": ["world"] },{ "op": "remove", "path": "/foo" }]"#],
                       [#"value {"baz":"qux","foo":"bar"}"#,
                        #"patch null"#,
                        #"value {"baz":"boo","hello":["world"]}"#,
                        #"patch [{"op":"replace","path":"\/baz","value":"boo"},{"op":"add","path":"\/hello","value":["world"]},{"op":"remove","path":"\/foo"}]"#])
    }
    
    func testInvalidPatch() {
        errorTemplate([#"{}"#,#"^Pfoo"#],
                      "61 - The JSON Patch for the field 1 is not well-formed")
    }
    func testInvalidJson() {
        errorTemplate([#"foo"#,#"^P[]"#],
                      "61 - Cannot convert the field 1 to JSON")
    }
    func testInvalidApply() {
        errorTemplate([#"{}"#,#"^P[{ "op": "replace", "path": "/baz", "value": "boo" }]"#],
                      "61 - Cannot apply the JSON Patch to the field 1")
    }
    func testInvalidApply_Null() {
        errorTemplate(["#",#"^P[]"#],
                       "61 - Cannot apply the JSON patch to the field 1 because the field is null")
    }
    
    func testEmptyString() {
        updateTemplate(["$"],
                       ["value ", "patch null"])
    }
    
    func testFromInitEvtNull() {
        updateTemplate(["#"],
                       ["value null", "patch null"])
    }
    func testFromInitEvtString() {
        updateTemplate(["foo"],
                       ["value foo", "patch null"])
    }
    func testFromInitEvtPatch() {
        errorTemplate([#"^P[{"op":"add","path":"/foo","value":1}]"#],
                      "61 - Cannot set the field 1 because the first update is a JSONPatch")
    }
    func testFromInitEvtUnchanged() {
        errorTemplate([""],
                      "61 - Cannot set the field 1 because the first update is UNCHANGED")
    }
    
    func testFromStringEvtNull() {
        updateTemplate(["foo", "#"],
                       ["value foo", "patch null",
                        "value null", "patch null"])
    }
    func testFromStringEvtString() {
        updateTemplate(["foo", "bar"],
                       ["value foo", "patch null",
                        "value bar", "patch null"])
    }
    func testFromStringEvtPatch() {
        updateTemplate(["{}",
                        #"^P[{"op":"add","path":"\/foo","value":1}]"#],
                       [#"value {}"#,
                        #"patch null"#,
                        #"value {"foo":1}"#,
                        #"patch [{"op":"add","path":"\/foo","value":1}]"#])
    }
    func testFromStringEvtUnchanged() {
        updateTemplate(["foo", ""],
                       ["value foo", "patch null",
                        "value foo", "patch null"])
    }
    
    func testFromJsonEvtNull() {
        updateTemplate(["{}",
                        #"^P[{"op":"add","path":"\/foo","value":1}]"#,
                        "#"],
                       [#"value {}"#,
                        #"patch null"#,
                        #"value {"foo":1}"#,
                        #"patch [{"op":"add","path":"\/foo","value":1}]"#,
                        #"value null"#,
                        #"patch null"#])
    }
    func testFromJsonEvtString() {
        updateTemplate(["{}",
                        #"^P[{"op":"add","path":"\/foo","value":1}]"#,
                        #"foo"#],
                       [#"value {}"#,
                        #"patch null"#,
                        #"value {"foo":1}"#,
                        #"patch [{"op":"add","path":"\/foo","value":1}]"#,
                        #"value foo"#,
                        #"patch null"#])
    }
    func testFromJsonEvtPatch() {
        updateTemplate(["{}",
                        #"^P[{"op":"add","path":"\/foo","value":1}]"#,
                        #"^P[{"op":"add","path":"\/bar","value":2}]"#],
                       ["value {}",
                        #"patch null"#,
                        #"value {"foo":1}"#,
                        #"patch [{"op":"add","path":"\/foo","value":1}]"#,
                        #"value {"foo":1,"bar":2}"#,
                        #"patch [{"op":"add","path":"\/bar","value":2}]"#])
    }
    func testFromJsonEvtUnchanged() {
        updateTemplate(["{}",
                        #"^P[{"op":"add","path":"\/foo","value":1}]"#,
                        ""],
                       [#"value {}"#,
                        #"patch null"#,
                        #"value {"foo":1}"#,
                        #"patch [{"op":"add","path":"\/foo","value":1}]"#,
                        #"value {"foo":1}"#,
                        #"patch []"#])
    }
    
    func testFromNullEvtNull() {
        updateTemplate(["#", "#"],
                       ["value null", "patch null",
                        "value null", "patch null"])
    }
    func testFromNullEvtString() {
        updateTemplate(["#", "foo"],
                       ["value null", "patch null",
                        "value foo", "patch null"])
    }
    func testFromNullEvtPatch() {
        errorTemplate(["#", #"^P[{"op":"add","path":"/foo","value":1}]"#],
                      "61 - Cannot apply the JSON patch to the field 1 because the field is null")
    }
    func testFromNullEvtUnchanged() {
        updateTemplate(["#", ""],
                       ["value null", "patch null",
                        "value null", "patch null"])
    }
    
    func testIsChanged() {
        class JsonPatchDelegate: TestSubDelegate {
            override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
                addTrace("value \(update.value(withFieldPos: 1) ?? "null")")
                addTrace("changed \(update.isValueChanged(withFieldPos: 1))")
            }
        }
        
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        let mySubDelegate = JsonPatchDelegate()
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1," + "{}")
        ws.onText("U,1,1,")
        ws.onText("U,1,1," + #"^P[{"op":"add","path":"/foo","value":1}]"#)
        ws.onText("U,1,1," + "#")
        
        asyncAssert {
            XCTAssertEqual(["onSUB",
                            "value {}",
                            "changed true",
                            "value {}",
                            "changed false",
                            #"value {"foo":1}"#,
                            "changed true",
                            "value null",
                            "changed true"].joined(separator: "\n"),
                           mySubDelegate.trace)
        }
    }
    
    func testGetFields() {
        class JsonPatchDelegate: TestSubDelegate {
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
        let mySubDelegate = JsonPatchDelegate()
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1," + "{}")
        ws.onText("U,1,1,")
        ws.onText("U,1,1," + #"^P[{"op":"add","path":"/foo","value":1}]"#)
        ws.onText("U,1,1," + "#")
        
        asyncAssert {
            XCTAssertEqual(["onSUB",
                            "isChanged true value {}",
                            "fields: count {}",
                            "changed fields: count {}",
                            "isChanged false value {}",
                            "fields: count {}",
                            #"isChanged true value {"foo":1}"#,
                            #"fields: count {"foo":1}"#,
                            #"changed fields: count {"foo":1}"#,
                            "isChanged true value null",
                            "fields: count null",
                            "changed fields: count null"].joined(separator: "\n"),
                           mySubDelegate.trace)
        }
    }
    
    func testIsSnapshot() {
        class JsonPatchDelegate: TestSubDelegate {
            override func subscription(_ subscription: Subscription, didUpdateItem update: ItemUpdate) {
                addTrace("value \(update.value(withFieldPos: 1) ?? "null")")
                addTrace("snapshot \(update.isSnapshot)")
            }
        }
        
        client = newClient("http://server")
        let sub = Subscription(subscriptionMode: .MERGE, items: ["count"], fields: ["count"])
        sub.requestedSnapshot = .yes
        let mySubDelegate = JsonPatchDelegate()
        sub.addDelegate(mySubDelegate)
        client.subscribe(sub)
        client.connect()
        
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("SUBOK,1,1,1")
        ws.onText("U,1,1,foo")
        ws.onText("U,1,1,bar")
        
        asyncAssert {
            XCTAssertEqual(["onSUB",
                            "value foo",
                            "snapshot true",
                            "value bar",
                            "snapshot false"].joined(separator: "\n"),
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
        ws.onText(#"U,1,1,k1|ADD|{"x":1}"#)
        ws.onText(#"U,1,1,k2|ADD|^P[{ "op": "replace", "path": "/x", "value": 2 }]"#)
        
        asyncAssert {
            XCTAssertEqual("""
                onSUB
                onU 0
                onU 1
                """, self.subDelegate.trace)
            
            XCTAssertEqual(2, self.subDelegate.updates.count)
            
            var u = self.subDelegate.updates[0]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"{"x":1}"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[1]
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual(#"{"x":2}"#, u.value(withFieldName: "value"))
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
        ws.onText(#"U,1,1,k2|ADD|{"x":1}"#)
        ws.onText(#"U,1,1,k1|ADD|^P[{ "op": "replace", "path": "/x", "value": 2 }]"#)
        ws.onText(#"U,1,1,k2|UPDATE|^P[{ "op": "replace", "path": "/x", "value": 3 }]"#)
        
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
            XCTAssertEqual(#"{"x":1}"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[1]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"{"x":2}"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[2]
            XCTAssertEqual("k2", u.value(withFieldName: "key"))
            XCTAssertEqual(#"{"x":3}"#, u.value(withFieldName: "value"))
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
        ws.onText(#"U,2,1,{"x":1}"#)
        ws.onText(#"U,2,1,^P[{ "op": "replace", "path": "/x", "value": 2 }]"#)
        
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
            XCTAssertEqual(#"{"x":1}"#, u.value(withFieldName: "value"))
            XCTAssertEqual(nil, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            u = self.subDelegate.updates[2]
            XCTAssertEqual("k1", u.value(withFieldName: "key"))
            XCTAssertEqual(#"{"x":2}"#, u.value(withFieldName: "value"))
            XCTAssertEqual(#"[{"op":"replace","path":"\/x","value":2}]"#, u.valueAsJSONPatchIfAvailable(withFieldName: "value"))
            XCTAssertEqual(#"[{"op":"replace","path":"\/x","value":2}]"#, u.valueAsJSONPatchIfAvailable(withFieldPos: 3))
            
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
