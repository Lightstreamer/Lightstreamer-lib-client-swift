import Foundation
import XCTest
@testable import LightstreamerClient

final class MpnBuilderTests: XCTestCase {

    func testSetFields() {
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":"ALERT"}}
            """, MPNBuilder()
                .alert("ALERT")
                .build())
        XCTAssertEqual("""
            {"aps":{"badge":10}}
            """, MPNBuilder()
                .badgeWithInt(10)
                .build())
        XCTAssertEqual("""
            {"aps":{"badge":"BADGE"}}
            """, MPNBuilder()
                .badgeWithString("BADGE")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"body":"BODY"}}}
            """, MPNBuilder()
                .body("BODY")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"loc-args":["a1","a2"]}}}
            """, MPNBuilder()
                .bodyLocArguments(["a1", "a2"])
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"loc-key":"LKEY"}}}
            """, MPNBuilder()
                .bodyLocKey("LKEY")
                .build())
        XCTAssertEqual("""
            {"aps":{"category":"CAT"}}
            """, MPNBuilder()
                .category("CAT")
                .build())
        XCTAssertEqual("""
            {"aps":{"content-available":20}}
            """, MPNBuilder()
                .contentAvailableWithInt(20)
                .build())
        XCTAssertEqual("""
            {"aps":{"content-available":"CAV"}}
            """, MPNBuilder()
                .contentAvailableWithString("CAV")
                .build())
        XCTAssertEqual("""
            {"aps":{"mutable-content":30}}
            """, MPNBuilder()
                .mutableContentWithInt(30)
                .build())
        XCTAssertEqual("""
            {"aps":{"mutable-content":"MC"}}
            """, MPNBuilder()
                .mutableContentWithString("MC")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"launch-image":"IMG"}}}
            """, MPNBuilder()
                .launchImage("IMG")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"action-loc-key":"LAKEY"}}}
            """, MPNBuilder()
                .locActionKey("LAKEY")
                .build())
        XCTAssertEqual("""
            {"aps":{"sound":"SND"}}
            """, MPNBuilder()
                .sound("SND")
                .build())
        XCTAssertEqual("""
            {"aps":{"thread-id":"TID"}}
            """, MPNBuilder()
                .threadId("TID")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"title":"TIT"}}}
            """, MPNBuilder()
                .title("TIT")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"subtitle":"STIT"}}}
            """, MPNBuilder()
                .subtitle("STIT")
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"title-loc-args":["b1","b2"]}}}
            """, MPNBuilder()
                .titleLocArguments(["b1", "b2"])
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{"title-loc-key":"TLKEY"}}}
            """, MPNBuilder()
                .titleLocKey("TLKEY")
                .build())
    }
    
    func testUnsetFields() {
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .alert("ALERT")
                .alert(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .badgeWithInt(10)
                .badgeWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .badgeWithString("BADGE")
                .badgeWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .body("BODY")
                .body(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .bodyLocArguments(["a1", "a2"])
                .bodyLocArguments(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .bodyLocKey("LKEY")
                .bodyLocKey(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .category("CAT")
                .category(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .contentAvailableWithInt(20)
                .contentAvailableWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .contentAvailableWithString("CAV")
                .contentAvailableWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .mutableContentWithInt(30)
                .mutableContentWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .mutableContentWithString("MC")
                .mutableContentWithString(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .customData(["f1":true])
                .customData(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .launchImage("IMG")
                .launchImage(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .locActionKey("LAKEY")
                .locActionKey(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .sound("SND")
                .sound(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .threadId("TID")
                .threadId(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .title("TIT")
                .title(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .subtitle("STIT")
                .subtitle(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .titleLocArguments(["b1", "b2"])
                .titleLocArguments(nil)
                .build())
        XCTAssertEqual("""
            {"aps":{"alert":{}}}
            """, MPNBuilder()
                .titleLocKey("TLKEY")
                .titleLocKey(nil)
                .build())
        
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .title("TIT")
                .alert(nil)
                .build())
    }
    
    func testInitFromJson() {
        let builder = MPNBuilder("""
            {
              "aps" : {
                "badge" : 9,
                "alert" : {
                  "body" : "Bob wants to play poker",
                  "subtitle" : "Five Card Draw",
                  "title" : "Game Request",
                  "loc-args" : ["Shelly", "Rick"],
                  "loc-key" : "GAME_PLAY_REQUEST_FORMAT"
                },
                "category" : "GAME_INVITATION"
              },
              "gameID" : "12345678"
            }
            """)!
        XCTAssertEqual(9, builder.badgeAsInt)
        XCTAssertEqual("Bob wants to play poker", builder.body)
        XCTAssertEqual("Five Card Draw", builder.subtitle)
        XCTAssertEqual("Game Request", builder.title)
        XCTAssertEqual(["Shelly", "Rick"], builder.bodyLocArguments)
        XCTAssertEqual("GAME_PLAY_REQUEST_FORMAT", builder.bodyLocKey)
        XCTAssertEqual("GAME_INVITATION", builder.category)
        XCTAssertEqual(["gameID":"12345678"], builder.customData as! [String : String])
        
        XCTAssertNil(MPNBuilder("}{"))
    }
    
    @available(macOS 10.13, *)
    @available(iOS 11.0, *)
    @available(tvOS 11.0, *)
    @available(watchOS 4.0, *)
    func testBuild() {
        XCTAssertEqual("""
            {
              "aps" : {

              },
              "f1" : true
            }
            """, MPNBuilder()
                .customData(["f1":true])
                .buildTest())
        XCTAssertEqual("""
            {
              "aps" : {
                "alert" : {
                  "body" : "Bob wants to play poker",
                  "subtitle" : "Five Card Draw",
                  "title" : "Game Request"
                },
                "category" : "GAME_INVITATION"
              },
              "gameID" : "12345678"
            }
            """, MPNBuilder()
                .title("Game Request")
                .subtitle("Five Card Draw")
                .body("Bob wants to play poker")
                .category("GAME_INVITATION")
                .customData(["gameID":"12345678"])
                .buildTest())
        XCTAssertEqual("""
            {
              "aps" : {
                "badge" : 9,
                "sound" : "bingbong.aiff"
              },
              "messageID" : "ABCDEFGHIJ"
            }
            """, MPNBuilder()
                .badgeWithInt(9)
                .sound("bingbong.aiff")
                .customData(["messageID":"ABCDEFGHIJ"])
                .buildTest())
        XCTAssertEqual("""
            {
              "aps" : {
                "alert" : {
                  "loc-args" : [
                    "Shelly",
                    "Rick"
                  ],
                  "loc-key" : "GAME_PLAY_REQUEST_FORMAT"
                }
              }
            }
            """, MPNBuilder()
                .bodyLocKey("GAME_PLAY_REQUEST_FORMAT")
                .bodyLocArguments(["Shelly", "Rick"])
                .buildTest())
    }
}
