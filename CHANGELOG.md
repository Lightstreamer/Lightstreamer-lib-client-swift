# SDK for Swift Clients CHANGELOG


## 5.0.0 beta 2

_Compatible with Lightstreamer Server since 7.2.0._<br>
_Compatible with code developed with the previous version._<br>
_Released on 27 Aug 2021 ._

Used a custom DispatchQueue instead of DispatchQueue.main to fire the Client delegates.

Changed the signatures of the following methods in order to ease the porting of the code based on the Client SDK 4.x:

- LightstreamerClient.init
- LightstreamerClient.register
- MPNBuilder.init
- MPNBuilder.badge
- MPNBuilder.contentAvailable
- MPNBuilder.mutableContent
- MPNDevice.init
- MPNSubscription.init
- Subscription.init
- ItemUpdate.value
- ItemUpdate.isValueChanged
- MPNDeviceDelegate.mpnDevice
- MPNSubscriptionDelegate.mpnSubscription
- SubscriptionDelegate.subscription
- ConsoleLogger.init
- ConsoleLoggerProvider.init


## 5.0.0 beta 1

_Compatible with Lightstreamer Server since 7.2.0._<br/>
_Not compatible with code developed for the previous versions (i.e. iOS, macOS, tvOS, and watchOS SDKs); see the full list of changes below._<br/>
_Released on 12 Aug 2021 ._

The Swift Client SDK is meant to replace the existing Client SDKs for all the Apple platforms (iOS, macOS, tvOS and watchOS).
The library is now open source, available on GitHub at the following address:

