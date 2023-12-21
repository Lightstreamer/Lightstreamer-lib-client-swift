import Foundation
import XCTest
@testable import LightstreamerClient

class TestMpnSubDelegate: MPNSubscriptionDelegate {
    var trace = ""
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func mpnSubscriptionDidAddDelegate(_ subscription: MPNSubscription) {}
    func mpnSubscriptionDidRemoveDelegate(_ subscription: MPNSubscription) {}
    
    func mpnSubscriptionDidSubscribe(_ subscription: MPNSubscription) {
        addTrace("mpn.onSubscription")
    }
    
    func mpnSubscriptionDidUnsubscribe(_ subscription: MPNSubscription) {
        addTrace("mpn.onUnsubscription")
    }
    
    func mpnSubscription(_ subscription: MPNSubscription, didFailSubscriptionWithErrorCode code: Int, message: String?) {
        addTrace("mpn.onSubscriptionError \(code) \(message ?? "")")
    }
    
    func mpnSubscription(_ subscription: MPNSubscription, didFailUnsubscriptionWithErrorCode code: Int, message: String?) {
        addTrace("mpn.onUnsubscriptionError \(code) \(message ?? "")")
    }
    
    func mpnSubscriptionDidTrigger(_ subscription: MPNSubscription) {
        addTrace("mpn.onTrigger")
    }
    
    func mpnSubscription(_ subscription: MPNSubscription, didChangeStatus status: MPNSubscription.Status, timestamp: Int64) {
        addTrace("mpn.onStatusChange \(status) \(timestamp)")
    }
    
    func mpnSubscription(_ subscription: MPNSubscription, didChangeProperty property: String) {
        addTrace("mpn.onPropertyChange \(property)")
    }
    
    func mpnSubscription(_ subscription: MPNSubscription, didFailModificationWithErrorCode code: Int, message: String?, property: String) {
        addTrace("mpn.onModificationError \(code) \(message ?? "") \(property)")
    }
}

final class MpnSubscriptionTests: BaseTestCase {
    let preamble = """
        ws.init http://server/lightstreamer
        wsok
        create_session\r
        LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
        WSOK
        CONOK,sid,70000,5000,*
        control\r
        LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
        MPNREG,devid,adapter
        control\r
        LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
        control\r
        LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
        
        """
    
