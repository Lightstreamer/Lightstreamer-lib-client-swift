import Foundation

/**
 The real maximum update frequency of a Subscription.
 */
public enum RealMaxFrequency: Equatable, CustomStringConvertible {
    /**
     A decimal number representing the maximum frequency applied by the Server (expressed in updates per second).
     */
    case limited(Double)
    /**
     No limit applied on the frequency.
     */
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
 Protocol to be implemented to receive `Subscription` events comprehending notifications of subscription/unsubscription, updates, errors and others.
 
 Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event,
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single `LightstreamerClient`, including
 notifications to `ClientDelegate`, SubscriptionDelegate, `ClientMessageDelegate`, `MPNDeviceDelegate` and `MPNSubscriptionDelegate` will be dispatched by the same thread.
 */
public protocol SubscriptionDelegate: AnyObject {
    /**
     Event handler that is called by Lightstreamer each time a request to clear the snapshot pertaining to an item in the `Subscription` has been
     received from the Server.
     
     More precisely, this kind of request can occur in two cases:
     
     - For an item delivered in COMMAND mode, to notify that the state of the item becomes empty; this is equivalent to receiving an update carrying a
       DELETE command once for each key that is currently active.

     - For an item delivered in DISTINCT mode, to notify that all the previous updates received for the item should be considered as obsolete; hence, if the
       delegate were showing a list of recent updates for the item, it should clear the list in order to keep a coherent view.
     
     Note that, if the involved `Subscription` has a two-level behavior enabled (see `Subscription.commandSecondLevelFields` and `Subscription.commandSecondLevelFieldSchema`), the notification refers to the first-level item (which is in COMMAND mode). This kind of notification is not possible for second-level items (which are in MERGE mode).
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter itemName: The name of the involved item. If the `Subscription` was initialized using an "Item Group" then a nil value is supplied.
     
     - Parameter itemPos: The 1-based position of the item within the "Item List" or "Item Group".
     */
    func subscription(_ subscription: Subscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt)
    /**
     Event handler that is called by Lightstreamer to notify that, due to internal resource limitations, Lightstreamer Server dropped one or more updates
     for an item that was subscribed to as a second-level subscription.
     
     Such notifications are sent only if the `Subscription` was configured in unfiltered mode (second-level items are always in `MERGE` mode and inherit
     the frequency configuration from the first-level Subscription).
     
     By implementing this method it is possible to perform recovery actions.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter lostUpdates: The number of consecutive updates dropped for the item.
     
     - Parameter key: The value of the key that identifies the second-level item.
     
     - SeeAlso: `Subscription.requestedMaxFrequency`
     
     - SeeAlso: `Subscription.commandSecondLevelFields`
     
     - SeeAlso: `Subscription.commandSecondLevelFieldSchema`
     */
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forCommandSecondLevelItemWithKey key: String)
    /**
     Event handler that is called when the Server notifies an error on a second-level subscription.
     
     The error code can be one of the following:
     
     - 14 - the key value is not a valid name for the Item to be subscribed; only in this case, the error is detected directly by the library before issuing
       the actual request to the Server
     
     - 17 - bad Data Adapter name or default Data Adapter not defined for the current Adapter Set
     
     - 21 - bad Group name
     
     - 22 - bad Group name for this Schema
     
     - 23 - bad Schema name
     
     - 24 - mode not allowed for an Item
     
     - 26 - unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item
     
     - 27 - unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item
     
     - 28 - unfiltered dispatching is not allowed by the current license terms (for special licenses only)
     
     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - `<=` 0 - the Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     
     - Parameter key: The value of the key that identifies the second-level item.
     
     - SeeAlso: `ConnectionDetails.adapterSet`

     - SeeAlso: `Subscription.commandSecondLevelFields`
     
     - SeeAlso: `Subscription.commandSecondLevelFieldSchema`
     */
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String)
    /**
     Event handler that is called by Lightstreamer to notify that all snapshot events for an item in the `Subscription` have been received, so that
     real time events are now going to be received.
     
     The received snapshot could be empty. Such notifications are sent only if the items are delivered in DISTINCT or COMMAND subscription mode and
     snapshot information was indeed requested for the items. By implementing this method it is possible to perform actions which require that all the initial
     values have been received.
     
     Note that, if the involved `Subscription` has a two-level behavior enabled (see `Subscription.commandSecondLevelFields` and `Subscription.commandSecondLevelFieldSchema`), the notification refers to the first-level item (which is in COMMAND mode). Snapshot-related updates for the second-level items (which are in MERGE mode) can be received both before and after this notification.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter itemName: The name of the involved item. If the Subscription was initialized using an "Item Group" then a nil value is supplied.
     
     - Parameter itemPos: The 1-based position of the item within the "Item List" or "Item Group".
     
     - SeeAlso: `Subscription.requestedSnapshot`
     
     - SeeAlso: `ItemUpdate.isSnapshot`
     */
    func subscription(_ subscription: Subscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt)
    /**
     Event handler that is called by Lightstreamer to notify that, due to internal resource limitations, Lightstreamer Server dropped one or more updates
     for an item in the Subscription.
     
     Such notifications are sent only if the items are delivered in an unfiltered mode; this occurs if the subscription mode is:
     
     - `RAW`
     
     - `MERGE` or `DISTINCT`, with unfiltered dispatching specified
     
     - `COMMAND`, with unfiltered dispatching specified
     
     - `COMMAND`, without unfiltered dispatching specified (in this case, notifications apply to ADD and DELETE events only)
     
     By implementing this method it is possible to perform recovery actions.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter lostUpdates: The number of consecutive updates dropped for the item.
     
     - Parameter itemName: The name of the involved item. If the Subscription was initialized using an "Item Group" then a nil value is supplied.
     
     - Parameter itemPos: The 1-based position of the item within the "Item List" or "Item Group".
     
     - SeeAlso: `Subscription.requestedMaxFrequency`
     */
    func subscription(_ subscription: Subscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt)
    /**
     Event handler that is called by Lightstreamer each time an update pertaining to an item in the `Subscription` has been received from the Server.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter itemUpdate: A value object containing the updated values for all the fields, together with meta-information about the update itself and some helper methods that can be used to iterate through all or new values.
     */
    func subscription(_ subscription: Subscription, didUpdateItem itemUpdate: ItemUpdate)
    /**
     Event handler that receives a notification when the SubscriptionDelegate instance is removed from a `Subscription` through `Subscription.removeDelegate(_:)`.
     
     This is the last event to be fired on the delegate.
     
     - Parameter subscription: The `Subscription` this instance was removed from.
     */
    func subscriptionDidRemoveDelegate(_ subscription: Subscription)
    /**
     Event handler that receives a notification when the SubscriptionDelegate instance is added to a `Subscription` through
     `Subscription.addDelegate(_:)`.
     
     This is the first event to be fired on the delegate.
     
     - Parameter subscription: The `Subscription` this instance was added to.
     */
    func subscriptionDidAddDelegate(_ subscription: Subscription)
    /**
     Event handler that is called by Lightstreamer to notify that a `Subscription` has been successfully subscribed to through the Server.
     
     This can happen multiple times in the life of a `Subscription` instance, in case the Subscription is performed multiple times through `LightstreamerClient.unsubscribe(_:)` and `LightstreamerClient.subscribe(_:)`. This can also happen multiple times in case of automatic recovery after a connection restart.
     
     This notification is always issued before the other ones related to the same subscription. It invalidates all data that has been received previously.
     
     Note that two consecutive calls to this method are not possible, as before a second `subscriptionDidSubscribe:` event is fired an `subscriptionDidUnsubscribe(_:)` event is eventually fired.
     
     If the involved `Subscription` has a two-level behavior enabled (see `Subscription.commandSecondLevelFields` and `Subscription.commandSecondLevelFieldSchema`), second-level subscriptions are not notified.
     
     - Parameter subscription: The `Subscription` involved.
     */
    func subscriptionDidSubscribe(_ subscription: Subscription)
    /**
     Event handler that is called when the Server notifies an error on a `Subscription`.
     
     By implementing this method it is possible to perform recovery actions.
     
     Note that, in order to perform a new subscription attempt, `LightstreamerClient.unsubscribe(_:)` and `LightstreamerClient.subscribe(_:)` should be issued again, even if no change to the `Subscription` attributes has been applied.
     
     The error code can be one of the following:
     
     - 15 - "key" field not specified in the schema for a COMMAND mode subscription
     
     - 16 - "command" field not specified in the schema for a COMMAND mode subscription
     
     - 17 - bad Data Adapter name or default Data Adapter not defined for the current Adapter Set
     
     - 21 - bad Group name
     
     - 22 - bad Group name for this Schema
     
     - 23 - bad Schema name
     
     - 24 - mode not allowed for an Item
     
     - 25 - bad Selector name
     
     - 26 - unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item
     
     - 27 - unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item
     
     - 28 - unfiltered dispatching is not allowed by the current license terms (for special licenses only)
     
     - 29 - RAW mode is not allowed by the current license terms (for special licenses only)
     
     - 30 - subscriptions are not allowed by the current license terms (for special licenses only)
     
     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - `<=` 0 - the Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata
       Adapter implementation
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     
     - SeeAlso: `ConnectionDetails.adapterSet`
     */
    func subscription(_ subscription: Subscription, didFailWithErrorCode code: Int, message: String?)
    /**
     Event handler that is called by Lightstreamer to notify that a `Subscription` has been successfully unsubscribed from.
     
     This can happen multiple times in the life of a `Subscription` instance, in case the `Subscription` is performed multiple times through `LightstreamerClient.unsubscribe(_:)` and `LightstreamerClient.subscribe(_:)`. This can also happen multiple times in case of automatic recovery after a connection restart.
     
     After this notification no more events can be received until a new `subscriptionDidSubscribe(_:)` event.
     
     Note that two consecutive calls to this method are not possible, as before a second `subscriptionDidUnsubscribe(_:)` event is fired an `subscriptionDidSubscribe(_:)` event is eventually fired.
     
     If the involved `Subscription` has a two-level behavior enabled (see `Subscription.commandSecondLevelFields` and `Subscription.commandSecondLevelFieldSchema`), second-level unsubscriptions are not notified.

     - Parameter subscription: The `Subscription` involved.
     */
    func subscriptionDidUnsubscribe(_ subscription: Subscription)
    /**
     Event handler that is called by Lightstreamer to notify the client with the real maximum update frequency of the Subscription.
     
     It is called immediately after the Subscription is established and in response to a requested change (see `Subscription.requestedMaxFrequency`). Since the frequency limit is applied on an item basis and a Subscription can involve multiple items,  this is actually the maximum frequency among all items. For Subscriptions with two-level behavior enabled (see `Subscription.commandSecondLevelFields` and `Subscription.commandSecondLevelFieldSchema`), the reported frequency limit applies to both first-level and second-level items.
     
     The value may differ from the requested one because of restrictions operated on the server side,  but also because of number rounding.
     
     Note that a maximum update frequency (that is, a non-unlimited one) may be applied by the Server even when the subscription mode is RAW or
     the Subscription was done with unfiltered dispatching.
     
     - Parameter subscription: The `Subscription` involved.
     
     - Parameter frequency: A decimal number, representing the maximum frequency applied by the Server (expressed in updates per second), or the value `unlimited`. A nil value is possible in rare cases, when the frequency can no longer be determined.
     */
    func subscription(_ subscription: Subscription, didReceiveRealFrequency frequency: RealMaxFrequency?)
}

