import Foundation

/**
 Protocol to be implemented to receive `LightstreamerClient` events comprehending notifications of connection activity and errors.

 Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event,
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single `LightstreamerClient`, including
 notifications to LSClientDelegate, `SubscriptionDelegate`, `ClientMessageDelegate`, `MPNDeviceDelegate` and `MPNSubscriptionDelegate`, will be dispatched by the same thread.
 */
public protocol ClientDelegate: AnyObject {
    /**
     Event handler that receives a notification when the LSClientDelegate instance is removed from a `LightstreamerClient` through
     `LightstreamerClient.removeDelegate(_:)`.

     This is the last event to be fired on the delegate.

     - Parameter client: The `LightstreamerClient` this instance was removed from.
     */
    func clientDidRemoveDelegate(_ client: LightstreamerClient)
    /**
     Event handler that receives a notification when the LSClientDelegate instance is added to a `LightstreamerClient` through
     `LightstreamerClient.addDelegate(_:)`.

     This is the first event to be fired on the delegate.

     - Parameter client: The `LightstreamerClient` this instance was added to.
     */
    func clientDidAddDelegate(_ client: LightstreamerClient)
    /**
     Event handler that is called when the Server notifies a refusal on the client attempt to open a new connection or the interruption of a streaming connection.

     In both cases, the `client(_:didChangeStatus:)` event handler has already been invoked with a `DISCONNECTED` status and no
     recovery attempt has been performed. By setting a custom handler, however, it is possible to override this and perform custom recovery actions.

     The error code can be one of the following:

     - 1 - user/password check failed

     - 2 - requested Adapter Set not available

     - 7 - licensed maximum number of sessions reached (this can only happen with some licenses)

     - 8 - configured maximum number of sessions reached

     - 9 - configured maximum server load reached

     - 10 - new sessions temporarily blocked

     - 11 - streaming is not available because of Server license restrictions (this can only happen with special licenses).

     - 21 - a request for this session has unexpectedly reached a wrong Server instance, which suggests that a routing issue may be in place.

     - 30-41 - the current connection or the whole session has been closed by external agents; the possible cause may be:

     - The session was closed on the Server side (via software or by the administrator) (32), or through a client "destroy" request (31);

     - The Metadata Adapter imposes limits on the overall open sessions for the current user and has requested the closure of the current session upon opening
       of a new session for the same user on a different browser window (35);

     - An unexpected error occurred on the Server while the session was in activity (33, 34);

     - An unknown or unexpected cause; any code different from the ones identified in the above cases could be issued. A detailed description for the specific
       cause is currently not supplied (i.e. errorMessage is nil in this case).

     - 60 - this version of the client is not allowed by the current license terms.

     - 61 - there was an error in the parsing of the server response thus the client cannot continue with the current session.

     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.

     - 68 - the Server could not open or continue with the session because of an internal error.
     
     - 70 - an unusable port was configured on the server address.
     
     - 71 - this kind of client is not allowed by the current license terms.

     - `<=` 0 - the Metadata Adapter has refused the user connection; the code value is dependent on the specific Metadata Adapter implementation

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter errorCode: The error code.

     - Parameter errorMessage: The description of the error as sent by the Server.

     - SeeAlso: `client(_:didChangeStatus:)`

     - SeeAlso: `ConnectionDetails.adapterSet`
     */
    func client(_ client: LightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String)
    /**
     Event handler that receives a notification each time the `LightstreamerClient` status has changed.

     The status changes may be originated either by custom actions (e.g. by calling `LightstreamerClient.disconnect()`) or by internal actions. The normal cases are the following:

     - After issuing `LightstreamerClient.connect()`, if the current status is `DISCONNECTED*`, the client will switch to `CONNECTING` first and to `CONNECTED:STREAM-SENSING` as soon as the pre-flight request receives its answer. As soon as the new session is established, it will switch to `CONNECTED:WS-STREAMING` if the environment permits WebSockets; otherwise it will switch to `CONNECTED:HTTP-STREAMING` if the environment permits streaming or to `CONNECTED:HTTP-POLLING` as a last resort. On the other hand if the status is already `CONNECTED:*` a switch to `CONNECTING` is usually not needed.

     - After issuing `LightstreamerClient.disconnect()`, the status will switch to `DISCONNECTED`.

     - In case of a server connection refusal, the status may switch from `CONNECTING` directly to `DISCONNECTED`. After that, the `client(_:didReceiveServerError:withMessage:)` event handler will be invoked.

     Possible special cases are the following:

     - In case of Server unavailability during streaming, the status may switch from `CONNECTED:*-STREAMING` to `STALLED` (see `ConnectionOptions.stalledTimeout`). If the unavailability ceases, the status will switch back to `CONNECTED:*-STREAMING`; otherwise, if the unavailability persists (see `ConnectionOptions.reconnectTimeout`), the status will switch to `DISCONNECTED:TRYING-RECOVERY` and eventually to `CONNECTED:*-STREAMING`.

     - In case the connection or the whole session is forcibly closed by the Server, the status may switch from `CONNECTED:*-STREAMING` or `CONNECTED:*-POLLING` directly to `DISCONNECTED`. After that, the `client(_:didReceiveServerError:withMessage:)` event handler will be invoked.

     - Depending on the setting in `ConnectionOptions.slowingEnabled`, in case of slow update processing, the status may switch from `CONNECTED:WS-STREAMING` to `CONNECTED:WS-POLLING` or from `CONNECTED:HTTP-STREAMING` to `CONNECTED:HTTP-POLLING`.

     - If the status is `CONNECTED:*-POLLING` and any problem during an intermediate poll occurs, the status may switch to `CONNECTING` and eventually to `CONNECTED:*-POLLING`. The same may hold for the `CONNECTED:*-STREAMING` case, when a rebind is needed.

     - In case a forced transport was set through `ConnectionOptions.forcedTransport`, only the related final status or statuses are possible.

     - In case of connection problems, the status may switch from any value to `DISCONNECTED:WILL-RETRY` (see `ConnectionOptions.retryDelay`), then to `CONNECTING` and a new attempt will start. However, in most cases, the client will try to recover the current session; hence, the `DISCONNECTED:TRYING-RECOVERY` status will be entered and the recovery attempt will start.
     
     - In case of connection problems during a recovery attempt, the status may stay in `DISCONNECTED:TRYING-RECOVERY` for long time, while further attempts are made. If the recovery is no longer possible, the current session will be abandoned and the status will switch to `DISCONNECTED:WILL-RETRY` before the next attempts.

     By setting a custom handler it is possible to perform actions related to connection and disconnection occurrences. Note that `LightstreamerClient.connect()` and `LightstreamerClient.disconnect()`, as any other method, can be issued directly from within a handler.
     
     The full list of possible new statuses is the following:
     
     - `CONNECTING` the client has started a connection attempt and is waiting for a Server answer.
     
     - `CONNECTED:STREAM-SENSING` the client received a first response from the server and is now evaluating if
       a streaming connection is fully functional.
     
     - `CONNECTED:WS-STREAMING` a streaming connection over WebSocket has been established.
     
     - `CONNECTED:HTTP-STREAMING` a streaming connection over HTTP has been established.
     
     - `CONNECTED:WS-POLLING` a polling connection over WebSocket has been started. Note that, unlike polling over
       HTTP, in this case only one connection is actually opened (see `ConnectionOptions.slowingEnabled`).
     
     - `CONNECTED:HTTP-POLLING` a polling connection over HTTP has been started.
     
     - `STALLED` a streaming session has been silent for a while, the status will eventually return to its previous
       `CONNECTED:*-STREAMING` status or will switch to `DISCONNECTED:WILL-RETRY` / `DISCONNECTED:TRYING-RECOVERY`.
     
     - `DISCONNECTED:WILL-RETRY` a connection or connection attempt has been closed; a new attempt will be
       performed (possibly after a timeout).
     
     - `DISCONNECTED:TRYING-RECOVERY` a connection has been closed and the client has started a connection attempt and
       is waiting for a Server answer; if successful, the underlying session will be kept.
     
     - `DISCONNECTED` a connection or connection attempt has been closed. The client will not connect anymore until
       a new `LightstreamerClient.connect()` call is issued.
     
     **Platform limitations:** On watchOS the WebSocket transport is not available.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter status: The new status.

     - SeeAlso: `LightstreamerClient.connect()`

     - SeeAlso: `LightstreamerClient.disconnect()`

     - SeeAlso: `LightstreamerClient.status`
     */
    func client(_ client: LightstreamerClient, didChangeStatus status: LightstreamerClient.Status)
    /**
     Event handler that receives a notification each time the value of a property of `LightstreamerClient.connectionDetails` or
     `LightstreamerClient.connectionOptions` is changed.

     Properties of these objects can be modified by direct calls to them or by server sent events. Possible property names are the following:

     - `adapterSet`

     - `serverAddress`

     - `user`

     - `password`

     - `serverInstanceAddress`

     - `serverSocketName`

     - `clientIp`

     - `sessionId`

     - `contentLength`

     - `idleTimeout`

     - `keepaliveInterval`

     - `requestedMaxBandwidth`

     - `realMaxBandwidth`

     - `pollingInterval`

     - `reconnectTimeout`

     - `stalledTimeout`

     - `retryDelay`

     - `firstRetryMaxDelay`

     - `slowingEnabled`

     - `forcedTransport`

     - `serverInstanceAddressIgnored`

     - `reverseHeartbeatInterval`

     - `earlyWSOpenEnabled`

     - `HTTPExtraHeaders`

     - `HTTPExtraHeadersOnSessionCreationOnly`

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter property: The name of the changed property.

     - SeeAlso: `LightstreamerClient.connectionDetails`

     - SeeAlso: `LightstreamerClient.connectionOptions`
     */
    func client(_ client: LightstreamerClient, didChangeProperty property: String)
}

/**
 Protocol to be implemented to receive `LightstreamerClient.sendMessage(_:withSequence:timeout:delegate:enqueueWhileDisconnected:)` events reporting a message
 processing outcome.

 Events for these delegates are dispatched by a different thread than the one that generates them. All the notifications for a single `LightstreamerClient`,
 including notifications to `ClientDelegate`, `SubscriptionDelegate`, `ClientMessageDelegate`, `MPNDeviceDelegate` and `MPNSubscriptionDelegate`, will be dispatched by the same thread. Only one event per message is fired on this delegate.
 */
public protocol ClientMessageDelegate: AnyObject {
    /**
     Event handler that is called by Lightstreamer when any notifications of the processing outcome of the related message haven't been received yet and
     can no longer be received.

     Typically, this happens after the session has been closed. In this case, the client has no way of knowing the processing outcome and any outcome is possible.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter originalMessage: The message to which this notification is related.

     - Parameter sentOnNetwork: `true` if the message was sent on the network, `false` otherwise. Even if the flag is `true`, it is not possible to infer whether the message actually reached the Lightstreamer Server or not.
     */
    func client(_ client: LightstreamerClient, didAbortMessage originalMessage: String, sentOnNetwork: Bool)
    /**
     Event handler that is called by Lightstreamer when the related message has been processed by the Server but the expected processing outcome could
     not be achieved for any reason.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter originalMessage: The message to which this notification is related.

     - Parameter code: The error code sent by the Server. The code value is dependent on the specific Metadata Adapter implementation.

     - Parameter error: The description of the error sent by the Server.
     */
    func client(_ client: LightstreamerClient, didDenyMessage originalMessage: String, withCode code: Int, error: String)
    /**
     Event handler that is called by Lightstreamer to notify that the related message has been discarded by the Server.

     This means that the message has not reached the Metadata Adapter and the message next in the sequence is considered enabled for processing.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter originalMessage: The message to which this notification is related.
     */
    func client(_ client: LightstreamerClient, didDiscardMessage originalMessage: String)
    /**
     Event handler that is called by Lightstreamer when the related message has been processed by the Server but the processing has failed for any reason.

     The level of completion of the processing by the Metadata Adapter cannot be determined.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter originalMessage: The message to which this notification is related.
     */
    func client(_ client: LightstreamerClient, didFailMessage originalMessage: String)
    /**
     Event handler that is called by Lightstreamer when the related message has been processed by the Server with success.

     - Parameter client: The `LightstreamerClient` instance.

     - Parameter originalMessage: The message to which this notification is related.
     
     - Parameter response: The response from the Metadata Adapter. If not supplied (i.e. supplied as nil), an empty message is received here.
     */
    func client(_ client: LightstreamerClient, didProcessMessage originalMessage: String, withResponse response: String)
}

protocol Encodable {
    func isPending() -> Bool
    func encode(isWS: Bool) -> String
    func encodeWS() -> String
}

class SwitchRequest: Encodable {
    unowned let client: LightstreamerClient
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    func isPending() -> Bool {
        client.s_m == .s150 && client.s_swt == .s1302
    }
    
    func encode(isWS: Bool) -> String {
        client.encodeSwitch(isWS: isWS)
    }
    
    func encodeWS() -> String {
        "control\r\n\(encode(isWS: true))"
    }
}

class ConstrainRequest: Encodable {
    unowned let client: LightstreamerClient
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    func isPending() -> Bool {
        client.s_bw == .s1202
    }
    
    func encode(isWS: Bool) -> String {
        client.encodeConstrain()
    }
    
    func encodeWS() -> String {
        "control\r\n\(encode(isWS: true))"
    }
}

class MpnRegisterRequest: Encodable {
    unowned let client: LightstreamerClient
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    func isPending() -> Bool {
        client.s_mpn.m == .s403 || client.s_mpn.m == .s406 || client.s_mpn.tk == .s453
    }
    
    func encode(isWS: Bool) -> String {
        if client.s_mpn.m == .s403 {
            return client.encodeMpnRegister()
        } else if client.s_mpn.m == .s406 {
            return client.encodeMpnRestore()
        } else if client.s_mpn.tk == .s453 {
            return client.encodeMpnRefreshToken()
        } else {
            fatalError()
        }
    }
    
    func encodeWS() -> String {
        "control\r\n\(encode(isWS: true))"
    }
}

class MpnFilterUnsubscriptionRequest: Encodable {
    unowned let client: LightstreamerClient
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    func isPending() -> Bool {
        client.s_mpn.ft == .s432
    }
    
    func encode(isWS: Bool) -> String {
        if isPending() {
            return client.encodeDeactivateFilter()
        } else {
            fatalError()
        }
    }
    
    func encodeWS() -> String {
        "control\r\n\(encode(isWS: true))"
    }
}

class MpnBadgeResetRequest: Encodable {
    unowned let client: LightstreamerClient
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    func isPending() -> Bool {
        client.s_mpn.bg == .s442
    }
    
    func encode(isWS: Bool) -> String {
        if isPending() {
            return client.encodeBadgeReset()
        } else {
            fatalError()
        }
    }
    
    func encodeWS() -> String {
        "control\r\n\(encode(isWS: true))"
    }
}

protocol State {
    var id: Int {get}
}

enum State_m: Int, State {
    case s100 = 100, s101 = 101
    case s110 = 110, s111 = 111, s112 = 112, s113 = 113, s114 = 114, s115 = 115, s116 = 116
    case s120 = 120, s121 = 121, s122 = 122
    case s130 = 130
    case s140 = 140
    case s150 = 150

    var id: Int {
        self.rawValue
    }
}

enum State_du: Int, State {
    case s20 = 20, s21 = 21, s22 = 22, s23 = 23

    var id: Int {
        self.rawValue
    }
}

enum State_tr: Int, State {
    case s200 = 200, s210 = 210, s220 = 220, s230 = 230, s240 = 240, s250 = 250, s260 = 260, s270 = 270

    var id: Int {
        self.rawValue
    }
}

enum State_h: Int, State {
    case s710 = 710, s720 = 720

    var id: Int {
        self.rawValue
    }
}

enum State_ctrl: Int, State {
    case s1100 = 1100, s1101 = 1101, s1102 = 1102, s1103 = 1103

    var id: Int {
        self.rawValue
    }
}

enum State_swt: Int, State {
    case s1300 = 1300, s1301 = 1301, s1302 = 1302, s1303 = 1303

    var id: Int {
        self.rawValue
    }
}

enum State_rhb: Int, State {
    case s320 = 320, s321 = 321, s322 = 322, s323 = 323, s324 = 324

    var id: Int {
        self.rawValue
    }
}

enum State_slw: Int, State {
    case s330 = 330, s331 = 331, s332 = 332, s333 = 333, s334 = 334

    var id: Int {
        self.rawValue
    }
}

enum State_w_p: Int, State {
    case s300 = 300

    var id: Int {
        self.rawValue
    }
}

enum State_w_k: Int, State {
    case s310 = 310, s311 = 311, s312 = 312

    var id: Int {
        self.rawValue
    }
}

enum State_w_s: Int, State {
    case s340 = 340

    var id: Int {
        self.rawValue
    }
}

enum State_ws_m: Int, State {
    case s500 = 500, s501 = 501, s502 = 502, s503 = 503

    var id: Int {
        self.rawValue
    }
}

enum State_ws_p: Int, State {
    case s510 = 510

    var id: Int {
        self.rawValue
    }
}

enum State_ws_k: Int, State {
    case s520 = 520, s521 = 521, s522 = 522

    var id: Int {
        self.rawValue
    }
}

enum State_ws_s: Int, State {
    case s550 = 550

    var id: Int {
        self.rawValue
    }
}

enum State_wp_m: Int, State {
    case s600 = 600, s601 = 601, s602 = 602

    var id: Int {
        self.rawValue
    }
}

enum State_wp_p: Int, State {
    case s610 = 610, s611 = 611, s612 = 612, s613 = 613

    var id: Int {
        self.rawValue
    }
}

enum State_wp_c: Int, State {
    case s620 = 620

    var id: Int {
        self.rawValue
    }
}

enum State_wp_s: Int, State {
    case s630 = 630

    var id: Int {
        self.rawValue
    }
}

enum State_hs_m: Int, State {
    case s800 = 800, s801 = 801, s802 = 802

    var id: Int {
        self.rawValue
    }
}

enum State_hs_p: Int, State {
    case s810 = 810, s811 = 811

    var id: Int {
        self.rawValue
    }
}

enum State_hs_k: Int, State {
    case s820 = 820, s821 = 821, s822 = 822

    var id: Int {
        self.rawValue
    }
}

enum State_hp_m: Int, State {
    case s900 = 900, s901 = 901, s902 = 902, s903 = 903, s904 = 904

    var id: Int {
        self.rawValue
    }
}

enum State_rec: Int, State {
    case s1000 = 1000, s1001 = 1001, s1002 = 1002, s1003 = 1003

    var id: Int {
        self.rawValue
    }
}

