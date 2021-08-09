# SDK for Swift Clients CHANGELOG

## 5.0.0 beta 1

_Compatible with Lightstreamer Server since 7.2.0._<br/>
_Not compatible with code developed for Objective-C Clients._<br/>
_Released on XXXXX._

The Swift Client SDK is meant to replace the Objective-C Client SDK for all the Apple platforms (iOS, macOS, tvOS and watchOS).

With respect to the Objective-C Client, the Client API has undergone several changes belonging to the following categories:

1. changes to make the API more Swift-friendly
2. changes to align the API with the other Lightstreamer Client SDKs
3. changes to add new features and to improve the usability.

### Changes to make the API more Swift-friendly

The prefix LS has been removed from the names of all the  public types, that is from:

- LSClientDelegate
- LSClientMessageDelegate
- LSConnectionDetails
- LSConnectionOptions
- LSConsoleLogger
- LSConsoleLoggerProvider
- LSItemUpdate
- LSLightstreamerClient
- LSMPNBuilder
- LSMPNDevice
- LSMPNDeviceDelegate
- LSMPNSubscription
- LSMPNSubscriptionDelegate
- LSSubscription
- LSSubscriptionDelegate

> **NB**  
> The classes LSLogger and LSLoggerProvider have kept their names to avoid name clashes with Foundation classes concerning the logging subsystem. 

The following methods/property setters that used to raise exceptions to validate their arguments are now guarded by preconditions:

- ConnectionDetails.serverAddress
- ConnectionOptions.contentLength
- ConnectionOptions.firstRetryMaxDelay
- ConnectionOptions.forcedTransport
- ConnectionOptions.idleTimeout
- ConnectionOptions.keepaliveInterval
- ConnectionOptions.requestedMaxBandwidth
- ConnectionOptions.pollingInterval
- ConnectionOptions.reconnectTimeout
- ConnectionOptions.retryDelay
- ConnectionOptions.reverseHeartbeatInterval
- ConnectionOptions.sessionRecoveryTimeout
- ConnectionOptions.stalledTimeout
- ItemUpdate.changedFields
- ItemUpdate.fields
- ItemUpdate.valueWithFieldPos
- ItemUpdate.valueWithFieldName
- ItemUpdate.isValueChangedWithFieldPos
- ItemUpdate.isValueChangedWithFieldName
- LightstreamerClient.init
- LightstreamerClient.connect
- LightstreamerClient.registerForMPN
- LightstreamerClient.subscribeMPN
- LightstreamerClient.unsubscribeMPN
- LightstreamerClient.unsubscribeMultipleMPN
- LightstreamerClient.MPNSubscriptions
- LightstreamerClient.filterMPNSubscriptions
- LightstreamerClient.findMPNSubscriptions
- LightstreamerClient.resetMPNBadge
- MPNBuilder.init
- MPNDevice.init
- MPNSubscription.init
- MPNSubscription.dataAdapter
- MPNSubscription.fields
- MPNSubscription.fieldSchema
- MPNSubscription.itemGroup
- MPNSubscription.items
- MPNSubscription.notificationFormat
- MPNSubscription.triggerExpression
- MPNSubscription.requestedBufferSize
- MPNSubscription.requestedMaxFrequency
- Subscription.init
- Subscription.commandPosition
- Subscription.commandSecondLevelDataAdapter
- Subscription.commandSecondLevelFields
- Subscription.commandSecondLevelFieldSchema
- Subscription.commandValueWithItemPos
- Subscription.commandValueWithItemName
- Subscription.dataAdapter
- Subscription.fields
- Subscription.fieldSchema
- Subscription.itemGroup
- Subscription.items
- Subscription.keyPosition
- Subscription.requestedBufferSize
- Subscription.requestedMaxFrequency
- Subscription.requestedSnapshot
- Subscription.selector
- Subscription.valueWithItemPos
- Subscription.valueWithItemName

The type NSHTTPCookie has been replaced by the type HTTPCookie everywhere, that is in:

- LightstreamerClient.addCookies
- LightstreamerClient.getCookiesForURL

The type NSURL has been replaced by the type URL everywhere, that is in:

- LightstreamerClient.addCookies
- LightstreamerClient.getCookiesForURL


 **In general enumeration types have been used in place of unrestricted strings.** Therefore the signatures of the following methods have been changed. 

- The enumeration TransportSelection has replaced the type String in the property ConnectionOptions.forcedTransport.

- The enumeration RequestedMaxBandwidth has replaced the type String in the property ConnectionOptions.requestedMaxBandwidth.

- The enumeration RealMaxBandwidth has replaced the type String in the property ConnectionOptions.realMaxBandwidth.

- The enumeration ConsoleLogLevel has replaced the constants LSConsoleLogLevelDebug, LSConsoleLogLevelInfo, LSConsoleLogLevelWarn, LSConsoleLogLevelError and LSConsoleLogLevelFatal.

- The enumeration LightstreamerClient.Status has replaced the type String in the property LightstreamerClient.status and in the method ClientDelegate.client(\_:didChangeStatus).

- The enumeration MPNSubscriptionStatus has replaced the type String in the methods LightstreamerClient.unsubscribeMultipleMPN and LightstreamerClient.filterMPNSubscriptions.

