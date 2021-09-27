import Foundation
import OrderedCollections

/**
 Protocol to be implemented to receive `MPNSubscription` events including subscription/unsubscription, triggering and status change.
 
 Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event,
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single `LightstreamerClient`, including
 notifications to `ClientDelegate`, `SubscriptionDelegate`, `ClientMessageDelegate`, `MPNDeviceDelegate` and MPNSubscriptionDelegate will be dispatched by the same thread.
 */
public protocol MPNSubscriptionDelegate {
    /**
     Event handler called when the MPNSubscriptionDelegate instance is added to an `MPNSubscription` through `MPNSubscription.addDelegate(_:)`.
     
     This is the first event to be fired on the delegate.
     
     - Parameter subscription: The `MPNSubscription` this instance was added to.
     */
    func mpnSubscriptionDidAddDelegate(_ subscription: MPNSubscription)
    /**
     Event handler called when the MPNSubscriptionDelegate instance is removed from an `MPNSubscription` through `MPNSubscription.removeDelegate(_:)`.
     
     This is the last event to be fired on the delegate.
     
     - Parameter subscription: The `MPNSubscription` this instance was removed from.
     */
    func mpnSubscriptionDidRemoveDelegate(_ subscription: MPNSubscription)
    /**
     Event handler called when an `MPNSubscription` has been successfully subscribed to on the server's MPN Module.
     
     This event handler is always called before other events related to the same subscription.
     
     Note that this event can be called multiple times in the life of an `MPNSubscription` instance only in case it is subscribed multiple times
     through `LightstreamerClient.unsubscribeMPN(_:)` and `LightstreamerClient.subscribeMPN(_:coalescing:)`. Two consecutive calls to this method are not possible, as before a second `mpnSubscriptionDidSubscribe:` event an `mpnSubscriptionDidUnsubscribe(_:)` event is always fired.
     
     - Parameter subscription: The `MPNSubscription` involved.
     */
    func mpnSubscriptionDidSubscribe(_ subscription: MPNSubscription)
    /**
     Event handler called when an `MPNSubscription` has been successfully unsubscribed from on the server's MPN Module.
     
     After this call no more events can be received until a new `mpnSubscriptionDidSubscribe(_:)` event.
     
     Note that this event can be called multiple times in the life of an `MPNSubscription` instance only in case it is subscribed multiple times through `LightstreamerClient.unsubscribeMPN(_:)` and `LightstreamerClient.subscribeMPN(_:coalescing:)`. Two consecutive calls to this method are not possible, as before a second `mpnSubscriptionDidUnsubscribe:` event an `mpnSubscriptionDidSubscribe(_:)` event is always fired.
     
     - Parameter subscription: The `MPNSubscription` involved.
     */
    func mpnSubscriptionDidUnsubscribe(_ subscription: MPNSubscription)
    /**
     Event handler called when the server notifies an error while subscribing to an `MPNSubscription`.
     
     By implementing this method it is possible to perform recovery actions.
     
     The error code can be one of the following:
     
     - 17 - bad Data Adapter name or default Data Adapter not defined for the current Adapter Set.
     
     - 21 - bad Group name.
     
     - 22 - bad Group name for this Schema.
     
     - 23 - bad Schema name.
     
     - 24 - mode not allowed for an Item.
     
     - 30 - subscriptions are not allowed by the current license terms (for special licenses only).
     
     - 40 - the MPN Module is disabled, either by configuration or by license restrictions.
     
     - 41 - the request failed because of some internal resource error (e.g. database connection, timeout etc.).
     
     - 43 - invalid or unknown application ID.
     
     - 44 - invalid syntax in trigger expression.
     
     - 45 - invalid or unknown MPN device ID.
     
     - 46 - invalid or unknown MPN subscription ID (for MPN subscription modifications).
     
     - 47 - invalid argument name in notification format or trigger expression.
     
     - 48 - MPN device suspended.
     
     - 49 - one or more subscription properties exceed maximum size.
     
     - 50 - no items or fields have been specified.

     - 52 - the notification format is not a valid JSON structure.

     - 53 - the notification format is empty.

     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - &lt;= 0 - the Metadata Adapter has refused the subscription request; the code value is dependent on the specific Metadata Adapter implementation.
     
     - Parameter subscription: The `MPNSubscription` involved.
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     */
    func mpnSubscription(_ subscription: MPNSubscription, didFailSubscriptionWithErrorCode code: Int, message: String?)
    /**
     Event handler called when the server notifies an error while unsubscribing from an `MPNSubscription`.
     
     By implementing this method it is possible to perform recovery actions.
     
     The error code can be one of the following:
     
     - 30 - subscriptions are not allowed by the current license terms (for special licenses only).
     
     - 40 - the MPN Module is disabled, either by configuration or by license restrictions.
     
     - 41 - the request failed because of some internal resource error (e.g. database connection, timeout etc.).
     
     - 43 - invalid or unknown application ID.
     
     - 45 - invalid or unknown MPN device ID.
     
     - 46 - invalid or unknown MPN subscription ID.
     
     - 48 - MPN device suspended.
     
     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - &lt;= 0 - the Metadata Adapter has refused the unsubscription request; the code value is dependent on the specific Metadata Adapter implementation.
     
     - Parameter subscription: The `MPNSubscription` involved.
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     */
    func mpnSubscription(_ subscription: MPNSubscription, didFailUnsubscriptionWithErrorCode code: Int, message: String?)
    /**
     Event handler called when the server notifies that an `MPNSubscription` did trigger.
     
     For this event to be called the `MPNSubscription` must have a `MPNSubscription.triggerExpression` set and it must have been evaluated to true at least once.
     
     Note that this event can be called multiple times in the life of an `MPNSubscription` instance only in case it is subscribed multiple times through `LightstreamerClient.unsubscribeMPN(_:)` and `LightstreamerClient.subscribeMPN(_:coalescing:)`. Two consecutive calls to this method are not possible.
     
     Note also that in some server clustering configurations this event may not be called. The corrisponding push notification is always sent, though.

     - Parameter subscription: The `MPNSubscription` involved.

     - SeeAlso: `MPNSubscription.triggerExpression`
     */
    func mpnSubscriptionDidTrigger(_ subscription: MPNSubscription)
    /**
     Event handler called when the server notifies that an `MPNSubscription` changed its status.
     
     Note that in some server clustering configurations the status change for the MPN subscription's trigger event may not be called. The corrisponding push
     notification is always sent, though.
     
     - Parameter subscription: The `MPNSubscription` involved.
     - Parameter status: The new status of the MPN subscription.
     - Parameter timestamp: The server-side timestamp of the new subscription status.

     - SeeAlso: `MPNSubscription.status`
     - SeeAlso: `MPNSubscription.statusTimestamp`
     */
    func mpnSubscription(_ subscription: MPNSubscription, didChangeStatus status: MPNSubscription.Status, timestamp: Int64)
    /**
     Event handler called each time the value of a property of `MPNSubscription` is changed.
     
     Properties can be modified by direct calls to them or by server sent events. A propery may be changed by a server sent event when the MPN subscription is modified, or when two MPN subscriptions coalesce (see `LightstreamerClient.subscribeMPN(_:coalescing:)`).
     
     Possible property names are the following:
     
     - `mode`
     
     - `group`
     
     - `schema`
     
     - `adapter`
     
     - `notification_format`
     
     - `trigger`
     
     - `requested_buffer_size`
     
     - `requested_max_frequency`
     
     - `status_timestamp`
     
     - Parameter subscription: The `MPNSubscription` involved.

     - Parameter property: The name of the changed property.
     */
    func mpnSubscription(_ subscription: MPNSubscription, didChangeProperty property: String)
    /**
     Event handler called when the server notifies an error while modifying the trigger expression or the notification format of an `MPNSubscription`.
     
     By implementing this method it is possible to perform recovery actions.
     
     The error code can be one of the following:
     
     - 3 - Protocol mismatch.
     
     - 22 - bad Group name for this Schema.
     
     - 23 - bad Schema name.
     
     - 40 - the MPN Module is disabled, either by configuration or by license restrictions.
     
     - 41 - the request failed because of some internal resource error (e.g. database connection, timeout etc.).
     
     - 44 - invalid syntax in trigger expression.
     
     - 45 - invalid or unknown MPN device ID.
     
     - 46 - invalid or unknown MPN subscription ID (for MPN subscription modifications).
     
     - 47 - invalid argument name in notification format or trigger expression.
     
     - 48 - MPN device suspended.
     
     - 49 - one or more subscription properties exceed maximum size.
     
     - 50 - no items or fields have been specified.

     - 52 - the notification format is not a valid JSON structure.

     - 53 - the notification format is empty.
     
     - 56 - MPN subscription to be modified had changed.

     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - &lt;= 0 - the Metadata Adapter has refused the subscription request; the code value is dependent on the specific Metadata Adapter implementation.
     
     - Parameter subscription: The `MPNSubscription` involved.
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server.
     
     - Parameter property: The name of the property which raised the error. It can be either `notification_format` or `trigger`.
     
     - SeeAlso: `MPNSubscription.triggerExpression`
     - SeeAlso: `MPNSubscription.notificationFormat`
     */
    func mpnSubscription(_ subscription: MPNSubscription, didFailModificationWithErrorCode code: Int, message: String?, property: String)
}

