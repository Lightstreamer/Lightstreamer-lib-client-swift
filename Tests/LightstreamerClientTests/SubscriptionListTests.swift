import XCTest
import LightstreamerClient

final class SubscriptionListTests: XCTestCase {
    func testListConstructorsAndDelayedConfiguration() {
        let single = Subscription(subscriptionMode: .MERGE, item: "group", fields: ["schema"])
        XCTAssertEqual(["group"], single.items)
        XCTAssertEqual(["schema"], single.fields)

        let sub = Subscription(subscriptionMode: .DISTINCT)
        XCTAssertNil(sub.items)
        XCTAssertNil(sub.fields)
        sub.items = ["i2", "i1"]
        sub.fields = ["f2", "f1"]
        XCTAssertEqual(["i2", "i1"], sub.items)
        XCTAssertEqual(["f2", "f1"], sub.fields)
        sub.items = nil
        sub.fields = nil
        XCTAssertNil(sub.items)
        XCTAssertNil(sub.fields)
        XCTAssertFalse(sub.isActive)
    }

    func testExplicitSecondLevelFieldsCanBeDisabled() {
        let sub = Subscription(subscriptionMode: .COMMAND, item: "item", fields: ["key", "command"])
        XCTAssertNil(sub.commandSecondLevelFields)
        sub.commandSecondLevelFields = ["f2", "f1"]
        XCTAssertEqual(["f2", "f1"], sub.commandSecondLevelFields)
        sub.commandSecondLevelFields = nil
        XCTAssertNil(sub.commandSecondLevelFields)
    }

    func testMPNConversionsAndCopiesPreserveExplicitLists() {
        for mode: Subscription.Mode in [.MERGE, .DISTINCT] {
            let sub = Subscription(subscriptionMode: mode, items: ["i2", "i1"], fields: ["f2", "f1"])
            sub.dataAdapter = "adapter"
            let mpn = MPNSubscription(subscription: sub)
            mpn.notificationFormat = "format"
            mpn.triggerExpression = "trigger"
            let copy = MPNSubscription(MPNSubscription: mpn)
            sub.items = nil
            sub.fields = nil
            mpn.items = ["changedItem"]
            mpn.fields = ["changedField"]
            XCTAssertEqual(mode.rawValue, copy.mode.rawValue)
            XCTAssertEqual(["i2", "i1"], copy.items)
            XCTAssertEqual(["f2", "f1"], copy.fields)
            XCTAssertEqual("adapter", copy.dataAdapter)
            XCTAssertEqual("format", copy.notificationFormat)
            XCTAssertEqual("trigger", copy.triggerExpression)
        }
    }

    func testUnconfiguredMPNListsRemainOptional() {
        let mpn = MPNSubscription(subscriptionMode: .MERGE)
        let copy = MPNSubscription(MPNSubscription: mpn)
        XCTAssertNil(copy.items)
        XCTAssertNil(copy.fields)
        copy.items = ["item"]
        copy.fields = ["field"]
        XCTAssertEqual(["item"], copy.items)
        XCTAssertEqual(["field"], copy.fields)
        XCTAssertNil(mpn.items)
        XCTAssertNil(mpn.fields)
    }
}