/**
 Contains all the information related to an update of the field values for an item.
 
 It reports all the new values of the fields.
 
 **COMMAND Subscriptions**
 
 If the involved `Subscription` is a COMMAND subscription, then the values for the current update are meant as relative to the same key.
 
 Moreover, if the involved `Subscription` has a two-level behavior enabled, then each update may be associated with either a first-level or a
 second-level item. In this case, the reported fields are always the union of the first-level and second-level fields and each single update can
 only change either the first-level or the second-level fields (but for the `command` field, which is first-level and is always set to `UPDATE` upon
 a second-level update); note that the second-level field values are always nil until the first second-level update occurs). When the two-level behavior
 is enabled, in all methods where a field name has to be supplied, the following convention should be followed:
 
 - The field name can always be used, both for the first-level and the second-level fields. In case of name conflict, the first-level field is meant.
 
 - The field position can always be used; however, the field positions for the second-level fields start at the highest position of the first-level
   field list + 1. If a field schema had been specified for either first-level or second-level Subscriptions, then client-side knowledge of the first-level
   schema length would be required.
 */
public protocol ItemUpdate: AnyObject, CustomStringConvertible {
    /**
     Values for each field changed with the last server update. The related field name is used as key for the values in the map.
     
     Note that if the `Subscription` mode of the involved Subscription is COMMAND, then changed fields are meant as relative to the previous update
     for the same key. On such tables if a DELETE command is received, all the fields, excluding the key field, will be present as changed, with nil value.
     All of this is also true on tables that have the two-level behavior enabled, but in case of DELETE commands second-level fields will not be iterated.
     
     - Precondition: the `Subscription` must have been initialized using a field list
     
     - SeeAlso: `Subscription.fieldSchema`
     
     - SeeAlso: `Subscription.fields`
     */
    var changedFields: [String:String?] {get}
    /**
     Values for each field changed with the last server update. The 1-based field position within the field schema or field list is used as key for
     the values in the map.
     
     Note that if the `Subscription` mode of the involved Subscription is COMMAND, then changed fields are meant as relative to the previous update
     for the same key. On such tables if a DELETE command is received, all the fields, excluding the key field, will be present as changed, with nil value.
     All of this is also true on tables that have the two-level behavior enabled, but in case of DELETE commands second-level fields will not be iterated.
     
     - SeeAlso: `Subscription.fieldSchema`
     
     - SeeAlso: `Subscription.fields`
     */
    var changedFieldsByPositions: [Int:String?] {get}
    /**
     Values for each field in the `Subscription`. The related field name is used as key for the values in the map.
     
     - Precondition: the `Subscription` must have been initialized using a field list
     
     - SeeAlso: `Subscription.fieldSchema`
     
     - SeeAlso: `Subscription.fields`
     */
    var fields: [String:String?] {get}
    /**
     Values for each field in the `Subscription`. The 1-based field position within the field schema or field list is used as key for the values in the map.
     
     - SeeAlso: `Subscription.fieldSchema`
     
     - SeeAlso: `Subscription.fields`
     */
    var fieldsByPositions: [Int:String?] {get}
    /**
     The name of the item to which this update pertains.
     
     The name will be nil if the related `Subscription` was initialized using an "Item Group".
     
     - SeeAlso: `Subscription.itemGroup`
     
     - SeeAlso: `Subscription.items`
     */
    var itemName: String? {get}
    /**
     The 1-based position in the "Item List" or "Item Group" of the item to which this update pertains.
     
     - SeeAlso: `Subscription.itemGroup`
     
     - SeeAlso: `Subscription.items`
     */
    var itemPos: Int {get}
    /**
     Returns the current value for the specified field.
     
     The value of a field can be nil in the following cases:
     
     - a nil value has been received from the Server, as nil is a possible value for a field;
     
     - no value has been received for the field yet;
     
     - the item is subscribed to with the COMMAND mode and a DELETE command is received (only the fields used to carry key and command information are valued).
     
     - Parameter fieldPos: The 1-based position of the field within the "Field List" or "Field Schema".
     
     - Returns: The value of the specified field.
     
     - Precondition: the specified field is part of the `Subscription`.
     
     - SeeAlso: `Subscription.fieldSchema`

     - SeeAlso: `Subscription.fields`
     */
    func value(withFieldPos fieldPos: Int) -> String?
    /**
     Returns the current value for the specified field.
     
     The value of a field can be nil in the following cases:
     
     - a nil value has been received from the Server, as nil is a possible value for a field;
     
     - no value has been received for the field yet;
     
     - the item is subscribed to with the COMMAND mode and a DELETE command is received (only the fields used to carry key and command information are valued).
     
     - Parameter fieldName: The field name as specified within the "Field List".
     
     - Returns: The value of the specified field.
     
     - Precondition: the specified field is part of the `Subscription`.
     
     - SeeAlso: `Subscription.fields`
     */
    func value(withFieldName fieldName: String) -> String?
    /**
     Tells whether the current update belongs to the item snapshot (which carries the current item state at the time of Subscription).
     
     Snapshot events are sent only if snapshot information was requested for the items through `Subscription.requestedSnapshot` and precede the real time events.
     Snapshot information take different forms in different subscription modes and can be spanned across zero, one or several update events. In particular:
     
     - if the item is subscribed to with the RAW subscription mode, then no snapshot is sent by the Server;
     
     - if the item is subscribed to with the MERGE subscription mode, then the snapshot consists of exactly one event, carrying the current value for all fields;
     
     - if the item is subscribed to with the DISTINCT subscription mode, then the snapshot consists of some of the most recent updates; these updates are as many as specified through `Subscription.requestedSnapshot`, unless fewer are available;
     
     - if the item is subscribed to with the COMMAND subscription mode, then the snapshot consists of an `ADD` event for each key that is currently present.
     
     Note that, in case of two-level behavior, snapshot-related updates for both the first-level item (which is in COMMAND mode) and any second-level
     items (which are in MERGE mode) are qualified with this flag.
     */
    var isSnapshot: Bool {get}
    /**
     Inquiry method that asks whether the value for a field has changed after the reception of the last update from the Server for an item.
     
     If the Subscription mode is COMMAND then the change is meant as relative to the same key.
     
     Unless the Subscription mode is COMMAND, the return value is `true` in the following cases:
     
     - it is the first update for the item;
     
     - the new field value is different than the previous field value received for the item.
     
     If the Subscription mode is COMMAND, the return value is `true` in the following cases:
     
     - it is the first update for the involved key value (i.e. the event carries an `ADD` command);
     
     - the new field value is different than the previous field value received for the item, relative to the same key value (the event must carry
       an `UPDATE` command);
     
     - the event carries a `DELETE` command (this applies to all fields other than the field used to carry key information).
     
     In all other cases, the return value is `false`.
     
     - Parameter fieldPos: The 1-based position of the field within the "Field List" or "Field Schema".
     
     - Returns: `true` if the value is changed (see above).
     
     - Precondition: the specified field is part of the `Subscription`.
     
     - SeeAlso: `Subscription.fieldSchema`
     
     - SeeAlso: `Subscription.fields`
     */
    func isValueChanged(withFieldPos fieldPos: Int) -> Bool
    /**
     Inquiry method that asks whether the value for a field has changed after the reception of the last update from the Server for an item.
     
     If the Subscription mode is COMMAND then the change is meant as relative to the same key.
     
     Unless the Subscription mode is COMMAND, the return value is `true` in the following cases:
     
     - it is the first update for the item;
     
     - the new field value is different than the previous field value received for the item.
     
     If the Subscription mode is COMMAND, the return value is `true` in the following cases:
     
     - it is the first update for the involved key value (i.e. the event carries an `ADD` command);
     
     - the new field value is different than the previous field value received for the item, relative to the same key value (the event must carry
       an `UPDATE` command);
     
     - the event carries a `DELETE` command (this applies to all fields other than the field used to carry key information).
     
     In all other cases, the return value is `false`.
     
     - Parameter fieldName: The field name as specified within the "Field List".
     
     - Returns: `true` if the value is changed (see above).
     
     - Precondition: the specified field is part of the `Subscription`.
     
     - SeeAlso: `Subscription.fields`
     */
    func isValueChanged(withFieldName fieldName: String) -> Bool
    /**
     Inquiry method that gets the difference between the new value and the previous one
     as a JSON Patch structure, provided that the Server has used the JSON Patch format
     to send this difference, as part of the "delta delivery" mechanism.
     This, in turn, requires that:<ul>
     <li>the Data Adapter has explicitly indicated JSON Patch as the privileged type of
     compression for this field;</li>
     <li>both the previous and new value are suitable for the JSON Patch computation
     (i.e. they are valid JSON representations);</li>
     <li>sending the JSON Patch difference has been evaluated by the Server as more
     efficient than sending the full new value.</li>
     </ul>
     Note that the last condition can be enforced by leveraging the Server's
     `<jsonpatch_min_length>` configuration flag, so that the availability of the
     JSON Patch form would only depend on the Client and the Data Adapter.
     <BR>When the above conditions are not met, the method just returns nil; in this
     case, the new value can only be determined through `value(...)`. For instance,
     this will always be needed to get the first value received.
    
     - Parameter fieldName: The field name as specified within the "Field List".
       
     - Returns: A JSON Patch structure representing the difference between
     the new value and the previous one, or nil if the difference in JSON Patch format
     is not available for any reason.
     
     - Precondition: the specified field is part of the `Subscription`.
       
     - SeeAlso: `value(...)`
     */
    func valueAsJSONPatchIfAvailable(withFieldName fieldName: String) -> String?
    /**
     Inquiry method that gets the difference between the new value and the previous one
     as a JSON Patch structure, provided that the Server has used the JSON Patch format
     to send this difference, as part of the "delta delivery" mechanism.
     This, in turn, requires that:<ul>
     <li>the Data Adapter has explicitly indicated JSON Patch as the privileged type of
     compression for this field;</li>
     <li>both the previous and new value are suitable for the JSON Patch computation
     (i.e. they are valid JSON representations);</li>
     <li>sending the JSON Patch difference has been evaluated by the Server as more
     efficient than sending the full new value.</li>
     </ul>
     Note that the last condition can be enforced by leveraging the Server's
     `<jsonpatch_min_length>` configuration flag, so that the availability of the
     JSON Patch form would only depend on the Client and the Data Adapter.
     <BR>When the above conditions are not met, the method just returns nil; in this
     case, the new value can only be determined through `value(...)`. For instance,
     this will always be needed to get the first value received.
    
     - Parameter fieldPos: The 1-based position of the field within the "Field List" or "Field Schema".
       
     - Returns: A JSON Patch structure representing the difference between
     the new value and the previous one, or nil if the difference in JSON Patch format
     is not available for any reason.
     
     - Precondition: the specified field is part of the `Subscription`.
       
     - SeeAlso: `value(...)`
     */
    func valueAsJSONPatchIfAvailable(withFieldPos fieldPos: Int) -> String?
}

