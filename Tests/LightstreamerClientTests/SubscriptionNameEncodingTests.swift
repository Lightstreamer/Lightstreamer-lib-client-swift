import XCTest
@testable import LightstreamerClient

final class SubscriptionNameEncodingTests: XCTestCase {
    func testNamesPreserveBytesAcrossConfigurationAndCopies() {
        let names = ["123", " ", " leading and trailing ", "&=%+?#/", "\t\r\n\0", "東京😀", "é", "e\u{301}"]
        let sub = Subscription(subscriptionMode: .MERGE, items: names, fields: names)
        sub.items = names.reversed()
        sub.fields = names.reversed()
        let bytes = names.reversed().map { Array($0.utf8) }
        XCTAssertEqual(bytes, sub.items!.map { Array($0.utf8) })
        XCTAssertEqual(bytes, sub.fields!.map { Array($0.utf8) })
        let command = Subscription(subscriptionMode: .COMMAND, item: "123", fields: ["key", "command"])
        command.commandSecondLevelFields = names
        XCTAssertEqual(names.map { Array($0.utf8) }, command.commandSecondLevelFields!.map { Array($0.utf8) })
        let mpn = MPNSubscription(subscription: sub)
        mpn.items = names
        mpn.fields = names
        let copy = MPNSubscription(MPNSubscription: mpn)
        XCTAssertEqual(names.map { Array($0.utf8) }, copy.items!.map { Array($0.utf8) })
        XCTAssertEqual(names.map { Array($0.utf8) }, copy.fields!.map { Array($0.utf8) })
        for name in names {
            XCTAssertTrue(isValidItem(name))
            XCTAssertTrue(isValidField(name))
            XCTAssertEqual(Array(name.utf8), Array(Subscription(subscriptionMode: .RAW, item: name, fields: [name]).items![0].utf8))
            XCTAssertEqual(Array(name.utf8), Array(MPNSubscription(subscriptionMode: .MERGE, item: name, fields: [name]).items![0].utf8))
        }
        XCTAssertFalse(allValidItems(["valid", ""]))
        XCTAssertFalse(allValidFields(["", "valid"]))
        XCTAssertFalse(notEmpty([String]()))
        XCTAssertTrue(allValidItems(nil))
        XCTAssertTrue(allValidFields(nil))
    }

    func testCompactedListsAndScalarEscaping() {
        let req = LsRequestBuilder()
        req.LS_reqId(1)
        req.LS_item(["a b", "x&y", "123"])
        req.LS_field(["f=1", "f+2", "%26"])
        req.LS_data_adapter("a&b +c")
        XCTAssertEqual("LS_reqId=1&LS_item=a%20b&x%26y&123&LS_field=f%3D1&f%2B2&%2526&LS_data_adapter=a%26b%20%2Bc", req.encodedString)
        let scalar = LsRequestBuilder()
        scalar.addParam("a", "f&=o")
        scalar.addParam("b", "b +r")
        XCTAssertEqual("a=f%26%3Do&b=b%20%2Br", scalar.encodedString)
    }

    func testControlUnicodeAndInjectionNamesAreData() {
        let req = LsRequestBuilder()
        req.LS_item(["x&LS_group=y", "é", "e\u{301}", "東京😀", "é"])
        req.LS_field(["\t\r\n\0", "&=%+?#/", "LS_field=z"])
        XCTAssertEqual("LS_item=x%26LS_group%3Dy&%C3%A9&e%CC%81&%E6%9D%B1%E4%BA%AC%F0%9F%98%80&%C3%A9&LS_field=%09%0D%0A%00&%26%3D%25%2B%3F%23%2F&LS_field%3Dz", req.encodedString)
        XCTAssertFalse(req.encodedString.contains("\r\n"))
    }

    func testProtocolVersions() {
        XCTAssertEqual("TLCP-2.6.0", TLCP_VERSION)
        XCTAssertEqual("TLCP-2.6.0.lightstreamer.com", FULL_TLCP_VERSION)
    }
}
