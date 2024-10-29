import Foundation

/**
 Protocol to be implemented to receive `MPNDevice` events including registration, suspension/resume and status change.
 
 Events for these delegates are dispatched by a different thread than the one that generates them. This means that, upon reception of an event,
 it is possible that the internal state of the client has changed. On the other hand, all the notifications for a single `LightstreamerClient`, including
 notifications to `ClientDelegate`, `SubscriptionDelegate`, `ClientMessageDelegate`, `MPNDeviceDelegate` and `MPNSubscriptionDelegate` will be dispatched by the same thread.
 */
public protocol MPNDeviceDelegate {
    /**
     Event handler called when the `MPNDeviceDelegate` instance is added to an `MPNDevice` through `MPNDevice.addDelegate(_:)`.
     
     This is the first event to be fired on the delegate.
     
     - Parameter device: The `MPNDevice` this instance was added to.
     */
    func mpnDeviceDidAddDelegate(_ device: MPNDevice)
    /**
     Event handler called when the `MPNDeviceDelegate` instance is removed from an `MPNDevice` through `MPNDevice.removeDelegate(_:)`.
     
     This is the last event to be fired on the delegate.
     
     - Parameter device: The `MPNDevice` this instance was removed from.
     */
    func mpnDeviceDidRemoveDelegate(_ device: MPNDevice)
    /**
     Event handler called when an `MPNDevice` has been successfully registered on the server's MPN Module.
     
     This event handler is always called before other events related to the same device.
     
     Note that this event can be called multiple times in the life of an `MPNDevice` instance in case the client disconnects and reconnects. In this case
     the device is registered again automatically.
     
     - Parameter device: The `MPNDevice` instance involved.
     */
    func mpnDeviceDidRegister(_ device: MPNDevice)
    /**
     Event handler called when an `MPNDevice` has been suspended on the server's MPN Module.
     
     An MPN device may be suspended if errors occur during push notification delivery.
     
     Note that in some server clustering configurations this event may not be called.

     - Parameter device: The `MPNDevice` instance involved.
     */
    func mpnDeviceDidSuspend(_ device: MPNDevice)
    /**
     Event handler called when an `MPNDevice` has been resumed on the server's MPN Module.
     
     An MPN device may be resumed from suspended state at the first subsequent registration.
     
     Note that in some server clustering configurations this event may not be called.
     
     - Parameter device: The `MPNDevice` instance involved.
     */
    func mpnDeviceDidResume(_ device: MPNDevice)
    /**
     Event handler called when the server notifies an error while registering an `MPNDevice`.
     
     By implementing this method it is possible to perform recovery actions.
     
     The error code can be one of the following:
     
     - 40 - the MPN Module is disabled, either by configuration or by license restrictions.
     
     - 41 - the request failed because of some internal resource error (e.g. database connection, timeout etc.).
     
     - 43 - invalid or unknown application ID.
     
     - 45 - invalid or unknown MPN device ID.
     
     - 48 - MPN device suspended.
     
     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - &lt;= 0 - the Metadata Adapter has refused the subscription request; the code value is dependent on the specific Metadata Adapter implementation.
     
     - Parameter device: The `MPNDevice` instance involved.

     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     */
    func mpnDevice(_ device: MPNDevice, didFailRegistrationWithErrorCode code: Int, message: String?)
    /**
     Event handler called when the server notifies that an `MPNDevice` changed its status.
     
     Note that in some server clustering configurations the status change for the MPN device suspend event may not be called.
     
     - Parameter device: The `MPNDevice` instance involved.
     - Parameter status: The new status of the MPN device.
     - Parameter timestamp: The server-side timestamp of the new device status.

     - SeeAlso: `MPNDevice.status`
     - SeeAlso: `MPNDevice.statusTimestamp`
     */
    func mpnDevice(_ device: MPNDevice, didChangeStatus status: MPNDevice.Status, timestamp: Int64)
    /**
     Event handler called when the server notifies that the list of MPN subscription associated with an `MPNDevice` has been updated.
     
     After registration, the list of pre-existing MPN subscriptions for an `MPNDevice` is updated and made available through the
     `LightstreamerClient.MPNSubscriptions` property.
     
     - Parameter device: The `MPNDevice` instance involved.

     - SeeAlso: `LightstreamerClient.MPNSubscriptions`
     */
    func mpnDeviceDidUpdateSubscriptions(_ device: MPNDevice)
    /**
     Event handler called when the server notifies that the badge of an `MPNDevice` has been reset.
     
     - Parameter device: The `MPNDevice` instance involved.
     
     - SeeAlso: `LightstreamerClient.resetMPNBadge()`
     */
    func mpnDeviceDidResetBadge(_ device: MPNDevice)
    /**
     Event handler called when the server notifies an error while resetting the badge of an `MPNDevice`.
     
     By implementing this method it is possible to perform recovery actions.
     
     The error code can be one of the following:
     
     - 40 - the MPN Module is disabled, either by configuration or by license restrictions.
     
     - 41 - the request failed because of some internal resource error (e.g. database connection, timeout etc.).
     
     - 43 - invalid or unknown application ID.
     
     - 45 - invalid or unknown MPN device ID.
     
     - 48 - MPN device suspended.
     
     - 66 - an unexpected exception was thrown by the Metadata Adapter while authorizing the connection.
     
     - 68 - the Server could not fulfill the request because of an internal error.
     
     - &lt;= 0 - the Metadata Adapter has refused the subscription request; the code value is dependent on the specific Metadata Adapter implementation.
     
     - Parameter device: The `MPNDevice` instance involved.
     
     - Parameter code: The error code sent by the Server.
     
     - Parameter message: The description of the error sent by the Server; it can be nil.
     */
    func mpnDevice(_ device: MPNDevice, didFailBadgeResetWithErrorCode code: Int, message: String?)
}

