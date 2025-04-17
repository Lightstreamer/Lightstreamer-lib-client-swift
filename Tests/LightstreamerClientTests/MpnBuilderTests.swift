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
                .badge(with: 10)
                .build())
        XCTAssertEqual("""
            {"aps":{"badge":"BADGE"}}
            """, MPNBuilder()
                .badge(with: "BADGE")
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
                .contentAvailable(with: 20)
                .build())
        XCTAssertEqual("""
            {"aps":{"content-available":"CAV"}}
            """, MPNBuilder()
                .contentAvailable(with: "CAV")
                .build())
        XCTAssertEqual("""
            {"aps":{"mutable-content":30}}
            """, MPNBuilder()
                .mutableContent(with: 30)
                .build())
        XCTAssertEqual("""
            {"aps":{"mutable-content":"MC"}}
            """, MPNBuilder()
                .mutableContent(with: "MC")
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
                .badge(with: 10)
                .badge(with: nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .badge(with: "BADGE")
                .badge(with: nil)
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
                .contentAvailable(with: 20)
                .contentAvailable(with: nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .contentAvailable(with: "CAV")
                .contentAvailable(with: nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .mutableContent(with: 30)
                .mutableContent(with: nil)
                .build())
        XCTAssertEqual("""
            {"aps":{}}
            """, MPNBuilder()
                .mutableContent(with: "MC")
                .mutableContent(with: nil)
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
        let builder = MPNBuilder(notificationFormat: """
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
        
        XCTAssertNil(MPNBuilder(notificationFormat: "}{"))
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
                .badge(with: 9)
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