/**
 Class representing a real-time subscription to be submitted to a Lightstreamer Server.

 It contains subscription details and the delegates needed to process the real-time data.

 After the creation, an Subscription object is in the "inactive" state. When an Subscription object is subscribed to on a `LightstreamerClient` object,
 through the `LightstreamerClient.subscribe(_:)` method, its state becomes "active". This means that the client activates a subscription to the required items through Lightstreamer Server and the Subscription object begins to receive real-time events.

 An Subscription can be configured to use either an Item Group or an Item List to specify the items to be subscribed to and using either a Field Schema or Field List to specify the fields.

 "Item Group" and "Item List" are defined as follows:

 - "Item Group": an Item Group is a String identifier representing a list of items. Such Item Group has to be expanded into a list of items by the
   `getItems` method of the MetadataProvider of the associated Adapter Set. When using an Item Group, items in the subscription are identified by their
   1-based index within the group. It is possible to configure the Subscription to use an "Item Group" using the `itemGroup` property.

 - "Item List": an Item List is an array of Strings each one representing an item. For the Item List to be correctly interpreted a LiteralBasedProvider or
   a MetadataProvider with a compatible implementation of getItems has to be configured in the associated Adapter Set. Note that no item in the list can be empty, can contain spaces or can be a number. When using an Item List, items in the subscription are identified by their name or by their 1-based index within the list. It is possible to configure the subscription to use an "Item List" using the `items` property or by specifying it in the constructor.

 "Field Schema" and "Field List" are defined as follows:

 - "Field Schema": a Field Schema is a String identifier representing a list of fields. Such Field Schema has to be expanded into a list of fields by
   the `getFields` method of the MetadataProvider of the associated Adapter Set. When using a Field Schema, fields in the subscription are identified by
   their 1-based index within the schema. It is possible to configure the Subscription to use a "Field Schema" using the `fieldSchema` property.

 - "Field List": a Field List is an array of Strings each one representing a field. For the Field List to be correctly interpreted a LiteralBasedProvider or
   a MetadataProvider with a compatible implementation of getFields has to be configured in the associated Adapter Set. Note that no field in the list can be empty, or can contain spaces. When using a Field List, fields in the subscription are identified by their name or by their 1-based index within the list.
   It is possible to configure the Subscription to use a "Field List" using the `fields` property or by specifying it in the constructor.
 */
