import Foundation
import OrderedCollections

/**
 Milliseconds.
 */
public typealias Millis = Int

/**
 - SeeAlso: `ConnectionOptions.forcedTransport`
 */
public enum TransportSelection: String, CustomStringConvertible {
    /// Websocket streaming or polling
    case WS = "WS"
    /// Websocket streaming
    case WS_STREAMING = "WS-STREAMING"
    /// Websocket polling
    case WS_POLLING = "WS-POLLING"
    /// HTTP streaming or polling
    case HTTP = "HTTP"
    /// HTTP streaming
    case HTTP_STREAMING = "HTTP-STREAMING"
    /// HTTP polling
    case HTTP_POLLING = "HTTP-POLLING"
    
    public var description: String {
        self.rawValue
    }
}

/**
 - SeeAlso: `ConnectionOptions.requestedMaxBandwidth`
 */
public enum RequestedMaxBandwidth: Equatable, CustomStringConvertible {
    /// Maximum bandwidth, expressed in kilobit/sec
    case limited(Double)
    /// Unlimited bandwidth
    case unlimited
    
    public var description: String {
        switch self {
        case .unlimited:
            return "unlimited"
        case .limited(let bw):
            return "\(bw) kilobits/sec"
        }
    }
}

/**
 - SeeAlso: `ConnectionOptions.realMaxBandwidth`
 */
public enum RealMaxBandwidth: Equatable, CustomStringConvertible {
    /// Maximum bandwidth, expressed in kilobit/sec
    case limited(Double)
    /// Unlimited bandwidth
    case unlimited
    /// Unmanaged bandwidth
    case unmanaged
    
    public var description: String {
        switch self {
        case .unlimited:
            return "unlimited"
        case .unmanaged:
            return "unmanaged"
        case .limited(let bw):
            return "\(bw) kilobits/sec"
        }
    }
}

/**
 Used by `LightstreamerClient` to provide an extra connection properties object.
 
 This object contains the policy settings used to connect to a Lightstreamer Server.
 
 An instance of this class is attached to every `LightstreamerClient` as `LightstreamerClient.connectionOptions`.
 
 - SeeAlso: `LightstreamerClient`
 */
public class ConnectionOptions: CustomStringConvertible {
    
    unowned let client: LightstreamerClient
    // all properties are guarded by client.lock
    var m_slowingEnabled: Bool = false
    var m_serverInstanceAddressIgnored: Bool = false
    var m_HTTPExtraHeadersOnSessionCreationOnly: Bool = false
    var m_stalledTimeout: Millis = 2_000
    var m_sessionRecoveryTimeout: Millis = 15_000
    var m_reverseHeartbeatInterval: Millis = 0
    var m_retryDelay: Millis = 4_000
    var m_reconnectTimeout: Millis = 3_000
    var m_pollingInterval: Millis = 0
    var m_keepaliveInterval: Millis = 0
    var m_idleTimeout: Millis = 19_000
    var m_firstRetryMaxDelay: Millis = 100
    var m_contentLength: UInt64 = 50_000_000
    var m_forcedTransport: TransportSelection? = nil
    var m_requestedMaxBandwidth: RequestedMaxBandwidth = .unlimited
    var m_realMaxBandwidth: RealMaxBandwidth? = nil
    var m_HTTPExtraHeaders: [String:String]? = nil
    
    init(_ client: LightstreamerClient) {
        self.client = client
    }
    