/**
 Class representing a Mobile Push Notifications (MPN) subscription to be submitted to the MPN Module of a Lightstreamer Server.
 
 It contains subscription details and the delegate needed to monitor its status. Real-time data is routed via native push notifications.
 
 In order to successfully subscribe an MPN subscription, first an `MPNDevice` must be created and registered on the `LightstreamerClient` with
 `LightstreamerClient.register(forMPN:)`.
 
 After creation, an MPNSubscription object is in the "inactive" state. When an MPNSubscription object is subscribed to on an `LightstreamerClient`
 object, through the `LightstreamerClient.subscribeMPN(_:coalescing:)` method, its state switches to "active". This means that the subscription request is being sent to the Lightstreamer Server. Once the server accepted the request, it begins to send real-time events via native push notifications and
 the MPNSubscription object switches to the "subscribed" state.
 
 If a `triggerExpression` is set, the MPN subscription does not send any push notifications until the expression evaluates to true. When this happens,
 the MPN subscription switches to "triggered" state and a single push notification is sent. Once triggered, no other push notifications are sent.
 
 When an MPNSubscription is subscribed on the server, it acquires a permanent `subscriptionId` that the server later uses to identify the same
 MPN subscription on subsequent sessions.

 An MPNSubscription can be configured to use either an Item Group or an Item List to specify the items to be subscribed to, and using either a Field Schema
 or Field List to specify the fields. The same rules that apply to `Subscription` apply to MPNSubscription.
 
 An MPNSubscription object can also be provided by the client to represent a pre-existing MPN subscription on the server. In fact, differently than real-time
 subscriptions, MPN subscriptions are persisted on the server's MPN Module database and survive the session they were created on.
 
 MPN subscriptions are associated with the MPN device, and after the device has been registered the client retrieves pre-existing MPN subscriptions from the
 server's database and exposes them in the `LightstreamerClient.MPNSubscriptions` collection.
 */
public class MPNSubscription: CustomStringConvertible {
    /**
     The mode of a Subscription.
     
     - SeeAlso: `mode`
     */
    public enum Mode: String, CustomStringConvertible {
        /// Merge mode
        case MERGE = "MERGE"
        /// Distinct mode
        case DISTINCT = "DISTINCT"
        
        public var description: String {
            self.rawValue
        }
    }
    