public class Subscription: CustomStringConvertible {
    
    /**
     The mode of a Subscription.
     
     - SeeAlso: `mode`
     */
    public enum Mode: String, CustomStringConvertible {
        /// Merge mode
        case MERGE = "MERGE"
        /// Distinct mode
        case DISTINCT = "DISTINCT"
        /// Command mode
        case COMMAND = "COMMAND"
        /// Raw mode
        case RAW = "RAW"
        
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
            case .limited(let len):
                return "\(len)"
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
        /// Unfiltered frequency
        case unfiltered
        
        public var description: String {
            switch self {
            case .unlimited:
                return "unlimited"
            case .limited(let freq):
                return "\(freq) updates/sec"
            case .unfiltered:
                return "unfiltered"
            }
        }
    }
    
    /**
     Snapshot delivery request for the items in a Subscription.
     
     - SeeAlso: `requestedSnapshot`
     */
    public enum RequestedSnapshot: Equatable, CustomStringConvertible {
        /// Full snapshot
        case yes
        /// No snapshot
        case no
        /// Limited snapshot
        case length(Int)
        
        public var description: String {
            switch self {
            case .yes:
                return "yes"
            case .no:
                return "no"
            case .length(let len):
                return "\(len)"
            }
        }
    }
    
    enum State {
        case Inactive, Active, Subscribed
    }
    
    /* error messages */
    static let EMPTY_ITEM_LIST = "Item List is empty"
    static let EMPTY_FIELD_LIST = "Field List is empty"
    static let INVALID_ITEM_LIST = "Item List is invalid"
    static let INVALID_FIELD_LIST = "Field List is invalid"
    static let MISSING_FIELD_KEY = "Field 'key' is missing"
    static let MISSING_FIELD_COMMAND = "Field 'command' is missing"
    static let IS_ACTIVE = "Cannot modify an active Subscription. Please unsubscribe before applying any change"
    static let IS_EMPTY = "The value is empty"
    static let NOT_COMMAND = "The operation is only available on COMMAND Subscriptions"
    static let NOT_MERGE_DISTINCT_COMMAND = "The operation in only available on MERGE, DISTINCT and COMMAND Subscripitons"
    static let ILLEGAL_FREQ = "Cannot change the frequency from/to 'unfiltered' or to null while the Subscription is active"
    static let ILLEGAL_SNAPSHOT_RAW = "Snapshot is not permitted if RAW was specified as mode"
    static let ILLEGAL_SNAPSHOT_OTHERS = "Snapshot length is not permitted if MERGE or COMMAND was specified as mode"
    /* config parameters */
    let m_mode: Mode
    var m_items: [String]?
    var m_fields: [String]?
    var m_group: String?
    var m_schema: String?
    let multicastDelegate = MulticastDelegate<SubscriptionDelegate>()
    let callbackQueue = defaultQueue
    var m_dataAdapter: String?
    var m_bufferSize: RequestedBufferSize?
    var m_snapshot: RequestedSnapshot?
    var m_requestedMaxFrequency: RequestedMaxFrequency?
    var m_selector: String?
    var m_dataAdapter2: String?
    var m_fields2: [String]?
    var m_schema2: String?
    /* other variables */
    let lock = NSRecursiveLock()
    var m_state: State = .Inactive
    var m_subId: Int?
    var m_cmdIdx: Int?
    var m_keyIdx: Int?
    var m_nItems: Int?
    var m_nFields: Int?
    var m_internal: Bool = false // special flag used to mark 2-level subscriptions
    weak var m_manager: SubscriptionManagerLiving?
    
    var nItems: Int! {
        synchronized {
            m_nItems
        }
    }
    
    var nFields: Int! {
        synchronized {
            m_nFields
        }
    }
    