    func simulateCreation() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
    }
    
    override func setUpWithError() throws {
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
    }
    
    func testSnapshot_EarlyDeletion() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,2,1,SUB-sub3|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(0, self.client.MPNSubscriptions.count)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                EOS,2,1
                U,2,1,SUB-sub3|DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_NotActive() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")

        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=activate&LS_subId=1&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_NotActive_Unsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        XCTAssertEqual(.s41, client.mpnSubscriptionManagers[0].s_m)
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.unsubscribeMPN(sub)

        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange UNKNOWN 0
                mpn.onSubscriptionError 55 The request was discarded because the operation could not be completed
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_NotActive_Abort() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        XCTAssertEqual(.s41, client.mpnSubscriptionManagers[0].s_m)
        
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        client.disconnect()

        asyncAssert(after: 0.5) {
            XCTAssertEqual("""
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_cid=\(LS_TEST_CID)&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange UNKNOWN 0
                mpn.onSubscriptionError 55 The request was discarded because the operation could not be completed
                """, self.mpnSubDelegate.trace)
        }
    }
   
    func testSubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("REQERR,4,-5,error")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                REQERR,4,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange UNKNOWN 0
                mpn.onSubscriptionError -5 error
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("REQOK,4")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s43, self.client.mpnSubscriptionManagers[0].s_m)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                REQOK,4
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_REQOK_MPNREG() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("REQOK,4")
        ws.onText("MPNOK,3,sub3")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                REQOK,4
                MPNOK,3,sub3
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_MPNREG() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testActive() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual(nil, sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.notificationFormat)
            XCTAssertEqual(nil, sub.triggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual(nil, sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(nil, sub.requestedBufferSize)
            XCTAssertEqual(nil, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testTriggered() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual("trg", sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#")
        ws.onText("U,4,1,TRIGGERED|110||||||||")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.TRIGGERED, sub.status)
            XCTAssertEqual(110, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.notificationFormat)
            XCTAssertEqual("trg", sub.triggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual(nil, sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(nil, sub.requestedBufferSize)
            XCTAssertEqual(nil, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#
                U,4,1,TRIGGERED|110||||||||
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange trigger
                mpn.onStatusChange TRIGGERED 110
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testTriggered_ActiveAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual("trg", sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#")
        ws.onText("U,4,1,TRIGGERED|110||||||||")
        ws.onText("U,4,1,ACTIVE|120||||||||")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(120, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.notificationFormat)
            XCTAssertEqual("trg", sub.triggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual(nil, sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(nil, sub.requestedBufferSize)
            XCTAssertEqual(nil, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#
                U,4,1,TRIGGERED|110||||||||
                U,4,1,ACTIVE|120||||||||
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange trigger
                mpn.onStatusChange TRIGGERED 110
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onStatusChange SUBSCRIBED 120
                mpn.onPropertyChange status_timestamp
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testStatus() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual("trg", sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#")
        ws.onText("U,4,1,|110||||||||")
        ws.onText("U,4,1,TRIGGERED|120||||||||")
        ws.onText("U,4,1,|130||||||||")
        ws.onText("U,4,1,ACTIVE|140||||||||")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(140, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.notificationFormat)
            XCTAssertEqual("trg", sub.triggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual(nil, sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(nil, sub.requestedBufferSize)
            XCTAssertEqual(nil, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|#|MERGE|#|#
                U,4,1,|110||||||||
                U,4,1,TRIGGERED|120||||||||
                U,4,1,|130||||||||
                U,4,1,ACTIVE|140||||||||
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange trigger
                mpn.onPropertyChange status_timestamp
                mpn.onStatusChange TRIGGERED 120
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange status_timestamp
                mpn.onStatusChange SUBSCRIBED 140
                mpn.onPropertyChange status_timestamp
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testOnPropertyChange() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual("trg", sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|format|trigger|item|field|adapter|DISTINCT|unlimited|unlimited")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("format", sub.actualNotificationFormat)
            XCTAssertEqual("trigger", sub.actualTriggerExpression)
            XCTAssertEqual("item", sub.itemGroup)
            XCTAssertEqual("field", sub.fieldSchema)
            XCTAssertEqual("adapter", sub.dataAdapter)
            XCTAssertEqual(.DISTINCT, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|format|trigger|item|field|adapter|DISTINCT|unlimited|unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange mode
                mpn.onPropertyChange adapter
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange trigger
                mpn.onPropertyChange requested_buffer_size
                mpn.onPropertyChange requested_max_frequency
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testOnPropertyChange2() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual(.UNKNOWN, sub.status)
        XCTAssertEqual(0, sub.statusTimestamp)
        XCTAssertEqual("fmt", sub.notificationFormat)
        XCTAssertEqual("trg", sub.triggerExpression)
        XCTAssertEqual(nil, sub.itemGroup)
        XCTAssertEqual(nil, sub.fieldSchema)
        XCTAssertEqual(nil, sub.dataAdapter)
        XCTAssertEqual(.MERGE, sub.mode)
        XCTAssertEqual(nil, sub.requestedBufferSize)
        XCTAssertEqual(nil, sub.requestedMaxFrequency)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|format|trigger|item|field|adapter|DISTINCT|123|45.6")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("format", sub.actualNotificationFormat)
            XCTAssertEqual("trigger", sub.actualTriggerExpression)
            XCTAssertEqual("item", sub.itemGroup)
            XCTAssertEqual("field", sub.fieldSchema)
            XCTAssertEqual("adapter", sub.dataAdapter)
            XCTAssertEqual(.DISTINCT, sub.mode)
            XCTAssertEqual(.limited(123), sub.requestedBufferSize)
            XCTAssertEqual(.limited(45.6), sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|format|trigger|item|field|adapter|DISTINCT|123|45.6
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange mode
                mpn.onPropertyChange adapter
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange trigger
                mpn.onPropertyChange requested_buffer_size
                mpn.onPropertyChange requested_max_frequency
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("U,2,1,SUB-sub3|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                U,2,1,SUB-sub3|DELETE
                control\r
                LS_reqId=7&LS_subId=4&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe_MPNDEL() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("MPNDEL,sub3")
            self.ws.onText("U,2,1,SUB-sub3|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                MPNDEL,sub3
                U,2,1,SUB-sub3|DELETE
                control\r
                LS_reqId=7&LS_subId=4&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe_DELETE() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("U,2,1,SUB-sub3|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                U,2,1,SUB-sub3|DELETE
                control\r
                LS_reqId=7&LS_subId=4&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("REQOK,6")
            self.ws.onText("U,2,1,SUB-sub3|DELETE")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                REQOK,6
                U,2,1,SUB-sub3|DELETE
                control\r
                LS_reqId=7&LS_subId=4&LS_op=delete&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("REQERR,6,-5,error")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                REQERR,6,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onUnsubscriptionError -5 error
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribe_REQERR_UnsubscribeAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        client.callbackQueue.async {
            self.client.unsubscribeMPN(sub)
            self.ws.onText("REQERR,6,-5,error")
            self.client.unsubscribeMPN(sub)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                control\r
                LS_reqId=6&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                REQERR,6,-5,error
                control\r
                LS_reqId=7&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onUnsubscriptionError -5 error
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testAbort() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,5,1,2,1,2")
        ws.onText("U,5,1,SUB-sub3|ADD")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=6&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=7&LS_op=add&LS_subId=5&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBCMD,5,1,2,1,2
                U,5,1,SUB-sub3|ADD
                control\r
                LS_reqId=8&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testAbort_Orphan() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,5,1,2,1,2")
        ws.onText("EOS,5,1")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=6&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=7&LS_op=add&LS_subId=5&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBCMD,5,1,2,1,2
                EOS,5,1
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testAbort_Unsubscription() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        client.unsubscribeMPN(sub)
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,5,1,2,1,2")
        ws.onText("U,5,1,SUB-sub3|ADD")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s80, self.client.mpnSubscriptionManagers[0].s_ab)
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                control\r
                LS_reqId=5&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=6&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=7&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=8&LS_op=add&LS_subId=5&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBCMD,5,1,2,1,2
                U,5,1,SUB-sub3|ADD
                control\r
                LS_reqId=9&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onUnsubscriptionError 54 The request was aborted because the operation could not be completed
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testAbort_AbortUnsubscription() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        client.unsubscribeMPN(sub)
        ws.onText("MPNDEL,sub3")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,5,1,2,1,2")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(0, self.client.mpnSubscriptionManagers.count)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                control\r
                LS_reqId=5&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionId=sub3
                MPNDEL,sub3
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=\(LS_TEST_CID)&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=6&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=7&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=8&LS_op=add&LS_subId=5&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBCMD,5,1,2,1,2
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeFormat() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "new fmt"
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s74, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("new fmt", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=new%20fmt
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeFormat_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "new fmt"
        ws.onText("REQOK,5")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("new fmt", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=new%20fmt
                REQOK,5
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeFormat_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "new fmt"
        ws.onText("REQERR,5,-5,error")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("new fmt", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=new%20fmt
                REQERR,5,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onModificationError -5 error notification_format
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testMultipleChangeFormat_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "fmt2"
        sub.notificationFormat = "fmt3"
        ws.onText("REQOK,5")
        ws.onText("REQOK,6")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("fmt3", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=fmt2
                REQOK,5
                control\r
                LS_reqId=6&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=fmt3
                REQOK,6
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testMultipleChangeFormat_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "fmt2"
        sub.notificationFormat = "fmt3"
        ws.onText("REQERR,5,-5,error")
        ws.onText("REQOK,6")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("fmt3", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=fmt2
                REQERR,5,-5,error
                control\r
                LS_reqId=6&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=fmt3
                REQOK,6
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeFormat_Abort() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("fmt", sub.notificationFormat)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.notificationFormat = "new fmt"
        ws.onError()
        XCTAssertEqual(.s20, self.client.mpnSubscriptionManagers[0].s_fu)

        asyncAssert(after: 0.5) {
            XCTAssertEqual(nil, sub.actualNotificationFormat)
            XCTAssertEqual("new fmt", sub.notificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_notificationFormat=new%20fmt
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onModificationError 54 The request was aborted because the operation could not be completed notification_format
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeTrigger() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "new trg"
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s73, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("new trg", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=new%20trg
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeTrigger_Remove() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = nil
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s73, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual(nil, sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeTrigger_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "new trg"
        ws.onText("REQOK,5")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("new trg", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=new%20trg
                REQOK,5
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeTrigger_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "new trg"
        ws.onText("REQERR,5,-5,error")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("new trg", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=new%20trg
                REQERR,5,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onModificationError -5 error trigger
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testMultipleChangeTrigger_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "trg2"
        sub.triggerExpression = "trg3"
        ws.onText("REQOK,5")
        ws.onText("REQOK,6")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("trg3", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=trg2
                REQOK,5
                control\r
                LS_reqId=6&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=trg3
                REQOK,6
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testMultipleChangeTrigger_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "trg2"
        sub.triggerExpression = "trg3"
        ws.onText("REQERR,5,-5,error")
        ws.onText("REQOK,6")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s71, self.client.mpnSubscriptionManagers[0].s_ct)
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("trg3", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=trg2
                REQERR,5,-5,error
                control\r
                LS_reqId=6&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=trg3
                REQOK,6
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testChangeTrigger_Abort() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.triggerExpression = "trg"
        sub.addDelegate(mpnSubDelegate)
        XCTAssertEqual("trg", sub.triggerExpression)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        sub.triggerExpression = "new trg"
        ws.onError()
        XCTAssertEqual(.s30, self.client.mpnSubscriptionManagers[0].s_tu)

        asyncAssert(after: 0.5) {
            XCTAssertEqual(nil, sub.actualTriggerExpression)
            XCTAssertEqual("new trg", sub.triggerExpression)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_trigger=trg
                MPNOK,3,sub3
                control\r
                LS_reqId=5&LS_op=pn_reconf&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_subscriptionId=sub3&PN_trigger=new%20trg
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onModificationError 54 The request was aborted because the operation could not be completed trigger
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_NoCoalesce() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,6,1,ACTIVE|100|fmt2|#|i1|f1|#|MERGE|#|#")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("fmt1", sub1.actualNotificationFormat)
            XCTAssertEqual("fmt2", sub2.actualNotificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,6,1,10
                U,6,1,ACTIVE|100|fmt2|#|i1|f1|#|MERGE|#|#
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_Coalesce() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: true)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual("fmt1", sub1.actualNotificationFormat)
            XCTAssertEqual("fmt1", sub2.actualNotificationFormat)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_coalescing=true
                MPNOK,3,sub3
                MPNOK,4,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe_Coalesce_Delete() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: true)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub3|DELETE")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(nil, sub1.actualNotificationFormat)
            XCTAssertEqual(nil, sub2.actualNotificationFormat)
            XCTAssertEqual(0, self.client.mpnSubscriptionManagers.count)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt&PN_coalescing=true
                MPNOK,3,sub3
                MPNOK,4,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub3|DELETE
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange UNKNOWN 0
                mpn.onUnsubscription
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(.ALL)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid
                REQOK,8
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter_nil() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(nil)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid
                REQOK,8
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter_SUB() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(.SUBSCRIBED)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=ACTIVE
                REQOK,8
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter_TRG() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(.TRIGGERED)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=TRIGGERED
                REQOK,8
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(.ALL)
            self.ws.onText("REQERR,8,-5,error")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid
                REQERR,8,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testUnsubscribeFilter_Multiple() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#")
        
        async(after: 0.5) {
            self.client.unsubscribeMultipleMPN(.SUBSCRIBED)
            self.client.unsubscribeMultipleMPN(.TRIGGERED)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s432, self.client.s_mpn.ft)
            self.ws.onText("REQOK,9")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                SUBOK,6,1,10
                U,5,1,ACTIVE|100|fmt|#|i1|f1|#|MERGE|#|#
                U,6,1,TRIGGERED|100|fmt|#|i1|f1|#|MERGE|#|#
                control\r
                LS_reqId=8&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=ACTIVE
                REQOK,8
                control\r
                LS_reqId=9&LS_op=deactivate&PN_deviceId=devid&PN_subscriptionStatus=TRIGGERED
                REQOK,9
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_EmptySnapshot() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(0, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(0, self.client.MPNSubscriptions.count)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                EOS,2,1
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,3,1,10")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(["sub3"], self.client.mpn_snapshotSet)
            XCTAssertEqual(0, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(0, self.client.MPNSubscriptions.count)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                EOS,2,1
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add2() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|")
        ws.onText("SUBOK,3,1,10")
        ws.onText("SUBOK,4,1,10")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(["sub3", "sub4"], self.client.mpn_snapshotSet)
            XCTAssertEqual(0, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(0, self.client.MPNSubscriptions.count)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                SUBOK,4,1,10
                EOS,2,1
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_AddAndRemoveBeforeEOS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,3,1,10")
        ws.onText("U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(1, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(1, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                EOS,2,1
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add2AndRemoveFirstBeforeEOS() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,3,1,10")
        ws.onText("U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(["sub4"], self.client.mpn_snapshotSet)
            XCTAssertEqual(1, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(1, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                EOS,2,1
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add2AndRemoveFirst_AfterEOSRemoveSecond() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,3,1,10")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(2, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(2, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            let sub2 = self.client.MPNSubscriptions[1]
            XCTAssertEqual(.SUBSCRIBED, sub2.status)
            XCTAssertEqual(100, sub2.statusTimestamp)
            XCTAssertEqual("fmt", sub2.actualNotificationFormat)
            XCTAssertEqual("trg", sub2.actualTriggerExpression)
            XCTAssertEqual("i1", sub2.itemGroup)
            XCTAssertEqual("f1", sub2.fieldSchema)
            XCTAssertEqual("adt", sub2.dataAdapter)
            XCTAssertEqual(.MERGE, sub2.mode)
            XCTAssertEqual(.unlimited, sub2.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub2.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                SUBOK,4,1,10
                U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                EOS,2,1
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add1_AfterEOSRemoveFirstAndThenAnother() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,3,1,10")
        
        async(after: 0.2) {
            XCTAssertEqual(["sub3"], self.client.mpn_snapshotSet)
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,2,1,SUB-sub3|UPDATE")
            self.ws.onText("U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
            self.ws.onText("U,2,1,SUB-sub4|ADD")
            self.ws.onText("SUBOK,4,1,10")
            self.ws.onText("U,2,1,SUB-sub4|UPDATE")
            self.ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(2, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(2, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            let sub2 = self.client.MPNSubscriptions[1]
            XCTAssertEqual(.SUBSCRIBED, sub2.status)
            XCTAssertEqual(100, sub2.statusTimestamp)
            XCTAssertEqual("fmt", sub2.actualNotificationFormat)
            XCTAssertEqual("trg", sub2.actualTriggerExpression)
            XCTAssertEqual("i1", sub2.itemGroup)
            XCTAssertEqual("f1", sub2.fieldSchema)
            XCTAssertEqual("adt", sub2.dataAdapter)
            XCTAssertEqual(.MERGE, sub2.mode)
            XCTAssertEqual(.unlimited, sub2.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub2.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                EOS,2,1
                U,2,1,SUB-sub3|UPDATE
                U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,2,1,SUB-sub4|UPDATE
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add1_AfterEOSRemoveAnotherAndThenFirst() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,3,1,10")
        
        async(after: 0.2) {
            XCTAssertEqual(["sub3"], self.client.mpn_snapshotSet)
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,2,1,SUB-sub4|ADD")
            self.ws.onText("SUBOK,4,1,10")
            self.ws.onText("U,2,1,SUB-sub4|UPDATE")
            self.ws.onText("U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
            self.ws.onText("U,2,1,SUB-sub3|UPDATE")
            self.ws.onText("U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(2, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(2, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            let sub2 = self.client.MPNSubscriptions[1]
            XCTAssertEqual(.SUBSCRIBED, sub2.status)
            XCTAssertEqual(100, sub2.statusTimestamp)
            XCTAssertEqual("fmt", sub2.actualNotificationFormat)
            XCTAssertEqual("trg", sub2.actualTriggerExpression)
            XCTAssertEqual("i1", sub2.itemGroup)
            XCTAssertEqual("f1", sub2.fieldSchema)
            XCTAssertEqual("adt", sub2.dataAdapter)
            XCTAssertEqual(.MERGE, sub2.mode)
            XCTAssertEqual(.unlimited, sub2.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub2.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                EOS,2,1
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,2,1,SUB-sub4|UPDATE
                U,4,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                U,2,1,SUB-sub3|UPDATE
                U,3,1,ACTIVE|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_Add1_AfterEOSRemoveAnother() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,3,1,10")
        
        async(after: 0.2) {
            XCTAssertEqual(["sub3"], self.client.mpn_snapshotSet)
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,2,1,SUB-sub4|ADD")
            self.ws.onText("SUBOK,4,1,10")
            self.ws.onText("U,2,1,SUB-sub4|UPDATE")
            self.ws.onText("U,4,1,TRIGGERED|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(["sub3"], self.client.mpn_snapshotSet)
            XCTAssertEqual(1, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(1, self.client.MPNSubscriptions.count)
            let sub = self.client.MPNSubscriptions[0]
            XCTAssertEqual(.TRIGGERED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt", sub.actualNotificationFormat)
            XCTAssertEqual("trg", sub.actualTriggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual("adt", sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(.unlimited, sub.requestedBufferSize)
            XCTAssertEqual(.unlimited, sub.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,3,1,10
                EOS,2,1
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,2,1,SUB-sub4|UPDATE
                U,4,1,TRIGGERED|100|fmt|trg|i1|f1|adt|MERGE|unlimited|unlimited
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSnapshot_ServerAndUserSubscriptions() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,4,1,10")
        ws.onText("U,4,1,ACTIVE|100|fmt1-sub3|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,2,1,SUB-sub4|ADD")
        async(after: 0.2) {
            self.ws.onText("EOS,2,1")
            self.ws.onText("U,4,1,ACTIVE|100|fmt2-sub3|#|i1|f1|#|MERGE|#|#")
            self.ws.onText("SUBOK,5,1,10")
            self.ws.onText("U,5,1,ACTIVE|100|fmt2-sub4|#|i1|f1|#|MERGE|#|#")
        }
        
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.SUBSCRIBED, sub.status)
            XCTAssertEqual(100, sub.statusTimestamp)
            XCTAssertEqual("fmt2-sub3", sub.actualNotificationFormat)
            XCTAssertEqual(nil, sub.triggerExpression)
            XCTAssertEqual("i1", sub.itemGroup)
            XCTAssertEqual("f1", sub.fieldSchema)
            XCTAssertEqual(nil, sub.dataAdapter)
            XCTAssertEqual(.MERGE, sub.mode)
            XCTAssertEqual(nil, sub.requestedBufferSize)
            XCTAssertEqual(nil, sub.requestedMaxFrequency)
            
            XCTAssertEqual([], self.client.mpn_snapshotSet)
            XCTAssertEqual(2, self.client.mpnSubscriptionManagers.count)
            XCTAssertEqual(2, self.client.MPNSubscriptions.count)
            let sub4 = self.client.MPNSubscriptions.filter({ $0.actualNotificationFormat == "fmt2-sub4" }).first!
            XCTAssertEqual(.SUBSCRIBED, sub4.status)
            XCTAssertEqual(100, sub4.statusTimestamp)
            XCTAssertEqual("fmt2-sub4", sub4.actualNotificationFormat)
            XCTAssertEqual(nil, sub4.triggerExpression)
            XCTAssertEqual("i1", sub4.itemGroup)
            XCTAssertEqual("f1", sub4.fieldSchema)
            XCTAssertEqual(nil, sub4.dataAdapter)
            XCTAssertEqual(.MERGE, sub4.mode)
            XCTAssertEqual(nil, sub4.requestedBufferSize)
            XCTAssertEqual(nil, sub4.requestedMaxFrequency)
            
            let sub3 = self.client.MPNSubscriptions.filter({ $0.actualNotificationFormat == "fmt2-sub3" }).first!
            XCTAssertEqual(.SUBSCRIBED, sub3.status)
            XCTAssertEqual(100, sub3.statusTimestamp)
            XCTAssertEqual("fmt2-sub3", sub3.actualNotificationFormat)
            XCTAssertEqual(nil, sub3.triggerExpression)
            XCTAssertEqual("i1", sub3.itemGroup)
            XCTAssertEqual("f1", sub3.fieldSchema)
            XCTAssertEqual(nil, sub3.dataAdapter)
            XCTAssertEqual(.MERGE, sub3.mode)
            XCTAssertEqual(nil, sub3.requestedBufferSize)
            XCTAssertEqual(nil, sub3.requestedMaxFrequency)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=5&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,4,1,10
                U,4,1,ACTIVE|100|fmt1-sub3|#|i1|f1|#|MERGE|#|#
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                EOS,2,1
                U,4,1,ACTIVE|100|fmt2-sub3|#|i1|f1|#|MERGE|#|#
                SUBOK,5,1,10
                U,5,1,ACTIVE|100|fmt2-sub4|#|i1|f1|#|MERGE|#|#
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                mpn.onPropertyChange notification_format
                """, self.mpnSubDelegate.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testGetSubscriptions() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let mpnSubDelegate1 = TestMpnSubDelegate()
        let sub1 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub1.notificationFormat = "fmt"
        sub1.addDelegate(mpnSubDelegate1)
        client.subscribeMPN(sub1, coalescing: false)
        let mpnSubDelegate2 = TestMpnSubDelegate()
        let sub2 = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub2.notificationFormat = "fmt"
        sub2.addDelegate(mpnSubDelegate2)
        client.subscribeMPN(sub2, coalescing: false)
        ws.onText("MPNOK,3,sub3")
        ws.onText("MPNOK,4,sub4")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,SUB-sub3|ADD")
        ws.onText("SUBOK,5,1,10")
        ws.onText("U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#")
        ws.onText("U,2,1,SUB-sub4|ADD")
        ws.onText("SUBOK,6,1,10")
        ws.onText("U,6,1,TRIGGERED|100|fmt2|#|i1|f1|#|MERGE|#|#")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(2, self.client.MPNSubscriptions.count)
            
            XCTAssertEqual(2, self.client.filterMPNSubscriptions(nil).count)
            XCTAssertEqual(2, self.client.filterMPNSubscriptions(.ALL).count)
            XCTAssertEqual(1, self.client.filterMPNSubscriptions(.SUBSCRIBED).count)
            XCTAssertEqual(1, self.client.filterMPNSubscriptions(.TRIGGERED).count)
            
            var subs: [MPNSubscription]!
            subs = self.client.MPNSubscriptions
            XCTAssertEqual(["sub3"], subs.filter { $0.status == .SUBSCRIBED }.map { $0.subscriptionId })
            XCTAssertEqual(["sub4"], subs.filter { $0.status == .TRIGGERED }.map { $0.subscriptionId })
            
            subs = self.client.filterMPNSubscriptions(nil)
            XCTAssertEqual(["sub3"], subs.filter { $0.status == .SUBSCRIBED }.map { $0.subscriptionId })
            XCTAssertEqual(["sub4"], subs.filter { $0.status == .TRIGGERED }.map { $0.subscriptionId })
            
            subs = self.client.filterMPNSubscriptions(.ALL)
            XCTAssertEqual(["sub3"], subs.filter { $0.status == .SUBSCRIBED }.map { $0.subscriptionId })
            XCTAssertEqual(["sub4"], subs.filter { $0.status == .TRIGGERED }.map { $0.subscriptionId })
            
            XCTAssertEqual("sub3", self.client.filterMPNSubscriptions(.SUBSCRIBED)[0].subscriptionId)
            XCTAssertEqual(.SUBSCRIBED, self.client.filterMPNSubscriptions(.SUBSCRIBED)[0].status)
            
            XCTAssertEqual("sub4", self.client.filterMPNSubscriptions(.TRIGGERED)[0].subscriptionId)
            XCTAssertEqual(.TRIGGERED, self.client.filterMPNSubscriptions(.TRIGGERED)[0].status)
            
            XCTAssertEqual("sub3", self.client.findMPNSubscription("sub3")!.subscriptionId)
            XCTAssertEqual(.SUBSCRIBED, self.client.findMPNSubscription("sub3")!.status)
            
            XCTAssertEqual("sub4", self.client.findMPNSubscription("sub4")!.subscriptionId)
            XCTAssertEqual(.TRIGGERED, self.client.findMPNSubscription("sub4")!.status)
            
            XCTAssertEqual(nil, self.client.findMPNSubscription("sub5")?.subscriptionId)
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=4&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                control\r
                LS_reqId=5&LS_op=activate&LS_subId=4&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                MPNOK,3,sub3
                MPNOK,4,sub4
                SUBCMD,2,1,2,1,2
                U,2,1,SUB-sub3|ADD
                control\r
                LS_reqId=6&LS_op=add&LS_subId=5&LS_mode=MERGE&LS_group=SUB-sub3&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,5,1,10
                U,5,1,ACTIVE|100|fmt1|#|i1|f1|#|MERGE|#|#
                U,2,1,SUB-sub4|ADD
                control\r
                LS_reqId=7&LS_op=add&LS_subId=6&LS_mode=MERGE&LS_group=SUB-sub4&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,6,1,10
                U,6,1,TRIGGERED|100|fmt2|#|i1|f1|#|MERGE|#|#
                """, self.io.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate1.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange SUBSCRIBED 0
                mpn.onSubscription
                mpn.onStatusChange TRIGGERED 100
                mpn.onTrigger
                mpn.onPropertyChange status_timestamp
                mpn.onPropertyChange group
                mpn.onPropertyChange schema
                mpn.onPropertyChange notification_format
                """, mpnSubDelegate2.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onSubscriptionsUpdated
                dev.onSubscriptionsUpdated
                """, self.mpnDevDelegate.trace)
        }
    }
}