/**
 Class representing a device that supports Mobile Push Notifications (MPN).
 
 It contains device details and the delegate needed to monitor its status.
 
 An MPN device is created from a device token obtained from system's Remote User Notification APIs, and must be registered on the `LightstreamerClient` in order to successfully subscribe an MPN subscription. See `MPNSubscription`.
 
 After creation, an MPNDevice object is in "unknown" state. It must then be passed to the Lightstreamer Server with the
 `LightstreamerClient.register(forMPN:)` method, which enables the client to subscribe MPN subscriptions and sends the device details to the
 server's MPN Module, where it is assigned a permanent `<deviceId>` and its state is switched to "registered".
 
 Upon registration on the server, active MPN subscriptions of the device are received and exposed in the `LightstreamerClient.MPNSubscriptions`
 collection.
 
 An MPNDevice's state may become "suspended" if errors occur during push notification delivery. In this case MPN subscriptions stop sending notifications
 and the device state is reset to "registered" at the first subsequent registration.
 */
public class MPNDevice: CustomStringConvertible {
    /**
     The status of the device.
     */
    public enum Status: String {
        /**
         The MPN device has just been created or deleted.
         */
        case UNKNOWN
        /**
         The MPN device has been successfully registered on the server.
         */
        case REGISTERED
        /**
         A server error occurred while sending push notifications.
         */
        case SUSPENDED
    }
    
    static let NO_APP_ID = "Couldn't obtain an appropriate application ID for device registration"
    static let classLock = NSRecursiveLock()
    let lock = NSRecursiveLock()
    let callbackQueue = defaultQueue
    let multicastDelegate = MulticastDelegate<MPNDeviceDelegate>()
    var m_statusTs: Int64?
    var m_deviceId: String?
    var m_adapterName: String?
    var m_status: Status = .UNKNOWN
    
    /**
     Creates an object to be used to describe an MPN device that is going to be registered to the MPN Module of Lightstreamer Server.
     
     During initialization the MPNDevice tries to acquires some more details:
     
     - The application ID, through the app's Main Bundle.
     
     - Any previously registered device token, from the User Defaults storage.
     
     It then saves the current device token on the User Defaults storage. Saving and retrieving the previous device token is used to handle automatically
     the cases where the token changes, such as when the app state is restored from a device backup. The MPN Module of Lightstreamer Server is able to move MPN subscriptions associated with the previous token to the new one.
     
     - Parameter deviceToken: The device token obtained through the system's Remote User Notification APIs. Must be represented with a contiguous string of hexadecimal characters.
     
     - Precondition: the application ID may be obtained from the main bundle.
     */
    public init(deviceToken: String) {
        Self.classLock.lock()
        defer {
            Self.classLock.unlock()
        }
        guard let appId = UserDefaults.standard.string(forKey: "LS_appID") ?? Bundle.main.bundleIdentifier else {
            preconditionFailure(Self.NO_APP_ID)
        }
        let prevDeviceToken = UserDefaults.standard.string(forKey: "LS_deviceToken")
        UserDefaults.standard.set(deviceToken, forKey: "LS_deviceToken")
        UserDefaults.standard.synchronize()
        self.platform = "Apple"
        self.applicationId = appId
        self.deviceToken = deviceToken
        self.previousDeviceToken = prevDeviceToken
    }
    