    var subManager: SubscriptionManagerLiving? {
        get {
            synchronized {
                m_manager
            }
        }
        
        set {
            synchronized {
                m_manager = newValue
            }
        }
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
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    /**
     Creates an object to be used to describe a real-time subscription that is going to be subscribed to through Lightstreamer Server.

     The object can be supplied to `LightstreamerClient.subscribe(_:)` and `LightstreamerClient.unsubscribe(_:)`, in order to bring the Subscription to "active" or back to "inactive" state.

     Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state;
     the only exception is `requestedMaxFrequency`.

     Permitted values for subscription mode are:

     - `MERGE`

     - `DISTINCT`

     - `RAW`

     - `COMMAND`

     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.
     */
    public init(subscriptionMode: Mode) {
        m_mode = subscriptionMode
        m_snapshot = subscriptionMode == .RAW ? nil : .yes
    }
    
    /**
     Creates an object to be used to describe a real-time subscription that is going to be subscribed to through Lightstreamer Server.

     The object can be supplied to `LightstreamerClient.subscribe(_:)` and `LightstreamerClient.unsubscribe(_:)`, in order to bring the Subscription to "active" or back to "inactive" state.

     Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state;
     the only exception is `requestedMaxFrequency`.

     Permitted values for subscription mode are:

     - `MERGE`

     - `DISTINCT`

     - `RAW`

     - `COMMAND`

     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.

     - Parameter item: The item name to be subscribed to through Lightstreamer Server.

     - Parameter fields: An array of fields for the items to be subscribed to through Lightstreamer Server. It is also possible to specify the "Field List" or
     "Field Schema" later through `fields` and `fieldSchema`.

     - Precondition: the specified "Field List" must be valid; see `fields` for details.
     */
    public convenience init(subscriptionMode: Mode, item: String, fields: [String]) {
        self.init(subscriptionMode: subscriptionMode, items: [item], fields: fields)
    }
    
    /**
     Creates an object to be used to describe a real-time subscription that is going to be subscribed to through Lightstreamer Server.

     The object can be supplied to `LightstreamerClient.subscribe(_:)` and `LightstreamerClient.unsubscribe(_:)`, in order to bring the Subscription to "active" or back to "inactive" state.

     Note that all of the methods used to describe the subscription to the server can only be called while the instance is in the "inactive" state;
     the only exception is `requestedMaxFrequency`.

     Permitted values for subscription mode are:

     - `MERGE`

     - `DISTINCT`

     - `RAW`

     - `COMMAND`

     - Parameter subscriptionMode: The subscription mode for the items, required by Lightstreamer Server.

     - Parameter items: An array of items to be subscribed to through Lightstreamer server. It is also possible specify the "Item List" or "Item Group" later through `items` and `itemGroup`.

     - Parameter fields: An array of fields for the items to be subscribed to through Lightstreamer Server. It is also possible to specify the "Field List" or "Field Schema" later through `fields` and `fieldSchema`.

     - Precondition: the specified "Item List" and "Field List" must be valid; see `items` and `fields` for details.
     */
    public convenience init(subscriptionMode: Mode, items: [String], fields: [String]) {
        precondition(!items.isEmpty, Self.EMPTY_ITEM_LIST)
        precondition(!fields.isEmpty, Self.EMPTY_FIELD_LIST)
        precondition(items.allSatisfy({ isValidItem($0) }), Self.INVALID_ITEM_LIST)
        precondition(fields.allSatisfy({ isValidField($0) }), Self.INVALID_FIELD_LIST)
        precondition(subscriptionMode == .COMMAND ? fields.contains("command") : true, Self.MISSING_FIELD_COMMAND)
        precondition(subscriptionMode == .COMMAND ? fields.contains("key") : true, Self.MISSING_FIELD_KEY)
        self.init(subscriptionMode: subscriptionMode)
        m_items = items
        m_fields = fields
    }
    
    /**
     Adds a delegate that will receive events from the Subscription instance.

     The same delegate can be added to several different Subscription instances.

     **Lifecycle:** a delegate can be added at any time. A call to add a delegate already present will be ignored.

     - Parameter delegate: An object that will receive the events as documented in the `SubscriptionDelegate` interface.

     - SeeAlso: `removeDelegate(_:)`
     */
    public func addDelegate(_ delegate: SubscriptionDelegate) {
        synchronized {
            guard !multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.addDelegate(delegate)
            callbackQueue.async {
                delegate.subscriptionDidAddDelegate(self)
            }
        }
    }
    
    /**
     Removes a delegate from the Subscription instance so that it will not receive events anymore.

     **Lifecycle:** a delegate can be removed at any time.

     - Parameter delegate: The delegate to be removed.

     - SeeAlso: `addDelegate(_:)`
     */
    public func removeDelegate(_ delegate: SubscriptionDelegate) {
        synchronized {
            guard multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.removeDelegate(delegate)
            callbackQueue.async {
                delegate.subscriptionDidRemoveDelegate(self)
            }
        }
    }
    
    /**
     List containing the `SubscriptionDelegate` instances that were added to this Subscription.

     - SeeAlso: `addDelegate(_:)`
     */
    public var delegates: [SubscriptionDelegate] {
        synchronized {
            multicastDelegate.getDelegates()
        }
    }
    
    /**
     Position of the "command" field in a COMMAND Subscription.

     This property can only be used if the Subscription `mode` is COMMAND and the Subscription was initialized using a "Field Schema".

     **Lifecycle:** this property can be read at any time after the first `SubscriptionDelegate.subscriptionDidSubscribe(_:)` event.
     */
    public var commandPosition: Int? {
        synchronized {
            m_cmdIdx
        }
    }
    
    /**
     Position of the "key" field in a COMMAND Subscription.

     This property can only be accessed if the Subscription `mode` is COMMAND and the Subscription was initialized using a "Field Schema".

     **Lifecycle:** this property can be read at any time.
     */
    public var keyPosition: Int? {
        synchronized {
            m_keyIdx
        }
    }
    
    /**
     Name of the second-level Data Adapter (within the Adapter Set used by the current session) that supplies all the second-level items.

     All the possible second-level items should be supplied in `MERGE` mode with snapshot available.

     The Data Adapter name is configured on the server side through the "name" attribute of the &lt;data_provider&gt; element, in the `adapters.xml`
     file that defines the Adapter Set (a missing attribute configures the `DEFAULT` name).

     **Default:** the default Data Adapter for the Adapter Set, configured as `DEFAULT` on the Server.

     **Lifecycle:** this property can only be change while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".
     
     - Precondition: the Subscription `mode` must be `COMMAND`.

     - SeeAlso: `commandSecondLevelFields`

     - SeeAlso: `commandSecondLevelFieldSchema`
     */
    public var commandSecondLevelDataAdapter: String? {
        get {
            synchronized {
                m_dataAdapter2
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(m_mode == .COMMAND, Self.NOT_COMMAND)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_dataAdapter2 = newValue
            }
            
        }
    }
    
    /**
     The "Field List" to be subscribed to through Lightstreamer Server for the second-level items. It can only be used on COMMAND Subscriptions.

     Any change to this property will override any "Field List" or "Field Schema" previously specified for the second-level.

     Setting this property enables the two-level behavior: in synthesis, each time a new key is received on the COMMAND Subscription, the key value is
     treated as an Item name and an underlying Subscription for this Item is created and subscribed to automatically, to feed fields specified by this property.
     This mono-item Subscription is specified through an "Item List" containing only the Item name received. As a consequence, all the conditions provided
     for subscriptions through Item Lists have to be satisfied. The item is subscribed to in `MERGE` mode, with snapshot request and with the same maximum
     frequency setting as for the first-level items (including the `unfiltered` case). All other Subscription properties are left as the default. When the
     key is deleted by a DELETE command on the first-level Subscription, the associated second-level Subscription is also unsubscribed from.

     Specifying nil as parameter will disable the two-level behavior.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the field names in the "Field List" must not contain a space or be empty/nil.

     - Precondition: the Subscription must be currently "inactive".

     - Precondition: the Subscription `mode` must be `COMMAND`.

     - SeeAlso: `commandSecondLevelFieldSchema`
     */
    public var commandSecondLevelFields: [String]? {
        get {
            synchronized {
                m_fields2
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(m_mode == .COMMAND, Self.NOT_COMMAND)
                precondition(notEmpty(newValue), Self.EMPTY_FIELD_LIST)
                precondition(allValidFields(newValue), Self.INVALID_FIELD_LIST)
                m_fields2 = newValue
                m_schema2 = nil
            }
        }
    }
    
    /**
     The "Field Schema" to be subscribed to through Lightstreamer Server for the second-level items. It can only be used on COMMAND Subscriptions.

     Any change to this property will override any "Field List" or "Field Schema" previously specified for the second-level.

     Setting this property enables the two-level behavior: in synthesis, each time a new key is received on the COMMAND Subscription, the key value is
     treated as an Item name and an underlying Subscription for this Item is created and subscribed to automatically, to feed fields specified by this property.
     This mono-item Subscription is specified through an "Item List" containing only the Item name received. As a consequence, all the conditions provided
     for subscriptions through Item Lists have to be satisfied. The item is subscribed to in `MERGE` mode, with snapshot request and with the same maximum
     frequency setting as for the first-level items (including the `unfiltered` case). All other Subscription properties are left as the default. When the
     key is deleted by a DELETE command on the first-level Subscription, the associated second-level Subscription is also unsubscribed from.

     Specifying nil as parameter will disable the two-level behavior.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".

     - Precondition: the Subscription `mode` must be `COMMAND`.

     - SeeAlso: `commandSecondLevelFields`
     */
    public var commandSecondLevelFieldSchema: String? {
        get {
            synchronized {
                m_schema2
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(m_mode == .COMMAND, Self.NOT_COMMAND)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_schema2 = newValue
                m_fields2 = nil
            }
            
        }
    }
    
    /**
     Name of the Data Adapter (within the Adapter Set used by the current session) that supplies all the items for this Subscription.

     The Data Adapter name is configured on the server side through the "name" attribute of the &lt;data_provider&gt; element, in the `adapters.xml` file
     that defines the Adapter Set (a missing attribute configures the `DEFAULT` name).

     Note that if more than one Data Adapter is needed to supply all the items in a set of items, then it is not possible to group all the items of
     the set in a single Subscription. Multiple Subscriptions have to be defined.

     **Default:** the default Data Adapter for the Adapter Set, configured as `DEFAULT` on the Server.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".

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

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the field names in the list must not contain a space or be empty/nil.

     - Precondition: the Subscription must be currently "inactive".
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
                precondition(m_mode == .COMMAND && newValue != nil ? newValue!.contains("command") : true, Self.MISSING_FIELD_COMMAND)
                precondition(m_mode == .COMMAND && newValue != nil ? newValue!.contains("key") : true, Self.MISSING_FIELD_KEY)
                m_fields = newValue
                m_schema = nil
            }
        }
    }
    
    /**
     The "Field Schema" to be subscribed to through Lightstreamer Server.

     Any change to this property will override any "Field List" or "Field Schema" previously specified.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".
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

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".
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

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the item names in the "Item List" must not contain a space or be a number or be empty/nil.

     - Precondition: the Subscription must be currently "inactive".
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
     The mode specified for this Subscription.

     **Lifecycle:** this property can be read at any time.
     */
    public var mode: Mode {
        synchronized {
            m_mode
        }
    }
    
    /**
     Length to be requested to Lightstreamer Server for the internal queuing buffers for the items in the Subscription.

     A Queuing buffer is used by the Server to accumulate a burst of updates for an item, so that they can all be sent to the client, despite of bandwidth
     or frequency limits. It can be used only when the Subscription `mode` is MERGE or DISTINCT and unfiltered dispatching has not been requested. If the value `unlimited` is supplied, then the buffer length is decided by the Server.

     Note that the Server may pose an upper limit on the size of its internal buffers.

     **Format:** an integer number (e.g. `10`), or `unlimited`, or nil.

     **Default:** nil, meaning to lean on the Server default based on the Subscription `mode`. This means that the buffer size will be 1 for MERGE subscriptions and `unlimited` for DISTINCT subscriptions.  See the "General Concepts" document for further details.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".

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
     Maximum update frequency to be requested to Lightstreamer Server for all the items in the Subscription.

     The maximum update frequency is expressed in updates per second and applies for each item in the Subscription; for instance, with a setting of 0.5,
     for each single item, no more than one update every 2 seconds will be received. If the value `unlimited` is supplied, then no frequency
     limit is requested. It is also possible to supply the value `unfiltered`, to ask for unfiltered dispatching, if it is allowed for the items, or a nil value
     stick to the Server default (which currently corresponds to `unlimited`).

     It can be used only if the Subscription `mode` is MERGE, DISTINCT or COMMAND (in the latter case, the frequency limitation applies to the UPDATE events for each single key). For Subscriptions with two-level behavior (see `commandSecondLevelFields` and `commandSecondLevelFieldSchema`), the specified frequency limit applies to both first-level and second-level items.

     Note that frequency limits on the items can also be set on the server side and this request can only be issued in order to furtherly reduce the
     frequency, not to rise it beyond these limits.

     This property can also be set to request unfiltered dispatching for the items in the Subscription. However, unfiltered dispatching requests may
     be refused if any frequency limit is posed on the server side for some item.

     **Edition note:** a further global frequency limit could also be imposed by the Server, depending on Edition and License Type; this specific limit also applies to RAW mode and to unfiltered dispatching. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Format:** a decimal number (e.g. `2.0`), or `unlimited`, or `unfiltered`, or nil.

     **Default:** nil, meaning to lean on the Server default based on the Subscription <mode>. This consists, for all modes, in not applying any frequency
     limit to the subscription (the same as `unlimited`); see the "General Concepts" document for further details.

     **Lifecycle:** this property can be changed at any time with some differences based on the Subscription status:

     - If the Subscription instance is in its "inactive" state then the value can be changed at will.

     - If the Subscription instance is in its "active" state then the value can still be changed unless the current value is `unfiltered` or the
       supplied value is `unfiltered` or nil. If the Subscription instance is in its "active" state and the connection to the server is currently open,
       then a request to change the frequency of the Subscription on the fly is sent to the server.

     - Precondition: an error is raised if the Subscription is currently "active" and the current value of this property is nil or `unfiltered`.

     - Precondition: an error is raised if the Subscription is currently "active" and the given parameter is nil or `unfiltered`.

     - Precondition: an error is raised if the specified value is not nil nor one of the special `unlimited` and `unfiltered` values nor a valid positive number.
     */
    public var requestedMaxFrequency: RequestedMaxFrequency? {
        get {
            synchronized {
                m_requestedMaxFrequency
            }
        }
        
        set {
            var manager: SubscriptionManagerLiving?
            synchronized {
                precondition(m_mode == .MERGE || m_mode == .DISTINCT || m_mode == .COMMAND, Self.NOT_MERGE_DISTINCT_COMMAND)
                precondition(isActive ? newValue != nil && newValue != .unfiltered && m_requestedMaxFrequency != .unfiltered : true, Self.ILLEGAL_FREQ)
                if subscriptionLogger.isInfoEnabled {
                    if let subId = m_subId {
                        let freq = newValue == nil ? "nil" : String(describing: newValue!)
                        subscriptionLogger.info("Subscription \(subId) requested max frequency changed: \(freq)")
                    }
                }
                m_requestedMaxFrequency = newValue
                manager = m_manager
            }
            if let manager = manager {
                manager.evtExtConfigure()
            }
        }
    }
    
    /**
     Enables/disables snapshot delivery request for the items in the Subscription.

     The snapshot delivery is expressed as `yes`/`no` to request/not request snapshot delivery (the check is case insensitive). If the Subscription `mode` is DISTINCT, instead of `yes`, it is also possible to supply an integer number, to specify the requested length of the snapshot (though the length of the received snapshot may be less than requested, because of insufficient data or server side limits); passing `yes`  means that the snapshot length should be determined only by the Server. Nil is also a valid value; if specified, no snapshot preference will be sent to the server that will decide itself whether or not to send any snapshot.

     The snapshot can be requested only if the Subscription `mode` is MERGE, DISTINCT or COMMAND:

     - In case of a RAW Subscription only nil is a valid value;

     - In case of a non-DISTINCT Subscription only nil, `yes` and `no` are valid values.

     **Format:** `yes`, `no`, an integer number (e.g. `10`), or nil.

     **Default:** `yes` if the Subscription `mode` is not `RAW`, nil otherwise.

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".

     - Precondition: an error is raised if the specified value is not compatible with the `mode` of the Subscription.

     - SeeAlso: `ItemUpdate.isSnapshot`
     */
    public var requestedSnapshot: RequestedSnapshot? {
        get {
            synchronized {
                m_snapshot
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(m_mode == .RAW ? newValue == nil : true, Self.ILLEGAL_SNAPSHOT_RAW)
                precondition(m_mode == .MERGE || m_mode == .COMMAND ? newValue == nil || newValue == .yes || newValue == .no : true, Self.ILLEGAL_SNAPSHOT_OTHERS)
                m_snapshot = newValue
            }
        }
    }
    
    /**
     The selector name for all the items in the Subscription.

     The selector is a filter on the updates received. It is executed on the Server and implemented by the Metadata Adapter.

     **Default:** nil (no selector).

     **Lifecycle:** this property can only be set while the Subscription instance is in its "inactive" state.

     - Precondition: the Subscription must be currently "inactive".
     */
    public var selector: String? {
        get {
            synchronized {
                m_selector
            }
        }
        
        set {
            synchronized {
                precondition(!isActive, Self.IS_ACTIVE)
                precondition(notEmpty(newValue), Self.IS_EMPTY)
                m_selector = newValue
            }
        }
    }
    
    /**
     Checks if the Subscription is currently "active" or not.

     Most of the Subscription properties cannot be modified if a Subscription is "active".

     The status of an Subscription is changed to "active" through the `LightstreamerClient.subscribe(_:)` method and back to "inactive" through the `LightstreamerClient.unsubscribe(_:)` one.

     **Lifecycle:** this property can be read at any time.

     - SeeAlso: `LightstreamerClient.subscribe(_:)`

     - SeeAlso: `LightstreamerClient.unsubscribe(_:)`
     */
    public var isActive: Bool {
        synchronized {
            m_state != .Inactive
        }
    }
    
    /**
     Checks if the Subscription is currently subscribed to through the server or not.

     This flag is switched to `true` by server sent subscription events, and back to `false` in case of client disconnection, `LightstreamerClient.unsubscribe(_:)` calls and server sent unsubscription events.

     **Lifecycle:** this property can be read at any time.
     */
    public var isSubscribed: Bool {
        synchronized {
            m_state == .Subscribed
        }
    }
    
    /**
     Returns the latest value received for the specified item/field pair.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     In case of COMMAND Subscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same item, will overwrite each other; for COMMAND Subscriptions, use `commandValueWithItemPos(_:key:fieldPos:)` instead.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     **Lifecycle:** this method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.

     - Parameter itemPos: The 1-based position of an item within the configured "Item Group" or "Item List"

     - Parameter fieldPos: The 1-based position of a field within the configured "Field Schema" or "Field List"

     - Returns: The current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
     */
    public func valueWithItemPos(_ itemPos: Int, fieldPos: Int) -> String? {
        var manager: SubscriptionManagerLiving?
        synchronized {
            precondition(itemPos >= 1)
            precondition(fieldPos >= 1)
            manager = m_manager
        }
        if let manager = manager {
            return manager.getValue(itemPos, fieldPos)
        } else {
            return nil
        }
    }
    
    /**
     Returns the latest value received for the specified item/field pair.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     In case of COMMAND Subscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same item, will overwrite each other; for COMMAND Subscriptions, use `commandValueWithItemPos(_:key:fieldName:)` instead.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     **Lifecycle:** this method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.

     - Parameter itemPos: The 1-based position of an item within the configured "Item Group" or "Item List"

     - Parameter fieldName: An item in the configured "Field List"

     - Returns: The current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
     */
    public func valueWithItemPos(_ itemPos: Int, fieldName: String) -> String? {
        synchronized {
            guard let fields = m_fields, let fieldPos = fields.firstIndex(of: fieldName) else {
                preconditionFailure("Unknown field name")
            }
            return valueWithItemPos(itemPos, fieldPos: fieldPos + 1)
        }
    }
    
    /**
     Returns the latest value received for the specified item/field pair.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     In case of COMMAND Subscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same item, will overwrite each other; for COMMAND Subscriptions, use `commandValueWithItemName(_:key:fieldPos:)` instead.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     **Lifecycle:** this method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.

     - Parameter itemName: An item in the configured "Item List"

     - Parameter fieldPos: The 1-based position of a field within the configured "Field Schema" or "Field List"

     - Returns: The current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
     */
    public func valueWithItemName(_ itemName: String, fieldPos: Int) -> String? {
        synchronized {
            guard let items = m_items, let itemPos = items.firstIndex(of: itemName) else {
                preconditionFailure("Unknown item name")
            }
            return valueWithItemPos(itemPos + 1, fieldPos: fieldPos)
        }
    }
   
    /**
     Returns the latest value received for the specified item/field pair.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     In case of COMMAND Subscriptions, the value returned by this method may be misleading, as in COMMAND mode all the keys received, being part of the same item, will overwrite each other; for COMMAND Subscriptions, use `commandValueWithItemName(_:key:fieldName:)` instead.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     **Lifecycle:** this method can be called at any time; if called to retrieve a value that has not been received yet, then it will return nil.

     - Parameter itemName: An item in the configured "Item List"

     - Parameter fieldName: An item in the configured "Field List"

     - Returns: The current value for the specified field of the specified item (possibly nil), or nil if no value has been received yet.
     */
    public func valueWithItemName(_ itemName: String, fieldName: String) -> String? {
        synchronized {
            guard let items = m_items, let itemPos = items.firstIndex(of: itemName) else {
                preconditionFailure("Unknown item name")
            }
            guard let fields = m_fields, let fieldPos = fields.firstIndex(of: fieldName) else {
                preconditionFailure("Unknown field name")
            }
            return valueWithItemPos(itemPos + 1, fieldPos: fieldPos + 1)
        }
    }
    
    /**
     Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription `mode` is COMMAND.
     Subscriptions with two-level behavior (see `commandSecondLevelFields` and `commandSecondLevelFieldSchema`) are also supported, hence the specified field can be either a first-level or a second-level one.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     - Parameter itemPos: The 1-based position of an item within the configured "Item Group" or "Item List"

     - Parameter key: The value of a key received on the COMMAND Subscription.

     - Parameter fieldPos: The 1-based position of a field within the configured "Field Schema" or "Field List"

     - Precondition: the Subscription `mode` must be COMMAND.

     - Returns: The current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
     been added yet (note that it might have been added and then deleted).
     */
    public func commandValueWithItemPos(_ itemPos: Int, key: String, fieldPos: Int) -> String? {
        var manager: SubscriptionManagerLiving?
        synchronized {
            precondition(m_mode == .COMMAND)
            precondition(itemPos >= 1)
            precondition(fieldPos >= 1)
            manager = m_manager
        }
        if let manager = manager {
            return manager.getCommandValue(itemPos, key, fieldPos)
        } else {
            return nil
        }
    }
    
    /**
     Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription `mode` is COMMAND.
     Subscriptions with two-level behavior (see `commandSecondLevelFields` and `commandSecondLevelFieldSchema`) are also supported, hence the specified field can be either a first-level or a second-level one.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     - Parameter itemPos: The 1-based position of an item within the configured "Item Group" or "Item List"

     - Parameter key: The value of a key received on the COMMAND Subscription.

     - Parameter fieldName: A item in the configured "Field List"

     - Precondition: the Subscription `mode` must be COMMAND.

     - Returns: The current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
     been added yet (note that it might have been added and then deleted).
     */
    public func commandValueWithItemPos(_ itemPos: Int, key: String, fieldName: String) -> String? {
        synchronized {
            precondition(m_mode == .COMMAND)
            guard let fields = m_fields, let fieldPos = fields.firstIndex(of: fieldName) else {
                preconditionFailure("Unknown field name")
            }
            return commandValueWithItemPos(itemPos, key: key, fieldPos: fieldPos + 1)
        }
    }
    
    /**
     Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription `mode` is COMMAND.
     Subscriptions with two-level behavior (see `commandSecondLevelFields` and `commandSecondLevelFieldSchema`) are also supported, hence the specified field can be either a first-level or a second-level one.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     - Parameter itemName: An item in the configured "Item List"

     - Parameter key: The value of a key received on the COMMAND Subscription.

     - Parameter fieldPos: The 1-based position of a field within the configured "Field Schema" or "Field List"

     - Precondition: the Subscription `mode` must be COMMAND.

     - Returns: The current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
     been added yet (note that it might have been added and then deleted).
     */
    public func commandValueWithItemName(_ itemName: String, key: String, fieldPos: Int) -> String? {
        synchronized {
            precondition(m_mode == .COMMAND)
            guard let items = m_items, let itemPos = items.firstIndex(of: itemName) else {
                preconditionFailure("Unknown item name")
            }
            return commandValueWithItemPos(itemPos + 1, key: key, fieldPos: fieldPos)
        }
    }
    
    /**
     Returns the latest value received for the specified item/key/field combination. This method can only be used if the Subscription `mode` is COMMAND.
     Subscriptions with two-level behavior (see `commandSecondLevelFields` and `commandSecondLevelFieldSchema`) are also supported, hence the specified field can be either a first-level or a second-level one.

     It is suggested to consume real-time data by implementing and adding a proper `SubscriptionDelegate` rather than probing this method.

     Note that internal data is cleared when the Subscription is unsubscribed from.

     - Parameter itemName: An item in the configured "Item List"

     - Parameter key: The value of a key received on the COMMAND Subscription.

     - Parameter fieldName: An item in the configured "Field List"
     
     - Precondition: the Subscription `mode` must be COMMAND.

     - Returns: The current value for the specified field of the specified key within the specified item (possibly nil), or nil if the specified key has not
     been added yet (note that it might have been added and then deleted).
     */
    public func commandValueWithItemName(_ itemName: String, key: String, fieldName: String) -> String? {
        synchronized {
            precondition(m_mode == .COMMAND)
            guard let items = m_items, let itemPos = items.firstIndex(of: itemName) else {
                preconditionFailure("Unknown item name")
            }
            guard let fields = m_fields, let fieldPos = fields.firstIndex(of: fieldName) else {
                preconditionFailure("Unknown field name")
            }
            return commandValueWithItemPos(itemPos + 1, key: key, fieldPos: fieldPos + 1)
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
            map["requestedSnapshot"] = m_snapshot
            map["requestedMaxFrequency"] = m_requestedMaxFrequency
            map["selector"] = m_selector
            map["secondLevelFields"] = m_fields2 ?? m_schema2
            map["secondLevelDataAdapter"] = m_dataAdapter2
            return String(describing: map)
        }
    }
    
    func setActive() {
        synchronized {
            m_state = .Active
        }
    }
    
    func setInactive() {
        synchronized {
            m_state = .Inactive
            m_subId = nil
            m_cmdIdx = nil
            m_keyIdx = nil
            m_nItems = nil
            m_nFields = nil
        }
    }
    
    func setSubscribed(subId: Int, nItems: Int, nFields: Int) {
        synchronized {
            m_state = .Subscribed
            m_subId = subId
            m_nItems = nItems
            m_nFields = nFields
        }
    }
    
    func setSubscribed(subId: Int, nItems: Int, nFields: Int, cmdIdx: Int, keyIdx: Int) {
        synchronized {
            m_state = .Subscribed
            m_subId = subId
            m_cmdIdx = cmdIdx
            m_keyIdx = keyIdx
            m_nItems = nItems
            m_nFields = nFields
        }
    }
    
    func isInternal() -> Bool {
        synchronized {
            m_internal
        }
    }
    
    func setInternal() {
        synchronized {
            m_internal = true
        }
    }
    
    func getItemName(_ itemIdx: Int) -> String? {
        synchronized {
            if let items = m_items {
                return items[itemIdx - 1]
            }
            return nil
        }
    }
    
    func relate(to manager: SubscriptionManagerLiving) {
        synchronized {
            m_manager = manager
        }
    }
    
    func unrelate(from manager: SubscriptionManagerLiving) {
        synchronized {
            guard manager === m_manager else {
                return
            }
            m_manager = nil
        }
    }
    
    func hasSnapshot() -> Bool {
        synchronized {
            !(m_snapshot == nil || m_snapshot == .no)
        }
    }
    
    func getItemNameOrPos(_ itemIdx: Pos) -> String {
        return items?[itemIdx - 1] ?? "\(itemIdx)"
    }
    
    func fireOnSubscription(subId: Int) {
        synchronized {
            if subscriptionLogger.isInfoEnabled {
                subscriptionLogger.info("Subscription \(subId) added")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscriptionDidSubscribe(self)
                }
            }
        }
    }
    