    /**
     Length to be requested to Lightstreamer Server for the internal queuing buffers for the items in a Subscription.
     
     - SeeAlso: `requestedBufferSize`
     */
    public enum RequestedBufferSize: Equatable, CustomStringConvertible {
        /// Limited buffer size
        case limited(Int)
        /// Unlimited buffer
        case unlimited
        
        public var description: String {
            switch self {
            case .unlimited:
                return "unlimited"
            case .limited(let size):
                return "\(size)"
            }
        }
    }
    
    /**
     Maximum update frequency to be requested to Lightstreamer Server for all the items in a Subscription.
     
     - SeeAlso: `requestedMaxFrequency`
     */
    public enum RequestedMaxFrequency: Equatable, CustomStringConvertible {
        /// Limited frequency (in updates per second)
        case limited(Double)
        /// Unlimited frequency
        case unlimited
        
        public var description: String {
            switch self {
            case .unlimited:
                return "unlimited"
            case .limited(let freq):
                return "\(freq) updates/sec"
            }
        }
    }
    
    /**
     The status of a subscription.
     */
    public enum Status: String {
        /// `UNKNOWN`: when the MPN subscription has just been created or deleted (i.e. unsubscribed).
        case UNKNOWN = "UNKNOWN"
        /// `ACTIVE`: when the MPN susbcription has been submitted to the server, but no confirm has been received yet.
        case ACTIVE = "ACTIVE"
        /// `SUBSCRIBED`: when the MPN subscription has been successfully subscribed on the server. If a trigger expression is set, it has not been evaluated to true yet.
        case SUBSCRIBED = "SUBSCRIBED"
        /// `TRIGGERED`: when the MPN subscription has a trigger expression set, has been successfully on the server and the trigger expression evaluated to true at least once.
        case TRIGGERED = "TRIGGERED"
    }
    
    static let EMPTY_ITEM_LIST = "Item List is empty"
    static let EMPTY_FIELD_LIST = "Field List is empty"
    static let INVALID_ITEM_LIST = "Item List is invalid"
    static let INVALID_FIELD_LIST = "Field List is invalid"
    static let IS_ACTIVE = "Cannot modify an active MPNSubscription. Please unsubscribe before applying any change"
    static let IS_EMPTY = "The value is empty"
    let lock = NSRecursiveLock()
    let multicastDelegate = MulticastDelegate<MPNSubscriptionDelegate>()
    let callbackQueue = defaultQueue
    var m_status: Status = .UNKNOWN
    var m_mode: Mode!
    var m_items: [String]?
    var m_fields: [String]?
    var m_group: String?
    var m_schema: String?
    var m_dataAdapter: String?
    var m_bufferSize: RequestedBufferSize?
    var m_requestedMaxFrequency: RequestedMaxFrequency?
    var m_statusTs: Int64 = 0
    var m_mpnSubId: String?
    var m_requestedTrigger: String?
    var m_realTrigger: String?
    var m_requestedFormat: String?
    var m_realFormat: String?
    let m_madeByServer: Bool
    weak var m_manager: MpnSubscriptionManager?
    
    /**
     Creates an object to be used to describe an MPN subscription that is going to be subscribed to through the MPN Module of Lightstreamer Server.
     
     The object can be supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring the MPN subscription to "active" state.
     
     Note that all of the methods used to describe the subscription to the server, except `triggerExpression` and `notificationFormat`, can only be called while the instance is in the "inactive" state.
     
     Permitted values for subscription mode are:
     
     - `MERGE`
     
     - `DISTINCT`
     
     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.
     */
    public init(subscriptionMode: Mode) {
        m_mode = subscriptionMode
        m_madeByServer = false
    }
    
    /**
     Creates an object to be used to describe an MPN subscription that is going to be subscribed to through the MPN Module of Lightstreamer Server.
     
     The object can be supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring the MPN subscription to "active" state.
     
     Note that all of the methods used to describe the subscription to the server, except `triggerExpression` and `notificationFormat`, can only be called while the instance is in the "inactive" state.
     
     Permitted values for subscription mode are:
     
     - `MERGE`
     
     - `DISTINCT`
     
     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.
     
     - Parameter item: The item name to be subscribed to through Lightstreamer Server.

     - Parameter fields: An array of fields for the items to be subscribed to through Lightstreamer Server. It is also possible to specify the "Field List" or
     "Field Schema" later through `fields` and `fieldSchema`.
     
     - Precondition: the specified "Item List" and "Field List" must be valid; see `items` and `fields` for details.
     */
    public convenience init(subscriptionMode: Mode, item: String, fields: [String]) {
        self.init(subscriptionMode: subscriptionMode, items: [item], fields: fields)
    }
    
    /**
     Creates an object to be used to describe an MPN subscription that is going to be subscribed to through the MPN Module of Lightstreamer Server.
     
     The object can be supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring the MPN subscription to "active" state.
     
     Note that all of the methods used to describe the subscription to the server, except `triggerExpression` and `notificationFormat`, can only be called while the instance is in the "inactive" state.
     
     Permitted values for subscription mode are:
     
     - `MERGE`
     
     - `DISTINCT`

     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.
     
     - Parameter items: An array of items to be subscribed to through Lightstreamer Server. It is also possible specify the "Item List" or
     "Item Group" later through `items` and `itemGroup`.
     
     - Parameter fields: An array of fields for the items to be subscribed to through Lightstreamer Server. It is also possible to specify the "Field List" or
     "Field Schema" later through `fields` and `fieldSchema`.
     
     - Precondition: the specified "Item List" and "Field List" must be valid; see `items` and `fields` for details.
     */
    public convenience init(subscriptionMode: Mode, items: [String], fields: [String]) {
        precondition(!items.isEmpty, Self.EMPTY_ITEM_LIST)
        precondition(!fields.isEmpty, Self.EMPTY_FIELD_LIST)
        precondition(items.allSatisfy({ isValidItem($0) }), Self.INVALID_ITEM_LIST)
        precondition(fields.allSatisfy({ isValidField($0) }), Self.INVALID_FIELD_LIST)
        self.init(subscriptionMode: subscriptionMode)
        m_items = items
        m_fields = fields
    }
    
