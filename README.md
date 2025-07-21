# Lightstreamer Swift Client SDK

[![Swift](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-Orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_visionOS-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_visionOS-Green?style=flat-square)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/LightstreamerClient.svg?style=flat-square)](https://img.shields.io/cocoapods/v/LightstreamerClient.svg)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

Lightstreamer Swift Client SDK enables any Swift application to communicate bidirectionally with a **Lightstreamer Server**. The API allows to subscribe to real-time data pushed by the server and to send any message to the server.

The library offers automatic recovery from connection failures, automatic selection of the best available transport, and full decoupling of subscription and connection operations. It is responsible of forwarding the subscriptions to the Server and re-forwarding all the subscriptions whenever the connection is broken and then reopened.

The library also offers support for mobile push notifications (MPN). While real-time subscriptions deliver their updates via the client connection, MPN subscriptions deliver their updates via push notifications, even when the application is offline. They are handled by a special module of the Server, the MPN Module, that keeps them active at all times and continues pushing with no need for a client connection.

This SDK is also meant to replace and evolve all the Client SDKs targeted to the Apple platforms (i.e. iOS, macOS, tvOS, and watchOS Client SDKs).

## Requirements

| Platform | Minimum Swift Version | Installation | Status |
| --- | --- | --- | --- |
| iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+ / visionOS 1.0+ | 5.1 | [Swift Package Manager](#swift-package-manager), [Manual](#manually),[CocoaPods](#cocoapods) | Fully Tested |

## Installation

The package exports two different library flavors: **LightstreamerClient** (Full) and **LightstreamerClientCompact** (Compact).

The compact library has no third-party dependencies. However, it doesn't support decoding subscription fields in JSON Patch format. If a Lightstreamer server sends an update containing JSON Patch–encoded fields, the library will close the active session and notify the client through the `ClientDelegate.client(_:didReceiveServerError:withMessage:)` method. Additionally, the compact library doesn't support the `ItemUpdate` methods `valueAsJSONPatchIfAvailable(withFieldName:)` and `valueAsJSONPatchIfAvailable(withFieldPos:)`.

The full library has none of these limitations, but it relies on external libraries.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.
With SPM, simply add the Lightstreamer Swift Client SDK to the `dependencies` array in your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git", from: "6.3.0")
]
```

Both Compact and Full libraries are available via Swift Package Manager.  

Normally you'll want to depend on the **LightstreamerClient** library (Full):

```swift
targets: [
    .target(
        name: "MyTarget",
        dependencies: [ .product(name: "LightstreamerClient", package: "Lightstreamer-lib-client-swift") ])
]
```

But if you don't want any dependencies on external libraries, you can depend on the **LightstreamerClientCompact** library:

```swift
targets: [
    .target(
        name: "MyTarget",
        dependencies: [ .product(name: "LightstreamerClientCompact", package: "Lightstreamer-lib-client-swift") ])
]
```

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. 
To integrate LightstreamerClient into your Xcode project using CocoaPods, specify it in your Podfile:

```
pod 'LightstreamerClient'
```

CocoaPods hosts **only** the Full (**LightstreamerClient**) library. 

### Manually

If you prefer not to use any of the above dependency managers, you can integrate the Lightstreamer Swift Client SDK manually:

- Open Terminal and clone the SDK repository:  
  ```sh
  git clone https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git
  ```

- In Xcode, choose `File > Add Package Dependencies`  
  - Click `Add Local`, navigate to the folder where you cloned the SDK, and click `Add Package`.  
  - On the next screen, select either **LightstreamerClient** or **LightstreamerClientCompact**.

- In the Project Navigator, select your app's project, then tap your app target under `Targets` in the sidebar.

- Switch to the `General` tab.

- Under `Frameworks, Libraries, and Embedded Content`, verify that **LightstreamerClient** or **LightstreamerClientCompact** is listed.

## Quickstart

To connect to a Lightstreamer Server, a [LightstreamerClient](https://lightstreamer.com/api/ls-swift-client/6.3.0/Classes/LightstreamerClient.html) object has to be created, configured, and instructed to connect to the Lightstreamer Server. 
A minimal version of the code that creates a LightstreamerClient and connects to the Lightstreamer Server on *https://push.lightstreamer.com* will look like this:

```swift
let client = LightstreamerClient(serverAddress: "https://push.lightstreamer.com/", adapterSet: "DEMO")
client.connect()
```

For each subscription to be subscribed to a Lightstreamer Server a [Subscription](https://lightstreamer.com/api/ls-swift-client/6.3.0/Classes/Subscription.html) instance is needed.
A simple Subscription containing three items and two fields to be subscribed in *MERGE* mode is easily created (see [Lightstreamer General Concepts](https://www.lightstreamer.com/docs/ls-server/latest/General%20Concepts.pdf)):

```swift
let items = [ "item1", "item2", "item3" ]
let fields = [ "stock_name", "last_price" ]
let sub = Subscription(subscriptionMode: .MERGE, items: items, fields: fields)
sub.dataAdapter = "QUOTE_ADAPTER"
sub.requestedSnapshot = .yes
client.subscribe(sub)
```

Before sending the subscription to the server, usually at least one [SubscriptionDelegate](https://lightstreamer.com/api/ls-swift-client/6.3.0/Protocols/SubscriptionDelegate.html) is attached to the Subscription instance in order to consume the real-time updates. The following code shows the values of the fields *stock_name* and *last_price* each time a new update is received for the subscription:

```swift
class SubscriptionDelegateImpl: SubscriptionDelegate {
    func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
        print("\(itemUpdate.value(withFieldName: "stock_name")): \(itemUpdate.value(withFieldName: "last_price"))")
    }
    // other methods...
}