    /**
     Adds a delegate that will receive events from the MPNDevice instance.
     
     The same delegate can be added to several different MPNDevice instances.
     
     **Lifecycle:** a delegate can be added at any time. A call to add a delegate already present will be ignored.
     
     - Parameter delegate: An object that will receive the events as documented in the `MPNDeviceDelegate` interface.
     
     - SeeAlso: `removeDelegate(_:)`
     */
    public func addDelegate(_ delegate: MPNDeviceDelegate) {
        synchronized {
            guard !multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.addDelegate(delegate)
            callbackQueue.async {
                delegate.mpnDeviceDidAddDelegate(self)
            }
        }
    }
    
    /**
     Removes a delegate from the `MPNDevice` instance so that it will not receive events anymore.
     
     **Lifecycle:** a delegate can be removed at any time.
     
     - Parameter delegate: The delegate to be removed.
     
     - SeeAlso: `addDelegate(_:)`
     */
    public func removeDelegate(_ delegate: MPNDeviceDelegate) {
        synchronized {
            guard multicastDelegate.containsDelegate(delegate) else {
                return
            }
            multicastDelegate.removeDelegate(delegate)
            callbackQueue.async {
                delegate.mpnDeviceDidRemoveDelegate(self)
            }
        }
    }
    
    /**
     List containing the `MPNDeviceDelegate` instances that were added to this `MPNDevice`.
     
     - SeeAlso: `addDelegate(_:)`
     */
    public var delegates: [MPNDeviceDelegate] {
        synchronized {
            multicastDelegate.getDelegates()
        }
    }
    
    /**
     The platform identifier of this MPN device. It equals to the constant `Apple` and is used by the server as part of the device identification.
     
     **Lifecycle:** this property can be read at any time.
     */
    public let platform: String
    
    /**
     The application ID of this MPN device. It is determined automatically from the main bundle identifier and is used by the server as part of the
     device identification.
     
     **Lifecycle:** this property can be read at any time.
     */
    public let applicationId: String
    
    /**
     The device token of this MPN device. It is passed during creation and is used by the server as part of the device identification.
     
     **Lifecycle:** this property can be read at any time.
     */
    public let deviceToken: String
    
    /**
     The previous device token of this MPN device. It is obtained automatically from the User Defaults storage during creation and is used
     by the server to restore MPN subscriptions associated with this previous token. May be nil if no MPN device has been registered yet on
     the application.
     
     **Lifecycle:** this property can be read at any time.
     */
    public let previousDeviceToken: String?
    
    /**
     Checks whether the `MPNDevice` is currently registered on the server or not.
     
     This flag is switched to `true` by server sent registration events, and back to `false` in case of client disconnection or server sent suspension events.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `status`
     */
    public var isRegistered: Bool {
        synchronized {
            m_status == .REGISTERED
        }
    }
    
    /**
     Checks whether the `MPNDevice` is currently suspended on the server or not.
     
     An MPN device may be suspended if errors occur during push notification delivery.
     
     This flag is switched to `true` by server sent suspension events, and back to `false` in case of client disconnection or server sent resume events.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `status`
     */
    public var isSuspended: Bool {
        synchronized {
            m_status == .SUSPENDED
        }
    }
    
    /**
     The status of the device.
     
     The status can be:
     
     - `UNKNOWN`: when the MPN device has just been created or deleted.
     
     - `REGISTERED`: when the MPN device has been successfully registered on the server.
     
     - `SUSPENDED`: when a server error occurred while sending push notifications to this MPN device and consequently it has been suspended.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `isRegistered`
     
     - SeeAlso: `isSuspended`
     */
    public var status: Status {
        synchronized {
            m_status
        }
    }
    