    func fireOnUnsubscription(subId: Int) {
        synchronized {
            if subscriptionLogger.isInfoEnabled {
                subscriptionLogger.info("Subscription \(subId) deleted")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscriptionDidUnsubscribe(self)
                }
            }
        }
    }
    
    func fireOnSubscriptionError(subId: Int, _ code: Int, _ msg: String) {
        synchronized {
            if subscriptionLogger.isWarnEnabled {
                subscriptionLogger.warn("Subscription \(subId) failed: \(code) - \(msg)")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didFailWithErrorCode: code, message: msg)
                }
            }
        }
    }
    
    func fireOnEndOfSnapshot(_ itemIdx: Int, subId: Int) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId):\(getItemNameOrPos(itemIdx)): snapshot ended")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didEndSnapshotForItemName: self.getItemName(itemIdx), itemPos: UInt(itemIdx))
                }
            }
        }
    }
    
    func fireOnClearSnapshot(_ itemIdx: Int, subId: Int) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId):\(getItemNameOrPos(itemIdx)): snapshot cleared")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didClearSnapshotForItemName: self.getItemName(itemIdx), itemPos: UInt(itemIdx))
                }
            }
        }
    }
    
    func fireOnLostUpdates(_ itemIdx: Int, _ lostUpdates: Int, subId: Int) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId):\(getItemNameOrPos(itemIdx)): lost \(lostUpdates) updates")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didLoseUpdates: UInt(lostUpdates), forItemName: self.getItemName(itemIdx), itemPos: UInt(itemIdx))
                }
            }
        }
    }
    
    func fireOnItemUpdate(_ update: ItemUpdate, subId: Int) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId):\(getItemNameOrPos(update.itemPos)) update: \(String(describing: update))")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didUpdateItem: update)
                }
            }
        }
    }
    
    func fireOnRealMaxFrequency(_ freq: RealMaxFrequency?, subId: Int) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId) real max frequency changed: \(freq == nil ? "nil" : String(describing: freq!))")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didReceiveRealFrequency: freq)
                }
            }
        }
    }
    
    func fireOnSubscriptionError2Level(_ keyName: String, _ code: Int, _ msg: String, subId: Int, itemIdx: Pos) {
        synchronized {
            if subscriptionLogger.isWarnEnabled {
                subscriptionLogger.warn("Subscription \(subId):\(getItemNameOrPos(itemIdx)):\(keyName) failed: \(code) - \(msg)")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didFailWithErrorCode: code, message: msg, forCommandSecondLevelItemWithKey: keyName)
                }
            }
        }
    }
    
    func fireOnLostUpdates2Level(_ keyName: String, _ lostUpdates: Int, subId: Int, itemIdx: Pos) {
        synchronized {
            if subscriptionLogger.isDebugEnabled {
                subscriptionLogger.debug("Subscription \(subId):\(getItemNameOrPos(itemIdx)):\(keyName): lost \(lostUpdates) updates")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.subscription(self, didLoseUpdates: UInt(lostUpdates), forCommandSecondLevelItemWithKey: keyName)
                }
            }
        }
    }
}

func notEmpty(_ newValue: String?) -> Bool {
    newValue != nil ? !newValue!.isEmpty : true
}

func notEmpty(_ newValue: [String]?) -> Bool {
    newValue != nil ? !newValue!.isEmpty : true
}

func isValidItem(_ item: String) -> Bool {
    !item.isEmpty && !item.contains(where: { $0 == " " }) && !CharacterSet(charactersIn: item).isSubset(of: CharacterSet(charactersIn: "0123456789"))
}

func isValidField(_ field: String) -> Bool {
    !field.isEmpty && !field.contains(where: { $0 == " " })
}

func allValidFields(_ newValue: [String]?) -> Bool {
    newValue != nil ? newValue!.allSatisfy({ isValidField($0) }) : true
}

func allValidItems(_ newValue: [String]?) -> Bool {
    newValue != nil ? newValue!.allSatisfy({ isValidItem($0) }) : true
}