sub.addDelegate(SubscriptionDelegateImpl())
```

## Mobile Push Notifications Quickstart

Mobile Push Notifications (MPN) are based on [Apple Push Notification Service technology](https://developer.apple.com/documentation/usernotifications).

Before you can use MPN services, you need to
- register your app with APNs (read carefully the documentation about [Setting Up a Remote Notification Server](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server));
- configure the Lightstreamer MPN module (read carefully the section *5 Mobile and Web Push Notifications* in the [General Concepts guide](https://lightstreamer.com/docs/ls-server/7.4.0/General%20Concepts.pdf)).

After you have an APNs account, you can create a [MPN device](https://lightstreamer.com/api/ls-swift-client/6.3.0/Classes/MPNDevice.html), which represents a specific app running on a specific mobile device.

The following snippet shows a sample implementation of the iOS app delegate methods needed to register for remote notifications and receive the corresponding token.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
   // Override point for customization after application launch.       
   UIApplication.shared.registerForRemoteNotifications()
   return true
}

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
   let tokenAsString = deviceToken.map { String(format: "%02x", $0) }.joined()
   let mpnDevice = MPNDevice(deviceToken: tokenAsString)
}

func application(_ application: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError 
                error: Error) {
   // Try again later.
}
```

To receive notifications, you need to subscribe to a [MPN subscription](https://lightstreamer.com/api/ls-swift-client/6.3.0/Classes/MPNSubscription.html): it contains subscription details and the listener needed to monitor its status. Real-time data is routed via native push notifications.

```swift
let builder = MPNBuilder()
builder.body("Stock ${stock_name} is now ${last_price}")
builder.sound("Default")
builder.badge(with: "AUTO")
builder.customData([
    "stock_name" : "${stock_name}",
    "last_price" : "${last_price}"])
let format = builder.build()

let items = [ "item1", "item2", "item3" ]
let fields = [ "stock_name", "last_price" ]
let sub = MPNSubscription(subscriptionMode: .MERGE, items: items, fields: fields)
sub.notificationFormat = format
sub.triggerExpression = "Double.parseDouble($[2])>45.0"
client.subscribeMPN(sub, coalescing: true)
```

The notification format lets you specify how to format the notification message. It can contain a special syntax that lets you compose the message with the content of the subscription updates (see §5.4.1 of the [General Concepts guide](https://lightstreamer.com/distros/ls-server/7.4.5/docs/General%20Concepts.pdf) ).

The optional  trigger expression  lets you specify  when to send  the notification message: it is a boolean expression, in Java language, that when evaluates to true triggers the sending of the notification (see §5.4.2 of the [General Concepts guide](https://lightstreamer.com/distros/ls-server/7.4.5/docs/General%20Concepts.pdf)). If not specified, a notification is sent each time the Data Adapter produces an update.

## Logging

To enable the internal client logger, create an instance of [LoggerProvider](https://lightstreamer.com/api/ls-swift-client/6.3.0/Protocols/LSLoggerProvider.html) and set it as the default provider of [LightstreamerClient](https://lightstreamer.com/api/ls-swift-client/6.3.0/Classes/LightstreamerClient.html).

```swift
let loggerProvider = ConsoleLoggerProvider(level: .debug)
LightstreamerClient.setLoggerProvider(loggerProvider)
```
## Compatibility

Compatible with Lightstreamer Server since version 7.4.0.

## Documentation

- [Live demos](https://demos.lightstreamer.com/?p=lightstreamer&t=client&lclient=apple&sclientapple=ios&sclientapple=macos&sclientapple=tvos&sclientapple=watchos)

- [API Reference](https://lightstreamer.com/api/ls-swift-client/6.3.0/index.html)

- [Lightstreamer General Concepts](https://lightstreamer.com/distros/ls-server/7.4.5/docs/General%20Concepts.pdf)

## Support

For questions and support please use the [Official Forum](https://forums.lightstreamer.com/). The issue list of this page is **exclusively** for bug reports and feature requests.

## License

[Apache 2.0](https://opensource.org/licenses/Apache-2.0)
