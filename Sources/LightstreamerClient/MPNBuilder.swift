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

/**
 Utility class that provides methods to build or parse the JSON structure used to represent the format of a push notification.
 
 It provides properties and methods to get and set the fields of a push notification, following the format specified by Apple's Push Notification service (APNs).
 This format is compatible with `MPNSubscription.notificationFormat`.
 
 - SeeAlso: `MPNSubscription.notificationFormat`
 */
public class MPNBuilder {
    
    let lock = NSLock()
    var aps = [String:Any]()
    var m_customData = [String:Any]()
    
    /**
     Creates an empty object to be used to create a push notification format from scratch.
     
     Use setters methods to set the value of push notification fields.
     */
    public init() {}
    
    /**
     Creates an object based on the specified push notification format.
     
     Use properties and setter methods to get and set the value of push notification fields.
     
     - Parameter notificationFormat: A JSON structure representing a push notification format.

     - Precondition: the notification must be a valid JSON structure.
     */
    public init?(notificationFormat: String) {
        guard let data = notificationFormat.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
            return nil
        }
        if let aps = json["aps"] as? [String:Any] {
            self.aps = aps
        }
        self.m_customData = json
        self.m_customData["aps"] = nil
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    private func setVal(key: String, val: Any?) -> MPNBuilder {
        aps[key] = val
        return self
    }
    
    private func setVal(key1: String, key2: String, val: Any?) -> MPNBuilder {
        var key1Map = aps[key1] as? [String:Any] ?? [String:Any]()
        key1Map[key2] = val
        aps[key1] = key1Map
        return self
    }
    
    private func getVal<T>(key: String) -> T? {
        aps[key] as? T
    }
    
    private func getVal<T>(key1: String, key2: String) -> T? {
        if let key1Map = aps[key1] as? [String:Any] {
            return key1Map[key2] as? T
        } else {
            return nil
        }
    }
    
    /**
     Produces the JSON structure for the push notification format specified by this object.
     */
    public func build() -> String {
        synchronized {
            var dict = m_customData
            dict["aps"] = aps
            let data = try! JSONSerialization.data(withJSONObject: dict)
            return String(data: data, encoding: .utf8)!
        }
    }
    
