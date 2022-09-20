import Foundation
import XCTest
@testable import LightstreamerClient

class TestMpnDeviceDelegate: MPNDeviceDelegate {
    var trace = ""
    
    func addTrace(_ s: String) {
        trace += trace.isEmpty ? s : "\n\(s)"
    }
    
    func mpnDeviceDidAddDelegate(_ device: MPNDevice) {}
    
    func mpnDeviceDidRemoveDelegate(_ device: MPNDevice) {}
    
    func mpnDeviceDidRegister(_ device: MPNDevice) {
        addTrace("dev.onRegister")
    }
    
    func mpnDeviceDidSuspend(_ device: MPNDevice) {
        addTrace("dev.onSuspend")
    }
    
    func mpnDeviceDidResume(_ device: MPNDevice) {
        addTrace("dev.onResume")
    }
    
    func mpnDevice(_ device: MPNDevice, didFailRegistrationWithErrorCode code: Int, message: String?) {
        addTrace("dev.onError \(code) \(message ?? "")")
    }
    
    func mpnDevice(_ device: MPNDevice, didChangeStatus status: MPNDevice.Status, timestamp: Int64) {
        addTrace("dev.onStatus \(status.rawValue) \(timestamp)")
    }
    
    func mpnDeviceDidUpdateSubscriptions(_ device: MPNDevice) {
        addTrace("dev.onSubscriptionsUpdated")
    }
    
    func mpnDeviceDidResetBadge(_ device: MPNDevice) {
        addTrace("dev.onResetBadge")
    }
    
    func mpnDevice(_ device: MPNDevice, didFailBadgeResetWithErrorCode code: Int, message: String?) {
        addTrace("dev.onResetBadgerError \(code) \(message ?? "")")
    }
}

final class MpnTests: BaseTestCase {
    let preamble = """
        ws.init http://server/lightstreamer
        wsok
        create_session\r
        LS_cid=cid&LS_send_sync=false&LS_cause=api
        WSOK
        CONOK,sid,70000,5000,*
        
        """
    