    /**
     The server-side timestamp of the device status.
     
     **Lifecycle:** this property can be read at any time.
     
     - SeeAlso: `status`
     */
    public var statusTimestamp: Int64? {
        synchronized {
            m_statusTs
        }
    }
    
    /**
     The server-side unique persistent ID of the device.
     
     The ID is available only after the MPN device has been successfully registered on the server. I.e. when its status is `REGISTERED` or `SUSPENDED`.
     
     Note: a device token change, if the previous device token was correctly stored on the User Defaults storage, does not cause the device ID to change: the
     server moves previous MPN subscriptions from the previous token to the new one and the device ID remains unaltered.
     
     **Lifecycle:** this property can be read at any time.
     */
    public var deviceId: String? {
        synchronized {
            m_deviceId
        }
    }
    
    public var description: String {
        synchronized {
            var map = OrderedDictionary<String, CustomStringConvertible>()
            map["deviceToken"] = deviceToken
            map["prevDeviceToken"] = previousDeviceToken
            map["applicationId"] = applicationId
            map["platform"] = platform
            return String(describing: map)
        }
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    func setDeviceId(_ deviceId: String, _ adapterName: String) {
        synchronized {
            m_deviceId = deviceId
            m_adapterName = adapterName
        }
    }
    
    func onRegistered(_ timestamp: Int64) {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN device registered: \(m_deviceId ?? "n.a.")")
            }
            m_status = .REGISTERED
            m_statusTs = timestamp
            
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDevice(self, didChangeStatus: .REGISTERED, timestamp: timestamp)
                    delegate.mpnDeviceDidRegister(self)
                }
            }
        }
    }
    
    func onSuspend(_ timestamp: Int64) {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN device suspended: \(m_deviceId ?? "n.a.")")
            }
            m_status = .SUSPENDED
            m_statusTs = timestamp
            
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDevice(self, didChangeStatus: .SUSPENDED, timestamp: timestamp)
                    delegate.mpnDeviceDidSuspend(self)
                }
            }
        }
    }
    
    func onResume(_ timestamp: Int64) {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN device resumed: \(m_deviceId ?? "n.a.")")
            }
            m_status = .REGISTERED
            m_statusTs = timestamp
            
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDevice(self, didChangeStatus: .REGISTERED, timestamp: timestamp)
                    delegate.mpnDeviceDidResume(self)
                }
            }
        }
    }
    
    func onError(_ code: Int, _ msg: String) {
        synchronized {
            if mpnDeviceLogger.isWarnEnabled {
                mpnDeviceLogger.warn("MPN device error: \(code) - \(msg) \(m_deviceId ?? "n.a.")")
            }
            m_status = .UNKNOWN
            m_statusTs = nil
            m_deviceId = nil
            m_adapterName = nil
            
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDevice(self, didFailRegistrationWithErrorCode: code, message: msg)
                    delegate.mpnDevice(self, didChangeStatus: .UNKNOWN, timestamp: 0)
                }
            }
        }
    }
    
    func onReset() {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN device NOT registered")
            }
            let oldStatus = m_status
            m_status = .UNKNOWN
            m_statusTs = nil
            m_deviceId = nil
            m_adapterName = nil
            
            if oldStatus != .UNKNOWN {
                multicastDelegate.invokeDelegates { delegate in
                    callbackQueue.async {
                        delegate.mpnDevice(self, didChangeStatus: .UNKNOWN, timestamp: 0)
                    }
                }
            }
        }
    }
    
    func fireOnSubscriptionsUpdated() {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN subscriptions have been updated: \(m_deviceId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDeviceDidUpdateSubscriptions(self)
                }
            }
        }
    }
    
    func fireOnBadgeResetFailed(_ code: Int, _ msg: String) {
        synchronized {
            if mpnDeviceLogger.isWarnEnabled {
                mpnDeviceLogger.warn("MPN badge reset failed: \(code) - \(msg) \(m_deviceId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDevice(self, didFailBadgeResetWithErrorCode: code, message: msg)
                }
            }
        }
    }
    
    func fireOnBadgeReset() {
        synchronized {
            if mpnDeviceLogger.isInfoEnabled {
                mpnDeviceLogger.info("MPN badge successfully reset: \(m_deviceId ?? "n.a.")")
            }
            multicastDelegate.invokeDelegates { delegate in
                callbackQueue.async {
                    delegate.mpnDeviceDidResetBadge(self)
                }
            }
        }
    }
}