    /**
     Length, expressed in bytes, to be used by the Server for the response body on a HTTP stream connection (a minimum length, however, is ensured by the server).
     
     After the content length exhaustion, the connection will be closed and a new bind connection will be automatically reopened.
     
     Note: this setting only applies to the `HTTP-STREAMING` case (i.e. not to WebSockets).
     
     **Default:** A length decided by the library, to ensure the best performance. It can be of a few MB or much higher, depending on the environment.
     
     **Lifecycle:** the content length should be set on the `LightstreamerClient.connectionOptions` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next HTTP bind request.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `contentLength` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     */
    public var contentLength: UInt64 {
        get {
            client.synchronized {
                m_contentLength
            }
        }
        set {
            precondition(newValue > 0, "contentLength must be greater than zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("contentLength changed: \(newValue)")
                }
                m_contentLength = newValue
                client.fireDidChangeProperty("contentLength")
            }
        }
    }
    
    /**
     Maximum time the to wait before trying a new connection to the Server in case the previous one is unexpectedly closed while correctly working.
     
     The new connection may be either the opening of a new session or an attempt to recovery the current session, depending on the kind of interruption.
     
     The actual delay is a randomized value between 0 and this value. This randomization might help avoid a load spike on the cluster due to simultaneous reconnections, should one of the active servers be stopped. Note that this delay is only applied before the first reconnection: should such reconnection fail, only the setting of `retryDelay` will be applied.
     
     **Default:** 100 milliseconds
     
     **Lifecycle:** this property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `firstRetryMaxDelay` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     */
    public var firstRetryMaxDelay: Millis {
        get {
            client.synchronized {
                m_firstRetryMaxDelay
            }
        }
        set {
            precondition(newValue > 0, "firstRetryMaxDelay must be greater than zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("firstRetryMaxDelay changed: \(newValue)")
                }
                m_firstRetryMaxDelay = newValue
                client.fireDidChangeProperty("firstRetryMaxDelay")
            }
        }
    }
    
    /**
     Value of the forced transport (if any), that can be used to disable/enable the Stream-Sense algorithm and to force the client to use a fixed transport
     or a fixed combination of a transport and a connection type.
     
     When a combination is specified the Stream-Sense algorithm is completely disabled.
     
     The property can be used to switch between streaming and polling connection types and between HTTP and WebSocket transports.
     
     In some cases, the requested status may not be reached, because of connection or environment problems. In that case the client will continuously attempt
     to reach the configured status(es).
     
     Note that if the Stream-Sense algorithm is disabled, the client may still enter the `CONNECTED:STREAM-SENSING` status; however, in that case, if it
     eventually finds out that streaming is not possible, no recovery will be tried.
     
     **Platform limitations:** On watchOS the WebSocket transport is not available.

     **Default:** nil (full Stream-Sense enabled).
     
     **Lifecycle:** this property can be changed at any time. If called while the client is connecting or connected it will instruct to switch connection type to match the given configuration.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `forcedTransport` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var forcedTransport: TransportSelection? {
        get {
            client.synchronized {
                m_forcedTransport
            }
        }
        set {
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("forcedTransport changed: \(newValue?.rawValue ?? "nil")")
                }
                m_forcedTransport = newValue
                client.fireDidChangeProperty("forcedTransport")
                client.evtExtSetForcedTransport()
            }
        }
    }
    
    /**
     Enables/disables the setting of extra HTTP headers to all the request performed to the Lightstreamer server by the client.
     
     Note that the Content-Type header is reserved by the client library itself, while other headers might be refused by the environment and others might
     cause the connection to the server to fail. For instance, you cannot use this property to specify custom cookies to be sent to
     Lightstreamer Server; leverage `LightstreamerClient.addCookies(_:forURL:)` instead. The use of custom headers might also cause the client to send an OPTIONS request to the server before opening the actual connection.
     
     **Default:** nil (meaning no extra headers are sent).
     
     **Lifecycle:** this property can be changed at any time: each request will carry headers accordingly to the most recent setting. Note that if extra headers are specified while a WebSocket is open, the requests will continue to be sent through the WebSocket and thus this setting will be ignored until a new session starts.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `HTTPExtraHeaders` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - SeeAlso: `HTTPExtraHeadersOnSessionCreationOnly`
     */
    public var HTTPExtraHeaders: [String:String]? {
        get {
            client.synchronized {
                m_HTTPExtraHeaders
            }
        }
        set {
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("httpExtraHeaders changed: \(newValue ?? [:])")
                }
                m_HTTPExtraHeaders = newValue
                client.fireDidChangeProperty("httpExtraHeaders")
            }
        }
    }
    
    /**
     Maximum time the Server is allowed to wait for any data to be sent in response to a polling request, if none has accumulated at request time.
     
     Setting this time to a nonzero value and the polling interval to zero leads to an "asynchronous polling" behaviour, which, on low data rates, is very
     similar to the streaming case. Setting this time to zero and the polling interval to a nonzero value, on the other hand, leads to a classical
     "synchronous polling".
     
     Note that the Server may, in some cases, delay the answer for more than the supplied time, to protect itself against a high polling rate or because
     of bandwidth restrictions. Also, the Server may impose an upper limit on the wait time, in order to be able to check for client-side connection drops.
     
     **Default:** 19 seconds.
     
     **Lifecycle:** the idle timeout should be set on the `LightstreamerClient.connectionOptions` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next polling request (this only applies to the `*-POLLING` cases).
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `idleTimeout` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than or equal to zero
     */
    public var idleTimeout: Millis {
        get {
            client.synchronized {
                m_idleTimeout
            }
        }
        set {
            precondition(newValue >= 0, "idleTimeout must be greater than or equal to zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    if newValue != m_idleTimeout {
                        actionLogger.info("idleTimeout changed: \(newValue)")
                    }
                }
                m_idleTimeout = newValue
                client.fireDidChangeProperty("idleTimeout")
            }
        }
    }
    
    /**
     Interval between two keepalive packets sent by Lightstreamer Server on a stream connection when no actual data is being transmitted.
     
     The Server may, however, impose a lower limit on the keepalive interval, in order to protect itself. Also, the Server may impose an upper limit on the
     keepalive interval, in order to be able to check for client-side connection drops. If 0 is specified, the interval will be decided by the Server.
     
     **Default:** 0 (meaning that the Server will send keepalive packets based on its own configuration).
     
     **Lifecycle:** the keepalive interval should be set on the `LightstreamerClient.connectionOptions` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next bind request (this only applies to the `*-STREAMING` cases).
     
     Note that, if the value has just been set and a connection to Lightstreamer Server has not been established yet, the returned value is the time that is being requested to the Server. Afterwards, the returned value is the time used by the Server, that may be different, because of Server side constraints.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `keepaliveInterval` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than or equal to zero
     
     - SeeAlso: `stalledTimeout`
     
     - SeeAlso: `reconnectTimeout`
     */
    public var keepaliveInterval: Millis {
        get {
            client.synchronized {
                m_keepaliveInterval
            }
        }
        set {
            precondition(newValue >= 0, "keepaliveInterval must be greater than or equal to zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    if newValue != m_keepaliveInterval {
                        actionLogger.info("keepaliveInterval changed: \(newValue)")
                    }
                }
                m_keepaliveInterval = newValue
                client.fireDidChangeProperty("keepaliveInterval")
            }
        }
    }
    
    /**
     Maximum bandwidth, expressed in kilobit/sec, that can be consumed for the data coming from Lightstreamer Server, as requested for this session.
     
     The maximum bandwidth limit really applied by the Server on the session is provided by `realMaxBandwidth`.
     
     A limit on bandwidth may already be posed by the Metadata Adapter, but the client can furtherly restrict this limit. The limit applies to the bytes
     received in each streaming or polling connection. The value `unlimited` is also allowed, to mean that the maximum bandwidth can be
     entirely decided on the Server side.
     
     **Edition note:** bandwidth control is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Format:** a decimal number (e.g. `5.0`), or `unlimited`.
     
     **Default:** `unlimited`.
     
     **Lifecycle:** this property can changed at any time. If a connection is currently active, the bandwidth limit for the connection is changed on the fly.
     Remember that the Server may apply a different limit.
     
     Note that, if the value has just been set and a connection to Lightstreamer Server has not been established yet, the returned value is the bandwidth limit that is being requested to the Server.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `requestedMaxBandwidth` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     Moreover, upon any change or attempt to change the limit, the Server will notify the client and such notification will be received through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `realMaxBandwidth` on any ClientListener listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     
     - SeeAlso: `realMaxBandwidth`
     */
    public var requestedMaxBandwidth: RequestedMaxBandwidth {
        get {
            client.synchronized {
                m_requestedMaxBandwidth
            }
        }
        set {
            switch newValue {
            case .limited(let bw):
                guard bw > 0 else {
                     preconditionFailure("requestedMaxBandwidth must be greater than zero")
                }
            default:
                break
            }
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("requestedMaxBandwidth changed: \(newValue)")
                }
                m_requestedMaxBandwidth = newValue
                client.fireDidChangeProperty("requestedMaxBandwidth")
                client.evtExtSetRequestedMaxBandwidth()
            }
        }
    }
    
    /**
     The maximum bandwidth, expressed in kilobit/sec, that can be consumed for the data coming from Lightstreamer Server.
     
     This is the actual maximum bandwidth, in contrast with `requestedMaxBandwidth`. The value may differ from the requested one because of restrictions operated on the server side, or because bandwidth management is not supported (in this case it is always `unlimited`), but also because of number rounding.
     
     **Format:** a decimal number (e.g. `5.0`), or `unlimited`.
     
     **Lifecycle:** if a connection to Lightstreamer Server is not currently active, nil is returned; soon after the connection is established, the value becomes available, as notified by a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `realMaxBandwidth`.
     
     **Related notifications:** when the value becomes available, a notification is sent with call to `ClientDelegate.client(_:didChangeProperty:)` with argument `realMaxBandwidth` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - SeeAlso: `requestedMaxBandwidth`
     */
    public var realMaxBandwidth: RealMaxBandwidth? {
        client.synchronized {
            m_realMaxBandwidth
        }
    }

    func setRealMaxBandwidth(_ newValue: RealMaxBandwidth?) {
        client.synchronized {
            m_realMaxBandwidth = newValue
            client.fireDidChangeProperty("realMaxBandwidth")
        }
    }
    
    /**
     Polling interval used for polling connections.
     
     The client switches from the default streaming mode to polling mode when the client network infrastructure does not allow streaming. Also,
     polling mode can be forced by setting `forcedTransport` to `WS-POLLING` or `HTTP-POLLING`.
     
     The polling interval affects the rate at which polling requests are issued. It is the time between the start of a polling request and the start of
     the next request. However, if the polling interval expires before the first polling request has returned, then the second polling request is delayed. This
     may happen, for instance, when the Server delays the answer because of the idle timeout setting. In any case, the polling interval allows for setting an upper limit on the polling frequency.
     
     The Server does not impose a lower limit on the client polling interval. However, in some cases, it may protect itself against a high polling rate by
     delaying its answer. Network limitations and configured bandwidth limits may also lower the polling rate, despite of the client polling interval.
     
     The Server may, however, impose an upper limit on the polling interval, in order to be able to promptly detect terminated polling request sequences and
     discard related session information.
     
     **Default:** 0 (pure "asynchronous polling" is configured).
     
     **Lifecycle:** the polling interval should be set on the `LightstreamerClient.connectionOptions` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next bind request (this only applies to the `*-POLLING` cases).
     
     Note that, if the value has just been set and a polling request to Lightstreamer Server has not been performed yet, the returned value is the polling interval
     that is being requested to the Server. After each polling request, the value may be changed to the one imposed by the Server.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `pollingInterval` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than or equal to zero
     */
    public var pollingInterval: Millis {
        get {
            client.synchronized {
                m_pollingInterval
            }
        }
        set {
            precondition(newValue >= 0, "pollingInterval must be greater than or equal to zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    if newValue != m_pollingInterval {
                        actionLogger.info("pollingInterval changed: \(newValue)")
                    }
                }
                m_pollingInterval = newValue
                client.fireDidChangeProperty("pollingInterval")
            }
        }
    }
    
    /**
     Time the client, after entering `STALLED` status, is allowed to keep waiting for a keepalive packet or any data on a stream connection,
     before disconnecting and trying to reconnect to the Server.
     
     The new connection may be either the opening of a new session or an attempt to recovery the current session, depending on the kind of interruption.

     **Default:** 3 seconds.
     
     **Lifecycle:** this property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `reconnectTimeout` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     
     - SeeAlso: `stalledTimeout`
     
     - SeeAlso: `keepaliveInterval`
     */
    public var reconnectTimeout: Millis {
        get {
            client.synchronized {
                m_reconnectTimeout
            }
        }
        set {
            precondition(newValue > 0, "reconnectTimeout must be greater than zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("reconnectTimeout changed: \(newValue)")
                }
                m_reconnectTimeout = newValue
                client.fireDidChangeProperty("reconnectTimeout")
            }
        }
    }
    
    /**
     Minimum time to wait before trying a new connection to the Server in case the previous one failed for any reason,
     which is also the maximum time to wait for a response to a request before dropping the connection and trying with a different approach.
     
     Enforcing a delay between reconnections prevents strict loops of connection attempts when these attempts always fail immediately because
     of some persisting issue. This applies both to reconnections aimed at opening a new session and to reconnections aimed at
     attempting a recovery of the current session.

     Note that the delay is calculated from the moment the effort to create a connection is made, not from the moment the failure is detected.
     
     As a consequence, when a working connection is interrupted, this timeout is usually already consumed and the new attempt can be immediate
     (except that `firstRetryMaxDelay` will apply in this case).
     
     As another consequence, when a connection attempt gets no answer and times out, the new attempt will be immediate.
     
     As a timeout on unresponsive connections, it is applied in these cases:
     
     - *Streaming*: Applied on any attempt to setup the streaming connection. If after the timeout no data has arrived on the stream connection,
       the client may automatically switch transport or may resort to a polling connection.
     
     - *Polling and pre-flight requests*: Applied on every connection. If after the timeout no data has arrived on the polling connection,
       the entire connection process restarts from scratch.
     
     **This setting imposes only a minimum delay. In order to avoid network congestion, the library may use a longer delay if the issue preventing the
     establishment of a session persists.**

     **Default:** 4 seconds.
     
     **Lifecycle:** this property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `retryDelay` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     */
    public var retryDelay: Millis {
        get {
            client.synchronized {
                m_retryDelay
            }
        }
        set {
            precondition(newValue > 0, "retryDelay must be greater than zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("retryDelay changed: \(newValue)")
                }
                m_retryDelay = newValue
                client.fireDidChangeProperty("retryDelay")
            }
        }
    }
    
    /**
     Reverse-heartbeat interval on the control connection.
     
     If the given value equals 0 then the reverse-heartbeat mechanism will be disabled; otherwise if the given value is greater than 0 the mechanism will be enabled with the specified interval.
     
     When the mechanism is active, the client will ensure that there is at most the specified interval between a control request and the following one,
     by sending empty control requests (the "reverse heartbeats") if necessary.
     
     This can serve various purposes:
     
     - Preventing the communication infrastructure from closing an inactive socket that is ready for reuse for more HTTP control requests,
       to avoid connection reestablishment overhead. However it is not guaranteed that the connection will be kept open,
       as the underlying TCP implementation may open a new socket each time a HTTP request needs to be sent. Note that this will be done only when a session is in place.
     
     - Allowing the Server to detect when a streaming connection or Websocket is interrupted but not closed. In these cases, the client eventually closes
       the connection, but the Server cannot see that (the connection remains "half-open") and just keeps trying to write. This is done by notifying the timeout to the Server upon each streaming request. For long polling, the <idleTimeout> setting has a similar function.
     
     - Allowing the Server to detect cases in which the client has closed a connection in HTTP streaming, but the socket is kept open by some intermediate node, which keeps consuming the response. This is also done by notifying the timeout to the Server upon each streaming request, whereas, for long polling, the `idleTimeout` setting has a similar function.

     **Default:** 0 (meaning that the mechanism is disabled).
     
     **Lifecycle:** this setting should be performed before calling the `LightstreamerClient.connect()` method. However, the value can be changed at any time: the setting will be obeyed immediately, unless a higher heartbeat frequency was notified to the Server for the current connection. The setting will always be obeyed upon the next connection (either a bind or a brand new session).
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `reverseHeartbeatInterval` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than or equal to zero
     */
    public var reverseHeartbeatInterval: Millis {
        get {
            client.synchronized {
                m_reverseHeartbeatInterval
            }
        }
        set {
            precondition(newValue >= 0, "reverseHeartbeatInterval must be greater than or equal to zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("reverseHeartbeatInterval changed: \(newValue)")
                }
                m_reverseHeartbeatInterval = newValue
                client.fireDidChangeProperty("reverseHeartbeatInterval")
                client.evtExtSetReverseHeartbeatInterval()
            }
        }
    }
    
    /**
     Maximum time allowed for attempts to recover the current session upon an interruption, after which a new session will be created.
     
     If the given value equals 0, then any attempt to recover the current session will be prevented in the first place.
     
     In fact, in an attempt to recover the current session, the client will periodically try to access the Server at the address related with the current session. In some cases, this timeout, by enforcing a fresh connection attempt, may prevent an infinite sequence of unsuccessful attempts to access the Server.
     
     Note that, when the Server is reached, the recovery may fail due to a Server side timeout on the retention of the session and the updates sent. In that case, a new session will be created anyway.
     
     A setting smaller than the Server timeouts may prevent such useless failures, but, if too small, it may also prevent successful recovery in some cases.
     
     **Default:** 15 seconds.
     
     **Lifecycle:** This property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `sessionRecoveryTimeout` on any `ClientDelegate` listening to the related `LightstreamerClient`.

     - Precondition: the value must be greater than or equal to zero
     */
    public var sessionRecoveryTimeout: Millis {
        get {
            client.synchronized {
                m_sessionRecoveryTimeout
            }
        }
        set {
            precondition(newValue >= 0, "sessionRecoveryTimeout must be greater than or equal to zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("sessionRecoveryTimeout changed: \(newValue)")
                }
                m_sessionRecoveryTimeout = newValue
                client.fireDidChangeProperty("sessionRecoveryTimeout")
            }
        }
    }
    
    /**
     Extra time the client can wait when an expected keepalive packet has not been received on a stream connection (and no actual data has arrived), before entering the `STALLED` status.
     
     **Default:** 2 seconds.
     
     **Lifecycle:** This property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `stalledTimeout` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the value must be greater than zero
     
     - SeeAlso: `reconnectTimeout`
     
     - SeeAlso: `keepaliveInterval`
     */
    public var stalledTimeout: Millis {
        get {
            client.synchronized {
                m_stalledTimeout
            }
        }
        set {
            precondition(newValue > 0, "stalledTimeout must be greater than zero")
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("stalledTimeout changed: \(newValue)")
                }
                m_stalledTimeout = newValue
                client.fireDidChangeProperty("stalledTimeout")
            }
        }
    }
    
    /**
     Enables/disables a restriction on the forwarding of the extra http headers specified through `HTTPExtraHeaders`.
     
     If `true`, said headers will only be sent during the session creation process (and thus will still be available to the metadata adapter `notifyUser` method) but will not be sent on following requests. On the contrary, when set to `true`, the specified extra headers will be sent to the server on every request.
     
     **Default:** `false`.
     
     **Lifecycle:** this property can be changed at any time enabling/disabling the sending of headers on future requests.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `HTTPExtraHeadersOnSessionCreationOnly` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - SeeAlso: `HTTPExtraHeaders`
     */
    public var HTTPExtraHeadersOnSessionCreationOnly: Bool {
        get {
            client.synchronized {
                m_HTTPExtraHeadersOnSessionCreationOnly
            }
        }
        set {
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("httpExtraHeadersOnSessionCreationOnly changed: \(newValue)")
                }
                m_HTTPExtraHeadersOnSessionCreationOnly = newValue
                client.fireDidChangeProperty("httpExtraHeadersOnSessionCreationOnly")
            }
        }
    }
    
    /**
     Disable/enable the automatic handling of server instance address that may be returned by the Lightstreamer server during session creation.
     
     In fact, when a Server cluster is in place, the Server address specified through `ConnectionDetails.serverAddress` can identify various Server instances; in order to ensure that all requests related to a session are issued to the same Server instance, the Server can answer to the session opening request by providing an address which uniquely identifies its own instance.
     
     Setting this value to `true` permits to ignore that address and to always connect through the address supplied in serverAddress. This may be needed in a test environment, if the Server address specified is actually a local address to a specific Server instance in the cluster.
     
     **Edition note:** server clustering is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).
     
     **Default:** `false`.
     
     **Lifecycle:** this property can be changed at any time. If called while connected, it will be applied when the next session creation request is issued.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `serverInstanceAddressIgnored` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - SeeAlso: `ConnectionDetails.serverAddress`
     */
    public var serverInstanceAddressIgnored: Bool {
        get {
            client.synchronized {
                m_serverInstanceAddressIgnored
            }
        }
        set {
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("serverInstanceAddressIgnored changed: \(newValue)")
                }
                m_serverInstanceAddressIgnored = newValue
                client.fireDidChangeProperty("serverInstanceAddressIgnored")
            }
        }
    }
    
    /**
     Turns on or off the slowing algorithm.
     
     This heuristic algorithm tries to detect when the client CPU is not able to keep the pace of the events sent by the Server on a streaming connection.
     In that case, an automatic transition to polling is performed.
     
     In polling, the client handles all the data before issuing the next poll, hence a slow client would just delay the polls, while the Server accumulates
     and merges the events and ensures that no obsolete data is sent.
     
     Only in very slow clients, the next polling request may be so much delayed that the Server disposes the session first, because of its protection timeouts.
     In this case, a request for a fresh session will be reissued by the client and this may happen in cycle.
     
     **Default:** `false`.
     
     **Lifecycle:** the algorithm should be enabled/disabled on the `LightstreamerClient.connectionOptions` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next connection attempt.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `slowingEnabled` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var slowingEnabled: Bool {
        get {
            client.synchronized {
                m_slowingEnabled
            }
        }
        set {
            client.synchronized {
                if actionLogger.isInfoEnabled {
                    actionLogger.info("slowingEnabled changed: \(newValue)")
                }
                m_slowingEnabled = newValue
                client.fireDidChangeProperty("slowingEnabled")
            }
        }
    }
    
    public var description: String {
        client.synchronized {
            var map = OrderedDictionary<String, CustomStringConvertible>()
            map["forcedTransport"] = m_forcedTransport
            map["requestedMaxBandwidth"] = m_requestedMaxBandwidth
            map["realMaxBandwidth"] = m_realMaxBandwidth
            map["retryDelay"] = m_retryDelay
            map["firstRetryMaxDelay"] = m_firstRetryMaxDelay
            map["sessionRecoveryTimeout"] = m_sessionRecoveryTimeout > 0 ? m_sessionRecoveryTimeout : nil
            map["reverseHeartbeatInterval"] = m_reverseHeartbeatInterval > 0 ? m_reverseHeartbeatInterval : nil
            map["stalledTimeout"] = m_stalledTimeout
            map["reconnectTimeout"] = m_reconnectTimeout
            map["keepaliveInterval"] = m_keepaliveInterval > 0 ? m_keepaliveInterval : nil
            map["pollingInterval"] = m_pollingInterval > 0 ? m_pollingInterval : nil
            map["idleTimeout"] = m_idleTimeout
            map["contentLength"] = m_contentLength
            map["slowingEnabled"] = m_slowingEnabled ? true : nil
            map["serverInstanceAddressIgnored"] = m_serverInstanceAddressIgnored ? true : nil
            map["HTTPExtraHeadersOnSessionCreationOnly"] = m_HTTPExtraHeadersOnSessionCreationOnly ? true : nil
            map["HTTPExtraHeaders"] = m_HTTPExtraHeaders
            return String(describing: map)
        }
    }
}