    func simulateCreation() {
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid,70000,5000,*")
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
    
    func testRegister_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(.s401, client.s_mpn.m)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQERR,1,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegister_REQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        ws.onText("REQOK,1")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQOK,1
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegister_Retry_In403() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        ws.onError()
        XCTAssertEqual(.s403, client.s_mpn.m)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegister_Retry_In404() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        ws.onText("REQOK,1")
        ws.onError()
        XCTAssertEqual(.s403, client.s_mpn.m)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQOK,1
                ws.dispose
                """, self.io.trace)
            XCTAssertEqual("""
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegister_REQERR_RegisterAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        ws.onText("REQERR,1,-5,error")
        XCTAssertEqual(.s401, client.s_mpn.m)
        let dev2 = MPNDevice(deviceToken: "tok2")
        client.register(forMPN: dev2)
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQERR,1,-5,error
                control\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok2
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegisterTwice_REQERR() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        let dev2 = MPNDevice(deviceToken: "tok2")
        client.register(forMPN: dev2)
        ws.onText("REQERR,1,-5,error")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQERR,1,-5,error
                control\r
                LS_reqId=2&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok2
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRegister_Disconnect_Reconnect() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        
        client.disconnect()
        XCTAssertEqual(.s401, client.s_mpn.m)
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                control\r
                LS_reqId=2&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=3&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
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
    
    func testMPNREG_AfterREQOK() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("REQOK,1")
        ws.onText("MPNREG,devid,adapter")
        
        asyncAssert {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                REQOK,1
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
    
    func testDeviceSuspended() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,SUSPENDED|100")
        
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
                U,1,1,SUSPENDED|100
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus SUSPENDED 100
                dev.onSuspend
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testDeviceResumed() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,SUSPENDED|100")
        ws.onText("U,1,1,ACTIVE|110")
        
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
                U,1,1,SUSPENDED|100
                U,1,1,ACTIVE|110
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus SUSPENDED 100
                dev.onSuspend
                dev.onStatus REGISTERED 110
                dev.onResume
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
    
    func testRefreshToken_REQOK_MPNREG() {
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
        ws.onText("REQOK,4")
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
                REQOK,4
                MPNREG,devid,adapter
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRefreshToken_REQERR() {
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
        ws.onText("REQERR,4,-5,error")
        
        asyncAssert {
            XCTAssertEqual(.s401, self.client.s_mpn.m)
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
                REQERR,4,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRefreshTokenTwice_REQERR() {
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
        let dev3 = MPNDevice(deviceToken: "tok3")
        dev3.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev3)
        ws.onText("REQERR,4,-5,error")
        
        asyncAssert {
            XCTAssertEqual(.s453, self.client.s_mpn.tk)
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
                REQERR,4,-5,error
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok3&LS_cause=refresh.token
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRefreshToken_InvalidDeviceId() {
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
        ws.onText("MPNREG,devid2,adapter")
        
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
                MPNREG,devid2,adapter
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 DeviceId or Adapter Name has unexpectedly been changed
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRefreshToken_InvalidAdapter() {
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
        ws.onText("MPNREG,devid,adapter2")
        
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
                MPNREG,devid,adapter2
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 DeviceId or Adapter Name has unexpectedly been changed
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testDeviceActive_Disconnect_Reconnect() {
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
        client.callbackQueue.async {
            self.client.disconnect()
            self.client.connect()
            self.ws.onOpen()
            self.ws.onText("WSOK")
            self.ws.onText("CONOK,sid2,70000,5000,*")
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
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                control\r
                LS_reqId=4&LS_op=destroy&LS_close_socket=true&LS_cause=api
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testDeviceItemSubscriptionError_RegisterAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("REQERR,2,-5,error")
        client.callbackQueue.async {
            self.client.register(forMPN: dev)
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
                REQERR,2,-5,error
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 MPN device activation can't be completed (62/1)
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testDeviceItemUnexpectedUnsubscription_RegisterAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("UNSUB,1")
        client.callbackQueue.async {
            self.client.register(forMPN: dev)
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
                SUBOK,1,1,2
                UNSUB,1
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 MPN device activation can't be completed (62/2)
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSUBSItemSubscriptionError_RegisterAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("REQERR,3,-5,error")
        client.callbackQueue.async {
            self.client.register(forMPN: dev)
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
                REQERR,3,-5,error
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 MPN device activation can't be completed (62/3)
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSUBSItemUnexpectedUnsubscription_RegisterAgain() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("UNSUB,2")
        client.callbackQueue.async {
            self.client.register(forMPN: dev)
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
                SUBCMD,2,1,2,1,2
                UNSUB,2
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 MPN device activation can't be completed (62/4)
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testSUBSItemUnexpected2LevelError_Ignored() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBCMD,2,1,2,1,2")
        ws.onText("U,2,1,sub1|ADD")
        ws.onText("REQERR,4,-5,error")
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                SUBCMD,2,1,2,1,2
                U,2,1,sub1|ADD
                control\r
                LS_reqId=4&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=sub1&LS_schema=status%20status_timestamp%20notification_format%20trigger%20group%20schema%20adapter%20mode%20requested_buffer_size%20requested_max_frequency&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                REQERR,4,-5,error
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
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
    
    func testRestoreToken_Retry() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onError()
        scheduler.fireRetryTimeout()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid3,70000,5000,*")
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid2&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid3,70000,5000,*
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=6&LS_op=add&LS_subId=3&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=7&LS_op=add&LS_subId=4&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken_REQERR() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onText("REQERR,4,-5,error")
        
        asyncAssert {
            XCTAssertEqual(.s401, self.client.s_mpn.m)
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                REQERR,4,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError -5 error
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken_REQOK() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onText("REQOK,4")
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                REQOK,4
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
    
    func testRestoreToken_DifferentDeviceId() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onText("MPNREG,devid2,adapter")
        
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid2,adapter
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 DeviceId or Adapter Name has unexpectedly been changed
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken_DifferentAdapter() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        ws.onText("MPNREG,devid,adapter2")
        
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter2
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onError 62 DeviceId or Adapter Name has unexpectedly been changed
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken_Disconnect() {
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
        client.disconnect()
        client.connect()
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        
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
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_send_sync=false&LS_cause=api
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus UNKNOWN 0
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testRestoreToken_REQERR_RegisterAgain() {
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
        ws.onOpen()
        ws.onText("WSOK")
        ws.onText("CONOK,sid2,70000,5000,*")
        client.register(forMPN: dev)
        
        asyncAssert(after: 0.5) {
            self.ws.onText("REQERR,4,-5,error")
            
            XCTAssertEqual(self.preamble + """
                control\r
                LS_reqId=1&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok
                MPNREG,devid,adapter
                control\r
                LS_reqId=2&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=3&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=4&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                REQERR,4,-5,error
                control\r
                LS_reqId=5&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                """, self.io.trace)
            XCTAssertEqual("""
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
    
    func testResetBadge_Early() {
        client = newClient("http://server")
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        client.resetMPNBadge()
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
                control\r
                LS_reqId=4&LS_op=reset_badge&PN_deviceId=devid
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testResetBadge_REQOK() {
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
        client.callbackQueue.async {
            self.ws.onText("REQOK,4")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s441, self.client.s_mpn.bg)
            
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
                REQOK,4
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testResetBadge_REQERR() {
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
        client.callbackQueue.async {
            self.ws.onText("REQERR,4,-5,error")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s441, self.client.s_mpn.bg)
            
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
                REQERR,4,-5,error
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onResetBadgerError -5 error
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testResetBadge_MPNZERO() {
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
        client.callbackQueue.async {
            self.ws.onText("REQOK,4")
            self.ws.onText("MPNZERO,devid")
        }
        
        asyncAssert(after: 0.5) {
            XCTAssertEqual(.s441, self.client.s_mpn.bg)
            
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
                REQOK,4
                MPNZERO,devid
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onResetBadge
                """, self.mpnDevDelegate.trace)
        }
    }
    
    func testPending_NoRecovery() {
        client = newClient("http://server")
        client.connectionOptions.sessionRecoveryTimeout = 0
        client.addDelegate(delegate)
        client.connect()
        
        simulateCreation()
        let dev = MPNDevice(deviceToken: "tok")
        dev.addDelegate(mpnDevDelegate)
        client.register(forMPN: dev)
        ws.onText("MPNREG,devid,adapter")
        ws.onText("SUBOK,1,1,2")
        ws.onText("U,1,1,ACTIVE|100")
        
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        let mpnSubDelegate = TestMpnSubDelegate()
        sub.addDelegate(mpnSubDelegate)
        
        async(after: 0.2) {
            self.client.resetMPNBadge()
            self.client.unsubscribeMultipleMPN(.ALL)
            self.client.subscribeMPN(sub, coalescing: false)
            self.ws.onError()
            self.scheduler.fireRetryTimeout()
            self.ws.onOpen()
            self.ws.onText("WSOK")
            self.ws.onText("CONOK,sid2,70000,5000,*")
            self.ws.onText("MPNREG,devid,adapter")
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
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                control\r
                LS_reqId=4&LS_op=reset_badge&PN_deviceId=devid
                control\r
                LS_reqId=5&LS_op=deactivate&PN_deviceId=devid
                control\r
                LS_reqId=6&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                ws.dispose
                ws.init http://server/lightstreamer
                wsok
                create_session\r
                LS_keepalive_millis=5000&LS_cid=cid&LS_old_session=sid&LS_send_sync=false&LS_cause=ws.error
                WSOK
                CONOK,sid2,70000,5000,*
                control\r
                LS_reqId=7&LS_op=register&PN_type=Apple&PN_appId=testApp&PN_deviceToken=tok&PN_newDeviceToken=tok&LS_cause=restore.token
                MPNREG,devid,adapter
                control\r
                LS_reqId=8&LS_op=add&LS_subId=4&LS_mode=MERGE&LS_group=DEV-devid&LS_schema=status%20status_timestamp&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=9&LS_op=add&LS_subId=5&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false
                control\r
                LS_reqId=10&LS_op=deactivate&PN_deviceId=devid
                control\r
                LS_reqId=11&LS_op=reset_badge&PN_deviceId=devid
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                mpn.onStatusChange UNKNOWN 0
                mpn.onSubscriptionError 54 The request was aborted because the operation could not be completed
                """, mpnSubDelegate.trace)
        }
    }
    
    func testPending_Recovery() {
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
        
        let sub = MPNSubscription(subscriptionMode: .MERGE, item: "i1", fields: ["f1"])
        sub.notificationFormat = "fmt"
        let mpnSubDelegate = TestMpnSubDelegate()
        sub.addDelegate(mpnSubDelegate)
        
        async(after: 0.2) {
            self.client.resetMPNBadge()
            self.client.unsubscribeMultipleMPN(.ALL)
            self.client.subscribeMPN(sub, coalescing: false)
            self.ws.onError()
            self.scheduler.fireRecoveryTimeout()
            self.http.onText("CONOK,sid,70000,5000,*")
            self.http.onText("PROG,3")
            self.http.onText("LOOP,0")
            self.ws.onOpen()
            self.ws.onText("WSOK")
            self.ws.onText("CONOK,sid,70000,5000,*")
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
                SUBOK,1,1,2
                U,1,1,ACTIVE|100
                control\r
                LS_reqId=4&LS_op=reset_badge&PN_deviceId=devid
                control\r
                LS_reqId=5&LS_op=deactivate&PN_deviceId=devid
                control\r
                LS_reqId=6&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt
                ws.dispose
                http.send http://server/lightstreamer/bind_session.txt?LS_protocol=\(TLCP_VERSION)
                LS_session=sid&LS_recovery_from=3&LS_polling=true&LS_polling_millis=0&LS_idle_millis=0&LS_cause=ws.error
                CONOK,sid,70000,5000,*
                PROG,3
                LOOP,0
                http.dispose
                ws.init http://server/lightstreamer
                wsok
                bind_session\r
                LS_session=sid&LS_keepalive_millis=5000&LS_send_sync=false&LS_cause=recovery.loop
                WSOK
                CONOK,sid,70000,5000,*
                control\r
                LS_reqId=7&LS_op=add&LS_subId=2&LS_mode=COMMAND&LS_group=SUBS-devid&LS_schema=key%20command&LS_data_adapter=adapter&LS_snapshot=true&LS_requested_max_frequency=unfiltered&LS_ack=false\r
                LS_reqId=8&LS_op=activate&LS_subId=3&LS_mode=MERGE&LS_group=i1&LS_schema=f1&PN_deviceId=devid&PN_notificationFormat=fmt\r
                LS_reqId=9&LS_op=deactivate&PN_deviceId=devid\r
                LS_reqId=10&LS_op=reset_badge&PN_deviceId=devid
                """, self.io.trace)
            XCTAssertEqual("""
                dev.onStatus REGISTERED 0
                dev.onRegister
                """, self.mpnDevDelegate.trace)
            XCTAssertEqual("""
                mpn.onStatusChange ACTIVE 0
                """, mpnSubDelegate.trace)
        }
    }
}