    /**
     Creates an MPNSubscription object copying subscription mode, items, fields and data adapter from the specified real-time subscription.
     
     The object can be supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring the MPN subscription to "active" state.
     
     Note that all of the methods used to describe the subscription to the server, except `triggerExpression` and `notificationFormat`, can only be called while the instance is in the "inactive" state.

     - Parameter subscription: The `Subscription` object to copy properties from.
     */
    public init(subscription: Subscription) {
        switch subscription.mode {
        case .MERGE:
            m_mode = .MERGE
        case .DISTINCT:
            m_mode = .DISTINCT
        default:
            preconditionFailure("Invalid mode: only MERGE and COMMAND modes are supported")
        }
        m_items = subscription.items
        m_group = subscription.itemGroup
        m_fields = subscription.fields
        m_schema = subscription.fieldSchema
        m_dataAdapter = subscription.dataAdapter
        switch subscription.requestedBufferSize {
        case .limited(let size):
            m_bufferSize = .limited(size)
        case .unlimited:
            m_bufferSize = .unlimited
        case .none:
            m_bufferSize = nil
        }
        switch subscription.requestedMaxFrequency {
        case .limited(let freq):
            m_requestedMaxFrequency = .limited(freq)
        case .unlimited:
            m_requestedMaxFrequency = .unlimited
        case .none:
            m_requestedMaxFrequency = nil
        default:
            preconditionFailure("Invalid frequency: only 'limited' and 'unlimited' values are supported")
        }
        m_madeByServer = false
    }
    
    /**
     Creates an MPNSubscription object copying all properties from the specified MPN subscription.
     
     The object can be supplied to `LightstreamerClient.subscribeMPN(_:coalescing:)` in order to bring the MPN subscription to "active" state.
     
     Note that all of the methods used to describe the subscription to the server, except `triggerExpression` and `notificationFormat`, can only be called while the instance is in the "inactive" state.
     
     - Parameter mpnSubscription: The MPNSubscription object to copy properties from.
     */
    public init(MPNSubscription mpnSubscription: MPNSubscription) {
        m_mode = mpnSubscription.mode
        m_items = mpnSubscription.items
        m_group = mpnSubscription.itemGroup
        m_fields = mpnSubscription.fields
        m_schema = mpnSubscription.fieldSchema
        m_dataAdapter = mpnSubscription.dataAdapter
        m_bufferSize = mpnSubscription.requestedBufferSize
        m_requestedMaxFrequency = mpnSubscription.requestedMaxFrequency
        m_requestedFormat = mpnSubscription.requestedFormat
        m_requestedTrigger = mpnSubscription.requestedTrigger
        m_madeByServer = false
    }
    
    init(_ mpnSubId: String) {
        m_mpnSubId = mpnSubId
        m_madeByServer = true
    }
    
    var itemsOrGroup: String {
        synchronized {
            items?.joined(separator: " ") ?? itemGroup ?? ""
        }
    }
    
    var fieldsOrSchema: String {
        synchronized {
            fields?.joined(separator: " ") ?? fieldSchema ?? ""
        }
    }
    
    /**
     The mode specified for this MPNSubscription.
     
     **Lifecycle:** this property can be read at any time.
     */
    public var mode: Mode {
        synchronized {
            m_mode
        }
    }
    
    var requestedTrigger: String? {
        synchronized {
            m_requestedTrigger
        }
    }
    
    /**
     A boolean expression that, when set, is evaluated against each update and will act as a trigger to deliver the push notification.
     
     If a trigger expression is set, the MPN subscription does not send any push notifications until the expression evaluates to true. When this happens,
     the MPN subscription "triggers" and a single push notification is sent. Once triggered, no other push notifications are sent. In other words, with a trigger
     expression set, the MPN subscription sends *at most one* push notification.
     
     The expression must be strictly in Java syntax and can contain named arguments with the format `${field}`, or indexed arguments with the format `$[1]`. The same rules that apply to `notificationFormat` apply also to the trigger expression. The expression is verified and evaluated on the server.
     
     Named and indexed arguments are replaced by the server with the value of corresponding subscription fields before the expression is evaluated. They are
     represented as String variables, and as such appropriate type conversion must be considered. E.g.
     
     - `Double.parseDouble(${last_price}) > 500.0`
     
     Argument variables are named with the prefix `LS_MPN_field` followed by an index. Thus, variable names like `LS_MPN_field1` should be considered reserved and their use avoided in the expression.
     
     Consider potential impact on server performance when writing trigger expressions. Since Java code may use classes and methods of the JDK, a badly written trigger may cause CPU hogging or memory exhaustion. For this reason, a server-side filter may be applied to refuse poorly written (or even maliciously crafted) trigger expressions. See the "General Concepts" document for more information.

     - Remark: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     named arguments are always mapped to its corresponding indexed argument, even if originally the trigger expression used a named argument.

     - Remark: the content of this property may be subject to length restrictions (See the "General Concepts" document for more information).
     
     **Lifecycle:** this property can be changed at any time.

     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `trigger` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.
     
     - Parameter newValue: the boolean expression that acts as a trigger to deliver the push notification. If the value is `nil`, no trigger is set on the subscription.

     - Returns: returns the trigger expression requested by the user.

     - SeeAlso: `isTriggered`
     - SeeAlso: `actualTriggerExpression`
     */
    public var triggerExpression: String? {
        get {
            synchronized {
                m_requestedTrigger
            }
        }
        
        set {
            var manager: MpnSubscriptionManager?
            synchronized {
                m_requestedTrigger = newValue
                manager = m_manager
            }
            manager?.evtExtMpnSetTrigger()
        }
    }
    
