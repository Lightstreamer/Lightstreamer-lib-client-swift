import Foundation
import XCTest
@testable import LightstreamerClient

class MpnWsPollingTests: BaseTestCase {
    let preamble = """
        http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
        LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_cause=api
        CONOK,sid,70000,5000,*
        LOOP,0
        http.dispose
        ws.init http://server/lightstreamer
        wsok
        WSOK
        bind_session\r
        LS_session=sid&LS_polling=true&LS_polling_millis=0&LS_idle_millis=19000&LS_cause=http.loop
        CONOK,sid,70000,5000,*

        """
    
    func simulateCreation() {
        http.onText("CONOK,sid,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
    }
    
    override func newClient(_ url: String, adapterSet: String? = nil) -> LightstreamerClient {
        let client = super.newClient(url, adapterSet: adapterSet)
        client.connectionOptions.forcedTransport = .WS_POLLING
        return client
    }
    
    override func setUpWithError() throws {
        UserDefaults.standard.set("testApp", forKey: "LS_appID")
        UserDefaults.standard.removeObject(forKey: "LS_deviceToken")
    }
    
    func testRegister() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testMPNREG() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testDeviceActive() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,ACTIVE|100")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRefreshToken() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        let dev2 = MPNDevice(deviceToken: "tok2")
        dev2.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev2)
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok2&LS_cause=refresh.token
                MPNREG,devid,adapter
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onError()
        scheduler.fireRetryTimeout()
        http.onText("CONOK,sid2,70000,5000,*")
        http.onText("LOOP,0")
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                ws.dispose
                http.send http://server/lightstreamer/create_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cid=\(LS_CID)&LS_old_session=sid&LS_cause=ws.error
                CONOK,sid2,70000,5000,*
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                WSOK
                bind_session\r
                LS_session=sid2&LS_polling=true&LS_polling_millis=0&LS_idle_millis=5000&LS_cause=http.loop
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                CONOK,sid2,70000,5000,*
                MPNREG,devid,adapter
                control\r
                LS_reqId=5&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=6&LS_op=add&LS_subId=4&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testResetBadge() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,ACTIVE|100")
        client.resetMPNBadge()
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                control\r
                LS_reqId=4&LS_op=reset_badge&PN_deviceId=devid
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        sub.addDelegate(mpnSubDelegate)
        client.subscribeMPN(sub, coalescing: false)
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
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
    
    func testUnsubscribe() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
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
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
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
    
    func testChangeFormat() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
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
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
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
    
    func testChangeTrigger() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
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
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
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
    
    func testUnsubscribeFilter() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
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
        
        async(after: 0.2) {
            self.client.unsubscribeMultipleMPN(.ALL)
            self.ws.onText("REQOK,8")
            XCTAssertEqual(.s431, self.client.s_mpn.ft)
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
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
}
