# Lightstreamer Client SDK

[![Swift](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-Orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_Linux_Windows-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_Linux_Windows-Green?style=flat-square)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

Lightstreamer Client SDK enables any Swift application to communicate bidirectionally with a **Lightstreamer Server**. The API allows to subscribe to real-time data pushed by the server and to send any message to the server.

The library offers automatic recovery from connection failures, automatic selection of the best available transport, and full decoupling of subscription and connection operations. It is responsible of forwarding the subscriptions to the Server and re-forwarding all the subscriptions whenever the connection is broken and then reopened.

The library also offers support for mobile push notifications (MPN). While real-time subscriptions deliver their updates via the client connection, MPN subscriptions deliver their updates via push notifications, even when the application is offline. They are handled by a special module of the Server, the MPN Module, that keeps them active at all times and continues pushing with no need for a client connection.

## Requirements

| Platform | Minimum Swift Version | Installation | Status |
| --- | --- | --- | --- |
| iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+ | 5.1 | [Swift Package Manager](#swift-package-manager), [Manual](#manually) | Fully Tested |

## Installation

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding Lightstreamer Client SDK as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git", from: "5.0.0-beta.1")
]
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Lightstreamer Client SDK into your project manually.

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

  ```bash
  $ git init
  ```

- Add Lightstreamer Client SDK as a git [submodule](https://git-scm.com/docs/git-submodule) by running the following command:

  ```bash
  $ git submodule add https://github.com/Lightstreamer/Lightstreamer-lib-client-swift.git
  ```

- Open the new `Lightstreamer-lib-client-swift` folder, and drag the `LightstreamerClient.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.
    
- Once that is complete, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.

- In the tab bar at the top of that window, open the "General" panel.

- Click on the + button under the "Frameworks, Libraries and Embedded Content" section.

- Select the entry `LightstreamerClient`.

## Quickstart

To connect to a Lightstreamer Server, a [LightstreamerClient](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Classes/LightstreamerClient.html) object has to be created, configured, and instructed to connect to the Lightstreamer Server. 
A minimal version of the code that creates a LightstreamerClient and connects to the Lightstreamer Server on *https://push.lightstreamer.com* will look like this:

```swift
let client = LightstreamerClient("https://push.lightstreamer.com/", adapterSet: "DEMO")
client.connect()
```

For each subscription to be subscribed to a Lightstreamer Server a [Subscription](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Classes/Subscription.html) instance is needed.
A simple Subscription containing three items and two fields to be subscribed in *MERGE* mode is easily created (see [Lightstreamer General Concepts](https://www.lightstreamer.com/docs/base/General%20Concepts.pdf)):

```swift
let items = [ "item1", "item2", "item3" ]
let fields = [ "stock_name", "last_price" ]
let sub = Subscription(.MERGE, items: items, fields: fields)
sub.dataAdapter = "QUOTE_ADAPTER"
sub.requestedSnapshot = .yes
client.subscribe(sub)
```

Before sending the subscription to the server, usually at least one [SubscriptionDelegate](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Protocols/SubscriptionDelegate.html) is attached to the Subscription instance in order to consume the real-time updates. The following code shows the values of the fields *stock_name* and *last_price* each time a new update is received for the subscription:

```swift
class SubscriptionDelegateImpl: SubscriptionDelegate {
    func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
        print("\(itemUpdate.valueWithFieldName("stock_name")): \(itemUpdate.valueWithFieldName("last_price"))")
    }
    // other methods...
}

sub.addDelegate(SubscriptionDelegateImpl())
```

## Mobile Push Notifications Quickstart

Mobile Push Notifications (MPN) are based on [Apple Push Notification Service technology](https://developer.apple.com/documentation/usernotifications).

Before you can use MPN services, you need to
- register your app with APNs (read carefully the documentation about [Setting Up a Remote Notification Server](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server));
- configure the Lightstreamer MPN module (read carefully the section *5 Mobile and Web Push Notifications* in the [General Concepts guide](https://lightstreamer.com/docs/ls-server/7.2.0/General%20Concepts.pdf)).

After you have an APNs account, you can create a [MPN device](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Classes/MpnDevice.html), which represents a specific app running on a specific mobile device.

The following snippet shows a sample implementation of the iOS app delegate methods needed to register for remote notifications and receive the corresponding token.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
   // Override point for customization after application launch.       
   UIApplication.shared.registerForRemoteNotifications()
   return true
}

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
   let tokenAsString = deviceToken.map { String(format: "%02x", $0) }.joined()
   let mpnDevice = MPNDevice(tokenAsString)
}

func application(_ application: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError 
                error: Error) {
   // Try again later.
}
```

To receive notifications, you need to subscribe to a [MPN subscription](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Classes/MpnSubscription.html): it contains subscription details and the listener needed to monitor its status. Real-time data is routed via native push notifications.

```swift
let builder = MPNBuilder()
builder.body("Stock ${stock_name} is now ${last_price}")
builder.sound("Default")
builder.badgeWithString("AUTO")
builder.customData([
    "stock_name" : "${stock_name}",
    "last_price" : "${last_price}"])
let format = builder.build()

let items = [ "item1", "item2", "item3" ]
let fields = [ "stock_name", "last_price" ]
let sub = MPNSubscription(.MERGE, items: items, fields: fields)
sub.notificationFormat = format
sub.triggerExpression = "Double.parseDouble($[2])>45.0"
client.subscribeMPN(sub, coalescing: true)
```

The notification format lets you specify how to format the notification message. It can contain a special syntax that lets you compose the message with the content of the subscription updates (see §5.4.1 of the [General Concepts guide](https://lightstreamer.com/docs/ls-server/7.2.0/General%20Concepts.pdf) ).

The optional  trigger expression  lets you specify  when to send  the notification message: it is a boolean expression, in Java language, that when evaluates to true triggers the sending of the notification (see §5.4.2 of the [General Concepts guide](https://lightstreamer.com/docs/ls-server/7.2.0/General%20Concepts.pdf)). If not specified, a notification is sent each time the Data Adapter produces an update.

## Logging

To enable the internal client logger, create an instance of [LoggerProvider](https://sdk.lightstreamer.com/ls-swift-client/5.0.0-beta.1/api/Protocols/LSLoggerProvider.html) and set it as the default provider of [LightstreamerClient](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/Classes/LightstreamerClient.html).

```swift
let loggerProvider = ConsoleLoggerProvider(.debug)
LightstreamerClient.setLoggerProvider(loggerProvider)
```
## Compatibility

Compatible with Lightstreamer Server since version 7.2.0.

## Documentation

- [Live demos](https://demos.lightstreamer.com/?p=lightstreamer&t=client&lclient=apple&sclientapple=ios&sclientapple=macos&sclientapple=tvos&sclientapple=watchos)

- [API Reference](https://lightstreamer.com/api/ls-swift-client/5.0.0-beta.1/api/)

- [Lightstreamer General Concepts](https://lightstreamer.com/docs/ls-server/7.2.0/General%20Concepts.pdf)

## Support

For questions and support please use the [Official Forum](https://forums.lightstreamer.com/). The issue list of this page is **exclusively** for bug reports and feature requests.

## License

[Apache 2.0](https://opensource.org/licenses/Apache-2.0)