    /**
     Inquiry method that gets the trigger expression evaluated by the Sever.
     
     - Returns: returns the trigger sent by the Server or `nil` if the value is not available.
     
     - SeeAlso: `triggerExpression`
     */
    public var actualTriggerExpression: String? {
        synchronized {
            m_realTrigger
        }
    }
    
    var requestedFormat: String? {
        synchronized {
            m_requestedFormat
        }
    }
    
    /**
     JSON structure to be used as the format of push notifications.
     
     This JSON structure is sent by the server to the push notification service provider (i.e. Apple's APNs), hence it must follow
     its specifications.
     
     The JSON structure may contain named arguments with the format `${field}`, or indexed arguments with the format `$[1]`. These arguments are replaced by the server with the value of corresponding subscription fields before the push notification is sent.
     
     For instance, if the subscription contains fields "stock_name" and "last_price", the notification format could be something like this:
     
     - `{ "aps" : { "alert" : "Stock ${stock_name} is now valued ${last_price}" } }`
     
     Named arguments are available if the Metadata Adapter is a subclass of LiteralBasedProvider or provides equivalent functionality, otherwise only
     indexed arguments may be used. In both cases common metadata rules apply: field names and indexes are checked against the Metadata Adapter, hence
     they must be consistent with the schema and group specified.
     
     Some special server-managed arguments may also be used:
     
     - `AUTO`: when specified for the badge value of the push notification, the badge will be assigned automatically as a progressive counter of all
     push notifications originated by MPN subscriptions with the "AUTO" value, on a per-device and per-application basis. The counter can also be reset at any time by calling `LightstreamerClient.resetMPNBadge`.
     
     - `${LS_MPN_subscription_ID}`: the ID of the MPN subscription generating the push notification.
     
     The `MPNBuilder` object provides methods to build an appropriate JSON structure from its defining fields.
     
     - Remark: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     named arguments are always mapped to its corresponding indexed argument, even if originally the notification format used a named argument.

     - Remark: the content of this property may be subject to length restrictions (See the "General Concepts" document for more information).
     
     **Lifecycle:** this property can be changed at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `notification_format` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Parameter newValue: the JSON structure to be used as the format of push notifications.

     - Returns: returns the notification format requested by the user.
     
     - SeeAlso: `MPNBuilder`
     - SeeAlso: `actualNotificationFormat`
     */
    public var notificationFormat: String? {
        get {
            synchronized {
                m_requestedFormat
            }
        }
        
        set {
            var manager: MpnSubscriptionManager?
            synchronized {
                m_requestedFormat = newValue
                manager = m_manager
            }
            manager?.evtExtMpnSetFormat()
        }
    }
    
    /**
      Inquiry method that gets the notification format used by the Sever to send notifications.
      
      - Returns: returns the notification format sent by the Server or `nil` if the value is not available.
      
      - SeeAlso: `notificationFormat`
     */
    public var actualNotificationFormat: String? {
        synchronized {
            m_realFormat
        }
    }
    
    /**
     Name of the Data Adapter (within the Adapter Set used by the current session) that supplies all the items for this MPNSubscription.
     
     The Data Adapter name is configured on the server side through the "name" attribute of the &lt;data_provider&gt; element, in the `adapters.xml` file
     that defines the Adapter Set (a missing attribute configures the `DEFAULT` name).
     
     Note that if more than one Data Adapter is needed to supply all the items in a set of items, then it is not possible to group all the items of
     the set in a single MPNSubscription. Multiple MPNSubscriptions have to be defined.
     
     **Default:** the default Data Adapter for the Adapter Set, configured as `DEFAULT` on the Server.
     
     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `adapter` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the MPNSubscription must be currently "inactive".
     
     - SeeAlso: `ConnectionDetails.adapterSet`
     */
    public var dataAdapter: String? {
        get {
            synchronized {
                m_dataAdapter
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_dataAdapter = newValue
            }
        }
    }
    
