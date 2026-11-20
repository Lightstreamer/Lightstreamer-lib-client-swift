import XCTest
@testable import LightstreamerClient

final class SubscriptionListTests: XCTestCase {
    func testEveryNonEmptyNameIsAcceptedWithoutChangingBytes() {
        let names = ["123", " ", " leading and trailing ", "&=%+?#/", "\t\r\n\0", "東京😀", "é", "e\u{301}"]
        let sub = Subscription(subscriptionMode: .MERGE, items: names, fields: names)
        sub.items = names.reversed()
        sub.fields = names.reversed()
        XCTAssertEqual(names.reversed().map { Array($0.utf8) }, sub.items!.map { Array($0.utf8) })
        XCTAssertEqual(names.reversed().map { Array($0.utf8) }, sub.fields!.map { Array($0.utf8) })
        for name in names {
            let single = Subscription(subscriptionMode: .MERGE, item: name, fields: [name])
            XCTAssertEqual(Array(name.utf8), Array(single.items![0].utf8))
        }
        let command = Subscription(subscriptionMode: .COMMAND, item: "123", fields: ["key", "command"])
        command.commandSecondLevelFields = names
        XCTAssertEqual(names.map { Array($0.utf8) }, command.commandSecondLevelFields!.map { Array($0.utf8) })
    }

    func testMPNAcceptsNamesWithoutLiteralSpacesWithoutChangingBytes() {
        let names = ["123", "\t", "\u{00A0}", "a\u{2003}b", "&=%+?#/", "\t\r\n\0", "東京😀", "é", "e\u{301}"]
        let original = names.map { Array($0.utf8) }
        let reversed = Array(names.reversed())
        let reordered = Array(original.reversed())
        for name in names {
            let single = MPNSubscription(subscriptionMode: .MERGE, item: name, fields: [name])
            XCTAssertEqual([Array(name.utf8)], single.items?.map { Array($0.utf8) })
            XCTAssertEqual([Array(name.utf8)], single.fields?.map { Array($0.utf8) })
        }
        for mode: MPNSubscription.Mode in [.MERGE, .DISTINCT] {
            let mpn = MPNSubscription(subscriptionMode: mode, items: names, fields: names)
            XCTAssertEqual(original, mpn.items?.map { Array($0.utf8) })
            XCTAssertEqual(original, mpn.fields?.map { Array($0.utf8) })
            mpn.items = reversed
            mpn.fields = reversed
            XCTAssertEqual(reordered, mpn.items?.map { Array($0.utf8) })
            XCTAssertEqual(reordered, mpn.fields?.map { Array($0.utf8) })
            let copy = MPNSubscription(MPNSubscription: mpn)
            XCTAssertEqual(reordered, copy.items?.map { Array($0.utf8) })
            XCTAssertEqual(reordered, copy.fields?.map { Array($0.utf8) })
        }
        let sub = Subscription(subscriptionMode: .MERGE, items: names, fields: reversed)
        let converted = MPNSubscription(subscription: sub)
        XCTAssertEqual(original, converted.items?.map { Array($0.utf8) })
        XCTAssertEqual(reordered, converted.fields?.map { Array($0.utf8) })
    }

    func testMPNRejectsEmptyNamesAndLiteralSpaces() {
        for name in ["", " ", " leading", "trailing ", "em bedded", "a \u{301}b"] {
            XCTAssertFalse(MPNSubscription.allValidNames(["valid", name]), "Unexpectedly accepted \(name.debugDescription)")
        }
        XCTAssertTrue(MPNSubscription.allValidNames(nil))
    }

    func testEmptyNamesAreStillInvalid() {
        XCTAssertFalse(isValidItem(""))
        XCTAssertFalse(isValidField(""))
        XCTAssertFalse(allValidItems(["valid", ""]))
        XCTAssertFalse(allValidFields(["", "valid"]))
        XCTAssertTrue(allValidItems(nil))
        XCTAssertTrue(allValidFields(nil))
        XCTAssertFalse(notEmpty([String]()))
    }

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