    @available(macOS 10.13, *)
    @available(iOS 11.0, *)
    @available(tvOS 11.0, *)
    @available(watchOS 4.0, *)
    func buildTest() -> String {
        synchronized {
            var dict = m_customData
            dict["aps"] = aps
            let data = try! JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8)!
        }
    }
    
    /**
     Sets the `aps.alert` field.
     
     - Parameter alert: A string to be used for the `aps.alert` field value, or nil to clear it.
     */
    @discardableResult
    public func alert(_ alert: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "alert", val: alert)
        }
    }
    
    /**
     Value of the `aps.alert` field.
     */
    public var alert: String? {
        synchronized {
            getVal(key: "alert")
        }
    }
    
    /**
     Sets the `aps.badge` field with an int value.
     
     - Parameter badge: An int to be used for the `aps.badge` field value.
     */
    @discardableResult
    public func badge(with badge: Int) -> MPNBuilder {
        synchronized {
            setVal(key: "badge", val: badge)
        }
    }
    
    /**
     Value of the `aps.badge` field as an int value.
     */
    public var badgeAsInt: Int? {
        synchronized {
            getVal(key: "badge")
        }
    }
    
    /**
     Sets the `aps.badge` field with a string value.
     
     - Parameter badge: A string to be used for the `aps.badge` field value, or nil to clear it.
     */
    @discardableResult
    public func badge(with badge: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "badge", val: badge)
        }
    }
    
    /**
     Value of the `aps.badge` field as a string value.
     */
    public var badgeAsString: String? {
        synchronized {
            getVal(key: "badge")
        }
    }
    
    /**
     Sets the `aps.alert.body` field.
     
     - Parameter body: A string to be used for the `aps.alert.body` field value, or nil to clear it.
     */
    @discardableResult
    public func body(_ body: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "body", val: body)
        }
    }
    
    /**
     Value of the `aps.alert.body` field.
     */
    public var body: String? {
        synchronized {
            getVal(key1: "alert", key2: "body")
        }
    }
    
    /**
     Sets the `aps.alert.loc-args` field.
     
     - Parameter bodyLocArguments: An array of strings to be used for the `aps.alert.loc-args` field value, or nil to clear it.
     */
    @discardableResult
    public func bodyLocArguments(_ bodyLocArguments: [String]?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "loc-args", val: bodyLocArguments)
        }
    }
    
    /**
     Value of the `aps.alert.loc-args` field as an array of strings.
     */
    public var bodyLocArguments: [String]? {
        synchronized {
            getVal(key1: "alert", key2: "loc-args")
        }
    }
    
    /**
     Sets the `aps.alert.loc-key` field.
     
     - Parameter bodyLocKey: A string to be used for the `aps.alert.loc-key` field value, or nil to clear it.
     */
    @discardableResult
    public func bodyLocKey(_ bodyLocKey: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "loc-key", val: bodyLocKey)
        }
    }
    
    /**
     Value of the `aps.alert.loc-key` field.
     */
    public var bodyLocKey: String? {
        synchronized {
            getVal(key1: "alert", key2: "loc-key")
        }
    }
    
    /**
     Sets the `aps.category` field.
     
     - Parameter category: A string to be used for the `aps.category` field value, or nil to clear it.
     */
    @discardableResult
    public func category(_ category: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "category", val: category)
        }
    }
    
    /**
     Value of the `aps.category` field.
     */
    public var category: String? {
        synchronized {
            getVal(key: "category")
        }
    }
    
    /**
     Sets the `aps.content-available` field with an int value.
     
     - Parameter contentAvailable: An int to be used for the `aps.content-available` field value.
     */
    @discardableResult
    public func contentAvailable(with contentAvailable: Int) -> MPNBuilder {
        synchronized {
            setVal(key: "content-available", val: contentAvailable)
        }
    }
    
    /**
     Value of the `aps.content-available` field as an int value.
     */
    public var contentAvailableAsInt: Int? {
        synchronized {
            getVal(key: "content-available")
        }
    }
    
    /**
     Sets the `aps.content-available` field with a string value.
     
     - Parameter contentAvailable: A string to be used for the `aps.content-available` field value, or nil to clear it.
     */
    @discardableResult
    public func contentAvailable(with contentAvailable: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "content-available", val: contentAvailable)
        }
    }
    
    /**
     Value of the `aps.content-available` field as a string value.
     */
    public var contentAvailableAsString: String? {
        synchronized {
            getVal(key: "content-available")
        }
    }
    
    /**
     Sets the `aps.mutable-content` field with an int value.
     
     - Parameter mutableContent: An int to be used for the `aps.mutable-content` field value.
     */
    @discardableResult
    public func mutableContent(with mutableContent: Int) -> MPNBuilder {
        synchronized {
            setVal(key: "mutable-content", val: mutableContent)
        }
    }
    
    /**
     Value of the `aps.mutable-content` field as an int value.
     */
    public var mutableContentAsInt: Int? {
        synchronized {
            getVal(key: "mutable-content")
        }
    }
    
    /**
     Sets the `aps.mutable-content` field with a string value.
     
     - Parameter mutableContent: A string to be used for the `aps.mutable-content` field value, or nil to clear it.
     */
    @discardableResult
    public func mutableContent(with mutableContent: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "mutable-content", val: mutableContent)
        }
    }
    
    /**
     Value of the `aps.mutable-content` field as a string value.
     */
    public var mutableContentAsString: String? {
        synchronized {
            getVal(key: "mutable-content")
        }
    }
    
    /**
     Sets fields in the root of the notification format (excluding `aps`).
     
     - Parameter customData: A dictionary to be used for fields in the root of the notification format (excluding `aps`), or nil to clear them.
     */
    @discardableResult
    public func customData(_ customData: [String:Any]?) -> MPNBuilder {
        synchronized {
            m_customData = customData ?? [:]
            return self
        }
    }
    
    /**
     Fields in the root of the notification format (excluding `aps`).
     */
    public var customData: [String:Any]? {
        synchronized {
            m_customData
        }
    }
    
    /**
     Sets the `aps.alert.launch-image` field.
     
     - Parameter launchImage: A string to be used for the `aps.alert.launch-image` field value, or nil to clear it.
     */
    @discardableResult
    public func launchImage(_ launchImage: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "launch-image", val: launchImage)
        }
    }
    
    /**
     Value of the `aps.alert.launch-image` field.
     */
    public var launchImage: String? {
        synchronized {
            getVal(key1: "alert", key2: "launch-image")
        }
    }
    
    /**
     Sets the `aps.alert.action-loc-key` field.
     
     - Parameter locActionKey: A string to be used for the `aps.alert.action-loc-key` field value, or nil to clear it.
     */
    @discardableResult
    public func locActionKey(_ locActionKey: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "action-loc-key", val: locActionKey)
        }
    }
    
    /**
     Value of the `aps.alert.action-loc-key` field.
     */
    public var locActionKey: String? {
        synchronized {
            getVal(key1: "alert", key2: "action-loc-key")
        }
    }
    
    /**
     Sets the `aps.sound` field.
     
     - Parameter sound: A string to be used for the `aps.sound` field value, or nil to clear it.
     */
    @discardableResult
    public func sound(_ sound: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "sound", val: sound)
        }
    }
    
    /**
     Value of the `aps.sound` field.
     */
    public var sound: String? {
        synchronized {
            getVal(key: "sound")
        }
    }
    
    /**
     Sets the `aps.thread-id` field.
     
     - Parameter threadId: A string to be used for the `aps.thread-id` field value, or nil to clear it.
     */
    @discardableResult
    public func threadId(_ threadId: String?) -> MPNBuilder {
        synchronized {
            setVal(key: "thread-id", val: threadId)
        }
    }
    
    /**
     Value of the `aps.thread-id` field.
     */
    public var threadId: String? {
        synchronized {
            getVal(key: "thread-id")
        }
    }
    
    /**
     Sets the `aps.alert.title` field.
     
     - Parameter title: A string to be used for the `aps.alert.title` field value, or nil to clear it.
     */
    @discardableResult
    public func title(_ title: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "title", val: title)
        }
    }
    
    /**
     Value of the `aps.alert.title` field.
     */
    public var title: String? {
        synchronized {
            getVal(key1: "alert", key2: "title")
        }
    }
    
    /**
     Sets the `aps.alert.subtitle` field.
     
     - Parameter subtitle: A string to be used for the `aps.alert.subtitle` field value, or nil to clear it.
     */
    @discardableResult
    public func subtitle(_ subtitle: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "subtitle", val: subtitle)
        }
    }
    
    /**
     Value of the `aps.alert.subtitle` field.
     */
    public var subtitle: String? {
        synchronized {
            getVal(key1: "alert", key2: "subtitle")
        }
    }
    
    /**
     Sets the `aps.alert.title-loc-args` field.
     
     - Parameter titleLocArguments: An array of strings to be used for the `aps.alert.title-loc-args` field value, or nil to clear it.
     */
    @discardableResult
    public func titleLocArguments(_ titleLocArguments: [String]?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "title-loc-args", val: titleLocArguments)
        }
    }
    
    /**
     Value of the `aps.alert.title-loc-args` field.
     */
    public var titleLocArguments: [String]? {
        synchronized {
            getVal(key1: "alert", key2: "title-loc-args")
        }
    }
    
    /**
     Sets the `aps.alert.title-loc-key` field.
     
     - Parameter titleLocKey: A string to be used for the `aps.alert.title-loc-key` field value, or nil to clear it.
     */
    @discardableResult
    public func titleLocKey(_ titleLocKey: String?) -> MPNBuilder {
        synchronized {
            setVal(key1: "alert", key2: "title-loc-key", val: titleLocKey)
        }
    }
    
    /**
     Value of the `aps.alert.title-loc-key` field.
     */
    public var titleLocKey: String? {
        synchronized {
            getVal(key1: "alert", key2: "title-loc-key")
        }
    }
}