    /**
     The "Field List" to be subscribed to through Lightstreamer Server.
     
     Any change to this property will override any "Field List" or "Field Schema" previously specified.
     
     Note: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     fields are always expressed with a "Field Schema"", even if originally the MPN subscription used a "Field List".
     
     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `schema` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the field names in the list must not contain a space or be empty/nil.
     
     - Precondition: the MPNSubscription must be currently "inactive".
     */
    public var fields: [String]? {
        get {
            synchronized {
                m_fields
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.EMPTY_FIELD_LIST)
                precondition(allValidFields(newValue), Self.INVALID_FIELD_LIST)
                m_fields = newValue
                m_schema = nil
            }
        }
    }
    
    /**
     The "Field Schema" to be subscribed to through Lightstreamer Server.
     
     Any change to this property will override any "Field List" or "Field Schema" previously specified.
     
     Note: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     fields are always expressed with a "Field Schema"", even if originally the MPN subscription used a "Field List".

     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `schema` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the MPNSubscription must be currently "inactive".
     */
    public var fieldSchema: String? {
        get {
            synchronized {
                m_schema
            }
            
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_schema = newValue
                m_fields = nil
            }
        }
    }
    
    /**
     The "Item Group" to be subscribed to through Lightstreamer Server.
     
     Any change to this property will override any "Item List" or "Item Group" previously specified.
     
     Note: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     items are always expressed with an "Item Group"", even if originally the MPN subscription used an "Item List".

     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `group` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the MPNSubscription must be currently "inactive".
     */
    public var itemGroup: String? {
        get {
            synchronized {
                m_group
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_group = newValue
                m_items = nil
            }
        }
    }
    
    /**
     The "Item List" to be subscribed to through Lightstreamer Server.
     
     Any change to this property will override any "Item List" or "Item Group" previously specified.
     
     Note: if the MPNSubscription has been created by the client, such as when obtained through `LightstreamerClient.MPNSubscriptions`,
     items are always expressed with an "Item Group"", even if originally the MPN subscription used an "Item List".

     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `group` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the item names in the "Item List" must not contain a space or be a number or be empty/nil.
     
     - Precondition: the MPNSubscription must be currently "inactive".
     */
    public var items: [String]? {
        get {
            synchronized {
                m_items
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.EMPTY_ITEM_LIST)
                precondition(allValidItems(newValue), Self.INVALID_ITEM_LIST)
                m_items = newValue
                m_group = nil
            }
        }
    }
    
    /**
     Length to be requested to Lightstreamer Server for the internal queuing buffers for the items in the MPNSubscription.
     
     A Queuing buffer is used by the Server to accumulate a burst of updates for an item, so that they can all sent as push notifications, despite of
     frequency limits. If the value `unlimited` is supplied, then the buffer length is decided by the Server.
     
     Note that the Server may pose an upper limit on the size of its internal buffers.
     
     **Format:** an integer number (e.g. `10`), or `unlimited`, or nil.
     
     **Default:** nil, meaning to lean on the Server default based on the MPNSubscription `mode`. This means that the buffer size will be 1 for MERGE subscriptions and `unlimited` for DISTINCT subscriptions.  See the "General Concepts" document for further details.
     
     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `requested_buffer_size` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the MPNSubscription must be currently "inactive".
     
     - SeeAlso: `requestedMaxFrequency`
     */
    public var requestedBufferSize: RequestedBufferSize? {
        get {
            synchronized {
                m_bufferSize
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                m_bufferSize = newValue
            }
        }
    }
    
    /**
     Maximum update frequency to be requested to Lightstreamer Server for all the items in the MPNSubscription.
     
     The maximum update frequency is expressed in updates per second and applies for each item in the MPNSubscription; for instance, with a setting of 0.5,
     for each single item, no more than one update every 2 seconds will be received. If the value `unlimited` is supplied, then no frequency
     limit is requested. It is also possible to supply the nil value stick to the Server default (which currently corresponds to `unlimited`).
     
     Note that frequency limits on the items can also be set on the server side and this request can only be issued in order to further reduce the
     frequency, not to rise it beyond these limits.
     
     **Edition note:** a further global frequency limit could also be imposed by the Server, depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Format:** a decimal number (e.g. `2.0`), or `unlimited`, or nil.
     
     **Default:** nil, meaning to lean on the Server default based on the MPNSubscription <mode>. This consists, for all modes, in not applying any frequency
     limit to the subscription (the same as `unlimited`); see the "General Concepts" document for further details.
     
     **Lifecycle:** this property can only be set while the MPNSubscription instance is in its "inactive" state.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `requested_max_frequency` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - Precondition: the MPNSubscription must be currently "inactive".
     */
    public var requestedMaxFrequency: RequestedMaxFrequency? {
        get {
            synchronized {
                m_requestedMaxFrequency
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                m_requestedMaxFrequency = newValue
            }
        }
    }
    
    /**
     Checks if the MPNSubscription is currently "active" or not.
     
     Most of the MPNSubscription properties cannot be modified if an MPNSubscription is "active".
     
     The status of an MPNSubscription is changed to "active" through the `LightstreamerClient.subscribeMPN(_:coalescing:)` method and back to "inactive" through the `LightstreamerClient.unsubscribeMPN(_:)` and `LightstreamerClient.unsubscribeMultipleMPN(_:)` ones.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `status`

     - SeeAlso: `LightstreamerClient.subscribeMPN(_:coalescing:)`
     
     - SeeAlso: `LightstreamerClient.unsubscribeMPN(_:)`
     
     - SeeAlso: `LightstreamerClient.unsubscribeMultipleMPN(_:)`
     */
    public var isActive: Bool {
        synchronized {
            m_status != .UNKNOWN
        }
    }
    
    /**
     Checks if the MPNSubscription is currently subscribed to through the server or not.
     
     This flag is switched to `true` by server sent subscription events, and back to `false` in case of client disconnection, `LightstreamerClient.unsubscribeMPN(_:)` or `LightstreamerClient.unsubscribeMultipleMPN(_:)` calls, and server sent unsubscription events.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `status`
     
     - SeeAlso: `LightstreamerClient.unsubscribeMPN(_:)`
     
     - SeeAlso: `LightstreamerClient.unsubscribeMultipleMPN(_:)`
     */
    public var isSubscribed: Bool {
        synchronized {
            m_status == .SUBSCRIBED
        }
    }
    
    /**
     Checks if the MPNSubscription is currently triggered or not.
     
     This flag is switched to `true` when a trigger expression has been set and it evaluated to true at least once. For this to happen, the subscription
     must already be in `isActive` and `isSubscribed` states. It is switched back to `false` if the subscription is modified with a `LightstreamerClient.subscribeMPN(_:coalescing:)` call on a copy of it, deleted with `LightstreamerClient.unsubscribeMPN(_:)` or `LightstreamerClient.unsubscribeMultipleMPN(_:)` calls, and server sent subscription events.

     **Lifecycle:** this property can be read at any time.

     - SeeAlso: `status`
     */
    public var isTriggered: Bool {
        synchronized {
            m_status == .TRIGGERED
        }
    }
    
    /**
     The status of the subscription.
     
     The status can be:
     
     - `UNKNOWN`: when the MPN subscription has just been created or deleted (i.e. unsubscribed). In this status `isActive`, `isSubscribed` and `isTriggered` are all `false`.
     
     - `ACTIVE`: when the MPN susbcription has been submitted to the server, but no confirm has been received yet. In this status `isActive` is `true`, `isSubscribed` and `isTriggered` are `false`.
     
     - `SUBSCRIBED`: when the MPN subscription has been successfully subscribed on the server. If a trigger expression is set, it has not been evaluated to true yet. In this status `isActive` and `isSubscribed` are `true`, `isTriggered` is `false`.
     
     - `TRIGGERED`: when the MPN subscription has a trigger expression set, has been successfully on the server and the trigger expression evaluated to true at least once. In this status `isActive`, `isSubscribed` and `isTriggered` are all `true`.
     
     **Lifecycle:** this property can be read at any time.

     - SeeAlso: `isActive`

     - SeeAlso: `isSubscribed`
     
     - SeeAlso: `isTriggered`
     */
    public var status: Status {
        synchronized {
            m_status
        }
    }
    
    /**
     The server-side timestamp of the subscription status.
     
     **Lifecycle:** this property can be read at any time.
     
     **Related notifications:** a change to this setting will be notified through a call to `MPNSubscriptionDelegate.mpnSubscription(_:didChangeProperty:)` with argument `status_timestamp` on any `MPNSubscriptionDelegate` listening to the related MPNSubscription.

     - SeeAlso: `status`
     */
    public var statusTimestamp: Int64 {
        synchronized {
            m_statusTs
        }
    }
    
    /**
     The server-side unique persistent ID of the MPN subscription.
     
     The ID is available only after the MPN subscription has been successfully subscribed on the server. I.e. when its status is `SUBSCRIBED` or `TRIGGERED`.
     
     Note: more than one MPNSubscription may exists at any given time referring to the same MPN subscription, and thus with the same subscription ID.
     For instace, copying an MPNSubscription with the copy initializer creates a second MPNSubscription instance with the same subscription ID. Also,
     the `coalescing` flag of `LightstreamerClient.subscribeMPN(_:coalescing:)` may cause the assignment of a pre-existing MPN subscription ID to the new subscription.
     
     Two MPNSubscription objects with the same subscription ID always represent the same server-side MPN subscription. It is the client's duty to keep the status and properties of these objects up to date and aligned.
     
     **Lifecycle:** this property can be read at any time.
     */
    public var subscriptionId: String? {
        synchronized {
            m_mpnSubId
        }
    }
    
    /**
     Adds a delegate that will receive events from the MPNSubscription instance.
     
     The same delegate can be added to several different MPNSubscription instances.
     
     **Lifecycle:** a delegate can be added at any time. A call to add a delegate already present will be ignored.
     
     - Parameter delegate: An object that will receive the events as documented in the `MPNSubscriptionDelegate` interface.
     Note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
     
     - SeeAlso: `removeDelegate(_:)`
     */
    public func addDelegate(_ delegate: MPNSubscriptionDelegate) {
        synchronized {
            guard !multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.addDelegate(delegate)
            callbackQueue.async {
                delegate.mpnSubscriptionDidAddDelegate(self)
            }
        }
    }
    
    /**
     Removes a delegate from the MPNSubscription instance so that it will not receive events anymore.
     
     **Lifecycle:** a delegate can be removed at any time.
     
     - Parameter delegate: The delegate to be removed.
     
     - SeeAlso: `addDelegate(_:)`
     */
    public func removeDelegate(_ delegate: MPNSubscriptionDelegate) {
        synchronized {
            guard multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.removeDelegate(delegate)
            callbackQueue.async {
                delegate.mpnSubscriptionDidRemoveDelegate(self)
            }
        }
    }
    
    /**
     List containing the `MPNSubscriptionDelegate` instances that were added to this MPNSubscription.
     
     - SeeAlso: `addDelegate(_:)`
     */
    public var delegates: [MPNSubscriptionDelegate] {
        synchronized {
            multicastDelegate.getDelegates()
        }
    }
    
    public var description: String {
        synchronized {
            var map = OrderedDictionary<String, CustomStringConvertible>()
            map["mode"] = m_mode
            map["items"] = m_items ?? m_group
            map["fields"] = m_fields ?? m_schema
            map["dataAdapter"] = m_dataAdapter
            map["requestedBufferSize"] = m_bufferSize
            map["requestedMaxFrequency"] = m_requestedMaxFrequency
            map["trigger"] = m_requestedTrigger
            map["notificationFormat"] = m_requestedFormat
            return String(describing: map)
        }
    }
    
    func setSubscriptionId(_ mpnSubId: String) {
        synchronized {
            m_mpnSubId = mpnSubId
        }
    }
    
    func changeStatus(_ status: MPNSubscription.Status, _ statusTs: String?) {
        synchronized {
            let statusTs = statusTs == nil ? m_statusTs : Int64(statusTs!)!
            if status != m_status {
                m_status = status
                multicastDelegate.invokeDelegates { delegate in
                    callbackQueue.async {
                        delegate.mpnSubscription(self, didChangeStatus: status, timestamp: statusTs)
                    }
                }
            }
        }
    }
    
    func changeStatusTs(_ rawStatusTs: String?) {
        synchronized {
            guard let rawStatusTs = rawStatusTs, let statusTs = Int64(rawStatusTs) else {
                return
            }
            if statusTs != m_statusTs {
                m_statusTs = statusTs
                fireOnPropertyChange("status_timestamp")
            }
        }
    }
    
    func changeMode(_ rawMode: String?) {
        synchronized {
            guard let rawMode = rawMode else {
                return
            }
            let mode: MPNSubscription.Mode
            switch rawMode.lowercased() {
            case "merge":
                mode = .MERGE
            case "distinct":
                mode = .DISTINCT
            default:
                fatalError()
            }
            if mode != m_mode {
                m_mode = mode
                fireOnPropertyChange("mode")
            }
        }
    }
    
    func changeGroup(_ group: String?) {
        synchronized {
            guard let group = group else {
                return
            }
            if group != m_group {
                m_group = group
                m_items = nil
                fireOnPropertyChange("group")
            }
        }
    }
    
    func changeSchema(_ schema: String?) {
        synchronized {
            guard let schema = schema else {
                return
            }
            if schema != m_schema {
                m_schema = schema
                m_fields = nil
                fireOnPropertyChange("schema")
            }
        }
    }
    
    func changeAdapter(_ adapter: String?) {
        synchronized {
            if adapter != m_dataAdapter {
                m_dataAdapter = adapter
                fireOnPropertyChange("adapter")
            }
        }
    }
    
    func changeFormat(_ format: String?) {
        synchronized {
            guard let format = format else {
                return
            }
            if format != m_realFormat {
                m_realFormat = format
                fireOnPropertyChange("notification_format")
            }
        }
    }
    
    func changeTrigger(_ trigger: String?) {
        synchronized {
            if trigger != m_realTrigger {
                m_realTrigger = trigger
                fireOnPropertyChange("trigger")
            }
        }
    }
    
    func changeBufferSize(_ rawBufferSize: String?) {
        synchronized {
            let bufferSize: MPNSubscription.RequestedBufferSize?
            if rawBufferSize == nil {
                bufferSize = nil
            } else if rawBufferSize!.lowercased() == "unlimited" {
                bufferSize = .unlimited
            } else if let size = Int(rawBufferSize!) {
                bufferSize = .limited(size)
            } else {
                fatalError()
            }
            if bufferSize != m_bufferSize {
                m_bufferSize = bufferSize
                fireOnPropertyChange("requested_buffer_size")
            }
        }
    }
    
    func changeMaxFrequency(_ rawFrequency: String?) {
        synchronized {
            let maxFreq: MPNSubscription.RequestedMaxFrequency?
            if rawFrequency == nil {
                maxFreq = nil
            } else if rawFrequency!.lowercased() == "unlimited" {
                maxFreq = .unlimited
            } else if let freq = Double(rawFrequency!) {
                maxFreq = .limited(freq)
            } else {
                fatalError()
            }
            if maxFreq != m_requestedMaxFrequency {
                m_requestedMaxFrequency = maxFreq
                fireOnPropertyChange("requested_max_frequency")
            }
        }
    }
    
    func reset() {
        synchronized {
            m_realFormat = nil
            m_realTrigger = nil
            m_statusTs = 0
            m_mpnSubId = nil
        }
    }
    
    func fireOnSubscription() {
        synchronized {
            if mpnSubscriptionLogger.isInfoEnabled {
                mpnSubscriptionLogger.info("\(m_madeByServer ? "Server " : "")MPNSubscription subscribed: pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscriptionDidSubscribe(self)
                }
            }
        }
    }
    
    func fireOnUnsubscription() {
        synchronized {
            if mpnSubscriptionLogger.isInfoEnabled {
                mpnSubscriptionLogger.info("\(m_madeByServer ? "Server " : "")MPNSubscription unsubscribed: pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscriptionDidUnsubscribe(self)
                }
            }
        }
    }
    
    func fireOnTriggered() {
        synchronized {
            if mpnSubscriptionLogger.isInfoEnabled {
                mpnSubscriptionLogger.info("\(m_madeByServer ? "Server " : "")MPNSubscription triggered: pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscriptionDidTrigger(self)
                }
            }
        }
    }
    
    func fireOnSubscriptionError(_ code: Int, _ msg: String) {
        synchronized {
            if mpnSubscriptionLogger.isWarnEnabled {
                mpnSubscriptionLogger.warn("\(m_madeByServer ? "Server " : "")MPNSubscription error: \(code) - \(msg) pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscription(self, didFailSubscriptionWithErrorCode: code, message: msg)
                }
            }
        }
    }
    
    func fireOnUnsubscriptionError(_ code: Int, _ msg: String) {
        synchronized {
            if mpnSubscriptionLogger.isWarnEnabled {
                mpnSubscriptionLogger.warn("\(m_madeByServer ? "Server " : "")MPNSubscription unsubscription error: \(code) - \(msg) pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscription(self, didFailUnsubscriptionWithErrorCode: code, message: msg)
                }
            }
        }
    }
    
    func fireOnModificationError(_ code: Int, message: String, property: String) {
        synchronized {
            if mpnSubscriptionLogger.isWarnEnabled {
                mpnSubscriptionLogger.warn("\(m_madeByServer ? "Server " : "")MPNSubscription \(property) modification error: \(code) - \(message) pnSubId: \(m_mpnSubId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscription(self, didFailModificationWithErrorCode: code, message: message, property: property)
                }
            }
        }
    }
    
    func fireOnPropertyChange(_ property: String) {
        synchronized {
            if mpnSubscriptionLogger.isInfoEnabled {
                let propVal: String
                switch property {
                case "mode":
                    propVal = "newValue: \(m_mode == nil ? "nil" : String(describing: m_mode))"
                case "group":
                    propVal = "newValue: \(m_group ?? "nil")"
                case "schema":
                    propVal = "newValue: \(m_schema ?? "nil")"
                case "adapter":
                    propVal = "newValue: \(m_dataAdapter ?? "nil")"
                case "notification_format":
                    propVal = "newValue: \(m_realFormat ?? "nil")"
                case "trigger":
                    propVal = "newValue: \(m_realTrigger ?? "nil")"
                case "requested_buffer_size":
                    propVal = "newValue: \(m_bufferSize == nil ? "nil" : String(describing: m_bufferSize))"
                case "requested_max_frequency":
                    propVal = "newValue: \(m_requestedMaxFrequency == nil ? "nil" : String(describing: m_requestedMaxFrequency))"
                case "status_timestamp":
                    propVal = ""
                default:
                    propVal = ""
                }
                // don't log timestamp: it's too verbose
                if property != "status_timestamp" {
                    mpnSubscriptionLogger.info("\(m_madeByServer ? "Server " : "")MPNSubscription \(property) changed: \(propVal) pnSubId: \(m_mpnSubId ?? "n.a.")")
                }
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnSubscription(self, didChangeProperty: property)
                }
            }
        }
    }
    
    var subManager: MpnSubscriptionManager? {
        synchronized {
            m_manager
        }
    }
    
    func relate(to manager: MpnSubscriptionManager) {
        synchronized {
            m_manager = manager
        }
    }
    
    func unrelate(from manager: MpnSubscriptionManager) {
        synchronized {
            guard manager === m_manager else {
                return
            }
            m_manager = nil
        }
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
}