enum State_bw: Int, State {
    case s1200 = 1200, s1201 = 1201, s1202 = 1202

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_m: Int, State {
    case s400 = 400, s401 = 401, s402 = 402, s403 = 403, s404 = 404, s405 = 405, s406 = 406, s407 = 407, s408 = 408

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_st: Int, State {
    case s410 = 410, s411 = 411

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_tk: Int, State {
    case s450 = 450, s451 = 451, s452 = 452, s453 = 453, s454 = 454

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_sbs: Int, State {
    case s420 = 420, s421 = 421, s422 = 422, s423 = 423, s424 = 424, s425 = 425

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_ft: Int, State {
    case s430 = 430, s431 = 431, s432 = 432

    var id: Int {
        self.rawValue
    }
}

enum State_mpn_bg: Int, State {
    case s440 = 440, s441 = 441, s442 = 442

    var id: Int {
        self.rawValue
    }
}

class StateVar_w {
    var p: State_w_p
    var k: State_w_k
    var s: State_w_s
    
    init(p: State_w_p, k: State_w_k, s: State_w_s) {
        self.p = p
        self.k = k
        self.s = s
    }
}

class StateVar_ws {
    var m: State_ws_m
    var p: State_ws_p!
    var k: State_ws_k!
    var s: State_ws_s!
    
    init(m: State_ws_m) {
        self.m = m
    }
}

class StateVar_wp {
    var m: State_wp_m
    var p: State_wp_p!
    var c: State_wp_c!
    var s: State_wp_s!
    
    init(m: State_wp_m) {
        self.m = m
    }
}

class StateVar_hs {
    var m: State_hs_m
    var p: State_hs_p!
    var k: State_hs_k!
    
    init(m: State_hs_m) {
        self.m = m
    }
}

class StateVar_hp {
    var m: State_hp_m
    
    init(m: State_hp_m) {
        self.m = m
    }
}

class StateVar_mpn {
    var m: State_mpn_m = .s400
    var st: State_mpn_st!
    var tk: State_mpn_tk!
    var sbs: State_mpn_sbs!
    var ft: State_mpn_ft!
    var bg: State_mpn_bg!
}

enum State_nr: Int, State {
    case s1400 = 1400, s1410 = 1410, s1411 = 1411, s1412 = 1412
    
    var id: Int {
        self.rawValue
    }
}

typealias Timestamp = UInt64

func randomInt(_ n: Int) -> Int {
    Int.random(in: 0...n)
}

/**
 Façade class for the management of the communication to Lightstreamer Server.

 Used to provide configuration settings, event handlers, operations for the control of the connection lifecycle, subscription handling and to send messages.
 */
public class LightstreamerClient {
    
    /**
     Client status and transport (when applicable).
     */
    public enum Status: String, CustomStringConvertible {
        /**
         The client is waiting for a Server's response in order to establish a connection.
         */
        case CONNECTING = "CONNECTING"
        /**
         The client has received a preliminary response from the server and is currently verifying if a streaming connection is possible.
         */
        case CONNECTED_STREAM_SENSING = "CONNECTED:STREAM-SENSING"
        /**
         A streaming connection over WebSocket is active.
         */
        case CONNECTED_WS_STREAMING = "CONNECTED:WS-STREAMING"
        /**
         A streaming connection over HTTP is active.
         */
        case CONNECTED_HTTP_STREAMING = "CONNECTED:HTTP-STREAMING"
        /**
         A polling connection over WebSocket is in progress.
         */
        case CONNECTED_WS_POLLING = "CONNECTED:WS-POLLING"
        /**
         A polling connection over HTTP is in progress.
         */
        case CONNECTED_HTTP_POLLING = "CONNECTED:HTTP-POLLING"
        /**
         The Server has not been sending data on an active streaming connection for longer than a configured time.
         */
        case STALLED = "STALLED"
        /**
         No connection is currently active but one will be opened (possibly after a timeout).
         */
        case DISCONNECTED_WILL_RETRY = "DISCONNECTED:WILL-RETRY"
        /**
         No connection is currently active, but one will be opened as soon as possible, as an attempt to recover the current session after a connection issue.
         */
        case DISCONNECTED_TRYING_RECOVERY = "DISCONNECTED:TRYING-RECOVERY"
        /**
         No connection is currently active.
         */
        case DISCONNECTED = "DISCONNECTED"
        
        public var description: String {
            self.rawValue
        }
    }
    
    /**
     A status filter to unsubscribe multiple MPN subscriptions at once. E.g. by passing `TRIGGERED` it is possible
     to unsubscribe all triggered MPN subscriptions.
     */
    public enum MPNSubscriptionStatus {
        /**
         All MPN subscriptions.
         */
        case ALL
        /**
         Subscribed subscriptions.
         */
        case SUBSCRIBED
        /**
         Triggered subscriptions.
         */
        case TRIGGERED
    }
    
    static let IS_ACTIVE = "Cannot subscribe to an active Subscription"
    static let NO_ITEMS = "Specify property 'items' or 'itemGroup'"
    static let NO_FIELDS = "Specify property 'fields' or 'fieldSchema'"
    static let IS_ACTIVE_MPN = "Cannot subscribe to an active MPNSubscription"
    static let NO_DEVICE = "No MPNDevice Registered"
    static let NO_FORMAT = "Specify property 'notificationFormat'"
    //
    let lock = NSRecursiveLock()
    var m_details: ConnectionDetails!
    var m_options: ConnectionOptions!
    let callbackQueue = defaultQueue
    let multicastDelegate = MulticastDelegate<ClientDelegate>()
    // resource factories
    let wsFactory: WSFactoryService
    let httpFactory: HTTPFactoryService
    let ctrlFactory: HTTPFactoryService
    let scheduler: ScheduleService
    let randomGenerator: (Int) -> Int
    // attributes
    let delayCounter: RetryDelayCounter
    var m_status: Status = .DISCONNECTED
    var m_nextReqId: Int = 0
    var m_nextSubId: Int = 0
    var defaultServerAddress: String!
    var requestLimit: Int!
    var keepaliveInterval: Millis!
    var idleTimeout: Millis!
    var sessionId: String!
    var serverInstanceAddress: String!
    var lastKnownClientIp: String?
    var cause: String?
    var connectTs: Timestamp = 0
    var recoverTs: Timestamp = 0
    var suspendedTransports: Set<TransportSelection> = Set()
    var disabledTransports: Set<TransportSelection> = Set()
    //
    var sequenceMap: [String:Int] = [:]
    var messageManagers: [MessageManager] = []
    //
    var subscriptionManagers: OrderedDictionary<Int, SubscriptionManager> = OrderedDictionary()
    //
    var switchRequest: SwitchRequest!
    var constrainRequest: ConstrainRequest!
    var mpnRegisterRequest: MpnRegisterRequest!
    var mpnFilterUnsubscriptionRequest: MpnFilterUnsubscriptionRequest!
    var mpnBadgeResetRequest: MpnBadgeResetRequest!
    //
    var ctrl_connectTs: Timestamp = 0
    //
    var swt_lastReqId: Int!
    //
    var rhb_grantedInterval: Millis!
    var rhb_currentInterval: Millis!
    //
    var bw_requestedMaxBandwidth: RequestedMaxBandwidth?
    var bw_lastReqId: Int?
    //
    let reachabilityManagerFactory: ReachabilityServiceFactory
    var nr_reachabilityManager: ReachabilityService?
    //
    var rec_serverProg: Int = 0
    var rec_clientProg: Int = 0
    //
    var slw_refTime: Timestamp = 0
    var slw_avgDelayMs: Int64 = 0
    let slw_maxAvgDelayMs: Int64 = 7_000
    let slw_hugeDelayMs: Int64 = 20_000
    let slw_m: Double = 0.5
    //
    var mpnSubscriptionManagers = [MpnSubscriptionManager]()
    var mpn_device: MPNDevice!
    var mpn_deviceId: String!
    var mpn_deviceToken: String!
    var mpn_adapterName: String!
    var mpn_lastRegisterReqId: Int!
    var mpn_candidate_devices = [MPNDevice]()
    var mpn_deviceSubscription: Subscription!
    var mpn_itemSubscription: Subscription!
    var mpn_deviceListener: MpnDeviceDelegate!
    var mpn_itemListener: MpnItemDelegate!
    var mpn_snapshotSet = Set<String>()
    var mpn_filter_pendings = [MPNSubscriptionStatus]()
    var mpn_filter_lastDeactivateReqId: Int!
    var mpn_badge_reset_requested = false
    var mpn_badge_lastResetReqId: Int!
    // connections
    var ws: LsWebsocketClient!
    var http: LsHttpClient!
    var ctrl_http: LsHttpClient!
    // timeouts
    var transportTimer: Scheduler.Task!
    var retryTimer: Scheduler.Task!
    var keepaliveTimer: Scheduler.Task!
    var stalledTimer: Scheduler.Task!
    var reconnectTimer: Scheduler.Task!
    var rhbTimer: Scheduler.Task!
    var recoveryTimer: Scheduler.Task!
    var idleTimer: Scheduler.Task!
    var pollingTimer: Scheduler.Task!
    var ctrlTimer: Scheduler.Task!
    // state variables
    var s_m: State_m
    var s_du: State_du
    var s_tr: State_tr!
    var s_w: StateVar_w!
    var s_ws: StateVar_ws!
    var s_wp: StateVar_wp!
    var s_hs: StateVar_hs!
    var s_hp: StateVar_hp!
    var s_rec: State_rec!
    var s_h: State_h!
    var s_ctrl: State_ctrl!
    var s_swt: State_swt!
    var s_bw: State_bw!
    var s_rhb: State_rhb!
    var s_slw: State_slw!
    var s_mpn: StateVar_mpn = StateVar_mpn()
    var s_nr: State_nr

    private func disposeSession() {
        disposeWS()
        disposeHTTP()
        disposeCtrl()
        
        m_details.m_serverInstanceAddress = nil
        m_details.m_serverSocketName = nil
        m_details.m_clientIp = nil
        m_details.m_sessionId = nil
        m_options.m_realMaxBandwidth = nil
        
        lastKnownClientIp = nil
        
        resetSequenceMap()
        
        rec_serverProg = 0
        rec_clientProg = 0
        
        bw_lastReqId = nil
        bw_requestedMaxBandwidth = nil
        
        swt_lastReqId = nil
    }

    private func disposeClient() {
        sessionId = nil
        enableAllTransports()
        resetCurrentRetryDelay()
        resetSequenceMap()
        cause = nil
    }
    
    func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    func synchronized<T>(block: () throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try block()
    }
    
    func fireDidChangeProperty(_ property: String) {
        multicastDelegate.invokeDelegates { delegate in
            callbackQueue.async {
                delegate.client(self, didChangeProperty: property)
            }
        }
    }

    /**
     Creates an object to be configured to connect to a Lightstreamer server and to handle all the communications with it.

     Each LightstreamerClient is the entry point to connect to a Lightstreamer server, subscribe to as many items as needed and to send messages.

     - Parameter serverAddress: The address of the Lightstreamer Server to which this LightstreamerClient will connect to.
     It is possible to specify it later by using nil here. See `ConnectionDetails.serverAddress` for details.

     - Parameter adapterSet: The name of the Adapter Set mounted on Lightstreamer Server to be used to handle all requests in the Session associated with this LightstreamerClient. It is possible not to specify it at all or to specify it later by using nil here. See `ConnectionDetails.adapterSet` for details.

     - Precondition: the address must be valid. See `ConnectionDetails.serverAddress` for details.
     */
    public convenience init(serverAddress: String?, adapterSet: String? = nil) {
        self.init(serverAddress,
                  adapterSet: adapterSet,
                  wsFactory: createWS,
                  httpFactory: createHTTP,
                  ctrlFactory: createHTTP,
                  scheduler: Scheduler(),
                  randomGenerator: randomInt,
                  reachabilityFactory: createReachabilityManager)
    }
    
    init(_ serverAddress: String?,
         adapterSet: String? = nil,
         wsFactory: @escaping WSFactoryService,
         httpFactory: @escaping HTTPFactoryService,
         ctrlFactory: @escaping HTTPFactoryService,
         scheduler: ScheduleService,
         randomGenerator: @escaping (Int) -> Int,
         reachabilityFactory: @escaping ReachabilityServiceFactory) {
        s_m = .s100
        s_du = .s20
        s_nr = .s1400
        delayCounter = RetryDelayCounter()
        self.wsFactory = wsFactory
        self.httpFactory = httpFactory
        self.ctrlFactory = ctrlFactory
        self.scheduler = scheduler
        self.randomGenerator = randomGenerator
        self.reachabilityManagerFactory = reachabilityFactory
        m_details = ConnectionDetails(self)
        m_options = ConnectionOptions(self)
        switchRequest = SwitchRequest(self)
        constrainRequest = ConstrainRequest(self)
        mpnRegisterRequest = MpnRegisterRequest(self)
        mpnFilterUnsubscriptionRequest = MpnFilterUnsubscriptionRequest(self)
        mpnBadgeResetRequest = MpnBadgeResetRequest(self)
        delayCounter.reset(m_options.m_retryDelay)
        if let serverAddress = serverAddress {
            m_details.serverAddress = serverAddress
        }
        if let adapterSet = adapterSet {
            m_details.adapterSet = adapterSet
        }
    }
    
    /**
     A constant string representing the name of the library.
     */
    public static let LIB_NAME: String = LS_LIB_NAME
    
    /**
     A constant string representing the version of the library.
     */
    public static let LIB_VERSION: String = LS_LIB_VERSION
    
    /**
     Static method that permits to configure the logging system used by the library.

     The logging system must respect the `LSLoggerProvider` interface. A custom class can be used to wrap any third-party logging system.

     If no logging system is specified, all the generated log is discarded.

     The following categories are available to be consumed:

     - `lightstreamer.stream`: logs socket activity on Lightstreamer Server connections;

       - at INFO level, socket operations are logged;

       - at DEBUG level, read/write data exchange is logged.

     - `lightstreamer.protocol`: logs requests to Lightstreamer Server and Server answers;

       - at INFO level, requests are logged;

       - at DEBUG level, request details and events from the Server are logged.

     - `lightstreamer.session`: logs Server Session lifecycle events;

       - at INFO level, lifecycle events are logged;

       - at DEBUG level, lifecycle event details are logged.

     - `lightstreamer.subscriptions`: logs subscription requests received by the clients and the related updates;

       - at WARN level, alert events from the Server are logged;

       - at INFO level, subscriptions and unsubscriptions are logged;

       - at DEBUG level, requests batching and update details are logged.

     - `lightstreamer.actions`: logs settings / API calls.

     - `lightstreamer.transport`: logs lower-level transport operations (HTTP and WebSocket).

     - `lightstreamer.reachability`: logs network reachability status.

     - Parameter provider: An `LSLoggerProvider` instance that will be used to generate log messages by the library classes.
     */
    public static func setLoggerProvider(_ loggerProvider: LSLoggerProvider) {
        LogManager.setLoggerProvider(loggerProvider)
    }
    
    /**
     Static method that can be used to share cookies between connections to the Server (performed by this library)
     and connections to other sites that are performed by the application.

     With this method, cookies received by the application can be added (or replaced if already present) to the cookie set used by the
     library to access the Server. Obviously, only cookies whose domain is compatible with the Server domain will be used internally.

     Specified cookies are actually added to the system's shared cookie storage, which is used by both HTTP and WebSocket connections.

     **Lifecycle:** this method can be called at any time; it will affect the internal cookie set immediately and the sending of cookies on future requests.

     - Parameter cookies: A list of cookies, represented by the system's standard cookie object `HTTPCookie`.

     - Parameter url: The URL from which the supplied cookies were received.

     - SeeAlso: `getCookiesForURL(_:)`
     */
    public static func addCookies(_ cookies: [HTTPCookie], forURL url: URL) {
        HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
    }
    
    /**
     Static inquiry method that can be used to share cookies between connections to the Server (performed by this library)
     and connections to other sites that are performed by the application.

     With this method, cookies received from the Server can be extracted for sending through other connections, according with the URL to be accessed.

     - Parameter url: The URL to which the cookies should be sent, or nil.

     - Returns: An immutable list with the various cookies that can be sent in a HTTP request for the specified URL. If a nil URI was supplied,
     all available non-expired cookies will be returned. The cookies are represented by the system's standard cookie object `HTTPCookie`.
     */
    public static func getCookiesForURL(_ url: URL?) -> [HTTPCookie]? {
        if let url = url {
            return HTTPCookieStorage.shared.cookies(for: url)
        } else {
            return HTTPCookieStorage.shared.cookies
        }
    }
    
    /**
     Object that contains the details needed to open a connection to a Lightstreamer Server.

     This instance is set up by the LightstreamerClient object at its own creation.

     Properties of this object can be overwritten by values received from a Lightstreamer Server.
     */
    public var connectionDetails: ConnectionDetails {
        synchronized {
            m_details
        }
    }

    /**
     Object that contains options and policies for the connection to the server.

     This instance is set up by the LightstreamerClient object at its own creation.

     Properties of this object can be overwritten by values received from a Lightstreamer Server.
     */
    public var connectionOptions: ConnectionOptions {
        synchronized {
            m_options
        }
    }

    /**
     Current client status and transport (when applicable).

     It can be one of the following values:

     - `CONNECTING` the client is waiting for a Server's response in order to establish a connection;

     - `CONNECTED:STREAM-SENSING` the client has received a preliminary response from the server and is currently verifying if a streaming connection is possible;

     - `CONNECTED:WS-STREAMING` a streaming connection over WebSocket is active;

     - `CONNECTED:HTTP-STREAMING` a streaming connection over HTTP is active;

     - `CONNECTED:WS-POLLING` a polling connection over WebSocket is in progress;

     - `CONNECTED:HTTP-POLLING` a polling connection over HTTP is in progress;

     - `STALLED` the Server has not been sending data on an active streaming connection for longer than a configured time;

     - `DISCONNECTED:WILL-RETRY` no connection is currently active but one will be opened (possibly after a timeout);

     - `DISCONNECTED:TRYING-RECOVERY` no connection is currently active, but one will be opened as soon as possible, as an attempt to recover
       the current session after a connection issue;
     
     - `DISCONNECTED` no connection is currently active.
     
     **Platform limitations:** On watchOS the WebSocket transport is not available.

     - SeeAlso: `ClientDelegate.client(_:didChangeStatus:)`
     */
    public var status: Status {
        synchronized {
            m_status
        }
    }

    /**
     Adds a delegate that will receive events from the LightstreamerClient instance.

     The same delegate can be added to several different LightstreamerClient instances.

     **Lifecycle:** a delegate can be added at any time. A call to add a delegate already present will be ignored.

     - Parameter delegate: An object that will receive the events as documented in the `ClientDelegate` interface. Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.

     - SeeAlso: `removeDelegate(_:)`
     */
    public func addDelegate(_ delegate: ClientDelegate) {
        synchronized {
            guard !multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.addDelegate(delegate)
            callbackQueue.async {
                delegate.clientDidAddDelegate(self)
            }
        }
    }

    /**
     Removes a delegate from the LightstreamerClient instance so that it will not receive events anymore.

     **Lifecycle:** a delegate can be removed at any time.

     - Parameter delegate: The delegate to be removed.

     - SeeAlso: `addDelegate(_:)`
     */
    public func removeDelegate(_ delegate: ClientDelegate) {
        synchronized {
            guard multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.removeDelegate(delegate)
            callbackQueue.async {
                delegate.clientDidRemoveDelegate(self)
            }
        }
    }
    
    /**
     List containing the `ClientDelegate` instances that were added to this client.

     - SeeAlso: `addDelegate(_:)`
     */
    public var delegates: [ClientDelegate] {
        synchronized {
            multicastDelegate.getDelegates()
        }
    }

    /**
     Operation method that requests to open a Session against the configured Lightstreamer Server.

     When `connect` is called, unless a single transport was forced through `ConnectionOptions.forcedTransport`, the so called "Stream-Sense" mechanism is started: if the client does not receive any answer for some seconds from the streaming connection, then it will automatically open a polling connection.

     A polling connection may also be opened if the environment is not suitable for a streaming connection.

     Note that as "polling connection" we mean a loop of polling requests, each of which requires opening a synchronous (i.e. not streaming) connection to
     Lightstreamer Server.

     **Lifecycle:** note that the request to connect is accomplished by the client in a separate thread; this means that an invocation of `status` right
     after connect might not reflect the change yet.

     When the request to connect is finally being executed, if the current `status` of the client is `CONNECTING`, `CONNECTED:*` or `STALLED`, then nothing will be done.
     
     - Precondition: a server address must be configured.
     
     - SeeAlso: `status`

     - SeeAlso: `disconnect()`

     - SeeAlso: `ClientDelegate.client(_:didChangeStatus:)`

     - SeeAlso: `ConnectionDetails.serverAddress`
     */
    public func connect() {
        synchronized {
            guard let serverAddress = m_details.m_serverAddress else {
                preconditionFailure("Configure the server address before trying to connect")
            }
            if actionLogger.isInfoEnabled {
                actionLogger.info("Connection requested: details: \(m_details!) options: \(m_options!)")
            }
            defaultServerAddress = serverAddress
            evtExtConnect()
        }
    }
    
    /**
     Operation method that requests to close the Session opened against the configured Lightstreamer Server (if any).

     When `disconnect()` is called, the "Stream-Sense" mechanism is stopped.

     Note that active `Subscription` instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.

     **Lifecycle:** note that the request to disconnect is accomplished by the client in a separate thread; this means that an invocation of `status` right after disconnect might not reflect the change yet.

     When the request to disconnect is finally being executed, if the `status` of the client is `DISCONNECTED`, then nothing will be done.

     - SeeAlso: `connect()`
     */
    public func disconnect() {
        synchronized {
            if actionLogger.isInfoEnabled {
                actionLogger.info("Disconnection requested")
            }
            evtExtDisconnect(.api)
        }
    }
    
    /**
     Operation method that sends a message to the Server.

     The message is interpreted and handled by the Metadata Adapter associated to the current Session. This operation supports in-order guaranteed message delivery with automatic batching. In other words, messages are guaranteed to arrive exactly once and respecting the original order, whatever is the underlying transport (HTTP or WebSockets). Furthermore, high frequency messages are automatically batched, if necessary, to reduce network round trips.

     Upon subsequent calls to the method, the sequential management of the involved messages is guaranteed. The ordering is determined by the order in which the calls to `sendMessage(...)` are issued. If a message, for any reason, doesn't reach the Server (this is possible with the HTTP transport), it will be resent; however, this may cause the subsequent messages to be delayed. For this reason, each message can specify a `delayTimeout`, which is the longest time the message, after reaching the Server, can be kept waiting if one of more preceding messages haven't been received yet. If the `delayTimeout` expires, these preceding messages will be discarded; any discarded message will be notified to the listener through `ClientMessageDelegate.client(_:didDiscardMessage:)`.
     
     Note that, because of the parallel transport of the messages, if a zero or very low timeout is set for a message and the previous message was sent
     immediately before, it is possible that the latter gets discarded even if no communication issues occur. The Server may also enforce its own timeout
     on missing messages, to prevent keeping the subsequent messages for long time.

     Sequence identifiers can also be associated with the messages. In this case, the sequential management is restricted to all subsets of messages with the
     same sequence identifier associated.

     Notifications of the operation outcome can be received by supplying a suitable delegate. The supplied delegate is guaranteed to be eventually invoked;
     delegates associated with a sequence are guaranteed to be invoked sequentially.

     The `UNORDERED_MESSAGES` sequence name has a special meaning. For such a sequence, immediate processing is guaranteed, while strict ordering and even sequentialization of the processing is not enforced. Likewise, strict ordering of the notifications is not enforced. However, messages that, for any reason, should fail to reach the Server whereas subsequent messages had succeeded, might still be discarded after a server-side timeout, in order to ensure that the listener eventually gets a notification.

     Moreover, if `UNORDERED_MESSAGES` is used and no listener is supplied, a "fire and forget" scenario is assumed.
     In this case, no checks on missing, duplicated or overtaken messages are performed at all, so as to optimize the processing and allow the highest possible throughput.

     **Lifecycle:** since a message is handled by the Metadata Adapter associated to the current connection, a message can be sent only if a connection is currently active. If the special `enqueueWhileDisconnected` flag is specified it is possible to call the method at any time and the client will take care of sending the message as soon as a connection is available, otherwise, if the current `status` is `DISCONNECTED*`, the message will be abandoned and the `ClientMessageDelegate.client(_:didAbortMessage:sentOnNetwork:)` event will be fired.

     Note that, in any case, as soon as the `status` switches again to `DISCONNECTED*`, any message still pending is aborted, including messages that were queued with the `enqueueWhileDisconnected` flag set to `true`.

     Also note that forwarding of the message to the server is made in a separate thread, hence, if a message is sent while the connection is active, it could
     be aborted because of a subsequent disconnection. In the same way a message sent while the connection is not active might be sent because of a subsequent connection.

     - Parameter message: A text message, whose interpretation is entirely demanded to the Metadata Adapter associated to the current connection.

     - Parameter sequence: An alphanumeric identifier, used to identify a subset of messages to be managed in sequence; underscore characters are also allowed. If the `UNORDERED_MESSAGES` identifier is supplied, the message will be processed in the special way described above. The parameter is optional; if set to nil, `UNORDERED_MESSAGES` is used as the sequence name.

     - Parameter delayTimeout: A timeout, expressed in milliseconds. If higher than the Server configured timeout  on missing messages, the latter will be used instead. The parameter is optional; if a negative value is supplied, the Server configured timeout on missing messages will be applied. This timeout is ignored for the special `UNORDERED_MESSAGES` sequence, although a server-side timeout on missing messages still applies.
     
     - Parameter delegate: An object suitable for receiving notifications about the processing outcome. The parameter is optional; if not supplied,
     no notification will be available. Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or
     they may be released prematurely.

     - Parameter enqueueWhileDisconnected: If this flag is set to `true`, and the client is in a disconnected status when the provided message is handled, then the message is not aborted right away but is queued waiting for a new session. Note that the message can still be aborted later when a new session is established.
     */
    public func sendMessage(_ message: String, withSequence sequence: String? = nil, timeout delayTimeout: Millis = -1, delegate: ClientMessageDelegate? = nil, enqueueWhileDisconnected: Bool = false) {
        synchronized {
            guard !(!enqueueWhileDisconnected && (s_m == .s100 || inRetryUnit())) else {
                if actionLogger.isInfoEnabled {
                    var map = OrderedDictionary<String, CustomStringConvertible>()
                    map["text"] = String(reflecting: message)
                    map["sequence"] = sequence ?? "UNORDERED_MESSAGES"
                    map["timeout"] = delayTimeout >= 0 ? delayTimeout : nil
                    map["enqueueWhileDisconnected"] = enqueueWhileDisconnected ? true : nil
                    actionLogger.info("Message sending requested: \(map)")
                }
                if messageLogger.isWarnEnabled {
                    messageLogger.warn("Message \(sequence ?? "UNORDERED_MESSAGES"):-1 \(message) aborted")
                }
                if let delegate = delegate {
                    callbackQueue.async {
                        delegate.client(self, didAbortMessage: message, sentOnNetwork: false)
                    }
                }
                return
            }
            if let sequence = sequence {
                guard sequence.range(of: "^[a-zA-Z0-9_]*$", options: .regularExpression) != nil else {
                    preconditionFailure("The given sequence name is not valid. Use only alphanumeric characters plus underscore or null")
                }
                let msg = MessageManager(txt: message, sequence: sequence, maxWait: delayTimeout, delegate: delegate, enqueueWhileDisconnected: enqueueWhileDisconnected, client: self)
                if actionLogger.isInfoEnabled {
                    actionLogger.info("Message sending requested: \(msg)")
                }
                msg.evtExtSendMessage()
            } else {
                let sequence = "UNORDERED_MESSAGES"
                let msg = MessageManager(txt: message, sequence: sequence, maxWait: delayTimeout, delegate: delegate, enqueueWhileDisconnected: enqueueWhileDisconnected, client: self)
                if actionLogger.isInfoEnabled {
                    actionLogger.info("Message sending requested: \(msg)")
                }
                msg.evtExtSendMessage()
            }
        }
    }
    
    /**
     Operation method that adds a `Subscription` to the list of "active" subscriptions.

     The `Subscription` cannot already be in the "active" state.

     Active subscriptions are subscribed to through the server as soon as possible (i.e. as soon as there is a session available). Active `Subscription`
     are automatically reissued across subsequent sessions as long as a related `unsubscribe(_:)` call is not issued.

     **Lifecycle:** an `Subscription` can be given to the LightstreamerClient at any time. Once done the `Subscription` immediately enters the "active" state.

     Once "active", a `Subscription` instance cannot be provided again to a LSLightstreamerClient unless it is first removed from the "active" state through a call to `unsubscribe(_:)`.

     Also note that forwarding of the subscription to the server is made in a separate thread.

     A successful subscription to the server will be notified through a `SubscriptionDelegate.subscriptionDidSubscribe(_:)` event.

     - Parameter subscription: A `Subscription` object, carrying all the information needed to process real-time values.

     - SeeAlso: `unsubscribe(_:)`
     */
    public func subscribe(_ subscription: Subscription) {
        subscribeExt(subscription)
    }
    
    func subscribeExt(_ subscription: Subscription, isInternal: Bool = false) {
        synchronized {
            precondition(!subscription.isActive, Self.IS_ACTIVE)
            precondition(subscription.items != nil || subscription.itemGroup != nil, Self.NO_ITEMS)
            precondition(subscription.fields != nil || subscription.fieldSchema != nil, Self.NO_FIELDS)
            let sm = SubscriptionManagerLiving(subscription, self)
            if actionLogger.isInfoEnabled {
                actionLogger.info("\(isInternal ? "Internal subscription" : "Subscription") requested: subId: \(sm.subId) \(String(describing: subscription))")
            }
            sm.evtExtSubscribe()
        }
    }
    
    /**
     Operation method that removes a `Subscription` that is currently in the "active" state.

     By bringing back a `Subscription` to the "inactive" state, the unsubscription from all its items is requested to Lightstreamer Server.

     **Lifecycle:** an `Subscription` can be unsubscribed from at any time. Once done the `Subscription` immediately exits the "active" state.

     Note that forwarding of the unsubscription to the server is made in a separate thread.

     The unsubscription will be notified through a `SubscriptionDelegate.subscriptionDidUnsubscribe(_:)` event.

     - Parameter subscription: An "active" `Subscription` object that was activated by this LightstreamerClient instance.
     */
    public func unsubscribe(_ subscription: Subscription) {
        synchronized {
            if let sm = subscription.subManager {
                precondition(subscriptionManagers.contains(where: { $1 === sm }),
                             "The Subscription is not subscribed to this Client")
                if actionLogger.isInfoEnabled {
                    actionLogger.info("Unsubscription requested: subId: \(sm.subId) \(String(describing: subscription))")
                }
                sm.evtExtUnsubscribe()
            }
        }
    }
    
    /**
     List containing all the `Subscription` instances that are currently "active" on this LightstreamerClient.

     Internal second-level `Subscription` are not included.

     The list can be empty.

     - SeeAlso: `subscribe(_:)`
     */
    public var subscriptions: [Subscription] {
        synchronized {
            var ls = [Subscription]()
            for (_, sm) in subscriptionManagers {
                switch sm {
                case let sml as SubscriptionManagerLiving:
                    let sub = sml.subscription
                    if sub.isActive && !sub.isInternal() {
                        ls.append(sub)
                    }
                default:
                    break
                }
            }
            return ls
        }
    }
    
    /**
     Operation method that registers the MPN device on the server's MPN Module.
     
     By registering an MPN device, the client enables MPN functionalities such as `subscribeMPN(_:coalescing:)` and `resetMPNBadge()`.
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** an `MPNDevice` can be registered at any time. The registration will be notified through a `MPNDeviceDelegate.mpnDeviceDidRegister(_:)` event.
     
     Note that forwarding of the registration to the server is made in a separate thread.
     
     - Parameter mpnDevice: An `MPNDevice` object, carrying all the information about the MPN device.
     
     - SeeAlso: `subscribeMPN(_:coalescing:)`

     - SeeAlso: `resetMPNBadge()`
     */
    public func register(forMPN mpnDevice: MPNDevice) {
        synchronized {
            mpn_candidate_devices.append(mpnDevice)
            if actionLogger.isInfoEnabled {
                actionLogger.info("MPN registration requested: \(String(describing: mpnDevice))")
            }
            evtExtMpnRegister()
        }
    }
    
    /**
     Operation method that subscribes an `MPNSubscription` on server's MPN Module.
     
     This operation adds the `MPNSubscription` to the list of "active" subscriptions. MPN subscriptions are activated on the server as soon as possible
     (i.e. as soon as there is a session available and subsequently as soon as the MPN device registration succeeds). Differently than real-time subscriptions,
     MPN subscriptions are persisted on the server's MPN Module database and survive the session they were created on.
     
     If the `coalescing` flag is *set*, the activation of two MPN subscriptions with the same Adapter Set, Data Adapter, Group, Schema and trigger expression will be considered the same MPN subscription. Activating two such subscriptions will result in the second activation modifying the first MPNSubscription (that could have been issued within a previous session). If the `coalescing` flag is *not set*, two activations are always considered different MPN subscriptions, whatever the Adapter Set, Data Adapter, Group, Schema and trigger expression are set.
     
     The rationale behind the `coalescing` flag is to allow simple apps to always activate their MPN subscriptions when the app starts, without worrying if
     the same subscriptions have been activated before or not. In fact, since MPN subscriptions are persistent, if they are activated every time the app starts and the `coalescing` flag is not set, every activation is a *new* MPN subscription, leading to multiple push notifications for the same event.
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** an `MPNSubscription` can be given to the LightstreamerClient once an `MPNDevice` registration has been requested. The `MPNSubscription` immediately enters the "active" state.
     
     Once "active", an `MPNSubscription` instance cannot be provided again to an LightstreamerClient unless it is first removed from the "active" state through a call to `unsubscribeMPN(_:)`.

     Note that forwarding of the subscription to the server is made in a separate thread.
     
     A successful subscription to the server will be notified through an `MPNSubscriptionDelegate.mpnSubscriptionDidSubscribe(_:)` event.

     - Parameter mpnSubscription: An `MPNSubscription` object, carrying all the information to route real-time data via push notifications.

     - Parameter coalescing: A flag that specifies if the MPN subscription must coalesce with any pre-existing MPN subscription with the same Adapter Set, Data Adapter, Group, Schema and trigger expression.

     - Precondition: the given MPN subscription must contain a field list/field schema.
     
     - Precondition: the given MPN subscription must contain a item list/item group.
     
     - Precondition: an MPN device must be registered.
     
     - Precondition: the given MPN subscription must be inactive.

     - SeeAlso: `unsubscribeMPN(_:)`
     
     - SeeAlso: `unsubscribeMultipleMPN(_:)`
     */
    public func subscribeMPN(_ mpnSubscription: MPNSubscription, coalescing: Bool) {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            precondition(!mpnSubscription.isActive, Self.IS_ACTIVE_MPN)
            precondition(mpnSubscription.requestedFormat != nil, Self.NO_FORMAT)
            precondition(mpnSubscription.items != nil || mpnSubscription.itemGroup != nil, Self.NO_ITEMS)
            precondition(mpnSubscription.fields != nil || mpnSubscription.fieldSchema != nil, Self.NO_FIELDS)
            let sm = MpnSubscriptionManager(mpnSubscription, coalescing: coalescing, self)
            if actionLogger.isInfoEnabled {
                actionLogger.info("MPN Subscription requested: subId: \(sm.subId) \(mpnSubscription) coalescing: \(coalescing)")
            }
            sm.evtExtMpnSubscribe()
        }
    }
    
    /**
     Operation method that unsubscribes an `MPNSubscription` from the server's MPN Module.
     
     This operation removes the `MPNSubscription` from the list of "active" subscriptions.
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** an `MPNSubscription` can be unsubscribed from at any time. Once done the `MPNSubscription` immediately exits the "active" state.
     
     Note that forwarding of the unsubscription to the server is made in a separate thread.
     
     The unsubscription will be notified through an `MPNSubscriptionDelegate.mpnSubscriptionDidUnsubscribe(_:)` event.

     - Parameter mpnSubscription: An "active" `MPNSubscription` object.

     - Precondition: an MPN device must be registered.

     - SeeAlso: `subscribeMPN(_:coalescing:)`

     - SeeAlso: `unsubscribeMultipleMPN(_:)`
     */
    public func unsubscribeMPN(_ mpnSubscription: MPNSubscription) {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            if let sm = mpnSubscription.subManager {
                precondition(mpnSubscriptionManagers.contains(where: { $0 === sm }),
                             "The MPNSubscription is not subscribed to this Client")
                if actionLogger.isInfoEnabled {
                    actionLogger.info("MPN Unsubscription requested: pnSubId: \(mpnSubscription.subscriptionId ?? "n.a.") \(mpnSubscription)")
                }
                sm.evtExtMpnUnsubscribe()
            }
        }
    }
    
    /**
     Operation method that unsubscribes all the MPN subscriptions with a specified status from the server's MPN Module.
     
     By specifying a status filter it is possible to unsubscribe multiple MPN subscriptions at once. E.g. by passing `TRIGGERED` it is possible
     to unsubscribe all triggered MPN subscriptions. This operation removes the involved MPN subscriptions from the list of "active" subscriptions.
     
     Possible filter values are:
     
     - `ALL` or nil

     - `TRIGGERED`
     
     - `SUBSCRIBED`
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** multiple unsubscription can be requested at any time. Once done the involved MPN subscriptions immediately exit the "active" state.
     
     Note that forwarding of the unsubscription to the server is made in a separate thread.
     
     The unsubscription will be notified through an `MPNSubscriptionDelegate.mpnSubscriptionDidUnsubscribe(_:)` event to all involved MPN subscriptions.

     - Parameter filter: A value to be used to select the MPN subscriptions to unsubscribe. If nil all existing MPN subscriptions are unsubscribed.
     
     - Precondition: an MPN device must be registered.

     - SeeAlso: `subscribeMPN(_:coalescing:)`
     
     - SeeAlso: `unsubscribeMPN(_:)`
     */
    public func unsubscribeMultipleMPN(_ filter: MPNSubscriptionStatus?) {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            let filter = filter ?? .ALL
            mpn_filter_pendings.append(filter)
            if actionLogger.isInfoEnabled {
                actionLogger.info("Multiple MPN Unsubscriptions requested: \(filter)")
            }
            evtExtMpnUnsubscribeFilter()
        }
    }
    
    /**
     Collection of the existing MPN subscriptions.
     
     Objects present in this collection are of type `MPNSubscription`. It contains both objects created by the user, via `MPNSubscription` constructors, and objects created by the client, to represent pre-existing MPN subscriptions.
     
     Note that objects in the collection may be substitutued at any time with equivalent ones: do not rely on pointer matching, instead rely on the
     `MPNSubscription.subscriptionId` property to verify the equivalence of two `MPNSubscription` objects. Substitutions may happen
     when an MPN subscription is modified, or when it is coalesced with a pre-existing subscription.
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** the collection is available once an `MPNDevice` registration has been requested, but reflects the actual server's collection only
     after an `MPNDeviceDelegate.mpnDeviceDidUpdateSubscriptions(_:)` event has been notified.
     
     - Precondition: an MPN device must be registered.
     
     - SeeAlso: `filterMPNSubscriptions(_:)`
     
     - SeeAlso: `findMPNSubscription(_:)`
     */
    public var MPNSubscriptions: [MPNSubscription] {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            return filterMPNSubscriptions(.ALL)
        }
    }
    
    /**
     Inquiry method that returns a collection of the existing MPN subscription with a specified status.
     
     Objects returned by this method are of type `MPNSubscription`. Can return both objects created by the user, via `MPNSubscription` constructors,
     and objects created by the client, to represent pre-existing MPN subscriptions.
     
     Note that objects returned by this method may be substitutued at any time with equivalent ones: do not rely on pointer matching, instead rely on the
     `MPNSubscription.subscriptionId` property to verify the equivalence of two `MPNSubscription` objects. Substitutions may happen
     when an MPN subscription is modified, or when it is coalesced with a pre-existing subscription.
     
     Possible filter values are:
     
     - `ALL` or nil
     
     - `TRIGGERED`
     
     - `SUBSCRIBED`
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     - Parameter filter: A value to be used to select the MPN subscriptions to return. If nil all existing MPN subscriptions are returned.
     
     - Precondition: an MPN device must be registered.
     
     - SeeAlso: `MPNSubscriptions`
     
     - SeeAlso: `findMPNSubscription(_:)`
     */
    public func filterMPNSubscriptions(_ filter: MPNSubscriptionStatus?) -> [MPNSubscription] {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            let filteredSubs: [MPNSubscription]
            switch filter {
            case nil, .ALL:
                filteredSubs = mpnSubscriptionManagers.map({ $0.m_subscription }).filter({ $0.status == .SUBSCRIBED || $0.status == .TRIGGERED })
            case .SUBSCRIBED, .TRIGGERED:
                filteredSubs =  mpnSubscriptionManagers.map({ $0.m_subscription }).filter({ ($0.status == .SUBSCRIBED && filter == .SUBSCRIBED) || ($0.status == .TRIGGERED && filter == .TRIGGERED) })
            }
            var res = [MPNSubscription]()
            let mapBySubId = Dictionary(grouping: filteredSubs, by: { $0.subscriptionId })
            outer:
            for (_, subs) in mapBySubId {
                // for each subscriptionId add to the result an user subscription, if it exists;
                // otherwise add the first one, that is a server subscription
                for sub in subs {
                    if !sub.m_madeByServer {
                        res.append(sub)
                        continue outer
                    }
                }
                if let first = subs.first {
                    res.append(first)
                }
            }
            return res
        }
    }
    