[https://github.com/Lightstreamer/Lightstreamer-lib-client-swift](https://github.com/Lightstreamer/Lightstreamer-lib-client-swift).

The binaries for the various platforms are no longer provided directly, but should be built from the source code.
See the README for details.
Note that the generated binaries may no longer be interoperable with client applications written in Objective-C.

With respect to the replaced Client SDKs, which were written in Objective-C, the Client API has undergone several changes belonging to the following categories:

1. changes to make the API more Swift-friendly
2. changes to align the API with the other Lightstreamer Client SDKs
3. changes to add new features and to improve the usability.

### Changes to make the API more Swift-friendly

The prefix LS has been removed from the names of all the public types, that is from:

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
> Only the classes LSLogger and LSLoggerProvider have kept their names, to avoid name clashes with Foundation classes concerning the logging subsystem. 

All methods and property setters that used to raise exceptions to validate their arguments are now guarded by preconditions. To resume, this applies to:

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
- LightstreamerClient.register
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

Now exceptions are no longer thrown by library code.
As a consequence, the LightstreamerClient.limitExceptionsUse method has been removed.

The type NSHTTPCookie has been replaced by the type HTTPCookie everywhere, that is in:

- LightstreamerClient.addCookies
- LightstreamerClient.getCookiesForURL

The type NSURL has been replaced by the type URL everywhere, that is in:

- LightstreamerClient.addCookies
- LightstreamerClient.getCookiesForURL

In general, enumeration types have been used in place of unrestricted strings. The following are the enumeration types introduced and the related signature changes:

- TransportSelection is now used for property ConnectionOptions.forcedTransport.
- RequestedMaxBandwidth is now used for property ConnectionOptions.requestedMaxBandwidth.
- RealMaxBandwidth is now used for property ConnectionOptions.realMaxBandwidth.
- ConsoleLogLevel is now used for constants LSConsoleLogLevelDebug, LSConsoleLogLevelInfo, LSConsoleLogLevelWarn, LSConsoleLogLevelError and LSConsoleLogLevelFatal.
- LightstreamerClient.Status is now used for property LightstreamerClient.status and for method ClientDelegate.client(\_:didChangeStatus).
- MPNSubscriptionStatus is now used for methods LightstreamerClient.unsubscribeMultipleMPN and LightstreamerClient.filterMPNSubscriptions.
- MPNDevice.Status is now used for property MPNDevice.status and for method MPNDeviceDelegate.mpnDevice(\_:didChangeStatus:timestamp:).
- MPNSubscription.Mode is now used for property MPNSubscription.mode and for constructor of MPNSubscription.
- MPNSubscription.RequestedBufferSize is now used for property MPNSubscription.requestedBufferSize.
- MPNSubscription.RequestedMaxFrequency is now used for property MPNSubscription.requestedMaxFrequency.
- MPNSubscription.Status is now used for property MPNSubscription.status and for method MPNSubscriptionDelegate.mpnSubscription(\_:didChangeStatus:timestamp).
- Subscription.Mode is now used for in the property Subscription.mode and for constructor of Subscription.
- Subscription.RequestedBufferSize is now used for property Subscription.requestedBufferSize.
- Subscription.RequestedMaxFrequency is now used for property Subscription.requestedMaxFrequency.
- Subscription.RequestedSnapshot is now used for property Subscription.requestedSnapshot.
- RealMaxFrequency is now used for method SubscriptionDelegate.subscription(\_:didReceiveRealFrequency:).

### Alignment with the other Lightstreamer Client SDKs

The connectTimeout and currentConnectTimeout properties of the ConnectionOptions class, which were deprecated, have been removed.

The maxConcurrentSessionsPerServer and maxConcurrentSessionsPerServerExceededPolicy properties of the ConnectionOptions class, have been removed.
It is now an application responsibility to prevent the opening of too many sessions in case the client environment is not able to keep too many TCP connections concurrently open.
Note that as long as the system limit is exceeded some TCP connection may become mute.

The client(\_:willSendRequestForAuthenticationChallenge:) callback in ClientDelegate has been removed.
It was available to accept self-signed certificates upon TLS connections, for testing purpose.
Currently, this facility is not provided.

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

The type NSDate has been replaced by the type Int64, representing a server-side timestamp, everywhere, that is in:

- MPNDevice.statusTimestamp
- MPNDeviceDelegate.mpnDevice(\_:didChangeStatus:timestamp)
- MPNSubscription.statusTimestamp
- MPNSubscriptionDelegate.mpnSubscription(\_:didChangeStatus:timestamp)

### New features

Fully revised and improved the session establishment process and the Stream-Sense algorithm. Now a websocket connection will be tried immediately, without a pre-flight http request; only if websockets turn out to be not supported by the browser/environment will http streaming be tried.
This should significantly reduce the average session establishment time in most scenarios.
The possible cases of wrong diagnosis of websocket unavailability and unnecessary resort to http streaming should also be reduced.
A noticeable consequence of the change is that, when a Load Balancer is in place and a "control link address" is configured on the Server, most of the streaming activity will now be expected on sockets opened towards the balancer endpoint, whereas, before, the whole streaming activity flowed on sockets opened towards the control link address.

As a consequence of the new Stream-Sense algorithm, the "earlyWSOpenEnabled" property of the ConnectionOptions class has been removed.

### Other API changes

The behavior of the property setters MPNSubscription.triggerExpression and MPNSubscription.notificationFormat has been partially changed. When they are called while an MPNSubscription is "active", a request is sent to the Server in order to change the corresponding parameter. If the request has success, the method `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` will eventually be called. In case of error, the new method `MPNSubscriptionDelegate.mpnSubscription(_:didFailModificationWithErrorCode:message:property:)` will be called instead.
The behavior of the property getters MPNSubscription.triggerExpression and MPNSubscription.notificationFormat has been partially changed as well. If they are called when an MPNSubscription is "inactive", they return the value requested by the user; but if they are called when a MPNSubscription is "active", they return the real value sent by the Server or `nil` if the value is not available.

The behavior of the constructor `MPNSubscription.init(_ mpnSubscription: MPNSubscription)` has been partially changed. It still creates an MPNSubscription object copying all the properties from the specified MPN subscription, but it doesn't copy the property subscriptionId anymore. As a consequence, when the object is supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring it to "active" state, the client creates a new MPN subscription on the Server. Previously any property changed would have replaced the corresponding value of the MPN subscription with the same subscription ID on the server.