- The enumeration MPNDevice.Status has replaced the type String in the property MPNDevice.status and in the method MPNDeviceDelegate.mpnDevice(\_:didChangeStatus:timestamp:).

- The enumeration MPNSubscription.Mode has replaced the type String in the property MPNSubscription.mode and in the constructor of MPNSubscription.

- The enumeration MPNSubscription.RequestedBufferSize has replaced the type String in the property MPNSubscription.requestedBufferSize.

- The enumeration MPNSubscription.RequestedMaxFrequency has replaced the type String in the property MPNSubscription.requestedMaxFrequency.

- The enumeration MPNSubscription.Status has replaced the type String in the property MPNSubscription.status and in the method MPNSubscriptionDelegate.mpnSubscription(\_:didChangeStatus:timestamp).

- The enumeration Subscription.Mode has replaced the type String in the property Subscription.mode and in the constructor of Subscription.

- The enumeration Subscription.RequestedBufferSize has replaced the type String in the property Subscription.requestedBufferSize.

- The enumeration Subscription.RequestedMaxFrequency has replaced the type String in the property Subscription.requestedMaxFrequency.

- The enumeration Subscription.RequestedSnapshot has replaced the type String in the property Subscription.requestedSnapshot.

- The enumeration RealMaxFrequency has replaced the type String in the method SubscriptionDelegate.subscription(\_:didReceiveRealFrequency:).

### Alignment with the other Lightstreamer Client SDKs

The following methods have been removed:

- LightstreamerClient.limitExceptionsUse
- ConnectionOptions.connectTimeout
- ConnectionOptions.currentConnectTimeout
- ConnectionOptions.earlyWSOpenEnabled
- ConnectionOptions.maxConcurrentSessionsPerServer
- ConnectionOptions.maxConcurrentSessionsPerServerExceededPolicy
- ClientDelegate.client(\_:willSendRequestForAuthenticationChallenge:)

The type NSTimeInterval has been replaced by the type Millis everywhere, that is in:

- ConnectionOptions.firstRetryMaxDelay
- ConnectionOptions.idleTimeout
- ConnectionOptions.keepaliveInterval
- ConnectionOptions.pollingInterval
- ConnectionOptions.reconnectTimeout
- ConnectionOptions.retryDelay
- ConnectionOptions.reverseHeartbeatInterval
- ConnectionOptions.sessionRecoveryTimeout
- ConnectionOptions.stalledTimeout
- LightstreamerClient.sendMessage

> **⚠ WARNING**  
> An important consequence of this change is that arguments that represent a time interval are now expressed in milliseconds instead of seconds.

The type NSDate has been replaced by the type Int64, representing a timestamp, everywhere, that is in:

- MPNDevice.statusTimestamp
- MPNDeviceDelegate.mpnDevice(\_:didChangeStatus:timestamp)
- MPNSubscription.statusTimestamp
- MPNSubscriptionDelegate.mpnSubscription(\_:didChangeStatus:timestamp)

### New features

Fully revised and improved the session establishment process and the Stream-Sense algorithm. Now a websocket connection will be tried immediately, without a pre-flight http request; only if websockets turn out to be not supported by the browser/environment will http streaming be tried.
This should significantly reduce the average session establishment time in most scenarios.
The possible cases of wrong diagnosis of websocket unavailability and unnecessary resort to http streaming should also be reduced.
A noticeable consequence of the change is that, when a Load Balancer is in place and a "control link address" is configured on the Server, most of the streaming activity will now be expected on sockets opened towards the balancer endpoint, whereas, before, the whole streaming activity flowed on sockets opened towards the control link address.

As a consequence of the new Stream-Sense algorithm, the "EarlyWSOpenEnabled" property of the ConnectionOptions bean has been removed. This affects its getter and setter and also the invocations of onPropertyChange on the ClientListener.

**COMPATIBILITY NOTE**: Custom code using "EarlyWSOpenEnabled" in any of the mentioned forms has to be modified by removing all references.

### Other API changes

The behavior of the property setters MPNSubscription.triggerExpression and MPNSubscription.notificationFormat has been partially changed. When they are called while an MPNSubscription is "active", a request is sent to the Server in order to change the corresponding parameter. If the request has success, the method `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` will eventually be called. In case of error, the new method `MPNSubscriptionDelegate.mpnSubscription(_:didFailModificationWithErrorCode:message:property:)` will be called instead.
The behavior of the property getters MPNSubscription.triggerExpression and MPNSubscription.notificationFormat has been partially changed as well. If they are called when an MPNSubscription is "inactive", they return the value requested by the user; but if they are called when a MPNSubscription is "active", they return the real value sent by the Server or `nil` if the value is not available.

The behavior of the constructor `MPNSubscription.init(_ mpnSubscription: MPNSubscription)` has been partially changed. It still creates an MPNSubscription object copying all the properties from the specified MPN subscription, but it doesn't copy the property subscriptionId anymore. As a consequence, when the object is supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring it to "active" state, the client creates a new MPN subscription on the Server. Previously any property changed would have replaced the corresponding value of the MPN subscription with the same subscription ID on the server.