    /**
     Inquiry method that returns the `MPNSubscription` with the specified subscription ID, or nil if not found.
     
     The object returned by this method can be an object created by the user, via `MPNSubscription` constructors, or an object created by the client,
     to represent pre-existing MPN subscriptions.
     
     Note that objects returned by this method may be substitutued at any time with equivalent ones: do not rely on pointer matching, instead rely on the
     `MPNSubscription.subscriptionId` property to verify the equivalence of two `MPNSubscription` objects. Substitutions may happen
     when an MPN subscription is modified, or when it is coalesced with a pre-existing subscription.
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     - Parameter subscriptionId: The subscription ID to search for.
     
     - Precondition: an MPN device must be registered.
     
     - SeeAlso: `MPNSubscriptions`

     - SeeAlso: `filterMPNSubscriptions(_:)`
     */
    public func findMPNSubscription(_ subscriptionId: String) -> MPNSubscription? {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            for sm in mpnSubscriptionManagers {
                if sm.m_subscription.subscriptionId == subscriptionId {
                    return sm.m_subscription
                }
            }
            return nil
        }
    }
    
    /**
     Operation method that resets the counter for the app badge.
     
     If the `AUTO` value has been used for the app badge in the `MPNSubscription.notificationFormat` of one or more MPN subscriptions, this operation resets the counter so that the next push notification will have badge "1".
     
     **Edition note:** MPN is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license,
     please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     - Precondition: an MPN device must be registered.
     
     - SeeAlso: `MPNSubscription.notificationFormat`
     */
    public func resetMPNBadge() {
        synchronized {
            precondition(mpn_device != nil, Self.NO_DEVICE)
            mpn_badge_reset_requested = true
            if actionLogger.isInfoEnabled {
                actionLogger.info("MPN Badge Reset requested: \(mpn_device.deviceId ?? "n.a.")")
            }
            evtExtMpnResetBadge()
        }
    }

    func evtExtConnect() {
        synchronized {
            let evt = "connect"
            var forward = true
            switch s_m {
            case .s100:
                trace(evt, State_m.s100, State_m.s101)
                cause = "api"
                resetCurrentRetryDelay()
                s_m = .s101
                forward = evtExtConnect_MpnRegion()
                evtSelectCreate()
            default:
                break
            }
            if forward {
                forward = evtExtConnect_MpnRegion()
            }
        }
    }
    
    private func evtExtConnect_MpnRegion() -> Bool {
        let evt = "connect"
        var forward = true
        if s_mpn.m == .s401 {
            trace(evt, State_mpn_m.s401, State_mpn_m.s403)
            s_mpn.m = .s403
            forward = evtExtConnect_NetworkReachabilityRegion()
            genSendMpnRegister()
        }
        if forward {
            forward = evtExtConnect_NetworkReachabilityRegion()
        }
        return false
    }
    
    private func evtExtConnect_NetworkReachabilityRegion() -> Bool {
        let evt = "nr:connect"
        if s_nr == .s1400 {
            trace(evt, State_nr.s1400, State_nr.s1410)
            var hostAddress: String!
            if let serverAddress = URL(string: getServerAddress()), let host = serverAddress.host {
                nr_reachabilityManager = reachabilityManagerFactory(host)
                hostAddress = host
            }
            s_nr = .s1410
            nr_reachabilityManager?.startListening { [weak self] status in
                switch status {
                case .notReachable:
                    self?.evtNetworkNotReachable(hostAddress)
                case .reachable:
                    self?.evtNetworkReachable(hostAddress)
                }
            }
        }
        return false
    }
    
    func evtNetworkNotReachable(_ host: String) {
        synchronized {
            if reachabilityLogger.isInfoEnabled {
                reachabilityLogger.info("\(host) is NOT reachable")
            }
            let evt = "nr:network.not.reachable"
            switch s_nr {
            case .s1410:
                trace(evt, State_nr.s1410, State_nr.s1411)
                s_nr = .s1411
            case .s1412:
                trace(evt, State_nr.s1412, State_nr.s1411)
                s_nr = .s1411
            default:
                break
            }
        }
    }
    
    func evtNetworkReachable(_ host: String) {
        synchronized {
            if reachabilityLogger.isInfoEnabled {
                reachabilityLogger.info("\(host) is reachable")
            }
            let evt = "nr:network.reachable"
            switch s_nr {
            case .s1410:
                trace(evt, State_nr.s1410, State_nr.s1412)
                s_nr = .s1412
            case .s1411:
                trace(evt, State_nr.s1411, State_nr.s1412)
                s_nr = .s1412
                evtOnlineAgain()
            default:
                break
            }
        }
    }
    
    func evtOnlineAgain() {
        synchronized {
            let evt = "online.again"
            if s_m == .s112 {
                trace(evt, State_m.s112, State_m.s116)
                s_m = .s116
                cancel_evtRetryTimeout()
                evtSelectCreate()
            } else if s_rec == .s1003 {
                trace(evt, State_rec.s1003, State_rec.s1001)
                sendRecovery()
                s_rec = .s1001
                cancel_evtRetryTimeout()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            }
        }
    }
    
    func evtServerAddressChanged() {
        synchronized {
            let evt = "nr:serverAddress.changed"
            switch s_nr {
            case .s1410, .s1411, .s1412:
                trace(evt, s_nr, State_nr.s1410)
                var hostAddress: String!
                let oldManager = nr_reachabilityManager
                if let serverAddress = URL(string: getServerAddress()), let host = serverAddress.host {
                    nr_reachabilityManager = reachabilityManagerFactory(host)
                    hostAddress = host
                }
                s_nr = .s1410
                oldManager?.stopListening()
                nr_reachabilityManager?.startListening { status in
                    switch status {
                    case .notReachable:
                        self.evtNetworkNotReachable(hostAddress)
                    case .reachable:
                        self.evtNetworkReachable(hostAddress)
                    }
                }
            default:
                break
            }
        }
    }

    func evtExtDisconnect(_ terminationCause: TerminationCause) {
        synchronized {
            let evt = "disconnect: cause=\(terminationCause)"
            switch s_m {
            case .s120, .s121, .s122:
                trace(evt, s_m, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerErrorIfCauseIsError(terminationCause)
                s_m = .s100
                cancel_evtTransportTimeout()
                evtTerminate(terminationCause)
            case .s130:
                trace(evt, State_m.s130, State_m.s100)
                disposeHTTP()
                notifyStatus(.DISCONNECTED)
                notifyServerErrorIfCauseIsError(terminationCause)
                s_m = .s100
                cancel_evtTransportTimeout()
                evtTerminate(terminationCause)
            case .s140:
                trace(evt, State_m.s140, State_m.s100)
                disposeHTTP()
                notifyStatus(.DISCONNECTED)
                notifyServerErrorIfCauseIsError(terminationCause)
                s_m = .s100
                cancel_evtTransportTimeout()
                evtTerminate(terminationCause)
            case .s150:
                switch s_tr! {
                case .s210:
                    trace(evt, State_tr.s210, State_m.s100)
                    sendDestroyWS()
                    closeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerErrorIfCauseIsError(terminationCause)
                    clear_w()
                    goto_m_from_session(.s100)
                    exit_w()
                    evtEndSession()
                    evtTerminate(terminationCause)
                case .s220:
                    trace(evt, State_tr.s220, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerErrorIfCauseIsError(terminationCause)
                    goto_m_from_session(.s100)
                    cancel_evtTransportTimeout()
                    evtEndSession()
                    evtTerminate(terminationCause)
                case .s230:
                    trace(evt, State_tr.s230, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerErrorIfCauseIsError(terminationCause)
                    goto_m_from_session(.s100)
                    cancel_evtTransportTimeout()
                    evtEndSession()
                    evtTerminate(terminationCause)
                case .s240:
                    switch s_ws.m {
                    case .s500:
                        trace(evt, State_ws_m.s500, State_m.s100)
                        disposeWS()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_ws(.s100)
                        exit_ws_to_m()
                        evtTerminate(terminationCause)
                    case .s501, .s502, .s503:
                        trace(evt, s_ws.m, State_m.s100)
                        sendDestroyWS()
                        closeWS()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_ws(.s100)
                        exit_ws_to_m()
                        evtTerminate(terminationCause)
                    }
                case .s250:
                    switch s_wp.m {
                    case .s600, .s601:
                        trace(evt, State_wp_m.s600, State_m.s100)
                        disposeWS()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_wp(.s100)
                        exit_ws_to_m()
                        evtTerminate(terminationCause)
                    case .s602:
                        trace(evt, s_wp.m, State_m.s100)
                        sendDestroyWS()
                        closeWS()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_wp(.s100)
                        exit_wp_to_m()
                        evtTerminate(terminationCause)
                    }
                case .s260:
                    trace(evt, s_rec!, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerErrorIfCauseIsError(terminationCause)
                    goto_m_from_rec(.s100)
                    exit_rec_to_m()
                    evtTerminate(terminationCause)
                case .s270:
                    switch s_h! {
                    case .s710:
                        trace(evt, s_hs.m, State_m.s100)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_hs(.s100)
                        exit_hs_to_m()
                        evtTerminate(terminationCause)
                    case .s720:
                        trace(evt, s_hp.m, State_m.s100)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED)
                        notifyServerErrorIfCauseIsError(terminationCause)
                        goto_m_from_hp(.s100)
                        exit_hp_to_m()
                        evtTerminate(terminationCause)
                    }
                default:
                    break
                }
            case .s110, .s111, .s112, .s113, .s114, .s115, .s116:
                trace(evt, s_m, State_m.s100)
                notifyStatus(.DISCONNECTED)
                notifyServerErrorIfCauseIsError(terminationCause)
                s_m = .s100
                cancel_evtRetryTimeout()
                evtTerminate(terminationCause)
            default:
                break
            }
        }
    }

    func evtSelectCreate() {
        synchronized {
            let evt = "select.create"
            switch s_m {
            case .s101, .s116:
                switch getBestForCreating() {
                case .ws:
                    trace(evt, s_m, State_m.s120)
                    notifyStatus(.CONNECTING)
                    openWS_Create()
                    s_m = .s120
                    evtCreate()
                    schedule_evtTransportTimeout(delayCounter.currentRetryDelay)
                case .http:
                    trace(evt, s_m, State_m.s130)
                    notifyStatus(.CONNECTING)
                    sendCreateHTTP()
                    s_m = .s130
                    evtCreate()
                    schedule_evtTransportTimeout(delayCounter.currentRetryDelay)
                }
            default:
                break
            }
        }
    }
    
    func evtWSOpen() {
        synchronized {
            let evt = "ws.open"
            switch s_m {
            case .s120:
                trace(evt, State_m.s120, State_m.s121)
                sendCreateWS()
                s_m = .s121
            case .s150:
                switch s_tr! {
                case .s240:
                    switch s_ws.m {
                    case .s500:
                        trace(evt, State_ws_m.s500, State_ws_m.s501)
                        sendBindWS_Streaming()
                        s_ws.m = .s501
                    default:
                        break
                    }
                case .s250:
                    switch s_wp.m {
                    case .s600:
                        trace(evt, State_wp_m.s600, State_wp_m.s601)
                        ws.send("wsok")
                        s_wp.m = .s601
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }
    
    func evtMessage(_ line: String) throws {
        try synchronized {
            if line.starts(with: "U,") {
                // U,<subscription id>,<itemd index>,<field values>
                let update = try parseUpdate(line)
                try evtU(update.subId, update.itemIdx, update.values, line)
            } else if line.starts(with: "REQOK") {
                // REQOK,<request id>
                if line == "REQOK" {
                    evtREQOK()
                } else {
                    let args = line.split(separator: ",", omittingEmptySubsequences: false)
                    let reqId = Int(args[1])!
                    evtREQOK(reqId)
                }
            } else if line.starts(with: "PROBE") {
                evtPROBE()
            } else if line.starts(with: "LOOP") {
                // LOOP,<delay [ms]>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let pollingMs = Millis(args[1])!
                evtLOOP(pollingMs)
            } else if line.starts(with: "CONOK") {
                // CONOK,<session id>,<request limit>,<keepalive/idle timeout [ms]>,(*|<control link>)
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let sessionId = String(args[1])
                let reqLimit = Int(args[2])!
                let keepalive = Millis(args[3])!
                let clink = String(args[4])
                evtCONOK(sessionId, reqLimit, keepalive, clink)
            } else if line.starts(with: "WSOK") {
                evtWSOK()
            } else if line.starts(with: "SERVNAME") {
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let serverName = String(args[1])
                evtSERVNAME(serverName)
            } else if line.starts(with: "CLIENTIP") {
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let ip = String(args[1])
                evtCLIENTIP(ip)
            } else if line.starts(with: "CONS") {
                // CONS,(unmanaged|unlimited|<bandwidth>)
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let bw = String(args[1])
                switch bw {
                case "unlimited":
                    evtCONS(.unlimited)
                case "unmanaged":
                    evtCONS(.unmanaged)
                default:
                    let n = Double(bw)!
                    evtCONS(.limited(n))
                }
            } else if line.starts(with: "MSGDONE") {
                // MSGDONE,(*|<sequence>),<prog>,<response>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                var seq = String(args[1])
                if seq == "*" {
                    seq = "UNORDERED_MESSAGES"
                }
                let prog = Int(args[2])!
                let rawResp = args[3]
                let resp = rawResp == "" ? "" : rawResp.removingPercentEncoding!
                evtMSGDONE(seq, prog, resp)
            } else if line.starts(with: "MSGFAIL") {
                // MSGFAIL,(*|<sequence>),<prog>,<code>,<message>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                var seq = String(args[1])
                if seq == "*" {
                    seq = "UNORDERED_MESSAGES"
                }
                let prog = Int(args[2])!
                let errorCode = Int(args[3])!
                let errorMsg = args[4].removingPercentEncoding!
                evtMSGFAIL(seq, prog, errorCode: errorCode, errorMsg: errorMsg)
            } else if line.starts(with: "REQERR") {
                // REQERR,<request id>,<code>,<message>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let reqId = Int(args[1])!
                let code = Int(args[2])!
                let msg = args[3].removingPercentEncoding!
                evtREQERR(reqId, code, msg)
            } else if line.starts(with: "PROG") {
                // PROG,<prog>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let prog = Int(args[1])!
                evtPROG(prog)
            } else if line.starts(with: "SUBOK") {
                // SUBOK,<subscription id>,<total items>,<total fields>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let nItems = Int(args[2])!
                let nFields = Int(args[3])!
                evtSUBOK(subId, nItems, nFields)
            } else if line.starts(with: "SUBCMD") {
                // SUBCMD,<subscription id>,<total items>,<total fields>,<key index>,<command index>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let nItems = Int(args[2])!
                let nFields = Int(args[3])!
                let keyIdx = Pos(args[4])!
                let cmdIdx = Pos(args[5])!
                evtSUBCMD(subId, nItems, nFields, keyIdx, cmdIdx)
            } else if line.starts(with: "UNSUB") {
                // UNSUB,<subscription id>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                evtUNSUB(subId)
            } else if line.starts(with: "CONF") {
                // CONF,<subscription id>,(unlimited|<frequency>),(filtered|unfiltered)
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                if args[2] == "unlimited" {
                    evtCONF(subId, .unlimited)
                } else {
                    let freq = Double(args[2])!
                    evtCONF(subId, .limited(freq))
                }
            } else if line.starts(with: "EOS") {
                // EOS,<subscription id>,<item index>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let itemIdx = Int(args[2])!
                evtEOS(subId, itemIdx)
            } else if line.starts(with: "CS") {
                // CS,<subscription id>,<item index>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let itemIdx = Int(args[2])!
                evtCS(subId, itemIdx)
            } else if line.starts(with: "OV") {
                // OV,<subscription id>,<item index>,<lost updates>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let itemIdx = Int(args[2])!
                let lostUpdates = Int(args[3])!
                evtOV(subId, itemIdx, lostUpdates)
            } else if line.starts(with: "NOOP") {
                evtNOOP()
            } else if line.starts(with: "CONERR") {
                // CONERR,<code>,<message>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let code = Int(args[1])!
                let msg = args[2].removingPercentEncoding!
                evtCONERR(code, msg)
            } else if line.starts(with: "END") {
                // END,<code>,<message>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let code = Int(args[1])!
                let msg = args[2].removingPercentEncoding!
                evtEND(code, msg)
            } else if line.starts(with: "ERROR") {
                // ERROR,<code>,<message>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let code = Int(args[1])!
                let msg = args[2].removingPercentEncoding!
                evtERROR(code, msg)
            } else if line.starts(with: "SYNC") {
                // SYNC,<elapsed time [sec]>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let seconds = UInt64(args[1])!
                evtSYNC(seconds)
            } else if line.starts(with: "MPNREG") {
                // MPNREG,<device id>,<adapter name>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let deviceId = String(args[1])
                let adapterName = String(args[2])
                evtMPNREG(deviceId, adapterName)
            } else if line.starts(with: "MPNZERO") {
                // MPNZERO,<device id>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let deviceId = String(args[1])
                evtMPNZERO(deviceId)
            } else if line.starts(with: "MPNOK") {
                // MPNOK,<subscription id>, <mpn subscription id>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let subId = Int(args[1])!
                let mpnSubId = String(args[2])
                evtMPNOK(subId, mpnSubId)
            } else if line.starts(with: "MPNDEL") {
                // MPNDEL,<mpn subscription id>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let mpnSubId = String(args[1])
                evtMPNDEL(mpnSubId)
            } else if line.starts(with: "MPNCONF") {
                // MPNCONF,<mpn subscription id>
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let mpnSubId = String(args[1])
                evtMPNCONF(mpnSubId)
            }
        }
    }
    
    func evtCtrlMessage(_ line: String) {
        if line.starts(with: "REQOK") {
            // REQOK,<request id>
            if line == "REQOK" {
                evtREQOK()
            } else {
                let args = line.split(separator: ",", omittingEmptySubsequences: false)
                let reqId = Int(args[1])!
                evtREQOK(reqId)
            }
        } else if line.starts(with: "REQERR") {
            // REQERR,<request id>,<code>,<message>
            let args = line.split(separator: ",", omittingEmptySubsequences: false)
            let reqId = Int(args[1])!
            let code = Int(args[2])!
            let msg = args[3].removingPercentEncoding!
            evtREQERR(reqId, code, msg)
        } else if line.starts(with: "ERROR") {
            // ERROR,<code>,<message>
            let args = line.split(separator: ",", omittingEmptySubsequences: false)
            let code = Int(args[1])!
            let msg = args[2].removingPercentEncoding!
            evtERROR(code, msg)
        }
    }

    func evtTransportTimeout() {
        synchronized {
            let evt = "transport.timeout"
            switch s_m {
            case .s120, .s121:
                trace(evt, s_m, State_m.s115)
                suspendWS_Streaming()
                disposeWS()
                cause = "ws.unavailable"
                s_m = .s115
                cancel_evtTransportTimeout()
                entry_m115(.ws_unavailable)
            case .s122:
                trace(evt, State_m.s122, State_m.s112)
                disposeWS()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ws.timeout"
                s_m = .s112
                cancel_evtTransportTimeout()
                entry_m112(.ws_timeout)
            case .s130:
                trace(evt, State_m.s130, State_m.s112)
                disposeHTTP()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "http.timeout"
                s_m = .s112
                cancel_evtTransportTimeout()
                entry_m112(.http_timeout)
            case .s140:
                trace(evt, State_m.s140, State_m.s111)
                disposeHTTP()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ttl.timeout"
                let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                s_m = .s111
                cancel_evtTransportTimeout()
                entry_m111(.http_error, pauseMs)
            case .s150:
                switch s_tr! {
                case .s220:
                    if m_options.m_sessionRecoveryTimeout == 0 {
                        trace(evt, State_tr.s220, State_m.s112)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_WILL_RETRY)
                        cause = "http.timeout"
                        goto_m_from_session(.s112)
                        cancel_evtTransportTimeout()
                        evtEndSession()
                        entry_m112(.http_timeout)
                    } else {
                        trace(evt, State_tr.s220, State_rec.s1000)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                        cause = "http.timeout"
                        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                        goto_rec()
                        cancel_evtTransportTimeout()
                        entry_rec(pause: pauseMs, .http_timeout)
                    }
                case .s230:
                    if m_options.m_sessionRecoveryTimeout == 0 {
                        trace(evt, State_tr.s230, State_m.s112)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_WILL_RETRY)
                        cause = "ttl.timeout"
                        goto_m_from_session(.s112)
                        cancel_evtTransportTimeout()
                        evtEndSession()
                        entry_m112(.http_timeout)
                    } else {
                        trace(evt, State_tr.s230, State_rec.s1000)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                        cause = "ttl.timeout"
                        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                        goto_rec()
                        cancel_evtTransportTimeout()
                        entry_rec(pause: pauseMs, .http_error)
                    }
                case .s240:
                    switch s_ws.m {
                    case .s500:
                        trace(evt, State_ws_m.s500, State_tr.s200)
                        disableWS()
                        disposeWS()
                        cause = "ws.unavailable"
                        clear_ws()
                        s_tr = .s200
                        cancel_evtTransportTimeout()
                        evtSwitchTransport()
                    case .s501:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_ws_m.s501, State_m.s112)
                            disableWS()
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.unavailable"
                            goto_m_from_ws(.s112)
                            exit_ws_to_m()
                            entry_m112(.ws_unavailable)
                        } else {
                            trace(evt, State_ws_m.s501, State_rec.s1000)
                            disableWS()
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.unavailable"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_ws()
                            exit_ws()
                            entry_rec(pause: pauseMs, .ws_unavailable)
                        }
                    case .s502:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_ws_m.s502, State_m.s112)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.timeout"
                            goto_m_from_ws(.s112)
                            exit_ws_to_m()
                            entry_m112(.ws_timeout)
                        } else {
                            trace(evt, State_ws_m.s502, State_rec.s1000)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.timeout"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_ws()
                            exit_ws()
                            entry_rec(pause: pauseMs, .ws_timeout)
                        }
                    default:
                        break
                    }
                case .s250:
                    switch s_wp.m {
                    case .s600, .s601:
                        trace(evt, s_wp.m, State_tr.s200)
                        disableWS()
                        disposeWS()
                        cause = "ws.unavailable"
                        clear_wp()
                        s_tr = .s200
                        exit_wp()
                        evtSwitchTransport()
                    default:
                        break
                    }
                case .s260:
                    if s_rec == .s1001 {
                        trace(evt, State_rec.s1001, State_rec.s1002)
                        disposeHTTP()
                        s_rec = .s1002
                        cancel_evtTransportTimeout()
                        evtCheckRecoveryTimeout(.transport_timeout)
                    }
                case .s270:
                    switch s_h! {
                    case .s710:
                        switch s_hs.m {
                        case .s800:
                            trace(evt, State_hs_m.s800, State_hs_m.s801)
                            disableHTTP_Streaming();
                            cause = "http.streaming.unavailable"
                            s_hs.m = .s801
                            cancel_evtTransportTimeout()
                            evtForcePolling()
                            schedule_evtTransportTimeout(m_options.m_retryDelay)
                        case .s801:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, State_hs_m.s801, State_m.s112)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "http.timeout"
                                goto_m_from_hs(.s112)
                                exit_hs_to_m()
                                entry_m112(.http_timeout)
                            } else {
                                trace(evt, State_hs_m.s801, State_rec.s1000)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "http.timeout"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_hs()
                                exit_hs_to_rec()
                                entry_rec(pause: pauseMs, .http_timeout)
                            }
                        default:
                            break
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }

    func evtTransportError() {
        synchronized {
            let evt = "transport.error"
            switch s_m {
            case .s120, .s121:
                trace(evt, s_m, State_m.s115)
                suspendWS_Streaming()
                disposeWS()
                cause = "ws.unavailable"
                s_m = .s115
                cancel_evtTransportTimeout()
                evtRetry(.ws_unavailable)
                evtRetryTimeout()
            case .s122:
                trace(evt, State_m.s122, State_m.s112)
                disposeWS()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ws.error"
                let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                s_m = .s112
                cancel_evtTransportTimeout()
                evtRetry(.ws_error, pauseMs)
                schedule_evtRetryTimeout(pauseMs)
            case .s130:
                trace(evt, State_m.s130, State_m.s112)
                disposeHTTP()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "http.error"
                let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                s_m = .s112
                cancel_evtTransportTimeout()
                evtRetry(.http_error, pauseMs)
                schedule_evtRetryTimeout(pauseMs)
            case .s140:
                trace(evt, State_m.s140, State_m.s111)
                disposeHTTP()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ttl.error"
                let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                s_m = .s111
                cancel_evtTransportTimeout()
                evtRetry(.http_error, pauseMs)
                schedule_evtRetryTimeout(pauseMs)
            case .s150:
                switch s_tr! {
                case .s210:
                    if m_options.m_sessionRecoveryTimeout == 0 {
                        trace(evt, State_tr.s210, State_m.s113)
                        disposeWS()
                        notifyStatus(.DISCONNECTED_WILL_RETRY)
                        cause = "ws.error"
                        clear_w()
                        goto_m_from_session(.s113)
                        exit_w()
                        evtEndSession()
                        entry_m113(.ws_error)
                    } else {
                        trace(evt, State_tr.s210, State_rec.s1000)
                        disposeWS()
                        notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                        cause = "ws.error"
                        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                        clear_w()
                        s_tr = .s260
                        s_rec = .s1000
                        exit_w()
                        entry_rec(pause: pauseMs, .ws_error)
                    }
                case .s220:
                    if m_options.m_sessionRecoveryTimeout == 0 {
                        trace(evt, State_tr.s220, State_m.s112)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_WILL_RETRY)
                        cause = "http.error"
                        let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                        goto_m_from_session(.s112)
                        cancel_evtTransportTimeout()
                        evtEndSession()
                        evtRetry(.http_error, pauseMs)
                        schedule_evtRetryTimeout(pauseMs)
                    } else {
                        trace(evt, State_tr.s220, State_rec.s1000)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                        cause = "http.error"
                        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                        goto_rec()
                        cancel_evtTransportTimeout()
                        entry_rec(pause: pauseMs, .http_error)
                    }
                case .s230:
                    if m_options.m_sessionRecoveryTimeout == 0 {
                        trace(evt, State_tr.s230, State_m.s112)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_WILL_RETRY)
                        cause = "ttl.error"
                        let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                        goto_m_from_session(.s112)
                        cancel_evtTransportTimeout()
                        evtEndSession()
                        evtRetry(.http_error, pauseMs)
                        schedule_evtRetryTimeout(pauseMs)
                    } else {
                        trace(evt, State_tr.s230, State_rec.s1000)
                        disposeHTTP()
                        notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                        cause = "ttl.error"
                        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                        goto_rec()
                        cancel_evtTransportTimeout()
                        entry_rec(pause: pauseMs, .http_error)
                    }
                case .s240:
                    switch s_ws.m {
                    case .s500:
                        trace(evt, State_ws_m.s500, State_tr.s200)
                        disableWS()
                        disposeWS()
                        cause = "ws.unavailable"
                        clear_ws()
                        s_tr = .s200
                        cancel_evtTransportTimeout()
                        evtSwitchTransport()
                    case .s501:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_ws_m.s501, State_m.s112)
                            disableWS()
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.unavailable"
                            goto_m_from_ws(.s112)
                            exit_ws_to_m()
                            entry_m112(.ws_unavailable)
                        } else {
                            trace(evt, State_ws_m.s501, State_rec.s1000)
                            disableWS()
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.unavailable"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_ws()
                            exit_ws()
                            entry_rec(pause: pauseMs, .ws_unavailable)
                        }
                    case .s502:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_ws_m.s502, State_m.s112)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.error"
                            goto_m_from_ws(.s112)
                            exit_ws_to_m()
                            entry_m112(.ws_error)
                        } else {
                            trace(evt, State_ws_m.s502, State_rec.s1000)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.error"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_ws()
                            cancel_evtTransportTimeout()
                            entry_rec(pause: pauseMs, .ws_error)
                        }
                    case .s503:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_ws_m.s503, State_m.s113)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.error"
                            goto_m_from_ws(.s113)
                            exit_ws_to_m()
                            entry_m113(.ws_error)
                        } else {
                            trace(evt, State_ws_m.s503, State_rec.s1000)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.error"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_ws()
                            exit_ws()
                            entry_rec(pause: pauseMs, .ws_error)
                        }
                    }
                case .s250:
                    switch s_wp.m {
                    case .s600, .s601:
                        trace(evt, s_wp.m, State_tr.s200)
                        disableWS()
                        disposeWS()
                        cause = "ws.unavailable"
                        clear_wp()
                        s_tr = .s200
                        cancel_evtTransportTimeout()
                        evtSwitchTransport()
                    case .s602:
                        if m_options.m_sessionRecoveryTimeout == 0 {
                            trace(evt, State_wp_m.s602, State_m.s113)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_WILL_RETRY)
                            cause = "ws.error"
                            goto_m_from_wp(.s113)
                            exit_wp_to_m()
                            entry_m113(.ws_error)
                        } else {
                            trace(evt, State_wp_m.s602, State_rec.s1000)
                            disposeWS()
                            notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                            cause = "ws.error"
                            let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                            goto_rec_from_wp()
                            exit_wp()
                            entry_rec(pause: pauseMs, .ws_error)
                        }
                    }
                case .s260:
                    if s_rec == .s1001 {
                        trace(evt, State_rec.s1001, State_rec.s1002)
                        disposeHTTP()
                        s_rec = .s1002
                        cancel_evtTransportTimeout()
                        evtCheckRecoveryTimeout(.transport_error)
                    }
                case .s270:
                    switch s_h! {
                    case .s710:
                        switch s_hs.m {
                        case .s800, .s801:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, s_hs.m, State_m.s112)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "http.error"
                                goto_m_from_hs(.s112)
                                exit_hs_to_m()
                                entry_m112(.http_error)
                            } else {
                                trace(evt, s_hs.m, State_rec.s1000)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "http.error"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_hs()
                                exit_hs_to_rec()
                                entry_rec(pause: pauseMs, .http_error)
                            }
                        case .s802:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, State_hs_m.s802, State_m.s113)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "http.error"
                                goto_m_from_hs(.s113)
                                exit_hs_to_m()
                                entry_m113(.http_error)
                            } else {
                                trace(evt, State_hs_m.s802, State_rec.s1000)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "http.error"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_hs()
                                exit_hs_to_rec()
                                entry_rec(pause: pauseMs, .http_error)
                            }
                        }
                    case .s720:
                        switch s_hp.m {
                        case .s900, .s901, .s902, .s903, .s904:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, s_hp.m, State_m.s112)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "http.error"
                                goto_m_from_hp(.s112)
                                exit_hp_to_m()
                                entry_m112(.http_error)
                            } else {
                                trace(evt, s_hp.m, State_rec.s1000)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "http.error"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_hp()
                                exit_hp_to_rec()
                                entry_rec(pause: pauseMs, .http_error)
                            }
                        }
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }

    func evtIdleTimeout() {
        synchronized {
            let evt = "idle.timeout"
            switch s_m {
            case .s150:
                switch s_tr! {
                case .s250:
                    switch s_wp.m {
                    case .s602:
                        switch s_wp.p! {
                        case .s610, .s611, .s613:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, s_wp.p!, State_m.s113)
                                disposeWS()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "ws.idle.timeout"
                                goto_m_from_wp(.s113)
                                exit_wp_to_m()
                                entry_m113(.idle_timeout)
                            } else {
                                trace(evt, s_wp.p!, State_rec.s1000)
                                disposeWS()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "ws.idle.timeout"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_wp()
                                exit_wp()
                                entry_rec(pause: pauseMs, .idle_timeout)
                            }
                        default:
                            break
                        }
                    default:
                        break
                    }
                case .s270:
                    switch s_h! {
                    case .s720:
                        switch s_hp.m {
                        case .s900, .s901, .s903:
                            if m_options.m_sessionRecoveryTimeout == 0 {
                                trace(evt, s_hp.m, State_m.s112)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_WILL_RETRY)
                                cause = "http.idle.timeout"
                                goto_m_from_hp(.s112)
                                exit_hp_to_m()
                                entry_m112(.idle_timeout)
                            } else {
                                trace(evt, s_hp.m, State_rec.s1000)
                                disposeHTTP()
                                notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                                cause = "http.idle.timeout"
                                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                                goto_rec_from_hp()
                                exit_hp_to_rec()
                                entry_rec(pause: pauseMs, .idle_timeout)
                            }
                        default:
                            break
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }

    func evtPollingTimeout() {
        synchronized {
            let evt = "polling.timeout"
            if let s = s_wp?.p, s == .s612 {
                trace(evt, State_wp_p.s612, State_wp_p.s613)
                sendBindWS_Polling()
                s_wp.p = .s613
                cancel_evtPollingTimeout()
                schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
            } else if let s = s_hp?.m, s == .s902 {
                trace(evt, State_hp_m.s902, State_hp_m.s903)
                sendBindHTTP_Polling()
                s_hp.m = .s903
                cancel_evtPollingTimeout()
                schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
            }
        }
    }
    
    func evtKeepaliveTimeout() {
        synchronized {
            let evt = "keepalive.timeout"
            if s_w?.k == .s310 {
                trace(evt, State_w_k.s310, State_w_k.s311)
                s_w.k = .s311
                cancel_evtKeepaliveTimeout()
                schedule_evtStalledTimeout(m_options.m_stalledTimeout)
            } else if s_ws?.k == .s520 {
                trace(evt, State_ws_k.s520, State_ws_k.s521)
                s_ws.k = .s521
                cancel_evtKeepaliveTimeout()
                schedule_evtStalledTimeout(m_options.m_stalledTimeout)
            } else if s_hs?.k == .s820 {
                trace(evt, State_hs_k.s820, State_hs_k.s821)
                s_hs.k = .s821
                cancel_evtKeepaliveTimeout()
                schedule_evtStalledTimeout(m_options.m_stalledTimeout)
            }
        }
    }
    
    func evtStalledTimeout() {
        synchronized {
            let evt = "stalled.timeout"
            if s_w?.k == .s311 {
                trace(evt, State_w_k.s311, State_w_k.s312)
                s_w.k = .s312
                cancel_evtStalledTimeout()
                schedule_evtReconnectTimeout(m_options.m_reconnectTimeout)
            } else if s_ws?.k == .s521 {
                trace(evt, State_ws_k.s521, State_ws_k.s522)
                s_ws.k = .s522
                cancel_evtStalledTimeout()
                schedule_evtReconnectTimeout(m_options.m_reconnectTimeout)
            } else if s_hs?.k == .s821 {
                trace(evt, State_hs_k.s821, State_hs_k.s822)
                s_hs.k = .s822
                cancel_evtStalledTimeout()
                schedule_evtReconnectTimeout(m_options.m_reconnectTimeout)
            }
        }
    }
    
    func evtReconnectTimeout() {
        synchronized {
            let evt = "reconnect.timeout"
            if s_w?.k == .s312 {
                if m_options.m_sessionRecoveryTimeout == 0 {
                    trace(evt, State_w_k.s312, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.stalled"
                    goto_m_from_w(.s113)
                    exit_w_to_m()
                    entry_m113(.stalled_timeout)
                } else {
                    trace(evt, State_w_k.s312, State_rec.s1000)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                    cause = "ws.stalled"
                    let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                    goto_rec_from_w()
                    exit_w()
                    entry_rec(pause: pauseMs, .stalled_timeout)
                }
            } else if s_ws?.k == .s522 {
                if m_options.m_sessionRecoveryTimeout == 0 {
                    trace(evt, State_ws_k.s522, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.stalled"
                    goto_m_from_ws(.s113)
                    exit_ws_to_m()
                    entry_m113(.stalled_timeout)
                } else {
                    trace(evt, State_ws_k.s522, State_rec.s1000)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                    cause = "ws.stalled"
                    let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                    goto_rec_from_ws()
                    exit_ws()
                    entry_rec(pause: pauseMs, .stalled_timeout)
                }
            } else if s_hs?.k == .s822 {
                if m_options.m_sessionRecoveryTimeout == 0 {
                    trace(evt, State_hs_k.s822, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.stalled"
                    goto_m_from_hs(.s113)
                    exit_hs_to_m()
                    entry_m113(.stalled_timeout)
                } else {
                    trace(evt, State_hs_k.s822, State_rec.s1000)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_TRYING_RECOVERY)
                    cause = "http.stalled"
                    let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                    goto_rec_from_hs()
                    exit_hs_to_rec()
                    entry_rec(pause: pauseMs, .stalled_timeout)
                }
            }
        }
    }
    
    func evtRestartKeepalive() {
        synchronized {
            let evt = "restart.keepalive"
            if let s = s_w?.k {
                trace(evt, s, State_w_k.s310)
                s_w.k = .s310
                exit_keepalive_unit()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
            } else if let s = s_ws?.k {
                trace(evt, s, State_ws_k.s520)
                s_ws.k = .s520
                exit_keepalive_unit()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
            } else if let s = s_hs?.k {
                trace(evt, s, State_hs_k.s820)
                s_hs.k = .s820
                exit_keepalive_unit()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
            }
        }
    }

    func evtWSOK() {
        synchronized {
            let evt = "WSOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt)")
            }
            switch s_m {
            case .s121:
                trace(evt, State_m.s121, State_m.s122)
                s_m = .s122
            case .s150:
                switch s_tr {
                case .s240:
                    switch s_ws.m {
                    case .s501:
                        trace(evt, State_ws_m.s501, State_ws_m.s502)
                        s_ws.m = .s502
                    default:
                        break
                    }
                case .s250:
                    switch s_wp.m {
                    case .s601:
                        trace(evt, State_wp_m.s601, State_wp_m.s602)
                        sendBindWS_FirstPolling()
                        s_wp.m = .s602
                        s_wp.p = .s610
                        s_wp.c = .s620
                        s_wp.s = .s630
                        cancel_evtTransportTimeout()
                        evtSendPendingControls()
                        evtSendPendingMessages()
                        schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }
    
    func evtCONERR(_ code: Int, _ msg: String) {
        synchronized {
            let evt = "CONERR"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(code) \(msg)")
            }
            let retryCause = RetryCause.standardError(code, msg)
            let terminationCause = TerminationCause.standardError(code, msg)
            if s_m == .s122 {
                switch code {
                case 4, 6, 20, 40, 41, 48:
                    trace(evt, State_m.s122, State_m.s112)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.conerr.\(code)"
                    let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                    s_m = .s112
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause, pauseMs)
                    schedule_evtRetryTimeout(pauseMs)
                case 5:
                    trace(evt, State_m.s122, State_m.s110)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.conerr.\(code)"
                    s_m = .s110
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause)
                    evtRetryTimeout()
                default:
                    trace(evt, State_m.s122, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    s_m = .s100
                    cancel_evtTransportTimeout()
                    evtTerminate(terminationCause)
                }
            } else if s_m == .s130 {
                switch code {
                case 4, 6, 20, 40, 41, 48:
                    trace(evt, State_m.s130, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.conerr.\(code)"
                    let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                    s_m = .s112
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause, pauseMs)
                    schedule_evtRetryTimeout(pauseMs)
                case 5:
                    trace(evt, State_m.s130, State_m.s110)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.conerr.\(code)"
                    s_m = .s110
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause)
                    evtRetryTimeout()
                default:
                    trace(evt, State_m.s130, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    s_m = .s100
                    cancel_evtTransportTimeout()
                    evtTerminate(terminationCause)
                }
            } else if s_m == .s140 {
                switch code {
                case 4, 6, 20, 40, 41, 48:
                    trace(evt, State_m.s140, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ttl.conerr.\(code)"
                    let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
                    s_m = .s112
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause, pauseMs)
                    schedule_evtRetryTimeout(pauseMs)
                case 5:
                    trace(evt, State_m.s140, State_m.s110)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ttl.conerr.\(code)"
                    s_m = .s110
                    cancel_evtTransportTimeout()
                    evtRetry(retryCause)
                    evtRetryTimeout()
                default:
                    trace(evt, State_m.s140, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    s_m = .s100
                    cancel_evtTransportTimeout()
                    evtTerminate(terminationCause)
                }
            } else if s_ws?.m == .s502 {
                switch code {
                case 4,6,20,40,41,48:
                    trace(evt, State_ws_m.s502, State_m.s112)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.conerr.\(code)"
                    goto_m_from_ws(.s112)
                    exit_ws_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, State_ws_m.s502, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    goto_m_from_ws(.s100)
                    exit_ws_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_wp?.p, s == .s610 || s == .s613 {
                switch code {
                case 4,6,20,40,41,48:
                    trace(evt, s, State_m.s112)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.conerr.\(code)"
                    goto_m_from_wp(.s112)
                    exit_wp_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    goto_m_from_wp(.s100)
                    exit_wp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_hs?.m, s == .s800 || s == .s801 {
                switch code {
                case 4,6,20,40,41,48:
                    trace(evt, s, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.conerr.\(code)"
                    goto_m_from_hs(.s112)
                    exit_hs_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    goto_m_from_hs(.s100)
                    exit_hs_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_hp?.m, s == .s900 || s == .s903 {
                switch code {
                case 4,6,20,40,41,48:
                    trace(evt, s, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.conerr.\(code)"
                    goto_m_from_hp(.s112)
                    exit_hp_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    goto_m_from_hp(.s100)
                    exit_hp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_rec == .s1001 {
                switch code {
                case 4, 6, 20, 40, 41, 48:
                    trace(evt, State_rec.s1001, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "recovery.conerr.\(code)"
                    goto_m_from_rec(.s113)
                    exit_rec_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_rec.s1001, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_CONERR(code, msg)
                    goto_m_from_rec(.s100)
                    exit_rec_to_m()
                    evtTerminate(terminationCause)
                }
            }
        }
    }

    func evtEND(_ code: Int, _ msg: String) {
        synchronized {
            let evt = "END"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(code) \(msg)")
            }
            let retryCause = RetryCause.standardError(code, msg)
            let terminationCause = TerminationCause.standardError(code, msg)
            if s_w?.p == .s300 {
                switch code {
                case 41, 48:
                    trace(evt, State_w_p.s300, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.end.\(code)"
                    let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                    clear_w()
                    goto_m_from_session(.s113)
                    exit_w()
                    evtEndSession()
                    evtRetry(.standardError(code, msg), pauseMs)
                    schedule_evtRetryTimeout(pauseMs)
                default:
                    trace(evt, State_w_p.s300, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    clear_w()
                    goto_m_from_session(.s100)
                    exit_w()
                    evtEndSession()
                    evtTerminate(terminationCause)
                }
            } else if s_ws?.m == .s502 {
                switch code {
                case 41, 48:
                    trace(evt, State_ws_m.s502, State_m.s112)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.end.\(code)"
                    goto_m_from_ws(.s112)
                    exit_ws_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, State_ws_m.s502, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_ws(.s100)
                    exit_ws_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_ws?.p == .s510 {
                switch code {
                case 41, 48:
                    trace(evt, State_ws_p.s510, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.end.\(code)"
                    goto_m_from_ws(.s113)
                    exit_ws_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_ws_p.s510, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_ws(.s100)
                    exit_ws_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_wp?.p, s == .s610 || s == .s613 {
                switch code {
                case 41, 48:
                    trace(evt, s, State_m.s112)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.end.\(code)"
                    goto_m_from_wp(.s112)
                    exit_wp_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_wp(.s100)
                    exit_wp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_wp?.p == .s611 {
                switch code {
                case 41, 48:
                    trace(evt, State_wp_p.s611, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "ws.end.\(code)"
                    goto_m_from_wp(.s113)
                    exit_wp_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_wp_p.s611, State_m.s100)
                    disposeWS()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_wp(.s100)
                    exit_wp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_hs?.m, s == .s800 || s == .s801 {
                switch code {
                case 41, 48:
                    trace(evt, s, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.end.\(code)"
                    goto_m_from_hs(.s112)
                    exit_hs_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_hs(.s100)
                    exit_hs_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_hs?.p == .s810 {
                switch code {
                case 41, 48:
                    trace(evt, State_hs_p.s810, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.end.\(code)"
                    goto_m_from_hs(.s113)
                    exit_hs_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_hs_p.s810, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_hs(.s100)
                    exit_hs_to_m()
                    evtTerminate(terminationCause)
                }
            } else if let s = s_hp?.m, s == .s900 || s == .s903 {
                switch code {
                case 41, 48:
                    trace(evt, s, State_m.s112)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.end.\(code)"
                    goto_m_from_hp(.s112)
                    exit_hp_to_m()
                    entry_m112(.standardError(code, msg))
                default:
                    trace(evt, s, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_hp(.s100)
                    exit_hp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_hp?.m == .s901 {
                switch code {
                case 41, 48:
                    trace(evt, State_hp_m.s901, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "http.end.\(code)"
                    goto_m_from_hp(.s113)
                    exit_hp_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_hp_m.s901, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_hp(.s100)
                    exit_hp_to_m()
                    evtTerminate(terminationCause)
                }
            } else if s_rec == .s1001 {
                switch code {
                case 41, 48:
                    trace(evt, State_rec.s1001, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "recovery.end.\(code)"
                    goto_m_from_rec(.s113)
                    exit_rec_to_m()
                    entry_m113(retryCause)
                default:
                    trace(evt, State_rec.s1001, State_m.s100)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED)
                    notifyServerError_END(code, msg)
                    goto_m_from_rec(.s100)
                    exit_rec_to_m()
                    evtTerminate(terminationCause)
                }
            }
        }
    }

    func evtERROR(_ code: Int, _ msg: String) {
        synchronized {
            let evt = "ERROR"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(code) \(msg)")
            }
            let terminationCause = TerminationCause.standardError(code, msg)
            if s_w?.p == .s300 {
                trace(evt, State_w_p.s300, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_ERROR(code, msg)
                clear_w()
                goto_m_from_session(.s100)
                exit_w()
                evtEndSession()
                evtTerminate(terminationCause)
            } else if s_ws?.p == .s510 {
                trace(evt, State_ws_p.s510, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_ERROR(code, msg)
                goto_m_from_ws(.s100)
                exit_ws_to_m()
                evtTerminate(terminationCause)
            } else if s_wp?.c == .s620 {
                trace(evt, State_wp_c.s620, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_ERROR(code, msg)
                goto_m_from_wp(.s100)
                exit_wp_to_m()
                evtTerminate(terminationCause)
            } else if s_ctrl == .s1102 {
                trace(evt, State_ctrl.s1102, State_m.s100)
                disposeHTTP()
                notifyStatus(.DISCONNECTED)
                notifyServerError_ERROR(code, msg)
                goto_m_from_ctrl(.s100)
                exit_ctrl_to_m()
                evtTerminate(terminationCause)
            }
        }
    }
    
    func evtREQOK() {
        synchronized {
            let evt = "REQOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt)")
            }
            if s_ctrl == .s1102 {
                trace(evt, State_ctrl.s1102, State_ctrl.s1102)
                // heartbeat response (only in HTTP)
                s_ctrl = .s1102
            }
        }
    }
    
    func evtREQOK(_ reqId: Int) {
        synchronized {
            let evt = "REQOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(reqId)")
            }
            var forward = true
            if s_swt == .s1302 && reqId == swt_lastReqId {
                trace(evt, State_swt.s1302, State_swt.s1303)
                s_swt = .s1303
                forward = evtREQOK_TransportRegion(reqId)
            } else if s_bw == .s1202 && reqId == bw_lastReqId {
                trace(evt, State_bw.s1202, State_bw.s1200)
                s_bw = .s1200
                forward = evtREQOK_TransportRegion(reqId)
                evtCheckBW()
            } else if s_mpn.m == .s403 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_m.s403, State_mpn_m.s404)
                s_mpn.m = .s404
                forward = evtREQOK_TransportRegion(reqId)
            } else if s_mpn.m == .s406 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_m.s406, State_mpn_m.s407)
                s_mpn.m = .s407
                forward = evtREQOK_TransportRegion(reqId)
            } else if s_mpn.tk == .s453 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_tk.s453, State_mpn_tk.s454)
                s_mpn.tk = .s454
                forward = evtREQOK_TransportRegion(reqId)
            } else if s_mpn.ft == .s432 && reqId == mpn_filter_lastDeactivateReqId {
                trace(evt, State_mpn_ft.s432, State_mpn_ft.s430)
                doREQMpnUnsubscribeFilter()
                s_mpn.ft = .s430
                forward = evtREQOK_TransportRegion(reqId)
                evtMpnCheckFilter()
            } else if s_mpn.bg == .s442 && reqId == mpn_badge_lastResetReqId {
                trace(evt, State_mpn_bg.s442, State_mpn_bg.s440)
                doREQOKMpnResetBadge()
                forward = evtREQOK_TransportRegion(reqId)
                s_mpn.bg = .s440
                evtMpnCheckReset()
            }
            if forward {
                forward = evtREQOK_TransportRegion(reqId)
            }
        }
    }
    
    private func evtREQOK_TransportRegion(_ reqId: Int) -> Bool {
        let evt = "REQOK"
        if s_w?.p == .s300 {
            trace(evt, State_w_p.s300, State_w_p.s300)
            s_w.p = .s300
            doREQOK(reqId)
            evtRestartKeepalive()
        } else if s_ws?.p == .s510 {
            trace(evt, State_ws_p.s510, State_ws_p.s510)
            s_ws.p = .s510
            doREQOK(reqId)
            evtRestartKeepalive()
        } else if s_wp?.c == .s620 {
            trace(evt, State_wp_c.s620, State_wp_c.s620)
            s_wp.c = .s620
            doREQOK(reqId)
        } else if s_ctrl == .s1102 {
            trace(evt, State_ctrl.s1102, State_ctrl.s1102)
            s_ctrl = .s1102
            doREQOK(reqId)
        }
        return false
    }

    func evtREQERR(_ reqId: Int, _ code: Int, _ msg: String) {
        synchronized {
            let evt = "REQERR"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(reqId) \(code) \(msg)")
            }
            var forward = true
            if s_swt == .s1302 && reqId == swt_lastReqId {
                trace(evt, State_swt.s1302, State_swt.s1301)
                s_swt = .s1301
                forward = evtREQERR_TransportRegion(reqId, code, msg)
            } else if s_bw == .s1202 && reqId == bw_lastReqId {
                trace(evt, State_bw.s1202, State_bw.s1200)
                s_bw = .s1200
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtCheckBW()
            } else if s_mpn.m == .s403 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_m.s403, State_mpn_m.s402)
                notifyDeviceError(code, msg)
                s_mpn.m = .s402
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtMpnCheckNext()
            } else if s_mpn.m == .s406 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_m.s406, State_mpn_m.s408)
                notifyDeviceError(code, msg)
                s_mpn.m = .s408
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtMpnCheckNext()
            } else if s_mpn.tk == .s453 && reqId == mpn_lastRegisterReqId {
                trace(evt, State_mpn_tk.s453, State_mpn_tk.s452)
                notifyDeviceError(code, msg)
                s_mpn.tk = .s452
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtMpnCheckNext()
            } else if s_mpn.ft == .s432 && reqId == mpn_filter_lastDeactivateReqId {
                trace(evt, State_mpn_ft.s432, State_mpn_ft.s430)
                doREQMpnUnsubscribeFilter()
                s_mpn.ft = .s430
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtMpnCheckFilter()
            } else if s_mpn.bg == .s442 && reqId == mpn_badge_lastResetReqId {
                trace(evt, State_mpn_bg.s442, State_mpn_bg.s440)
                doREQERRMpnResetBadge()
                notifyOnBadgeResetFailed(code, msg)
                s_mpn.bg = .s440
                forward = evtREQERR_TransportRegion(reqId, code, msg)
                evtMpnCheckReset()
            }
            if forward {
                forward = evtREQERR_TransportRegion(reqId, code, msg)
            }
        }
    }
    
    private func evtREQERR_TransportRegion(_ reqId: Int, _ code: Int, _ msg: String) -> Bool {
        let evt = "REQERR"
        let retryCause = RetryCause.standardError(code, msg)
        let terminationCause = TerminationCause.standardError(code, msg)
        if s_w?.p == .s300 {
            switch code {
            case 20:
                trace(evt, State_w_p.s300, State_m.s113)
                disposeWS()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ws.reqerr.\(code)"
                let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
                clear_w()
                goto_m_from_session(.s113)
                exit_w()
                evtEndSession()
                evtRetry(.standardError(code, msg), pauseMs)
                schedule_evtRetryTimeout(pauseMs)
            case 11, 65, 67:
                trace(evt, State_w_p.s300, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_REQERR(code, msg)
                clear_w()
                goto_m_from_session(.s100)
                exit_w()
                evtEndSession()
                evtTerminate(terminationCause)
            default:
                trace(evt, State_w_p.s300, State_w_p.s300)
                s_w.p = .s300
                doREQERR(reqId, code, msg)
                evtRestartKeepalive()
            }
        } else if s_ws?.p == .s510 {
            switch code {
            case 20:
                trace(evt, State_ws_p.s510, State_m.s113)
                disposeWS()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ws.reqerr.\(code)"
                goto_m_from_ws(.s113)
                exit_ws_to_m()
                entry_m113(retryCause)
            case 11, 65, 67:
                trace(evt, State_ws_p.s510, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_REQERR(code, msg)
                goto_m_from_ws(.s100)
                exit_ws_to_m()
                evtTerminate(terminationCause)
            default:
                trace(evt, State_ws_p.s510, State_ws_p.s510)
                s_ws.p = .s510
                doREQERR(reqId, code, msg)
                evtRestartKeepalive()
            }
        } else if s_wp?.c == .s620 {
            switch code {
            case 20:
                trace(evt, State_wp_c.s620, State_m.s113)
                disposeWS()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "ws.reqerr.\(code)"
                goto_m_from_wp(.s113)
                exit_wp_to_m()
                entry_m113(retryCause)
            case 11, 65, 67:
                trace(evt, State_wp_c.s620, State_m.s100)
                disposeWS()
                notifyStatus(.DISCONNECTED)
                notifyServerError_REQERR(code, msg)
                goto_m_from_wp(.s100)
                exit_wp_to_m()
                evtTerminate(terminationCause)
            default:
                trace(evt, State_wp_c.s620, State_wp_c.s620)
                s_wp.c = .s620
                doREQERR(reqId, code, msg)
            }
        } else if s_ctrl == .s1102 {
            switch code {
            case 20:
                trace(evt, State_ctrl.s1102, State_m.s113)
                disposeHTTP()
                notifyStatus(.DISCONNECTED_WILL_RETRY)
                cause = "http.reqerr.\(code)"
                goto_m_from_ctrl(.s113)
                exit_ctrl_to_m()
                entry_m113(retryCause)
            case 11, 65, 67:
                trace(evt, State_ctrl.s1102, State_m.s100)
                disposeHTTP()
                notifyStatus(.DISCONNECTED)
                notifyServerError_REQERR(code, msg)
                goto_m_from_ctrl(.s100)
                exit_ctrl_to_m()
                evtTerminate(terminationCause)
            default:
                trace(evt, State_ctrl.s1102, State_ctrl.s1102)
                s_ctrl = .s1102
                doREQERR(reqId, code, msg)
            }
        }
        return false
    }

    func evtPROG(_ prog: Int) {
        synchronized {
            let evt = "PROG"
            let retryCause = RetryCause.prog_mismatch(rec_serverProg, prog)
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(prog)")
            }
            if s_w?.p == .s300 {
                if prog != rec_serverProg {
                    trace(evt, State_w_p.s300, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    clear_w()
                    goto_m_from_session(.s113)
                    exit_w()
                    evtEndSession()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_w_p.s300, State_w_p.s300)
                    s_w.p = .s300
                    evtRestartKeepalive()
                }
            } else if s_tr == .s220 {
                if prog != rec_serverProg {
                    trace(evt, State_tr.s220, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_session(.s113)
                    cancel_evtTransportTimeout()
                    evtEndSession()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_tr.s220, State_tr.s220)
                    s_tr = .s220
                }
            } else if s_tr == .s230 {
                if prog != rec_serverProg {
                    trace(evt, State_tr.s230, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_session(.s113)
                    cancel_evtTransportTimeout()
                    evtEndSession()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_tr.s230, State_tr.s230)
                    s_tr = .s230
                }
            } else if s_ws?.p == .s510 {
                if prog != rec_serverProg {
                    trace(evt, State_ws_p.s510, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_ws(.s113)
                    exit_ws_to_m()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_ws_p.s510, State_ws_p.s510)
                    s_ws.p = .s510
                    evtRestartKeepalive()
                }
            } else if s_wp?.p == .s611 {
                if prog != rec_serverProg {
                    trace(evt, State_wp_p.s611, State_m.s113)
                    disposeWS()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_wp(.s113)
                    exit_wp_to_m()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_wp_p.s611, State_wp_p.s611)
                    s_wp.p = .s611
                }
            } else if s_hs?.p == .s810 {
                if prog != rec_serverProg {
                    trace(evt, State_hs_p.s810, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_hs(.s113)
                    exit_hs_to_m()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_hs_p.s810, State_hs_p.s810)
                    s_hs.p = .s810
                    evtRestartKeepalive()
                }
            } else if s_hp?.m == .s901 {
                if prog != rec_serverProg {
                    trace(evt, State_hp_m.s901, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_hp(.s113)
                    exit_hp_to_m()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_hp_m.s901, State_hp_m.s901)
                    s_hp.m = .s901
                }
            } else if s_rec == .s1001 {
                if prog > rec_clientProg {
                    trace(evt, State_rec.s1001, State_m.s113)
                    disposeHTTP()
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "prog.mismatch.\(prog).\(rec_serverProg)"
                    goto_m_from_rec(.s113)
                    exit_rec_to_m()
                    entry_m113(retryCause)
                } else {
                    trace(evt, State_rec.s1001, State_rec.s1001)
                    s_rec = .s1001
                    doPROG(prog)
                }
            }
        }
    }

    func evtLOOP(_ pollingMs: Millis) {
        synchronized {
            let evt = "LOOP"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(pollingMs)")
            }
            if let s =  s_w?.p, s == .s300 {
                trace(evt, State_w_p.s300, State_tr.s200)
                closeWS()
                cause = "ws.loop"
                clear_w()
                s_tr = .s200
                exit_w()
                evtSwitchTransport()
            } else if let s = s_tr, s == .s220 {
                trace(evt, State_tr.s220, State_tr.s200)
                closeHTTP()
                cause = "http.loop"
                s_tr = .s200
                cancel_evtTransportTimeout()
                evtSwitchTransport()
            } else if let s = s_tr, s == .s230 {
                trace(evt, State_tr.s230, State_tr.s200)
                closeHTTP()
                cause = "ttl.loop"
                s_tr = .s200
                cancel_evtTransportTimeout()
                evtSwitchTransport()
            } else if let s = s_ws?.p, s == .s510 {
                trace(evt, State_ws_p.s510, State_tr.s200)
                closeWS()
                cause = "ws.loop"
                clear_ws()
                s_tr = .s200
                exit_ws()
                evtSwitchTransport()
            } else if let s = s_wp?.p, s == .s611 {
                if isSwitching() {
                    trace(evt, State_wp_p.s611, State_tr.s200)
                    closeWS()
                    cause = "ws.loop"
                    clear_wp()
                    s_tr = .s200
                    exit_wp()
                    evtSwitchTransport()
                } else {
                    trace(evt, State_wp_p.s611, State_wp_p.s612)
                    doLOOP(pollingMs)
                    s_wp.p = .s612
                    cancel_evtIdleTimeout()
                    schedule_evtPollingTimeout(m_options.m_pollingInterval)
                }
            } else if let s = s_hs?.p, s == .s810 {
                trace(evt, State_hs_p.s810, State_hs_p.s811)
                closeHTTP()
                cause = "http.loop"
                s_hs.p = .s811
                evtSwitchTransport()
            } else if let s = s_hp?.m, s == .s901 {
                if isSwitching() {
                    trace(evt, State_hp_m.s901, State_hp_m.s904)
                    closeHTTP()
                    s_hp.m = .s904
                    cancel_evtIdleTimeout()
                    evtSwitchTransport()
                } else {
                    trace(evt, State_hp_m.s901, State_hp_m.s902)
                    doLOOP(pollingMs)
                    closeHTTP()
                    s_hp.m = .s902
                    cancel_evtIdleTimeout()
                    schedule_evtPollingTimeout(m_options.m_pollingInterval)
                }
            } else if s_rec == .s1001 {
                trace(evt, State_rec.s1001, State_tr.s200)
                closeHTTP()
                cause = "recovery.loop"
                s_rec = nil
                s_tr = .s200
                exit_rec()
                evtSwitchTransport()
            }
        }
    }

    func evtCONOK(_ sessionId: String, _ reqLimit: Int, _ keepalive: Millis, _ clink: String) {
        synchronized {
            let evt = "CONOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(sessionId) \(reqLimit) \(keepalive) \(clink)")
            }
            if s_m == .s122 {
                trace(evt, State_m.s122, State_w_p.s300)
                doCONOK_CreateWS(sessionId, reqLimit, keepalive, clink)
                resetCurrentRetryDelay()
                notifyStatus(.CONNECTED_WS_STREAMING)
                s_m = .s150
                s_tr = .s210
                s_w = StateVar_w(p: .s300, k: .s310, s: .s340)
                s_rhb = .s320
                s_slw = .s330
                s_swt = .s1300
                s_bw = .s1200
                cancel_evtTransportTimeout()
                evtSendPendingControls()
                evtSendPendingMessages()
                evtStartSession()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
                evtSelectRhb()
                evtCheckTransport()
                evtCheckBW()
            } else if s_m == .s130 {
                trace(evt, State_m.s130, State_tr.s220)
                doCONOK_CreateHTTP(sessionId, reqLimit, keepalive, clink)
                resetCurrentRetryDelay()
                notifyStatus(.CONNECTED_STREAM_SENSING)
                s_m = .s150
                s_tr = .s220
                s_swt = .s1300
                s_bw = .s1200
                cancel_evtTransportTimeout()
                evtStartSession()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
                evtCheckTransport()
                evtCheckBW()
            } else if s_m == .s140 {
                trace(evt, State_m.s140, State_tr.s230)
                doCONOK_CreateHTTP(sessionId, reqLimit, keepalive, clink)
                resetCurrentRetryDelay()
                notifyStatus(.CONNECTED_STREAM_SENSING)
                s_m = .s150
                s_tr = .s230
                s_swt = .s1300
                s_bw = .s1200
                cancel_evtTransportTimeout()
                evtStartSession()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
                evtCheckTransport()
                evtCheckBW()
            } else if s_ws?.m == .s502 {
                trace(evt, State_ws_m.s502, State_ws_m.s503)
                doCONOK_BindWS_Streaming(sessionId, reqLimit, keepalive, clink)
                notifyStatus(.CONNECTED_WS_STREAMING)
                s_ws.m = .s503
                s_ws.p = .s510
                s_ws.k = .s520
                s_ws.s = .s550
                s_rhb = .s320
                s_slw = .s330
                cancel_evtTransportTimeout()
                evtSendPendingControls()
                evtSendPendingMessages()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
                evtSelectRhb()
            } else if s_wp?.p == .s610 {
                trace(evt, State_wp_p.s610, State_wp_p.s611)
                doCONOK_BindWS_Polling(sessionId, reqLimit, keepalive, clink)
                notifyStatus(.CONNECTED_WS_POLLING)
                s_wp.p = .s611
            } else if s_wp?.p == .s613 {
                trace(evt, State_wp_p.s613, State_wp_p.s611)
                doCONOK_BindWS_Polling(sessionId, reqLimit, keepalive, clink)
                s_wp.p = .s611
            } else if s_hs?.m == .s800 {
                trace(evt, State_hs_m.s800, State_hs_m.s802)
                doCONOK_BindHTTP_Streaming(sessionId, reqLimit, keepalive, clink)
                notifyStatus(.CONNECTED_HTTP_STREAMING)
                s_hs.m = .s802
                s_hs.p = .s810
                s_hs.k = .s820
                s_rhb = .s320
                s_slw = .s330
                cancel_evtTransportTimeout()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
                evtSelectRhb()
            } else if s_hs?.m == .s801 {
                trace(evt, State_hs_m.s801, State_hs_m.s802)
                doCONOK_BindHTTP_Streaming(sessionId, reqLimit, keepalive, clink)
                notifyStatus(.CONNECTED_HTTP_STREAMING)
                s_hs.m = .s802
                s_hs.p = .s810
                s_hs.k = .s820
                s_rhb = .s320
                s_slw = .s330
                cancel_evtTransportTimeout()
                schedule_evtKeepaliveTimeout(keepaliveInterval)
                evtSelectRhb()
            } else if s_hp?.m == .s900 {
                trace(evt, State_hp_m.s900, State_hp_m.s901)
                doCONOK_BindHTTP_Polling(sessionId, reqLimit, keepalive, clink)
                notifyStatus(.CONNECTED_HTTP_POLLING)
                s_hp.m = .s901
            } else if s_hp?.m == .s903 {
                trace(evt, State_hp_m.s903, State_hp_m.s901)
                doCONOK_BindHTTP_Polling(sessionId, reqLimit, keepalive, clink)
                s_hp.m = .s901
            }
        }
    }
    
    func evtSERVNAME(_ serverName: String) {
        synchronized {
            let evt = "SERVNAME"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(serverName)")
            }
            if inPushing() {
                trace(evt)
                doSERVNAME(serverName)
                if inStreaming() {
                    evtRestartKeepalive()
                }
            }
        }
    }
    
    func evtCLIENTIP(_ clientIp: String) {
        synchronized {
            let evt = "CLIENTIP"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(clientIp)")
            }
            if inPushing() {
                trace(evt)
                doCLIENTIP(clientIp)
                if inStreaming() {
                    evtRestartKeepalive()
                }
            }
        }
    }
    
    func evtCONS(_ bandwidth: RealMaxBandwidth) {
        synchronized {
            let evt = "CONS"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(bandwidth)")
            }
            if inPushing() {
                trace(evt)
                doCONS(bandwidth)
                if inStreaming() {
                    evtRestartKeepalive()
                }
            }
        }
    }
    
    func evtPROBE() {
        synchronized {
            let evt = "PROBE"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt)")
            }
            if inPushing() {
                trace(evt)
                if inStreaming() {
                    evtRestartKeepalive()
                }
            }
        }
    }
    
    func evtNOOP() {
        synchronized {
            let evt = "NOOP"
            if inPushing() {
                trace(evt)
                if inStreaming() {
                    evtRestartKeepalive()
                }
            }
        }
    }
    
    func evtSYNC(_ seconds: UInt64) {
        synchronized {
            let evt = "SYNC"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(seconds)")
            }
            var forward = true
            if s_w?.p == .s300 || s_ws?.p == .s510 || s_hs?.p == .s810 {
                trace(evt)
                forward = evtSYNC_PushingRegion(seconds)
                evtRestartKeepalive()
            } else if s_tr == .s220 || s_tr == .s230 || s_wp?.p == .s611 || s_hp?.m == .s901 || s_rec == .s1001 {
                trace(evt)
                forward = evtSYNC_PushingRegion(seconds)
            }
            if forward {
                forward = evtSYNC_PushingRegion(seconds)
            }
        }
    }
    
    private func evtSYNC_PushingRegion(_ seconds: UInt64) -> Bool {
        synchronized {
            let evt = "SYNC"
            let syncMs = Timestamp(seconds * 1_000)
            if s_slw != nil {
                switch s_slw {
                case .s330:
                    trace(evt, State_slw.s330, State_slw.s331)
                    doSYNC(syncMs)
                    s_slw = .s331
                case .s331:
                    trace(evt, State_slw.s331, State_slw.s332)
                    let result = doSYNC_G(syncMs)
                    s_slw = .s332
                    evtCheckAvg(result)
                case .s333:
                    trace(evt, State_slw.s333, State_slw.s332)
                    let result = doSYNC_NG(syncMs)
                    s_slw = .s332
                    evtCheckAvg(result)
                default:
                    break
                }
            }
            return false
        }
    }
    
    func evtMSGDONE(_ sequence: String, _ prog: Int, _ response: String) {
        synchronized {
            let evt = "MSGDONE"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(sequence) \(prog) \(response)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMSGDONE(sequence, prog, response)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtMSGFAIL(_ sequence: String, _ prog: Int, errorCode: Int, errorMsg: String) {
        synchronized {
            let evt = "MSGFAIL"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(sequence) \(prog) \(errorCode) \(errorMsg)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMSGFAIL(sequence, prog, errorCode, errorMsg)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtU(_ subId: Int, _ itemIdx: Pos, _ values: [Pos:FieldValue], _ rawValue: String) throws {
        try synchronized {
            let evt = "U"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug(rawValue)
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    try doU(subId, itemIdx, values)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtSUBOK(_ subId: Int, _ nItems: Int, _ nFields: Int) {
        synchronized {
            let evt = "SUBOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(nItems) \(nFields)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doSUBOK(subId, nItems, nFields)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtSUBCMD(_ subId: Int, _ nItems: Int, _ nFields: Int, _ keyIdx: Pos, _ cmdIdx: Pos) {
        synchronized {
            let evt = "SUBCMD"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(nItems) \(nFields) \(keyIdx) \(cmdIdx)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doSUBCMD(subId, nItems, nFields, keyIdx, cmdIdx)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtUNSUB(_ subId: Int) {
        synchronized {
            let evt = "UNSUB"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doUNSUB(subId)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtEOS(_ subId: Int, _ itemIdx: Pos) {
        synchronized {
            let evt = "EOS"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(itemIdx)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doEOS(subId, itemIdx)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtCS(_ subId: Int, _ itemIdx: Pos) {
        synchronized {
            let evt = "CS"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(itemIdx)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doCS(subId, itemIdx)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtOV(_ subId: Int, _ itemIdx: Pos, _ lostUpdates: Int) {
        synchronized {
            let evt = "OV"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(itemIdx) \(lostUpdates)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doOV(subId, itemIdx, lostUpdates)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtCONF(_ subId: Int, _ freq: RealMaxFrequency) {
        synchronized {
            let evt = "CONF"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(freq)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doCONF(subId, freq)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    enum SyncCheckResult {
        case good, not_good, bad
    }
    
    func evtCheckAvg(_ result: SyncCheckResult) {
        synchronized {
            let evt = "check.avg"
            if s_slw == .s332 {
                switch result {
                case .good:
                    trace(evt, State_slw.s332, State_slw.s331)
                    s_slw = .s331
                case .not_good:
                    trace(evt, State_slw.s332, State_slw.s333)
                    s_slw = .s333
                case .bad:
                    trace(evt, State_slw.s332, State_slw.s334)
                    disableStreaming()
                    cause = "slow"
                    s_slw = .s334
                    evtForcePolling()
                }
            }
        }
    }
    
    func evtSendPendingControls() {
        synchronized {
            let evt = "send.pending.controls"
            let controls = getPendingControls()
            if s_w?.s == .s340 && !controls.isEmpty {
                trace(evt, State_w_s.s340, State_w_s.s340)
                sendPengingControlsWS(controls)
                s_w.s = .s340
                evtRestartHeartbeat()
            } else if s_ws?.s == .s550 && !controls.isEmpty {
                trace(evt, State_ws_s.s550, State_ws_s.s550)
                sendPengingControlsWS(controls)
                s_ws.s = .s550
                evtRestartHeartbeat()
            } else if s_wp?.s == .s630 && !controls.isEmpty {
                trace(evt, State_wp_s.s630, State_wp_s.s630)
                sendPengingControlsWS(controls)
                s_wp.s = .s630
            }
        }
    }
    
    func evtSendPendingMessages() {
        synchronized {
            let evt = "send.pending.messages"
            if s_w?.s == .s340 && messageManagers.contains(where: { $0.isPending() }) {
                trace(evt, State_w_s.s340, State_w_s.s340)
                sendPendingMessagesWS()
                s_w.s = .s340
                genAckMessagesWS()
                evtRestartHeartbeat()
            } else if s_ws?.s == .s550 && messageManagers.contains(where: { $0.isPending() }) {
                trace(evt, State_ws_s.s550, State_ws_s.s550)
                sendPendingMessagesWS()
                s_ws.s = .s550
                genAckMessagesWS()
                evtRestartHeartbeat()
            } else if s_wp?.s == .s630 && messageManagers.contains(where: { $0.isPending() }) {
                trace(evt, State_wp_s.s630, State_wp_s.s630)
                sendPendingMessagesWS()
                s_wp.s = .s630
                genAckMessagesWS()
            }
        }
    }
    
    func evtSelectRhb() {
        synchronized {
            let evt = "select.rhb"
            if s_rhb == .s320 {
                if rhb_grantedInterval == 0 {
                    if m_options.reverseHeartbeatInterval == 0 {
                        trace(evt, State_rhb.s320, State_rhb.s321)
                        s_rhb = .s321
                    } else {
                        trace(evt, State_rhb.s320, State_rhb.s322)
                        rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                        s_rhb = .s322
                        schedule_evtRhbTimeout(rhb_currentInterval)
                    }
                } else {
                    if 0 < m_options.m_reverseHeartbeatInterval && m_options.m_reverseHeartbeatInterval < rhb_grantedInterval {
                        trace(evt, State_rhb.s320, State_rhb.s323)
                        rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                        s_rhb = .s323
                        schedule_evtRhbTimeout(rhb_currentInterval)
                    } else {
                        trace(evt, State_rhb.s320, State_rhb.s323)
                        rhb_currentInterval = rhb_grantedInterval
                        s_rhb = .s323
                        schedule_evtRhbTimeout(rhb_currentInterval)
                    }
                }
            }
        }
    }
    
    func evtExtSetReverseHeartbeatInterval() {
        synchronized {
            let evt = "setReverseHeartbeatInterval"
            if s_rhb != nil {
                switch s_rhb {
                case .s321 where m_options.m_reverseHeartbeatInterval != 0:
                    trace(evt, State_rhb.s321, State_rhb.s322)
                    rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                    s_rhb = .s322
                    schedule_evtRhbTimeout(rhb_currentInterval)
                case .s322:
                    if m_options.m_reverseHeartbeatInterval == 0 {
                        trace(evt, State_rhb.s322, State_rhb.s321)
                        s_rhb = .s321
                        cancel_evtRhbTimeout()
                    } else {
                        trace(evt, State_rhb.s322, State_rhb.s322)
                        rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                        s_rhb = .s322
                    }
                case .s323:
                    if 0 < m_options.m_reverseHeartbeatInterval && m_options.m_reverseHeartbeatInterval < rhb_grantedInterval {
                        trace(evt, State_rhb.s323, State_rhb.s323)
                        rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                        s_rhb = .s323
                    } else {
                        trace(evt, State_rhb.s323, State_rhb.s323)
                        rhb_currentInterval = rhb_grantedInterval
                        s_rhb = .s323
                    }
                default:
                    break
                }
            }
        }
    }
    
    func evtRestartHeartbeat() {
        synchronized {
            let evt = "restart.heartbeat"
            if s_rhb != nil {
                switch s_rhb {
                case .s322:
                    trace(evt, State_rhb.s322, State_rhb.s322)
                    s_rhb = .s322
                    cancel_evtRhbTimeout()
                    schedule_evtRhbTimeout(rhb_currentInterval)
                case .s323:
                    trace(evt, State_rhb.s323, State_rhb.s323)
                    s_rhb = .s323
                    cancel_evtRhbTimeout()
                    schedule_evtRhbTimeout(rhb_currentInterval)
                case .s324:
                    if rhb_grantedInterval == 0 {
                        if m_options.m_reverseHeartbeatInterval != 0 {
                            trace(evt, State_rhb.s324, State_rhb.s322)
                            rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                            s_rhb = .s322
                            schedule_evtRhbTimeout(rhb_currentInterval)
                        } else {
                            trace(evt, State_rhb.s324, State_rhb.s321)
                            s_rhb = .s321
                        }
                    } else {
                        if 0 < m_options.m_reverseHeartbeatInterval && m_options.m_reverseHeartbeatInterval < rhb_grantedInterval {
                            trace(evt, State_rhb.s324, State_rhb.s323)
                            rhb_currentInterval = m_options.m_reverseHeartbeatInterval
                            s_rhb = .s323
                            schedule_evtRhbTimeout(rhb_currentInterval)
                        } else {
                            trace(evt, State_rhb.s324, State_rhb.s323)
                            rhb_currentInterval = rhb_grantedInterval
                            s_rhb = .s323
                            schedule_evtRhbTimeout(rhb_currentInterval)
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    func evtRhbTimeout() {
        synchronized {
            let evt = "rhb.timeout"
            if s_rhb == .s322 {
                trace(evt, State_rhb.s322, State_rhb.s324)
                s_rhb = .s324
                cancel_evtRhbTimeout()
                evtSendHeartbeat()
            } else if s_rhb == .s323 {
                trace(evt, State_rhb.s323, State_rhb.s324)
                s_rhb = .s324
                cancel_evtRhbTimeout()
                evtSendHeartbeat()
            }
        }
    }
    
    func evtDisposeCtrl() {
        synchronized {
            let evt = "du:dispose.ctrl"
            trace(evt, s_du, s_du)
            disposeCtrl()
        }
    }
    
    func evtStartRecovery() {
        synchronized {
            let evt = "start.recovery"
            if s_rec == .s1000 {
                trace(evt, State_rec.s1000, State_rec.s1000)
                recoverTs = scheduler.now
                s_rec = .s1000
            }
        }
    }
    
    func evtRecoveryTimeout() {
        synchronized {
            let evt = "recovery.timeout"
            if s_rec == .s1000 {
                trace(evt, State_rec.s1000, State_rec.s1001)
                sendRecovery()
                s_rec = .s1001
                cancel_evtRecoveryTimeout()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            }
        }
    }
    
    enum RecoveryRetryCause {
        case transport_timeout, transport_error
        
        var errorMsg: String {
            switch self {
            case .transport_error:
                return "connection error"
            case .transport_timeout:
                return "connection timeout"
            }
        }
    }
    
    func evtCheckRecoveryTimeout(_ retryCause: RecoveryRetryCause) {
        synchronized {
            let evt = "check.recovery.timeout"
            if s_rec == .s1002 {
                let retryDelayMs = UInt64(m_options.m_retryDelay)
                let sessionRecoveryMs = UInt64(m_options.m_sessionRecoveryTimeout)
                if connectTs + retryDelayMs < recoverTs + sessionRecoveryMs {
                    trace(evt, State_rec.s1002, State_rec.s1003)
                    cause = "recovery.error"
                    let diffMs = scheduler.now - connectTs
                    let pauseMs = retryDelayMs > diffMs ? Millis(retryDelayMs - diffMs) : 0
                    s_rec = .s1003
                    if sessionLogger.isErrorEnabled {
                        if pauseMs > 0 {
                            sessionLogger.error("Retrying recovery in \(pauseMs)ms. Cause: \(retryCause.errorMsg)")
                        } else {
                            sessionLogger.error("Retrying recovery. Cause: \(retryCause.errorMsg)")
                        }
                    }
                    schedule_evtRetryTimeout(pauseMs)
                } else {
                    trace(evt, State_rec.s1002, State_m.s113)
                    notifyStatus(.DISCONNECTED_WILL_RETRY)
                    cause = "recovery.timeout"
                    goto_m_from_rec(.s113)
                    exit_rec_to_m()
                    entry_m113(.recovery_timeout)
                }
            }
        }
    }
    
    func evtSwitchTransport() {
        synchronized {
            let evt = "switch.transport"
            var forward = true
            if let s = s_swt, s == .s1302 || s == .s1303 {
                trace(evt, s_swt!, State_swt.s1300)
                s_swt = .s1300
                forward = evtSwitchTransport_forwardToTransportRegion()
                evtCheckTransport()
            }
            if forward {
                forward = evtSwitchTransport_forwardToTransportRegion()
            }
        }
    }
    
    private func evtSwitchTransport_forwardToTransportRegion() -> Bool {
        let evt = "switch.transport"
        let terminationCause = TerminationCause.otherError("Selected transport \(m_options.forcedTransport?.rawValue ?? "ALL") is not available")
        if let s = s_tr, s == .s200 {
            switch getBestForBinding() {
            case .ws_streaming:
                trace(evt, State_tr.s200, State_ws_m.s500)
                openWS_Bind()
                s_tr = .s240
                s_ws = StateVar_ws(m: .s500)
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_streaming:
                trace(evt, State_tr.s200, State_hs_m.s800)
                sendBindHTTP_Streaming()
                s_tr = .s270
                s_h = .s710
                s_hs = StateVar_hs(m: .s800)
                s_ctrl = .s1100
                evtCheckCtrlRequests()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .ws_polling:
                trace(evt, State_tr.s200, State_wp_m.s600)
                openWS_Bind()
                s_tr = .s250
                s_wp = StateVar_wp(m: .s600)
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_polling:
                trace(evt, State_tr.s200, State_hp_m.s900)
                sendBindHTTP_Polling()
                s_tr = .s270
                s_h = .s720
                s_hp = StateVar_hp(m: .s900)
                s_rhb = .s320
                s_ctrl = .s1100
                evtCheckCtrlRequests()
                schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
                evtSelectRhb()
            case .none:
                trace(evt, State_tr.s200, State_m.s100)
                notifyStatus(.DISCONNECTED)
                goto_m_from_session(.s100)
                evtEndSession()
                evtTerminate(terminationCause)
            }
        } else if let s = s_hs?.p, s == .s811 {
            switch getBestForBinding() {
            case .ws_streaming:
                trace(evt, State_hs_p.s811, State_ws_m.s500)
                openWS_Bind()
                clear_hs()
                s_h = nil
                s_ctrl = nil
                s_tr = .s240
                s_ws = StateVar_ws(m: .s500)
                exit_hs()
                exit_ctrl()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_streaming:
                trace(evt, State_hs_p.s811, State_hs_m.s800)
                sendBindHTTP_Streaming()
                s_hs = StateVar_hs(m: .s800)
                exit_hs()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .ws_polling:
                trace(evt, State_hs_p.s811, State_wp_m.s600)
                openWS_Bind()
                clear_hs()
                s_h = nil
                s_ctrl = nil
                s_tr = .s250
                s_wp = StateVar_wp(m: .s600)
                exit_hs()
                exit_ctrl()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_polling:
                trace(evt, State_hs_p.s811, State_hp_m.s900)
                sendBindHTTP_Polling()
                clear_hs()
                s_h = .s720
                s_hp = StateVar_hp(m: .s900)
                s_rhb = .s320
                exit_hs()
                schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
                evtSelectRhb()
            case .none:
                trace(evt, State_hs_p.s811, State_m.s100)
                notifyStatus(.DISCONNECTED)
                goto_m_from_hs(.s100)
                exit_hs_to_m()
                evtTerminate(terminationCause)
            }
        } else if let s = s_hp?.m, s == .s904 {
            switch getBestForBinding() {
            case .ws_streaming:
                trace(evt, State_hp_m.s904, State_ws_m.s500)
                openWS_Bind()
                clear_hp()
                s_h = nil
                s_ctrl = nil
                s_tr = .s240
                s_ws = StateVar_ws(m: .s500)
                exit_hp()
                exit_ctrl()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_streaming:
                trace(evt, State_hp_m.s904, State_hs_m.s800)
                sendBindHTTP_Streaming()
                clear_hp()
                s_h = .s710
                s_hs = StateVar_hs(m: .s800)
                exit_hp()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .ws_polling:
                trace(evt, State_hp_m.s904, State_wp_m.s600)
                openWS_Bind()
                clear_hp()
                s_h = nil
                s_ctrl = nil
                s_tr = .s250
                s_wp = StateVar_wp(m: .s600)
                exit_hp()
                exit_ctrl()
                schedule_evtTransportTimeout(m_options.m_retryDelay)
            case .http_polling:
                trace(evt, State_hp_m.s904, State_hp_m.s900)
                sendBindHTTP_Polling()
                s_hp = StateVar_hp(m: .s900)
                s_rhb = .s320
                exit_hp()
                schedule_evtIdleTimeout(idleTimeout + m_options.m_retryDelay)
                evtSelectRhb()
            case .none:
                trace(evt, State_hp_m.s904, State_m.s100)
                notifyStatus(.DISCONNECTED)
                goto_m_from_hp(.s100)
                exit_hp_to_m()
                evtTerminate(terminationCause)
            }
        }
        return false
    }
    
    func evtCreate() {
        synchronized {
            let evt = "du:create"
            switch s_du {
            case .s20:
                trace(evt, State_du.s20, State_du.s21)
                s_du = .s21
            case .s23:
                trace(evt, State_du.s23, State_du.s21)
                s_du = .s21
            default:
                break
            }
        }
    }
    
    func evtCheckTransport() {
        synchronized {
            let evt = "check.transport"
            if let s = s_swt, s == .s1300 {
                if s_tr == .s220 || s_tr == .s230 || s_tr == .s260 {
                    trace(evt, State_swt.s1300, State_swt.s1301)
                    s_swt = .s1301
                } else {
                    let best = getBestForBinding()
                    if (best == .ws_streaming && (s_tr == .s210 || s_tr == .s240)) ||
                        (best == .http_streaming && s_tr == .s270 && s_h == .s710) ||
                        (best == .ws_polling && s_tr == .s250) ||
                        (best == .http_polling && s_tr == .s270 && s_h == .s720) {
                        trace(evt, State_swt.s1300, State_swt.s1301)
                        s_swt = .s1301
                    } else {
                        trace(evt, State_swt.s1300, State_swt.s1302)
                        s_swt = .s1302
                        evtSendControl(switchRequest)
                    }
                }
            }
        }
    }
    
    func evtCheckBW() {
        synchronized {
            let evt = "check.bw"
            if s_bw == .s1200 {
                if bw_requestedMaxBandwidth != m_options.m_requestedMaxBandwidth
                    && m_options.m_realMaxBandwidth != .unmanaged {
                    trace(evt, State_bw.s1200, State_bw.s1202)
                    bw_requestedMaxBandwidth = m_options.m_requestedMaxBandwidth
                    s_bw = .s1202
                    evtSendControl(constrainRequest)
                } else {
                    trace(evt, State_bw.s1200, State_bw.s1201)
                    s_bw = .s1201
                }
            }
        }
    }
    
    func evtCheckCtrlRequests() {
        synchronized {
            let evt = "check.ctrl.requests"
            if s_ctrl == .s1100 {
                let controls = getPendingControls()
                if !controls.isEmpty {
                    trace(evt, State_ctrl.s1100, State_ctrl.s1102)
                    sendPendingControlsHTTP(controls)
                    s_ctrl = .s1102
                    evtRestartHeartbeat()
                    schedule_evtCtrlTimeout(m_options.m_retryDelay)
                } else if messageManagers.contains(where: { $0.isPending() }) {
                    trace(evt, State_ctrl.s1100, State_ctrl.s1102)
                    sendPendingMessagesHTTP()
                    s_ctrl = .s1102
                    evtRestartHeartbeat()
                    schedule_evtCtrlTimeout(m_options.m_retryDelay)
                } else if s_rhb == .s324 {
                    trace(evt, State_ctrl.s1100, State_ctrl.s1102)
                    sendHeartbeatHTTP()
                    s_ctrl = .s1102
                    evtRestartHeartbeat()
                    schedule_evtCtrlTimeout(m_options.m_retryDelay)
                } else {
                    trace(evt, State_ctrl.s1100, State_ctrl.s1101)
                    s_ctrl = .s1101
                }
            }
        }
    }
    
    func evtCtrlDone() {
        synchronized {
            let evt = "ctrl.done"
            if let c = s_ctrl, c == .s1102 {
                trace(evt, State_ctrl.s1102, State_ctrl.s1100)
                closeCtrl()
                s_ctrl = .s1100
                cancel_evtCtrlTimeout()
                evtCheckCtrlRequests()
            }
        }
    }
    
    func evtCtrlError() {
        synchronized {
            let evt = "ctrl.error"
            if let c = s_ctrl, c == .s1102 {
                trace(evt, State_ctrl.s1102, State_ctrl.s1103)
                disposeCtrl()
                let pauseMs = waitingInterval(expectedMs: m_options.m_retryDelay, from: ctrl_connectTs)
                s_ctrl = .s1103
                cancel_evtCtrlTimeout()
                schedule_evtCtrlTimeout(pauseMs)
            }
        }
    }
    
    func evtCtrlTimeout() {
        synchronized {
            let evt = "ctrl.timeout"
            if let c = s_ctrl {
                if c == .s1102 {
                    trace(evt, State_ctrl.s1102, State_ctrl.s1103)
                    disposeCtrl()
                    let pauseMs = waitingInterval(expectedMs: m_options.m_retryDelay, from: ctrl_connectTs)
                    s_ctrl = .s1103
                    cancel_evtCtrlTimeout()
                    schedule_evtCtrlTimeout(pauseMs)
                } else if c == .s1103 {
                    trace(evt, State_ctrl.s1103, State_ctrl.s1100)
                    s_ctrl = .s1100
                    cancel_evtCtrlTimeout()
                    evtCheckCtrlRequests()
                }
            }
        }
    }
    
    func evtSendControl(_ request: Encodable) {
        synchronized {
            let evt = "send.control"
            if s_w?.s == .s340 {
                trace(evt, State_w_s.s340, State_w_s.s340)
                sendControlWS(request)
                s_w.s = .s340
                evtRestartHeartbeat()
            } else if s_ws?.s == .s550 {
                trace(evt, State_ws_s.s550, State_ws_s.s550)
                sendControlWS(request)
                s_ws.s = .s550
                evtRestartHeartbeat()
            } else if s_wp?.s == .s630 {
                trace(evt, State_wp_s.s630, State_wp_s.s630)
                sendControlWS(request)
                s_wp.s = .s630
            } else if s_ctrl == .s1101 {
                trace(evt, State_ctrl.s1101, State_ctrl.s1100)
                s_ctrl = .s1100
                evtCheckCtrlRequests()
            }
        }
    }
    
    func evtSendHeartbeat() {
        synchronized {
            let evt = "send.heartbeat"
            if s_w?.s == .s340 {
                trace(evt, State_w_s.s340, State_w_s.s340)
                sendHeartbeatWS()
                s_w.s = .s340
                evtRestartHeartbeat()
            } else if s_ws?.s == .s550 {
                trace(evt, State_ws_s.s550, State_ws_s.s550)
                sendHeartbeatWS()
                s_ws.s = .s550
                evtRestartHeartbeat()
            } else if s_ctrl == .s1101 {
                trace(evt, State_ctrl.s1101, State_ctrl.s1100)
                s_ctrl = .s1100
                evtCheckCtrlRequests()
            }
        }
    }

    func evtStartSession() {
        synchronized {
            if sessionLogger.isInfoEnabled {
                sessionLogger.info("Starting new session: \(sessionId!)")
            }
            let evt = "du:start.session"
            switch s_du {
            case .s21:
                trace(evt, State_du.s21, State_du.s22)
                s_du = .s22
            default:
                break
            }
        }
    }
    
    func evtEndSession() {
        synchronized {
            if sessionLogger.isInfoEnabled {
                sessionLogger.info("Destroying session: \(sessionId!)")
            }
        }
    }
    
    enum RetryCause {
        case standardError(Int, String)
        case ws_unavailable
        case ws_error
        case http_error
        case idle_timeout
        case stalled_timeout
        case ws_timeout
        case http_timeout
        case recovery_timeout
        case prog_mismatch(_ expected: Int, _ actual: Int)
        
        var errorMsg: String {
            var cause: String!
            switch self {
            case .standardError(let code, let msg):
                cause = "\(code) - \(msg)"
            case .ws_unavailable:
                cause = "Websocket transport not available"
            case .ws_error:
                cause = "Websocket error"
            case .http_error:
                cause = "HTTP error"
            case .idle_timeout:
                cause = "idleTimeout expired"
            case .stalled_timeout:
                cause = "stalledTimeout expired"
            case .ws_timeout:
                cause = "Websocket connect timeout expired"
            case .http_timeout:
                cause = "HTTP connect timeout expired"
            case .recovery_timeout:
                cause = "sessionRecoveryTimeout expired"
            case .prog_mismatch(let expected, let actual):
                cause = "Recovery counter mismatch: expected \(expected) but found \(actual)"
            }
            return cause
        }
    }

    func evtRetry(_ retryCause: RetryCause, _ timeout: Millis? = nil) {
        synchronized {
            if sessionLogger.isErrorEnabled {
                if let timeout = timeout, timeout > 0 {
                    sessionLogger.error("Retrying connection in \(timeout)ms. Cause: \(retryCause.errorMsg)")
                } else {
                    sessionLogger.error("Retrying connection. Cause: \(retryCause.errorMsg)")
                }
            }
            let evt = "du:retry"
            var forward = true
            switch s_du {
            case .s21:
                trace(evt, State_du.s21, State_du.s23)
                resetSequenceMap()
                s_du = .s23
                forward = evtRetry_MpnRegion()
                genAbortMessages()
            case .s22:
                trace(evt, State_du.s22, State_du.s23)
                disposeSession()
                s_du = .s23
                forward = evtRetry_MpnRegion()
                genAbortSubscriptions()
                genAbortMessages()
            default:
                break
            }
            if forward {
                forward = evtRetry_MpnRegion()
            }
        }
    }
    
    private func evtRetry_MpnRegion() -> Bool {
        let evt = "mpn:retry"
        switch s_mpn.m {
        case .s403, .s404:
            trace(evt, s_mpn.m, State_mpn_m.s403)
            s_mpn.m = .s403
        case .s406, .s407:
            trace(evt, s_mpn.m, State_mpn_m.s406)
            s_mpn.m = .s406
        case .s405:
            trace(evt, State_mpn_m.s405, State_mpn_m.s406)
            doRemoveMpnSpecialListeners()
            s_mpn.m = .s406
            s_mpn.st = nil
            s_mpn.tk = nil
            s_mpn.sbs = nil
            s_mpn.ft = nil
            s_mpn.bg = nil
            genUnsubscribeMpnSpecialItems()
        default:
            break
        }
        return false
    }
    
    enum TerminationCause {
        case standardError(Int, String)
        case otherError(String)
        case api
    }

    func evtTerminate(_ terminationCause: TerminationCause) {
        synchronized {
            if sessionLogger.isInfoEnabled {
                switch terminationCause {
                case .api:
                    sessionLogger.info("Disconnected. Cause: Requested by user")
                default:
                    // see below
                    break
                }
            }
            if sessionLogger.isErrorEnabled {
                switch terminationCause {
                case .standardError(let code, let msg):
                    sessionLogger.error("Disconnected. Cause: \(code) - \(msg)")
                case .otherError(let msg):
                    sessionLogger.error("Disconnected. Cause: \(msg)")
                case .api:
                    // see above
                    break
                }
            }
            let evt = "du:terminate"
            var forward = true
            switch s_du {
            case .s22:
                trace(evt, State_du.s22, State_du.s20)
                disposeSession()
                disposeClient()
                s_du = .s20
                forward = evtTerminate_MpnRegion()
                genAbortSubscriptions()
                genAbortMessages()
            case .s23:
                trace(evt, State_du.s23, State_du.s20)
                disposeClient()
                s_du = .s20
                forward = evtTerminate_MpnRegion()
                genAbortMessages()
            case .s21:
                trace(evt, State_du.s21, State_du.s20)
                disposeClient()
                s_du = .s20
                forward = evtTerminate_MpnRegion()
                genAbortMessages()
            default:
                break
            }
            if forward {
                forward = evtTerminate_MpnRegion()
            }
        }
    }
    
    private func evtTerminate_MpnRegion() -> Bool {
        let evt = "mpn:terminate"
        var forward = true
        switch s_mpn.m {
        case .s403, .s404:
            trace(evt, s_mpn.m, State_mpn_m.s401)
            s_mpn.m = .s401
            forward = evtTerminate_NetworkReachabilityRegion()
            evtResetMpnDevice()
        case .s406, .s407:
            trace(evt, s_mpn.m, State_mpn_m.s401)
            s_mpn.m = .s401
            forward = evtTerminate_NetworkReachabilityRegion()
            evtResetMpnDevice()
        case .s405:
            trace(evt, State_mpn_m.s405, State_mpn_m.s401)
            doRemoveMpnSpecialListeners()
            s_mpn.m = .s401
            s_mpn.st = nil
            s_mpn.tk = nil
            s_mpn.sbs = nil
            s_mpn.ft = nil
            s_mpn.bg = nil
            forward = evtTerminate_NetworkReachabilityRegion()
            genUnsubscribeMpnSpecialItems()
            evtResetMpnDevice()
        default:
            break
        }
        if forward {
            forward = evtTerminate_NetworkReachabilityRegion()
        }
        return false
    }
    
    func evtTerminate_NetworkReachabilityRegion() -> Bool {
        let evt = "nr:terminate"
        switch s_nr {
        case .s1410, .s1411, .s1412:
            trace(evt, s_nr, State_nr.s1400)
            let rm = nr_reachabilityManager
            nr_reachabilityManager = nil
            s_nr = .s1400
            rm?.stopListening()
        default:
            break
        }
        return false
    }
    
    func evtRetryTimeout() {
        synchronized {
            let evt = "retry.timeout"
            switch s_m {
            case .s115:
                trace(evt, State_m.s115, State_m.s116)
                s_m = .s116
                evtSelectCreate()
            case .s112:
                trace(evt, State_m.s112, State_m.s116)
                delayCounter.increase()
                s_m = .s116
                cancel_evtRetryTimeout()
                evtSelectCreate()
            case .s110:
                trace(evt, State_m.s110, State_m.s140)
                notifyStatus(.CONNECTING)
                sendCreateTTL()
                s_m = .s140
                evtCreate()
                schedule_evtTransportTimeout(60_000)
            case .s111:
                trace(evt, State_m.s111, State_m.s140)
                notifyStatus(.CONNECTING)
                delayCounter.increase()
                sendCreateTTL()
                s_m = .s140
                cancel_evtRetryTimeout()
                evtCreate()
                schedule_evtTransportTimeout(60_000)
            case .s113:
                trace(evt, State_m.s113, State_m.s116)
                s_m = .s116
                cancel_evtRetryTimeout()
                evtSelectCreate()
            case .s150:
                if s_rec == .s1003 {
                    trace(evt, State_rec.s1003, State_rec.s1001)
                    sendRecovery()
                    s_rec = .s1001
                    cancel_evtRetryTimeout()
                    schedule_evtTransportTimeout(m_options.m_retryDelay)
                }
            default:
                break
            }
        }
    }
    
    func evtExtSetForcedTransport() {
        synchronized {
            let evt = "setForcedTransport"
            if let s = s_swt, s == .s1301 {
                trace(evt, State_swt.s1301, State_swt.s1300)
                s_swt = .s1300
                evtCheckTransport()
            }
        }
    }
    
    func evtExtSetRequestedMaxBandwidth() {
        synchronized {
            let evt = "setRequestedMaxBandwidth"
            if s_bw == .s1201 {
                trace(evt, State_bw.s1201, State_bw.s1200)
                s_bw = .s1200
                evtCheckBW()
            }
        }
    }
    
    func evtForceSlowing() {
        synchronized {
            let evt = "force.slowing"
            if s_swt == .s1301 {
                trace(evt, State_swt.s1301, State_swt.s1300)
                s_swt = .s1300
                evtCheckTransport()
            }
        }
    }
    
    func evtForcePolling() {
        synchronized {
            let evt = "force.polling"
            if s_swt == .s1301 {
                trace(evt, State_swt.s1301, State_swt.s1300)
                s_swt = .s1300
                evtCheckTransport()
            }
        }
    }
    
    func evtSendMessage(_ msg: MessageManager) {
        synchronized {
            let evt = "send.message"
            if s_w?.s == .s340 {
                trace(evt, State_w_s.s340, State_w_s.s340)
                sendMsgWS(msg)
                s_w.s = .s340
                msg.evtWSSent()
                evtRestartHeartbeat()
            } else if s_ws?.s == .s550 {
                trace(evt, State_ws_s.s550, State_ws_s.s550)
                sendMsgWS(msg)
                s_ws.s = .s550
                msg.evtWSSent()
                evtRestartHeartbeat()
            } else if s_wp?.s == .s630 {
                trace(evt, State_wp_s.s630, State_wp_s.s630)
                sendMsgWS(msg)
                s_wp.s = .s630
                msg.evtWSSent()
            } else if s_ctrl == .s1101 {
                trace(evt, State_ctrl.s1101, State_ctrl.s1100)
                s_ctrl = .s1100
                evtCheckCtrlRequests()
            }
        }
    }
    
    /* MPN event handlers - BEGIN */
    
    func evtExtMpnRegister() {
        synchronized {
            let evt = "mpn.register"
            if s_mpn.m == .s400 {
                trace(evt, State_mpn_m.s400, State_mpn_m.s402)
                s_mpn.m = .s402
                evtMpnCheckNext()
            } else if s_mpn.m == .s401 {
                trace(evt, State_mpn_m.s401, State_mpn_m.s402)
                s_mpn.m = .s402
                evtMpnCheckNext()
            } else if s_mpn.tk == .s451 {
                trace(evt, State_mpn_tk.s451, State_mpn_tk.s452)
                s_mpn.tk = .s452
                evtMpnCheckNext()
            }
        }
    }
    
    func evtMpnCheckNext() {
        synchronized {
            let evt = "mpn.check.next"
            if s_mpn.m == .s402 {
                if mpn_candidate_devices.isEmpty {
                    trace(evt, State_mpn_m.s402, State_mpn_m.s401)
                    s_mpn.m = .s401
                    evtResetMpnDevice()
                } else {
                    trace(evt, State_mpn_m.s402, State_mpn_m.s403)
                    doRegisterMpnDevice()
                    s_mpn.m = .s403
                    genSendMpnRegister()
                }
            } else if s_mpn.m == .s408 {
                if mpn_candidate_devices.isEmpty {
                    trace(evt, State_mpn_m.s408, State_mpn_m.s401)
                    s_mpn.m = .s401
                    evtResetMpnDevice()
                } else {
                    trace(evt, State_mpn_m.s408, State_mpn_m.s406)
                    doRegisterMpnDevice()
                    s_mpn.m = .s406
                    genSendMpnRegister()
                }
            } else if s_mpn.tk == .s452 {
                if mpn_candidate_devices.isEmpty {
                    trace(evt, State_mpn_tk.s452, State_mpn_m.s401)
                    doRemoveMpnSpecialListeners()
                    s_mpn.m = .s401
                    s_mpn.st = nil
                    s_mpn.tk = nil
                    s_mpn.sbs = nil
                    s_mpn.ft = nil
                    s_mpn.bg = nil
                    genUnsubscribeMpnSpecialItems()
                    evtResetMpnDevice()
                } else {
                    trace(evt, State_mpn_tk.s452, State_mpn_tk.s453)
                    doRegisterMpnDevice()
                    s_mpn.tk = .s453
                    genSendMpnRegister()
                }
            }
        }
    }
    
    func evtResetMpnDevice() {
        synchronized {
            let evt = "reset.mpn.device"
            if s_mpn.m == .s401 {
                trace(evt, State_mpn_m.s401, State_mpn_m.s401)
                doResetMpnDevice()
                notifyDeviceReset()
                s_mpn.m = .s401
            }
        }
    }
    
    func evtMpnError(_ code: Int, _ msg: String) {
        synchronized {
            let evt = "mpn.error"
            if s_mpn.m == .s405 {
                trace(evt, State_mpn_m.s405, State_mpn_m.s401)
                doRemoveMpnSpecialListeners()
                notifyDeviceError(code, msg)
                s_mpn.m = .s401
                s_mpn.st = nil
                s_mpn.sbs = nil
                s_mpn.ft = nil
                s_mpn.bg = nil
                s_mpn.tk = nil
                genUnsubscribeMpnSpecialItems()
                evtResetMpnDevice()
            }
        }
    }
    
    func evtMPNREG(_ deviceId: String, _ adapterName: String) {
        synchronized {
            let evt = "MPNREG"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(deviceId) \(adapterName)")
            }
            var forward = true
            if inPushing() {
                if isFreshData() {
                    trace(evt, cond: "fresh")
                    doMPNREG()
                    let inStreaming = inStreaming()
                    forward = evtMPNREG_MpnRegion(deviceId, adapterName)
                    if inStreaming {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    let inStreaming = inStreaming()
                    forward = evtMPNREG_MpnRegion(deviceId, adapterName)
                    if inStreaming {
                        evtRestartKeepalive()
                    }
                }
            }
            if forward {
                forward = evtMPNREG_MpnRegion(deviceId, adapterName)
            }
        }
    }
    
    private func evtMPNREG_MpnRegion(_ deviceId: String, _ adapterName: String) -> Bool {
        let evt = "MPNREG"
        if s_mpn.m == .s403 || s_mpn.m == .s404 {
            trace(evt, s_mpn.m, State_mpn_m.s405)
            doMPNREG_Register(deviceId, adapterName)
            notifyDeviceRegistered(0)
            s_mpn.m = .s405
            s_mpn.st = .s410
            s_mpn.sbs = .s420
            s_mpn.ft = .s430
            s_mpn.bg = .s440
            s_mpn.tk = .s450
            genDeviceActive()
            genSubscribeSpecialItems()
            evtMpnCheckPending()
            evtSUBS_Init()
            evtMpnCheckFilter()
            evtMpnCheckReset()
        } else if s_mpn.m == .s406 || s_mpn.m == .s407 {
            if deviceId == mpn_deviceId && adapterName == mpn_adapterName {
                trace(evt, s_mpn.m, State_mpn_m.s405)
                doMPNREG_Register(deviceId, adapterName)
                notifyDeviceRegistered(0)
                s_mpn.m = .s405
                s_mpn.st = .s410
                s_mpn.sbs = .s420
                s_mpn.ft = .s430
                s_mpn.bg = .s440
                s_mpn.tk = .s450
                genDeviceActive()
                genSubscribeSpecialItems()
                evtMpnCheckPending()
                evtSUBS_Init()
                evtMpnCheckFilter()
                evtMpnCheckReset()
            } else {
                trace(evt, s_mpn.m, State_mpn_m.s408)
                doMPNREG_Error()
                notifyDeviceError_DifferentDevice()
                s_mpn.m = .s408
                evtMpnCheckNext()
            }
        } else if let s = s_mpn.tk, s == .s453 || s == .s454 {
            if deviceId == mpn_deviceId && adapterName == mpn_adapterName {
                trace(evt, s, State_mpn_tk.s450)
                doMPNREG_RefreshToken(deviceId, adapterName)
                s_mpn.tk = .s450
                evtMpnCheckPending()
            } else {
                trace(evt, s, State_mpn_tk.s452)
                doMPNREG_Error()
                notifyDeviceError_DifferentDevice()
                s_mpn.tk = .s452
                evtMpnCheckNext()
            }
        }
        return false
    }
    
    func evtMPNZERO(_ deviceId: String) {
        synchronized {
            let evt = "MPNZERO"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(deviceId)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMPNZERO(deviceId)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtMPNOK(_ subId: Int, _ mpnSubId: String) {
        synchronized {
            let evt = "MPNOK"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(subId) \(mpnSubId)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMPNOK(subId, mpnSubId)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtMPNDEL(_ mpnSubId: String) {
        synchronized {
            let evt = "MPNDEL"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(mpnSubId)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMPNDEL(mpnSubId)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtMPNCONF(_ mpnSubId: String) {
        synchronized {
            let evt = "MPNCONF"
            if protocolLogger.isDebugEnabled {
                protocolLogger.debug("\(evt) \(mpnSubId)")
            }
            if inPushing() {
                if isFreshData() {
                    trace(evt)
                    doMPNCONF(mpnSubId)
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                } else {
                    trace(evt, cond: "stale")
                    onStaleData()
                    if inStreaming() {
                        evtRestartKeepalive()
                    }
                }
            }
        }
    }
    
    func evtDEV_Update(_ status: String, _ timestamp: Int64) {
        synchronized {
            let evt = "DEV.update"
            if s_mpn.st == .s410 {
                if status == "ACTIVE" {
                    trace(evt, State_mpn_st.s410, State_mpn_st.s410)
                    if !mpn_device.isRegistered {
                        notifyDeviceRegistered(timestamp)
                    }
                    s_mpn.st = .s410
                } else if status == "SUSPENDED" {
                    trace(evt, State_mpn_st.s410, State_mpn_st.s411)
                    if !mpn_device.isSuspended {
                        notifyDeviceSuspended(timestamp)
                    }
                    s_mpn.st = .s411
                }
            } else if s_mpn.st == .s411 {
                if status == "ACTIVE" {
                    trace(evt, State_mpn_st.s411, State_mpn_st.s410)
                    notifyDeviceResume(timestamp)
                    s_mpn.st = .s410
                }
            }
        }
    }
    
    func evtMpnCheckPending() {
        synchronized {
            let evt = "mpn.check.pending"
            if s_mpn.tk == .s450 {
                if mpn_candidate_devices.isEmpty {
                    trace(evt, State_mpn_tk.s450, State_mpn_tk.s451)
                    s_mpn.tk = .s451
                } else {
                    trace(evt, State_mpn_tk.s450, State_mpn_tk.s452)
                    s_mpn.tk = .s452
                    evtMpnCheckNext()
                }
            }
        }
    }
    
    func evtSUBS_Init() {
        synchronized {
            let evt = "SUBS.init"
            if s_mpn.sbs == .s420 {
                trace(evt, State_mpn_sbs.s420, State_mpn_sbs.s421)
                doClearMpnSnapshot()
                s_mpn.sbs = .s421
            }
        }
    }
    
    func evtSUBS_Update(_ mpnSubId: String, _ update: ItemUpdate) {
        synchronized {
            let evt = "SUBS.update"
            let command = update.value(withFieldName: "command")
            let status = update.value(withFieldName: "status")
            if let s = s_mpn.sbs, exists(mpnSubId: mpnSubId) {
                trace(evt, cond: "top", s, s)
                genSUBS_update(mpnSubId, update)
            } else if s_mpn.sbs == .s421 && command != "DELETE" && !exists(mpnSubId: mpnSubId) {
                if status == nil {
                    trace(evt, cond: "nil", State_mpn_sbs.s421, State_mpn_sbs.s423)
                    doAddToMpnSnapshot(mpnSubId)
                    s_mpn.sbs = .s423
                } else {
                    trace(evt, cond: status!, State_mpn_sbs.s421, State_mpn_sbs.s423)
                    doRemoveFromMpnSnapshot(mpnSubId)
                    doAddMpnSubscription(mpnSubId)
                    s_mpn.sbs = .s423
                    genSUBS_update(mpnSubId, update)
                }
            } else if s_mpn.sbs == .s423 && command != "DELETE" && !exists(mpnSubId: mpnSubId) {
                if status == nil {
                    trace(evt, cond: "nil", State_mpn_sbs.s423, State_mpn_sbs.s423)
                    doAddToMpnSnapshot(mpnSubId)
                    s_mpn.sbs = .s423
                } else {
                    trace(evt, cond: status!, State_mpn_sbs.s423, State_mpn_sbs.s423)
                    doRemoveFromMpnSnapshot(mpnSubId)
                    doAddMpnSubscription(mpnSubId)
                    s_mpn.sbs = .s423
                    genSUBS_update(mpnSubId, update)
                }
            } else if s_mpn.sbs == .s424 && command != "DELETE" && status != nil && !exists(mpnSubId: mpnSubId) {
                if mpn_snapshotSet.count == 0 || (mpn_snapshotSet.count == 1 && mpn_snapshotSet.contains(mpnSubId)) {
                    trace(evt, cond: "empty", State_mpn_sbs.s424, State_mpn_sbs.s424)
                    doRemoveFromMpnSnapshot(mpnSubId)
                    doAddMpnSubscription(mpnSubId)
                    s_mpn.sbs = .s424
                    genSUBS_update(mpnSubId, update)
                    notifyOnSubscriptionsUpdated()
                } else if (mpn_snapshotSet.count == 1 && !mpn_snapshotSet.contains(mpnSubId)) || mpn_snapshotSet.count > 1 {
                    trace(evt, cond: "not empty", State_mpn_sbs.s424, State_mpn_sbs.s424)
                    doRemoveFromMpnSnapshot(mpnSubId)
                    doAddMpnSubscription(mpnSubId)
                    s_mpn.sbs = .s424
                    genSUBS_update(mpnSubId, update)
                }
            }
        }
    }
    
    func evtSUBS_EOS() {
        synchronized {
            let evt = "SUBS.EOS"
            if s_mpn.sbs == .s421 {
                trace(evt, State_mpn_sbs.s421, State_mpn_sbs.s424)
                s_mpn.sbs = .s424
                genSUBS_EOS()
                notifyOnSubscriptionsUpdated()
            } else if s_mpn.sbs == .s423 {
                if mpn_snapshotSet.count > 0 {
                    trace(evt, State_mpn_sbs.s423, State_mpn_sbs.s424)
                    s_mpn.sbs = .s424
                    genSUBS_EOS()
                } else {
                    trace(evt, State_mpn_sbs.s423, State_mpn_sbs.s424)
                    s_mpn.sbs = .s424
                    genSUBS_EOS()
                    notifyOnSubscriptionsUpdated()
                }
            }
        }
    }
    
    func evtExtMpnUnsubscribeFilter() {
        synchronized {
            let evt = "mpn.unsubscribe.filter"
            if s_mpn.ft == .s431 {
                trace(evt, State_mpn_ft.s431, State_mpn_ft.s430)
                s_mpn.ft = .s430
                evtMpnCheckFilter()
            }
        }
    }
    
    func evtMpnCheckFilter() {
        synchronized {
            let evt = "mpn.check.filter"
            if s_mpn.ft == .s430 {
                if mpn_filter_pendings.isEmpty {
                    trace(evt, State_mpn_ft.s430, State_mpn_ft.s431)
                    s_mpn.ft = .s431
                } else {
                    trace(evt, State_mpn_ft.s430, State_mpn_ft.s432)
                    s_mpn.ft = .s432
                    genSendMpnUnsubscribeFilter()
                }
            }
        }
    }
    
    func evtExtMpnResetBadge() {
        synchronized {
            let evt = "mpn.reset.badge"
            if s_mpn.bg == .s441 {
                trace(evt, State_mpn_bg.s441, State_mpn_bg.s440)
                s_mpn.bg = .s440
                evtMpnCheckReset()
            }
        }
    }
    
    func evtMpnCheckReset() {
        synchronized {
            let evt = "mpn.check.reset"
            if s_mpn.bg == .s440 {
                if mpn_badge_reset_requested {
                    trace(evt, State_mpn_bg.s440, State_mpn_bg.s442)
                    s_mpn.bg = .s442
                    genSendMpnResetBadge()
                } else {
                    trace(evt, State_mpn_bg.s440, State_mpn_bg.s441)
                    s_mpn.bg = .s441
                }
            }
        }
    }
    
    /* MPN event handlers - END */
    
    private func doRegisterMpnDevice() {
        assert(!mpn_candidate_devices.isEmpty)
        mpn_device = mpn_candidate_devices.removeFirst()
    }
    
    private func doRemoveMpnSpecialListeners() {
        mpn_deviceSubscription.removeDelegate(mpn_deviceListener)
        mpn_deviceListener.disable()
        mpn_deviceListener = nil
        mpn_itemSubscription.removeDelegate(mpn_itemListener)
        mpn_itemListener.disable()
        mpn_itemListener = nil
    }
    
    private func genSendMpnRegister() {
        evtSendControl(mpnRegisterRequest)
    }
    
    private func genUnsubscribeMpnSpecialItems() {
        unsubscribe(mpn_deviceSubscription)
        unsubscribe(mpn_itemSubscription)
    }
    
    private func doResetMpnDevice() {
        mpn_deviceId = nil
        mpn_deviceToken = nil
        mpn_adapterName = nil
        mpn_lastRegisterReqId = nil
        mpn_deviceSubscription = nil
        mpn_itemSubscription = nil
        mpn_deviceListener = nil
        mpn_itemListener = nil
        mpn_snapshotSet.removeAll()
        mpn_filter_pendings.removeAll()
        mpn_filter_lastDeactivateReqId = nil
        mpn_badge_reset_requested = false
        mpn_badge_lastResetReqId = nil
    }
    
    private func notifyDeviceReset() {
        mpn_device.onReset()
    }
    
    private func notifyDeviceError(_ code: Int, _ msg: String) {
        mpn_device.onError(code, msg)
    }
    
    private func doMPNREG() {
        onFreshData()
    }
    
    private func doMPNREG_Register(_ deviceId: String, _ adapterName: String) {
        mpn_deviceId = deviceId
        mpn_deviceToken = mpn_device.deviceToken
        mpn_adapterName = adapterName
        mpn_device.setDeviceId(deviceId, adapterName)
        createSpecialItems(deviceId, adapterName)
    }
    
    private func doMPNZERO(_ deviceId: String) {
        onFreshData()
        if let currDeviceId = mpn_deviceId, deviceId == currDeviceId {
            mpn_device?.fireOnBadgeReset()
        } else {
            // WARN unknown deviceId
        }
    }
    
    class SubscriptionDelegateBase: SubscriptionDelegate {
        weak var client: LightstreamerClient?
        var m_disabled = false
        
        init(_ client: LightstreamerClient) {
            self.client = client
        }
        
        func disable() {
            client?.synchronized {
                m_disabled = true
            }
        }
        
        func synchronized(block: () -> Void) {
            client?.synchronized {
                guard !m_disabled else {
                    return
                }
                block()
            }
        }
        
        func subscription(_ subscription: Subscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
        func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forCommandSecondLevelItemWithKey key: String) {}
        func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String) {}
        func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
        func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {}
        func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {}
        func subscriptionDidRemoveDelegate(_ subscription: Subscription) {}
        func subscriptionDidAddDelegate(_ subscription: Subscription) {}
        func subscriptionDidSubscribe(_ subscription: Subscription) {}
        func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?) {}
        func subscriptionDidUnsubscribe(_ subscription: Subscription) {}
        func subscription(_ subscription: Subscription, didReceiveRealFrequency frequency: RealMaxFrequency?) {}
    }
    
    class MpnDeviceDelegate: SubscriptionDelegateBase {
        
        override func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
            synchronized {
                let status = itemUpdate.value(withFieldName: "status")
                let timestamp = itemUpdate.value(withFieldName: "status_timestamp")
                if let status = status {
                    client?.evtDEV_Update(status, Int64(timestamp ?? "0")!)
                }
            }
        }
        
        override func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?) {
            synchronized {
                client?.evtMpnError(62, "MPN device activation can't be completed (62/1)")
            }
        }
        
        override func subscriptionDidUnsubscribe(_ subscription: Subscription) {
            synchronized {
                client?.evtMpnError(62, "MPN device activation can't be completed (62/2)")
            }
        }
    }
    
    class MpnItemDelegate: SubscriptionDelegateBase {
        
        override func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate) {
            synchronized {
                let key = itemUpdate.value(withFieldName: "key")
                if let key = key {
                    // key has the form "SUB-<id>"
                    let mpnSubId = String(key.dropFirst(4))
                    client?.evtSUBS_Update(mpnSubId, itemUpdate)
                }
            }
        }
        
        override func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {
            synchronized {
                client?.evtSUBS_EOS()
            }
        }
        
        override func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?) {
            synchronized {
                client?.evtMpnError(62, "MPN device activation can't be completed (62/3)")
            }
        }
        
        override func subscriptionDidUnsubscribe(_ subscription: Subscription) {
            synchronized {
                client?.evtMpnError(62, "MPN device activation can't be completed (62/4)")
            }
        }
        
        override func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String) {
            synchronized {
                if mpnDeviceLogger.isWarnEnabled {
                    mpnDeviceLogger.warn("MPN device can't complete the subscription of \(key)")
                }
            }
        }
    }
    
    private func createSpecialItems(_ deviceId: String, _ adapterName: String) {
        mpn_deviceListener = MpnDeviceDelegate(self)
        let deviceSub = Subscription(subscriptionMode: .MERGE)
        deviceSub.items = ["DEV-\(deviceId)"]
        deviceSub.fields = ["status", "status_timestamp"]
        deviceSub.setInternal()
        deviceSub.dataAdapter = adapterName
        deviceSub.requestedMaxFrequency = .unfiltered
        deviceSub.addDelegate(mpn_deviceListener)
        mpn_deviceSubscription = deviceSub
        
        mpn_itemListener = MpnItemDelegate(self)
        let itemSub = Subscription(subscriptionMode: .COMMAND)
        itemSub.items = ["SUBS-\(deviceId)"]
        itemSub.fields = ["key", "command"]
        itemSub.setInternal()
        itemSub.dataAdapter = adapterName
        itemSub.requestedMaxFrequency = .unfiltered
        itemSub.commandSecondLevelFields = [
            "status", "status_timestamp", "notification_format", "trigger", "group",
            "schema", "adapter", "mode", "requested_buffer_size", "requested_max_frequency"
        ]
        itemSub.commandSecondLevelDataAdapter = adapterName
        itemSub.addDelegate(mpn_itemListener)
        mpn_itemSubscription = itemSub
    }
    
    private func genDeviceActive() {
        for sm in mpnSubscriptionManagers {
            sm.evtDeviceActive()
        }
    }
    
    private func genSubscribeSpecialItems() {
        assert(mpn_deviceSubscription != nil)
        assert(mpn_itemSubscription != nil)
        subscribeExt(mpn_deviceSubscription, isInternal: true)
        subscribeExt(mpn_itemSubscription, isInternal: true)
    }
    
    private func doMPNREG_Error() {
        // empty method
    }
    
    private func notifyDeviceError_DifferentDevice() {
        mpn_device.onError(62, "DeviceId or Adapter Name has unexpectedly been changed")
    }
    
    private func doMPNREG_RefreshToken(_ deviceId: String, _ adapterName: String) {
        mpn_deviceToken = mpn_device.deviceToken
        mpn_device.setDeviceId(deviceId, adapterName)
    }
    
    private func notifyDeviceRegistered(_ timestamp: Int64) {
        mpn_device.onRegistered(timestamp)
    }
    
    private func notifyDeviceSuspended(_ timestamp: Int64) {
        mpn_device.onSuspend(timestamp)
    }
    
    private func notifyDeviceResume(_ timestamp: Int64) {
        mpn_device.onResume(timestamp)
    }
    
    private func doClearMpnSnapshot() {
        mpn_snapshotSet.removeAll()
    }
    
    private func exists(mpnSubId: String) -> Bool {
        mpnSubscriptionManagers.contains(where: { $0.mpnSubId == mpnSubId })
    }
    
    private func genSUBS_update(_ mpnSubId: String, _ update: ItemUpdate) {
        for sm in mpnSubscriptionManagers {
            if mpnSubId == sm.mpnSubId {
                sm.evtMpnUpdate(update)
            }
        }
    }
    
    private func doAddToMpnSnapshot(_ mpnSubId: String) {
        mpn_snapshotSet.insert(mpnSubId)
    }
    
    private func doRemoveFromMpnSnapshot(_ mpnSubId: String) {
        mpn_snapshotSet.remove(mpnSubId)
    }
    
    private func doAddMpnSubscription(_ mpnSubId: String) {
        let sm = MpnSubscriptionManager(mpnSubId, self)
        sm.start()
    }
    
    private func notifyOnSubscriptionsUpdated() {
        mpn_device.fireOnSubscriptionsUpdated()
    }
    
    private func genSUBS_EOS() {
        for sm in mpnSubscriptionManagers {
            sm.evtMpnEOS()
        }
    }
    
    private func genSendMpnUnsubscribeFilter() {
        evtSendControl(mpnFilterUnsubscriptionRequest)
    }
    
    private func genSendMpnResetBadge() {
        evtSendControl(mpnBadgeResetRequest)
    }
    
    private func doREQMpnUnsubscribeFilter() {
        mpn_filter_pendings.removeFirst()
    }
    
    private func doREQOKMpnResetBadge() {
        mpn_badge_reset_requested = false
    }
    
    private func doREQERRMpnResetBadge() {
        mpn_badge_reset_requested = false
    }
    
    private func notifyOnBadgeResetFailed(_ code: Int, _ msg: String) {
        mpn_device.fireOnBadgeResetFailed(code, msg)
    }
    
    private func doMPNOK(_ subId: Int, _ mpnSubId: String) {
        onFreshData()
        for sm in mpnSubscriptionManagers {
            if sm.m_subId == subId {
                sm.evtMPNOK(mpnSubId)
            }
        }
    }
    
    private func doMPNDEL(_ mpnSubId: String) {
        onFreshData()
        for sm in mpnSubscriptionManagers {
            if sm.mpnSubId == mpnSubId {
                sm.evtMPNDEL()
            }
        }
    }
    
    private func doMPNCONF(_ mpnSubId: String) {
        onFreshData()
    }
    
    fileprivate func encodeMpnRegister() -> String {
        let req = LsRequestBuilder()
        let deviceToken = mpn_device.deviceToken
        let prevDeviceToken = mpn_device.previousDeviceToken
        mpn_lastRegisterReqId = generateFreshReqId()
        req.LS_reqId(mpn_lastRegisterReqId)
        req.LS_op("register")
        req.PN_type(mpn_device.platform)
        req.PN_appId(mpn_device.applicationId)
        if  prevDeviceToken == nil || prevDeviceToken == deviceToken {
            req.PN_deviceToken(deviceToken)
        } else {
            req.PN_deviceToken(prevDeviceToken!)
            req.PN_newDeviceToken(deviceToken)
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNDevice register: \(req)")
        }
        return req.encodedString
    }
    
    fileprivate func encodeMpnRefreshToken() -> String {
        let req = LsRequestBuilder()
        mpn_lastRegisterReqId = generateFreshReqId()
        req.LS_reqId(mpn_lastRegisterReqId)
        req.LS_op("register")
        req.PN_type(mpn_device.platform)
        req.PN_appId(mpn_device.applicationId)
        req.PN_deviceToken(mpn_deviceToken)
        req.PN_newDeviceToken(mpn_device.deviceToken)
        req.LS_cause("refresh.token")
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNDevice refresh: \(req)")
        }
        return req.encodedString
    }
    
    fileprivate func encodeMpnRestore() -> String {
        let req = LsRequestBuilder()
        mpn_lastRegisterReqId = generateFreshReqId()
        req.LS_reqId(mpn_lastRegisterReqId)
        req.LS_op("register")
        req.PN_type(mpn_device.platform)
        req.PN_appId(mpn_device.applicationId)
        req.PN_deviceToken(mpn_deviceToken)
        req.PN_newDeviceToken(mpn_device.deviceToken)
        req.LS_cause("restore.token")
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNDevice restore: \(req)")
        }
        return req.encodedString
    }
    
    fileprivate func encodeDeactivateFilter() -> String {
        let req = LsRequestBuilder()
        mpn_filter_lastDeactivateReqId = generateFreshReqId()
        req.LS_reqId(mpn_filter_lastDeactivateReqId)
        req.LS_op("deactivate")
        req.PN_deviceId(mpn_deviceId)
        switch mpn_filter_pendings.first {
        case .SUBSCRIBED:
            req.PN_subscriptionStatus("ACTIVE")
        case .TRIGGERED:
            req.PN_subscriptionStatus("TRIGGERED")
        default:
            // if PN_subscriptionStatus is omitted, all subscriptions are deactivated
            break
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending multiple MPNSubscription deactivate: \(req)")
        }
        return req.encodedString
    }
    
    fileprivate func encodeBadgeReset() -> String {
        let req = LsRequestBuilder()
        mpn_badge_lastResetReqId = generateFreshReqId()
        req.LS_reqId(mpn_badge_lastResetReqId)
        req.LS_op("reset_badge")
        req.PN_deviceId(mpn_deviceId)
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending MPNDevice badge reset: \(req)")
        }
        return req.encodedString
    }
    
    private func inRetryUnit() -> Bool {
        [.s110, .s111, .s112, .s113, .s114, .s115, .s116].contains(where:{ $0 == s_m })
    }
    
    private func onFreshData() {
        assert(rec_serverProg == rec_clientProg)
        rec_serverProg += 1
        rec_clientProg += 1
    }
    
    private func onStaleData() {
        assert(rec_serverProg < rec_clientProg)
        rec_serverProg += 1
    }
    
    private func isFreshData() -> Bool {
        rec_serverProg == rec_clientProg
    }
    
    private func inPushing() -> Bool {
        inStreaming() || inPolling()
    }
    
    private func inStreaming() -> Bool {
        s_w?.p == .s300 || s_ws?.p == .s510 || s_hs?.p == .s810
    }
    
    private func inPolling() -> Bool {
        s_tr == .s220 || s_tr == .s230 || s_wp?.p == .s611 || s_hp?.m == .s901 || s_rec == .s1001
    }
    
    private func openWS(_ url: String, _ headers: [String:String]?) -> LsWebsocketClient {
        return wsFactory(lock, url,
                         FULL_TLCP_VERSION,
                         headers ?? [:],
                         { [weak self] wsClient in
                            guard !wsClient.disposed else {
                                return
                            }
                            self?.evtWSOpen()
                         },
                         { [weak self] wsClient, line in
                            guard !wsClient.disposed else {
                                return
                            }
                            do {
                                try self?.evtMessage(line)
                            } catch InternalException.IllegalStateException(let exMsg) {
                                sessionLogger.error(exMsg)
                                self?.evtExtDisconnect(.standardError(61, exMsg))
                            } catch {
                                sessionLogger.error(error.localizedDescription)
                                self?.evtExtDisconnect(.standardError(61, error.localizedDescription))
                            }
                         },
                         { [weak self] wsClient, error in
                            guard !wsClient.disposed else {
                                return
                            }
                            self?.evtTransportError()
                         })
    }
    
    private func openWS_Create() {
        connectTs = scheduler.now
        serverInstanceAddress = getServerAddress()
        let url = toUrl(serverInstanceAddress, path: "lightstreamer")
        ws = openWS(url, m_options.m_HTTPExtraHeaders)
    }
    
    private func openWS_Bind() {
        connectTs = scheduler.now
        let url = toUrl(serverInstanceAddress, path: "lightstreamer")
        let headers = getHeadersForRequestOtherThanCreate()
        ws = openWS(url, headers)
    }

    private func sendCreateWS() {
        let req = LsRequestBuilder()
        if m_options.m_keepaliveInterval > 0 {
            req.LS_keepalive_millis(m_options.m_keepaliveInterval)
        }
        rhb_grantedInterval = m_options.m_reverseHeartbeatInterval
        if m_options.m_reverseHeartbeatInterval > 0 {
            req.LS_inactivity_millis(m_options.m_reverseHeartbeatInterval)
        }
        bw_requestedMaxBandwidth = m_options.m_requestedMaxBandwidth
        switch m_options.m_requestedMaxBandwidth {
        case .limited(let bw):
            req.LS_requested_max_bandwidth(bw)
        default:
            break
        }
        if let adapterSet = m_details.m_adapterSet {
            req.LS_adapter_set(adapterSet)
        }
        if let user = m_details.m_user {
            req.LS_user(user)
        }
        req.LS_cid(LS_CID)
        if let sessionId = self.sessionId {
            req.LS_old_session(sessionId)
        }
        if !m_options.m_slowingEnabled {
            req.LS_send_sync(false)
        }
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session create: \(req)")
        }
        if let password = m_details.m_password {
            req.LS_password(password)
        }
        
        ws.send("wsok")
        ws.send("create_session\r\n\(req.encodedString)")
    }
    
    private func sendBindWS_Streaming() {
        let req = LsRequestBuilder()
        req.LS_session(sessionId)
        if m_options.m_keepaliveInterval > 0 {
            req.LS_keepalive_millis(m_options.m_keepaliveInterval)
        }
        rhb_grantedInterval = m_options.m_reverseHeartbeatInterval
        if m_options.m_reverseHeartbeatInterval > 0 {
            req.LS_inactivity_millis(m_options.m_reverseHeartbeatInterval)
        }
        if !m_options.m_slowingEnabled {
            req.LS_send_sync(false)
        }
        if let cause = cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session bind: \(req)")
        }
        
        ws.send("wsok")
        ws.send("bind_session\r\n\(req.encodedString)")
    }
    
    private func sendBindWS_FirstPolling() {
        let req = LsRequestBuilder()
        req.LS_session(sessionId)
        req.LS_polling(true)
        req.LS_polling_millis(m_options.m_pollingInterval)
        idleTimeout = m_options.m_idleTimeout
        req.LS_idle_millis(m_options.m_idleTimeout)
        if let cause = cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session bind: \(req)")
        }
        
        ws.send("bind_session\r\n\(req.encodedString)")
    }
    
    private func sendBindWS_Polling() {
        let req = LsRequestBuilder()
        req.LS_polling(true)
        req.LS_polling_millis(m_options.m_pollingInterval)
        idleTimeout = m_options.m_idleTimeout
        req.LS_idle_millis(m_options.m_idleTimeout)
        if let cause = cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session bind: \(req)")
        }
        
        ws.send("bind_session\r\n\(req.encodedString)")
    }
    
    private func sendDestroyWS() {
        let req = LsRequestBuilder()
        req.LS_reqId(generateFreshReqId())
        req.LS_op("destroy")
        req.LS_close_socket(true)
        req.LS_cause("api")
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session destroy: \(req)")
        }
        ws.send("control\r\n\(req.encodedString)")
    }
    
    private func sendHttpRequest(_ url: String, _ req: LsRequestBuilder, _ headers: [String:String]?) -> LsHttpClient {
        return httpFactory(lock, url,
                           req.encodedString,
                           headers ?? [:],
                           { [weak self] httpClient, line in
                            guard !httpClient.disposed else {
                                return
                            }
                            do {
                                try self?.evtMessage(line)
                            } catch InternalException.IllegalStateException(let exMsg) {
                                sessionLogger.error(exMsg)
                                self?.evtExtDisconnect(.standardError(61, exMsg))
                            } catch {
                                sessionLogger.error(error.localizedDescription)
                                self?.evtExtDisconnect(.standardError(61, error.localizedDescription))
                            }
                           },
                           { [weak self] httpClient, error in
                            guard !httpClient.disposed else {
                                return
                            }
                            self?.evtTransportError()
                           },
                           { httpClient in
                            // ignore onDone
                           })
    }
    
    private func sendCreateHTTP() {
        let req = LsRequestBuilder()
        req.LS_polling(true)
        req.LS_polling_millis(0)
        req.LS_idle_millis(0)
        bw_requestedMaxBandwidth = m_options.m_requestedMaxBandwidth
        switch m_options.m_requestedMaxBandwidth {
        case .limited(let bw):
            req.LS_requested_max_bandwidth(bw)
        default:
            break
        }
        if let adapterSet = m_details.m_adapterSet {
            req.LS_adapter_set(adapterSet)
        }
        if let user = m_details.m_user {
            req.LS_user(user)
        }
        req.LS_cid(LS_CID)
        if let sessionId = self.sessionId {
            req.LS_old_session(sessionId)
        }
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session create: \(req)")
        }
        if let password = m_details.m_password {
            req.LS_password(password)
        }
        
        connectTs = scheduler.now
        serverInstanceAddress = getServerAddress()
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/create_session.txt", query: [ URLQueryItem(name: "LS_protocol", value: TLCP_VERSION) ])
        http = sendHttpRequest(url, req, m_options.m_HTTPExtraHeaders)
    }
    
    private func sendBindHTTP_Streaming() {
        let req = LsRequestBuilder()
        req.LS_session(sessionId)
        req.LS_content_length(m_options.m_contentLength)
        if m_options.m_keepaliveInterval > 0 {
            req.LS_keepalive_millis(m_options.m_keepaliveInterval)
        }
        rhb_grantedInterval = m_options.m_reverseHeartbeatInterval
        if m_options.m_reverseHeartbeatInterval > 0 {
            req.LS_inactivity_millis(m_options.m_reverseHeartbeatInterval)
        }
        if !m_options.m_slowingEnabled {
            req.LS_send_sync(false)
        }
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session bind: \(req)")
        }
        
        connectTs = scheduler.now
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/bind_session.txt", query: [ URLQueryItem(name: "LS_protocol", value: TLCP_VERSION) ])
        let headers = getHeadersForRequestOtherThanCreate()
        http = sendHttpRequest(url, req, headers)
    }
    
    private func sendBindHTTP_Polling() {
        let req = LsRequestBuilder()
        req.LS_session(sessionId)
        req.LS_polling(true)
        req.LS_polling_millis(m_options.m_pollingInterval)
        idleTimeout = m_options.m_idleTimeout
        req.LS_idle_millis(m_options.m_idleTimeout)
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        // NB parameter LS_inactivity_millis is forbidden in polling
        rhb_grantedInterval = 0
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session bind: \(req)")
        }
        
        connectTs = scheduler.now
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/bind_session.txt", query: [ URLQueryItem(name: "LS_protocol", value: TLCP_VERSION) ])
        let headers = getHeadersForRequestOtherThanCreate()
        http = sendHttpRequest(url, req, headers)
    }
    
    private func sendCreateTTL() {
        let req = LsRequestBuilder()
        req.LS_ttl_millis("unlimited")
        req.LS_polling(true)
        req.LS_polling_millis(0)
        req.LS_idle_millis(0)
        bw_requestedMaxBandwidth = m_options.m_requestedMaxBandwidth
        switch m_options.m_requestedMaxBandwidth {
        case .limited(let bw):
            req.LS_requested_max_bandwidth(bw)
        default:
            break
        }
        if let adapterSet = m_details.m_adapterSet {
            req.LS_adapter_set(adapterSet)
        }
        if let user = m_details.m_user {
            req.LS_user(user)
        }
        req.LS_cid(LS_CID)
        if let sessionId = self.sessionId {
            req.LS_old_session(sessionId)
        }
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session create: \(req)")
        }
        if let password = m_details.m_password {
            req.LS_password(password)
        }
        
        connectTs = scheduler.now
        serverInstanceAddress = getServerAddress()
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/create_session.txt", query: [ URLQueryItem(name: "LS_protocol", value: TLCP_VERSION) ])
        http = sendHttpRequest(url, req, m_options.m_HTTPExtraHeaders)
    }
    
    private func sendRecovery() {
        let req = LsRequestBuilder()
        req.LS_session(sessionId)
        req.LS_recovery_from(rec_clientProg)
        req.LS_polling(true)
        req.LS_polling_millis(0)
        req.LS_idle_millis(0)
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending session recovery: \(req)")
        }
        
        connectTs = scheduler.now
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/bind_session.txt", query: [ URLQueryItem(name: "LS_protocol", value: TLCP_VERSION) ])
        let headers = getHeadersForRequestOtherThanCreate()
        http = sendHttpRequest(url, req, headers)
    }

    private func disposeWS() {
        if ws != nil {
            ws.dispose()
            ws = nil
        }
    }

    private func closeWS() {
        if ws != nil {
            ws.dispose()
            ws = nil
        }
    }
    
    private func suspendWS_Streaming() {
        if sessionLogger.isWarnEnabled {
            sessionLogger.warn("Websocket suspended")
        }
        suspendedTransports.insert(.WS_STREAMING)
    }
    
    private func disableWS() {
        if sessionLogger.isWarnEnabled {
            sessionLogger.warn("Websocket disabled")
        }
        disabledTransports = disabledTransports.union([.WS_STREAMING, .WS_POLLING])
    }
    
    private func disableHTTP_Streaming() {
        if sessionLogger.isWarnEnabled {
            sessionLogger.warn("HTTP streaming disabled")
        }
        disabledTransports = disabledTransports.union([.HTTP_STREAMING])
    }
    
    private func disableStreaming() {
        if sessionLogger.isWarnEnabled {
            sessionLogger.warn("Streaming disabled")
        }
        disabledTransports = disabledTransports.union([.WS_STREAMING, .HTTP_STREAMING])
    }
    
    private func enableAllTransports() {
        if sessionLogger.isInfoEnabled {
            if disabledTransports.count > 0 || suspendedTransports.count > 0 {
                sessionLogger.info("Transports enabled again.")
            }
        }
        disabledTransports = []
        suspendedTransports = []
    }
    
    private func disposeHTTP() {
        if http != nil {
            http.dispose()
            http = nil
        }
    }
    
    private func closeHTTP() {
        if http != nil {
            http.dispose()
            http = nil
        }
    }

    private func disposeCtrl() {
        if ctrl_http != nil {
            ctrl_http.dispose()
            ctrl_http = nil
        }
    }
    
    private func closeCtrl() {
        if ctrl_http != nil {
            ctrl_http.dispose()
            ctrl_http = nil
        }
    }

    private func notifyStatus(_ newStatus: Status) {
        let oldStatus = m_status
        m_status = newStatus
        if oldStatus != newStatus {
            if sessionLogger.isInfoEnabled {
                sessionLogger.info("Status: \(newStatus.rawValue)")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didChangeStatus: newStatus)
                }
            }
        }
    }
    
    enum BestForCreatingEnum {
        case ws, http
    }

    private func getBestForCreating() -> BestForCreatingEnum {
        let ft: TransportSelection! = m_options.m_forcedTransport
        if !suspendedTransports.union(disabledTransports).contains(.WS_STREAMING) && (ft == nil || ft == .WS || ft == .WS_STREAMING) {
            return .ws
        } else {
            return .http
        }
    }
    
    enum BestForBindingEnum {
        case none, ws_streaming, ws_polling, http_streaming, http_polling
    }
    
    private func getBestForBinding() -> BestForBindingEnum {
        let ft: TransportSelection! = m_options.m_forcedTransport
        if !disabledTransports.contains(.WS_STREAMING) && (ft == nil || ft == .WS || ft == .WS_STREAMING) {
            return .ws_streaming
        } else if !disabledTransports.contains(.HTTP_STREAMING) && (ft == nil || ft == .HTTP || ft == .HTTP_STREAMING) {
            return .http_streaming
        } else if !disabledTransports.contains(.WS_POLLING) && (ft == nil || ft == .WS || ft == .WS_POLLING) {
            return .ws_polling
        } else if ft == nil || ft == .HTTP || ft == .HTTP_POLLING {
            return .http_polling
        } else {
            return .none
        }
    }

    private func resetCurrentRetryDelay() {
        delayCounter.reset(m_options.m_retryDelay)
    }
    
    private func notifyServerErrorIfCauseIsError(_ terminationCause: TerminationCause) {
        switch terminationCause {
        case .api:
            // don't notify onServerError
            break
        case .standardError(let code, let msg):
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: code, withMessage: msg)
                }
            }
        case .otherError(let msg):
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: 61, withMessage: msg)
                }
            }
        }
    }

    private func notifyServerError_CONERR(_ code: Int, _ msg: String) {
        multicastDelegate.invokeDelegates { delegate in
            callbackQueue.async {
                delegate.client(self, didReceiveServerError: code, withMessage: msg)
            }
        }
    }

    private func notifyServerError_END(_ code: Int, _ msg: String) {
        if (0 < code && code < 30) || code > 39 {
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: 39, withMessage: msg)
                }
            }
        } else {
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: code, withMessage: msg)
                }
            }
        }
    }

    private func notifyServerError_ERROR(_ code: Int, _ msg: String) {
        multicastDelegate.invokeDelegates { delegate in
            callbackQueue.async {
                delegate.client(self, didReceiveServerError: code, withMessage: msg)
            }
        }
    }

    private func notifyServerError_REQERR(_ code: Int, _ msg: String) {
        if code == 11 {
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: 21, withMessage: msg)
                }
            }
        } else {
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.client(self, didReceiveServerError: code, withMessage: msg)
                }
            }
        }
    }
    
    private func doCONOK(sessionId: String, reqLimit: Int, keepalive: Millis? = nil, idleTimeout: Millis? = nil, clink: String) {
        self.sessionId = sessionId
        m_details.setSessionId(sessionId)
        self.requestLimit = reqLimit
        if let keepalive = keepalive {
            self.keepaliveInterval = keepalive
            m_options.keepaliveInterval = keepalive
        } else if let idleTimeout = idleTimeout {
            self.idleTimeout = idleTimeout
            m_options.idleTimeout = idleTimeout
        }
        if clink != "*" && !m_options.m_serverInstanceAddressIgnored {
            let clink = completeControlLink(clink, baseAddress: getServerAddress())
            self.serverInstanceAddress = clink
            m_details.setServerInstanceAddress(clink)
        }
    }

    private func doCONOK_CreateWS(_ sessionId: String, _ reqLimit: Int, _ keepalive: Millis, _ clink: String) {
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, keepalive: keepalive, clink: clink)
    }
    
    private func doCONOK_BindWS_Streaming(_ sessionId: String, _ reqLimit: Int, _ keepalive: Millis, _ clink: String) {
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, keepalive: keepalive, clink: clink)
    }
    
    private func doCONOK_BindWS_Polling(_ sessionId: String, _ reqLimit: Int, _ idleTimeout: Millis, _ clink: String) {
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, idleTimeout: idleTimeout, clink: clink)
    }
    
    private func doCONOK_CreateHTTP(_ sessionId: String, _ reqLimit: Int, _ keepalive: Millis, _ clink: String) {
        // keepalive or idleTimeout will be set by next bind_session
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, clink: clink)
    }
    
    private func doCONOK_BindHTTP_Streaming(_ sessionId: String, _ reqLimit: Int, _ keepalive: Millis, _ clink: String) {
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, keepalive: keepalive, clink: clink)
    }
    
    private func doCONOK_BindHTTP_Polling(_ sessionId: String, _ reqLimit: Int, _ idleTimeout: Millis, _ clink: String) {
        doCONOK(sessionId: sessionId, reqLimit: reqLimit, idleTimeout: idleTimeout, clink: clink)
    }
    
    private func doSERVNAME(_ serverName: String) {
        m_details.setServerSocketName(serverName)
    }
    
    private func doCLIENTIP(_ clientIp: String) {
        m_details.setClientIp(clientIp)
        if let lastIp = lastKnownClientIp, lastIp != clientIp {
            if sessionLogger.isInfoEnabled {
                sessionLogger.info("Client IP changed: \(lastIp) -> \(clientIp)")
            }
            enableAllTransports()
        }
        lastKnownClientIp = clientIp
    }
    
    private func doCONS(_ bandwidth: RealMaxBandwidth) {
        m_options.setRealMaxBandwidth(bandwidth)
    }
    
    private func doLOOP(_ pollingMs: Millis) {
        m_options.pollingInterval = pollingMs
    }
    
    private func doPROG(_ prog: Int) {
        assert(prog <= rec_clientProg)
        rec_serverProg = prog
    }
    
    private func doMSGDONE(_ sequence: String, _ prog: Int, _ response: String) {
        onFreshData()
        let messages = messageManagers.filter({ $0.sequence == sequence && $0.prog == prog })
        assert(messages.count <= 1)
        for msg in messages {
            msg.evtMSGDONE(response)
        }
    }
    
    private func doMSGFAIL(_ sequence: String, _ prog: Int, _ errorCode: Int, _ errorMsg: String) {
        onFreshData()
        if errorCode == 39 {
            // list of discarded messages. errorMsg is actually a counter
            let count = Int(errorMsg)!
            for p in (prog - count + 1)...prog {
                let messages = messageManagers.filter({ $0.sequence == sequence && $0.prog == p })
                assert(messages.count <= 1)
                for msg in messages {
                    msg.evtMSGFAIL(errorCode, errorMsg)
                }
            }
        } else {
            let messages = messageManagers.filter({ $0.sequence == sequence && $0.prog == prog })
            assert(messages.count <= 1)
            for msg in messages {
                msg.evtMSGFAIL(errorCode, errorMsg)
            }
        }
    }
    
    private func doU(_ subId: Int, _ itemIdx: Pos, _ values: [Pos:FieldValue]) throws {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            try sub.evtU(itemIdx, values)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtU(itemIdx, values)
        }
    }
    
    private func doSUBOK(_ subId: Int, _ nItems: Int, _ nFields: Int) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtSUBOK(nItems: nItems, nFields: nFields)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtSUBOK(nItems: nItems, nFields: nFields)
        }
    }
    
    private func doSUBCMD(_ subId: Int, _ nItems: Int, _ nFields: Int, _ keyIdx: Pos, _ cmdIdx: Pos) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtSUBCMD(nItems: nItems, nFields: nFields, keyIdx: keyIdx, cmdIdx: cmdIdx)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtSUBCMD(nItems: nItems, nFields: nFields, keyIdx: keyIdx, cmdIdx: cmdIdx)
        }
    }
    
    private func doUNSUB(_ subId: Int) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtUNSUB()
        }
    }
    
    private func doEOS(_ subId: Int, _ itemIdx: Pos) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtEOS(itemIdx)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtEOS(itemIdx)
        }
    }
    
    private func doCS(_ subId: Int, _ itemIdx: Pos) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtCS(itemIdx)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtCS(itemIdx)
        }
    }
    
    private func doOV(_ subId: Int, _ itemIdx: Pos, _ lostUpdates: Int) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtOV(itemIdx, lostUpdates)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtOV(itemIdx, lostUpdates)
        }
    }
    
    private func doCONF(_ subId: Int, _ freq: RealMaxFrequency) {
        onFreshData()
        if let sub = subscriptionManagers[subId] {
            sub.evtCONF(freq)
        } else {
            let sub = SubscriptionManagerZombie(subId, self)
            sub.evtCONF(freq)
        }
    }
    
    private func doREQOK(_ reqId: Int) {
        for (_, sub) in subscriptionManagers {
            sub.evtREQOK(reqId)
        }
        for msg in messageManagers {
            msg.evtREQOK(reqId)
        }
        for sub in mpnSubscriptionManagers {
            sub.evtREQOK(reqId)
        }
    }
    
    private func doREQERR(_ reqId: Int, _ errorCode: Int, _ errorMsg: String) {
        for (_, sub) in subscriptionManagers {
            sub.evtREQERR(reqId, errorCode, errorMsg)
        }
        for msg in messageManagers {
            msg.evtREQERR(reqId, errorCode, errorMsg)
        }
        for sub in mpnSubscriptionManagers {
            sub.evtREQERR(reqId, errorCode, errorMsg)
        }
    }
    
    private func doSYNC(_ syncMs: Timestamp) {
        slw_refTime = scheduler.now
        slw_avgDelayMs = -Int64(syncMs)
    }
    
    private func doSYNC_G(_ syncMs: Timestamp) -> SyncCheckResult {
        let diffTime = diffTimeSync(syncMs)
        if diffTime > slw_hugeDelayMs && diffTime > 2 * slw_avgDelayMs {
            if slw_avgDelayMs > slw_maxAvgDelayMs && m_options.m_slowingEnabled {
                return .bad
            } else {
                return .not_good
            }
        } else {
            slw_avgDelayMs = slowAvg(diffTime)
            if slw_avgDelayMs > slw_maxAvgDelayMs && m_options.m_slowingEnabled {
                return .bad
            } else {
                if slw_avgDelayMs < 60 {
                    slw_avgDelayMs = 0
                }
                return .good
            }
        }
    }
    
    private func doSYNC_NG(_ syncMs: Timestamp) -> SyncCheckResult {
        let diffTime = diffTimeSync(syncMs)
        if diffTime > slw_hugeDelayMs && diffTime > 2 * slw_avgDelayMs {
            slw_avgDelayMs = slowAvg(diffTime)
            if slw_avgDelayMs > slw_maxAvgDelayMs && m_options.m_slowingEnabled {
                return .bad
            } else {
                if slw_avgDelayMs < 60 {
                    slw_avgDelayMs = 0
                }
                return .good
            }
        } else {
            slw_avgDelayMs = slowAvg(diffTime)
            if slw_avgDelayMs > slw_maxAvgDelayMs && m_options.m_slowingEnabled {
                return .bad
            } else {
                if slw_avgDelayMs < 60 {
                    slw_avgDelayMs = 0
                }
                return .not_good
            }
        }
    }
    
    private func diffTimeSync(_ syncMs: Timestamp) -> Int64 {
        let diffMs = Int64(scheduler.now - slw_refTime)
        let diffTime = diffMs - Int64(syncMs)
        return diffTime
    }
    
    private func slowAvg(_ diffTime: Int64) -> Int64 {
        return Int64(Double(slw_avgDelayMs) * slw_m + Double(diffTime) * (1.0 - slw_m))
    }
    
    private func schedule_evtTransportTimeout(_ timeout: Millis) {
        transportTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtTransportTimeout()
        }
        scheduler.schedule("transport.timeout", timeout, transportTimer)
    }
    
    private func schedule_evtRetryTimeout(_ timeout: Millis) {
        retryTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtRetryTimeout()
        }
        scheduler.schedule("retry.timeout", timeout, retryTimer)
    }
    
    private func schedule_evtRecoveryTimeout(_ timeout: Millis) {
        recoveryTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtRecoveryTimeout()
        }
        scheduler.schedule("recovery.timeout", timeout, recoveryTimer)
    }
    
    private func schedule_evtIdleTimeout(_ timeout: Millis) {
        idleTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtIdleTimeout()
        }
        scheduler.schedule("idle.timeout", timeout, idleTimer)
    }
    
    private func schedule_evtPollingTimeout(_ timeout: Millis) {
        pollingTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtPollingTimeout()
        }
        scheduler.schedule("polling.timeout", timeout, pollingTimer)
    }
    
    private func schedule_evtCtrlTimeout(_ timeout: Millis) {
        ctrlTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtCtrlTimeout()
        }
        scheduler.schedule("ctrl.timeout", timeout, ctrlTimer)
    }
    
    private func schedule_evtKeepaliveTimeout(_ timeout: Millis) {
        keepaliveTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtKeepaliveTimeout()
        }
        scheduler.schedule("keepalive.timeout", timeout, keepaliveTimer)
    }
    
    private func schedule_evtStalledTimeout(_ timeout: Millis) {
        stalledTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtStalledTimeout()
        }
        scheduler.schedule("stalled.timeout", timeout, stalledTimer)
    }
    
    private func schedule_evtReconnectTimeout(_ timeout: Millis) {
        reconnectTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtReconnectTimeout()
        }
        scheduler.schedule("reconnect.timeout", timeout, reconnectTimer)
    }
    
    private func schedule_evtRhbTimeout(_ timeout: Millis) {
        rhbTimer = Scheduler.Task(self.lock) { [weak self] in
            self?.evtRhbTimeout()
        }
        scheduler.schedule("rhb.timeout", timeout, rhbTimer)
    }
    
    private func cancel_evtTransportTimeout() {
        if let task = transportTimer {
            scheduler.cancel("transport.timeout", task)
            transportTimer = nil
        }
    }
    
    private func cancel_evtRetryTimeout() {
        if let task = retryTimer {
            scheduler.cancel("retry.timeout", task)
            retryTimer = nil
        }
    }
    
    private func cancel_evtKeepaliveTimeout() {
        if let task = keepaliveTimer {
            scheduler.cancel("keepalive.timeout", task)
            keepaliveTimer = nil
        }
    }
    
    private func cancel_evtStalledTimeout() {
        if let task = stalledTimer {
            scheduler.cancel("stalled.timeout", task)
            stalledTimer = nil
        }
    }
    
    private func cancel_evtReconnectTimeout() {
        if let task = reconnectTimer {
            scheduler.cancel("reconnect.timeout", task)
            reconnectTimer = nil
        }
    }
    
    private func cancel_evtRhbTimeout() {
        if let task = rhbTimer {
            scheduler.cancel("rhb.timeout", task)
            rhbTimer = nil
        }
    }
    
    private func cancel_evtIdleTimeout() {
        if let task = idleTimer {
            scheduler.cancel("idle.timeout", task)
            idleTimer = nil
        }
    }
    
    private func cancel_evtPollingTimeout() {
        if let task = pollingTimer {
            scheduler.cancel("polling.timeout", task)
            pollingTimer = nil
        }
    }
    
    private func cancel_evtCtrlTimeout() {
        if let task = ctrlTimer {
            scheduler.cancel("ctrl.timeout", task)
            ctrlTimer = nil
        }
    }
    
    private func cancel_evtRecoveryTimeout() {
        if let task = recoveryTimer {
            scheduler.cancel("recovery.timeout", task)
            recoveryTimer = nil
        }
    }
    
    private func waitingInterval(expectedMs: Millis, from startTime: Timestamp) -> Millis {
        let diffMs = scheduler.now - startTime
        let expected = UInt64(expectedMs)
        return diffMs < expected ? Millis(expected - diffMs) : 0
    }
    
    private func exit_tr() {
        evtEndSession()
    }
    
    private func entry_m111(_ retryCause: RetryCause, _ timeout: Millis) {
        evtRetry(retryCause, timeout)
        schedule_evtRetryTimeout(timeout)
    }
    
    private func entry_m112(_ retryCause: RetryCause) {
        let pauseMs = waitingInterval(expectedMs: delayCounter.currentRetryDelay, from: connectTs)
        evtRetry(retryCause, pauseMs)
        schedule_evtRetryTimeout(pauseMs)
    }
    
    private func entry_m113(_ retryCause: RetryCause) {
        let pauseMs = randomGenerator(m_options.m_firstRetryMaxDelay)
        evtRetry(retryCause, pauseMs)
        schedule_evtRetryTimeout(pauseMs)
    }
    
    private func entry_m115(_ retryCause: RetryCause) {
        evtRetry(retryCause)
        evtRetryTimeout()
    }
    
    private func exit_w() {
        cancel_evtKeepaliveTimeout()
        cancel_evtStalledTimeout()
        cancel_evtReconnectTimeout()
        cancel_evtRhbTimeout()
    }
    
    private func exit_ws() {
        cancel_evtTransportTimeout()
        cancel_evtKeepaliveTimeout()
        cancel_evtStalledTimeout()
        cancel_evtReconnectTimeout()
        cancel_evtRhbTimeout()
    }
    
    private func exit_wp() {
        cancel_evtTransportTimeout()
        cancel_evtIdleTimeout()
        cancel_evtPollingTimeout()
    }
    
    private func exit_hs() {
        cancel_evtTransportTimeout()
        cancel_evtKeepaliveTimeout()
        cancel_evtStalledTimeout()
        cancel_evtReconnectTimeout()
        cancel_evtRhbTimeout()
    }
    
    private func exit_hp() {
        cancel_evtIdleTimeout()
        cancel_evtPollingTimeout()
        cancel_evtRhbTimeout()
    }
    
    private func exit_ctrl() {
        cancel_evtCtrlTimeout()
        evtDisposeCtrl()
    }
    
    private func exit_rec() {
        cancel_evtRecoveryTimeout()
        cancel_evtTransportTimeout()
        cancel_evtRetryTimeout()
    }
    
    private func exit_keepalive_unit() {
        cancel_evtKeepaliveTimeout()
        cancel_evtStalledTimeout()
        cancel_evtReconnectTimeout()
    }
    
    private func exit_w_to_m() {
        exit_w()
        exit_tr()
    }
    
    private func exit_ws_to_m() {
        exit_ws()
        exit_tr()
    }
    
    private func exit_wp_to_m() {
        exit_wp()
        exit_tr()
    }
    
    private func exit_hs_to_m() {
        exit_ctrl()
        exit_hs()
        exit_tr()
    }
    
    private func exit_hs_to_rec() {
        exit_ctrl()
        exit_hs()
    }
    
    private func exit_hp_to_m() {
        exit_ctrl()
        exit_hp()
        exit_tr()
    }
    
    private func exit_hp_to_rec() {
        exit_ctrl()
        exit_hp()
    }
    
    private func exit_ctrl_to_m() {
        exit_ctrl()
        exit_hs()
        exit_hp()
        exit_tr()
    }
    
    private func exit_rec_to_m() {
        exit_rec()
        exit_tr()
    }
    
    private func entry_rec(pause: Millis, _ retryCause: RetryCause) {
        if sessionLogger.isErrorEnabled {
            sessionLogger.error("Recovering connection in \(pause)ms. Cause: \(retryCause.errorMsg)")
        }
        evtStartRecovery()
        schedule_evtRecoveryTimeout(pause)
    }
    
    private func goto_m_from_w(_ m: State_m) {
        clear_w()
        goto_m_from_session(m)
    }
    
    private func goto_m_from_ws(_ m: State_m) {
        clear_ws()
        goto_m_from_session(m)
    }
    
    private func goto_rec_from_w() {
        clear_w()
        goto_rec()
    }
    
    private func goto_rec_from_ws() {
        clear_ws()
        goto_rec()
    }
    
    private func goto_m_from_wp(_ m: State_m) {
        clear_wp()
        goto_m_from_session(m)
    }
    
    private func goto_rec_from_wp() {
        clear_wp()
        goto_rec()
    }
    
    private func goto_m_from_hs(_ m: State_m) {
        clear_hs()
        s_ctrl = nil
        s_h = nil
        goto_m_from_session(m)
    }
    
    private func goto_m_from_rec(_ m: State_m) {
        s_tr = nil
        goto_m_from_session(m)
    }
    
    private func goto_rec_from_hs() {
        clear_hs()
        s_ctrl = nil
        s_h = nil
        goto_rec()
    }
    
    private func goto_m_from_hp(_ m: State_m) {
        clear_hp()
        s_ctrl = nil
        s_h = nil
        goto_m_from_session(m)
    }
    
    private func goto_rec_from_hp() {
        clear_hp()
        s_ctrl = nil
        s_h = nil
        goto_rec()
    }
    
    private func goto_rec() {
        s_tr = .s260
        s_rec = .s1000
    }
    
    private func goto_m_from_session(_ m: State_m) {
        s_tr = nil
        s_swt = nil
        s_bw = nil
        s_m = m
    }
    
    private func goto_m_from_ctrl(_ m: State_m) {
        clear_hs()
        clear_hp()
        s_ctrl = nil
        s_h = nil
        goto_m_from_session(m)
    }
    
    func generateFreshReqId() -> Int {
        synchronized {
            m_nextReqId += 1
            return m_nextReqId
        }
    }
    
    func generateFreshSubId() -> Int {
        synchronized {
            m_nextSubId += 1
            return m_nextSubId
        }
    }

    private func genAbortSubscriptions() {
        for (_, sub) in subscriptionManagers {
            sub.evtExtAbort()
        }
        for sub in mpnSubscriptionManagers {
            sub.evtAbort()
        }
    }
    
    private func genAckMessagesWS() {
        let messages = messageManagers.filter({ $0.isPending() })
        for msg in messages {
            msg.evtWSSent()
        }
    }

    private func genAbortMessages() {
        for msg in messageManagers {
            msg.evtAbort()
        }
    }

    private func resetSequenceMap() {
        sequenceMap.removeAll()
    }
    
    private func isSwitching() -> Bool {
        return s_m == .s150 && (s_swt == .s1302 || s_swt == .s1303)
    }
    
    fileprivate func encodeSwitch(isWS: Bool) -> String {
        let req = LsRequestBuilder()
        swt_lastReqId = generateFreshReqId()
        req.LS_reqId(swt_lastReqId)
        req.LS_op("force_rebind")
        if isWS {
            req.LS_close_socket(true)
        }
        if let cause = self.cause {
            req.LS_cause(cause)
            self.cause = nil
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending transport switch: \(req)")
        }
        return req.encodedString
    }
    
    fileprivate func encodeConstrain() -> String {
        let req = LsRequestBuilder()
        bw_lastReqId = generateFreshReqId()
        req.LS_reqId(bw_lastReqId!)
        req.LS_op("constrain")
        switch bw_requestedMaxBandwidth! {
        case .limited(let bw):
            req.LS_requested_max_bandwidth(bw)
        case .unlimited:
            req.LS_requested_max_bandwidth("unlimited")
        }
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Sending bandwidth constrain: \(req)")
        }
        return req.encodedString
    }
    
    private func getPendingControls() -> [Encodable] {
        var res = [Encodable]()
        if switchRequest.isPending() {
            res.append(switchRequest)
        }
        if constrainRequest.isPending() {
            res.append(constrainRequest)
        }
        for sub in subscriptionManagers.orderedValues.filter({ $0.isPending() }) {
            res.append(sub)
        }
        if mpnRegisterRequest.isPending() {
            res.append(mpnRegisterRequest)
        }
        for sub in mpnSubscriptionManagers.filter({ $0.isPending() }) {
            res.append(sub)
        }
        if mpnFilterUnsubscriptionRequest.isPending() {
            res.append(mpnFilterUnsubscriptionRequest)
        }
        if mpnBadgeResetRequest.isPending() {
            res.append(mpnBadgeResetRequest)
        }
        return res
    }
    
    private func sendControlWS(_ request: Encodable) {
        ws.send(request.encodeWS())
    }
    
    private func sendMsgWS(_ msg: MessageManager) {
        ws.send(msg.encodeWS())
    }
    
    private func sendPengingControlsWS(_ pendings: [Encodable]) {
        let batches = prepareBatchWS("control", pendings, requestLimit)
        sendBatchWS(batches)
    }
    
    private func sendPendingMessagesWS() {
        let messages = messageManagers.filter({ $0.isPending() })
        // ASSERT (for each i, j in DOMAIN messages :
        // i < j AND messages[i].sequence = messages[j].sequence => messages[i].prog < messages[j].prog)
        let batches = prepareBatchWS("msg", messages, requestLimit)
        sendBatchWS(batches)
    }
    
    private func sendBatchWS(_ batches: [String]) {
        for batch in batches {
            ws.send(batch)
        }
    }
    
    private func sendHeartbeatWS() {
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Heartbeat request")
        }
        ws.send("heartbeat\r\n\r\n") // since the request has no parameter, it must include EOL
    }
    
    private func sendPendingControlsHTTP(_ pendings: [Encodable]) {
        let body = prepareBatchHTTP(pendings, requestLimit)
        sendBatchHTTP(body, "control")
    }
    
    private func sendPendingMessagesHTTP() {
        let messages = messageManagers.filter({ $0.isPending() })
        // ASSERT (for each i, j in DOMAIN messages :
        // i < j AND messages[i].sequence = messages[j].sequence => messages[i].prog < messages[j].prog)
        let body = prepareBatchHTTP(messages, requestLimit)
        sendBatchHTTP(body, "msg")
    }
    
    private func sendHeartbeatHTTP() {
        if protocolLogger.isInfoEnabled {
            protocolLogger.info("Heartbeat request")
        }
        sendBatchHTTP("\r\n", "heartbeat") // since the request has no parameter, it must include EOL
    }
    
    private func sendBatchHTTP(_ body: String, _ reqType: String) {
        ctrl_connectTs = scheduler.now
        let url = toUrl(serverInstanceAddress, path: "/lightstreamer/\(reqType).txt", query: [
            URLQueryItem(name: "LS_protocol", value: TLCP_VERSION),
            URLQueryItem(name: "LS_session", value: sessionId)
        ])
        let headers = getHeadersForRequestOtherThanCreate()
        ctrl_http = ctrlFactory(lock, url,
                           body,
                           headers ?? [:],
                           { [weak self] httpClient, line in
                            guard !httpClient.disposed else {
                                return
                            }
                            self?.evtCtrlMessage(line)
                           },
                           { [weak self] httpClient, error in
                            guard !httpClient.disposed else {
                                return
                            }
                            self?.evtCtrlError()
                           },
                           { [weak self] httpClient in
                            guard !httpClient.disposed else {
                                return
                            }
                            self?.evtCtrlDone()
                           })
    }
    
    private func clear_w() {
        s_w = nil
        s_rhb = nil
        s_slw = nil
    }
    
    private func clear_ws() {
        s_ws = nil
        s_rhb = nil
        s_slw = nil
    }
    
    private func clear_wp() {
        s_wp = nil
    }
    
    private func clear_hs() {
        s_hs = nil
        s_rhb = nil
        s_slw = nil
    }
    
    private func clear_hp() {
        s_hp = nil
        s_rhb = nil
    }
    
    private func toUrl(_ host: String, path: String, query: [URLQueryItem]? = nil) -> String {
        let url = URL(string: host)!.appendingPathComponent(path)
        if let items = query {
            var comps = URLComponents(string: url.absoluteString)!
            comps.queryItems = items
            return comps.string!
        } else {
            return url.absoluteString
        }
    }
    
    private func trace(_ evt: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("\(evt) \(from.id)->\(to.id)")
        }
    }

    private func trace(_ evt: String, cond: String, _ from: State, _ to: State) {
        if internalLogger.isTraceEnabled {
            internalLogger.trace("\(evt) [\(cond)] \(from.id)->\(to.id)")
        }
    }

    private func trace(_ evt: String, cond: String? = nil) {
        if internalLogger.isTraceEnabled {
            if let cond = cond {
                internalLogger.trace("\(evt) [\(cond)]")
            } else {
                internalLogger.trace(evt)
            }
        }
    }
    
    private func getHeadersForRequestOtherThanCreate() -> [String:String]? {
        m_options.m_HTTPExtraHeadersOnSessionCreationOnly ? nil : m_options.m_HTTPExtraHeaders
    }
    
    private func getServerAddress() -> String {
        m_details.m_serverAddress ?? defaultServerAddress
    }
    
    func relate(to subManager: SubscriptionManager) {
        assert(subscriptionManagers[subManager.subId] == nil)
        subscriptionManagers[subManager.subId] = subManager
    }
    
    func unrelate(from subManager: SubscriptionManager) {
        subscriptionManagers.removeValue(forKey: subManager.subId)
    }
    
    func relate(to msgManager: MessageManager) {
        messageManagers.append(msgManager)
    }
    
    func unrelate(from msgManager: MessageManager) {
        guard let i = messageManagers.firstIndex(where: { $0 === msgManager }) else {
            return
        }
        messageManagers.remove(at: i)
    }
    
    func relate(to subManager: MpnSubscriptionManager) {
        assert(!mpnSubscriptionManagers.contains(where: { $0 === subManager }))
        mpnSubscriptionManagers.append(subManager)
    }
    
    func unrelate(from subManager: MpnSubscriptionManager) {
        guard let i = mpnSubscriptionManagers.firstIndex(where: { $0 === subManager }) else {
            return
        }
        mpnSubscriptionManagers.remove(at: i)
    }
    
    func getAndSetNextMsgProg(_ sequence: String) -> Int {
        let prog = sequenceMap[sequence] ?? 1
        sequenceMap[sequence] = prog + 1
        return prog
    }
}

func prepareBatchWS(_ reqType: String, _ pendings: [Encodable], _ requestLimit: Int) -> [String] {
    assert(pendings.count > 0)
    // NB $requestLimit must always be respected unless
    // one single request surpasses the limit: in that case the requests is sent on its own even if
    // we already know that the server will refuse it
    var out = [String]()
    var i = pendings.startIndex
    var subReq = pendings[i].encode(isWS: true)
    while i < pendings.endIndex {
        // prepare next batch
        let mainReq = LsRequest()
        mainReq.addSubRequest(reqType)
        mainReq.addSubRequest(subReq)
        i += 1
        while i < pendings.endIndex {
            subReq = pendings[i].encode(isWS: true)
            if mainReq.addSubRequestOnlyIfBodyIsLessThan(subReq, requestLimit: requestLimit) {
                i += 1
            } else {
                // batch is full: keep subReq for the next batch
                break
            }
        }
        out.append(mainReq.body)
    }
    return out
}

func prepareBatchHTTP(_ pendings: [Encodable], _ requestLimit: Int) -> String {
    assert(pendings.count > 0)
    // NB $requestLimit must always be respected unless
    // one single request surpasses the limit: in that case the requests is sent on its own even if
    // we already know that the server will refuse it
    let mainReq = LsRequest()
    var i = pendings.startIndex
    var subReq = pendings[i].encode(isWS: false)
    mainReq.addSubRequest(subReq)
    i += 1
    while i < pendings.endIndex {
        subReq = pendings[i].encode(isWS: false)
        if mainReq.addSubRequestOnlyIfBodyIsLessThan(subReq, requestLimit: requestLimit) {
            i += 1
        } else {
            break
        }
    }
    return mainReq.body
}
