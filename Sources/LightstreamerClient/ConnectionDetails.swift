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

enum ServerAddressError: Error {
    case malformed
    case wrongScheme
    case wrongQuery
}

func parseServerAddress(_ address: String) -> Result<String, ServerAddressError> {
    guard let url = URL(string: address) else {
        return .failure(.malformed)
    }
    guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
        return .failure(.wrongScheme)
    }
    guard url.query == nil else {
        return .failure(.wrongQuery)
    }
    return .success(url.absoluteString)
}

/**
 Used by `LightstreamerClient` to provide a basic connection properties object.
 
 This object contains the configuration settings needed to connect to a Lightstreamer Server.
 
 An instance of this class is attached to every `LightstreamerClient` as `LightstreamerClient.connectionDetails`.
 
 - SeeAlso: `LightstreamerClient`
 */
public class ConnectionDetails: CustomStringConvertible {
    
    unowned let client: LightstreamerClient
    // all properties are guarded by client.lock
    var m_serverAddress: String?
    var m_adapterSet: String?
    var m_user: String?
    var m_password: String?
    var m_sessionId: String?
    var m_serverInstanceAddress: String?
    var m_serverSocketName: String?
    var m_clientIp: String?
    var m_certificatePins: [SecKey] = []

    init(_ client: LightstreamerClient) {
        self.client = client
    }

    /**
     Configured address of Lightstreamer Server.
     
     Note that the addresses specified must always have the http: or https: scheme. In case WebSockets are used, the specified scheme is internally converted to match the related WebSocket protocol (i.e. http becomes ws while https becomes wss). If no server address is supplied the client will be unable to connect.
     
     **Edition note:** WSS/HTTPS is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).
     
     **Platform limitations:** On watchOS the WebSocket transport is not available.

     **Lifecycle:** this property can be changed at any time. If changed while connected, it will be applied when the next session creation request is issued.
     This setting can also be specified in the LightstreamerClient constructor. A nil value can also be used, to restore the default value. An IPv4 or IPv6 can also be used in place of a hostname. Some examples of valid values include:
     
     - `http://push.mycompany.com`

     - `http://push.mycompany.com:8080`
     
     - `http://79.125.7.252`
     
     - `http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]`
     
     - `http://[2001:0db8:85a3::8a2e:0370:7334]:8080`
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `serverAddress` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Precondition: the given address must be valid.
     */
    public var serverAddress: String? {
        get {
            client.synchronized {
                m_serverAddress
            }
        }
        set {
            client.synchronized {
                if let newValue = newValue {
                    let res = parseServerAddress(newValue)
                    switch res {
                    case .failure(let error):
                        switch error {
                        case .malformed:
                            preconditionFailure("serverAddress is malformed")
                        case .wrongScheme:
                            preconditionFailure("serverAddress scheme must be http or https")
                        case .wrongQuery:
                            preconditionFailure("serverAddress must not have query")
                        }
                    default:
                        break
                    }
                }
                if (newValue == m_serverAddress) {
                    return
                }
                if actionLogger.isInfoEnabled {
                    actionLogger.info("serverAddress changed: \(newValue ?? "nil")")
                }
                let oldValue = m_serverAddress
                m_serverAddress = newValue
                client.fireDidChangeProperty("serverAddress")
                if oldValue != newValue {
                    client.evtServerAddressChanged()
                }
            }
        }
    }
    
    /// Configures public key pinning for server authentication over TLS connections.
    ///
    /// When pins are configured, the client validates that at least one of the provided pins
    /// matches the public key of a certificate in the server's chain before establishing a session. If no match
    /// is found, the connection is aborted and any registered delegate is notified via `ClientDelegate.client(_:didReceiveServerError:withMessage:)`
    /// with error code `62` and the message `Unrecognized server's identity`.
    ///
    /// **Lifecycle:**
    /// Ideally, public key pins should be set before calling `LightstreamerClient.connect()`.
    /// However, this configuration is dynamic and can be updated at any time; new pins are
    /// applied to all subsequent network requests issued by the client.
    ///
    /// **Notification:**
    /// A change to this setting is notified to any registered listener via
    /// `ClientDelegate.client(_:didChangeProperty:)` with argument `certificatePins`.
    ///
    /// **Unsecure Connections:**
    /// Pinning is enforced only when the connection is established over HTTPS/WSS.
    /// For plain HTTP/WS connections, pins are ignored.
    ///
    /// **Self-Signed Certificates:**
    /// Pinning does not bypass standard TLS trust evaluation performed by the system.
    /// Certificates must still be considered valid by the platform trust store.
    ///
    /// **Example:**
    ///   ```swift
    ///   // Load a public key from a DER-encoded certificate in the app bundle
    ///   func loadPublicKey(named resource: String, withExtension ext: String = "cer", in bundle: Bundle = .main) -> SecKey? {
    ///       guard let url = bundle.url(forResource: resource, withExtension: ext),
    ///             let data = try? Data(contentsOf: url),
    ///             let cert = SecCertificateCreateWithData(nil, data as CFData) else {
    ///                 return nil
    ///       }
    ///       return SecCertificateCopyKey(cert)
    ///   }
    ///
    ///   // Configure pins (e.g., public keys of leaf and/or intermediate certificates)
    ///   if let leafKey = loadPublicKey(named: "leaf-cert"),
    ///      let intermediateKey = loadPublicKey(named: "ca-cert") {
    ///       client.connectionDetails.certificatePins = [leafKey, intermediateKey]
    ///   }
    ///
    ///   client.connect()
    ///   ```
    ///
    /// - Parameter pins: The list of public keys to pin. Each value should be a `SecKey`
    ///   derived from the certificate’s Subject Public Key Info (SPKI).
    ///   Pass an empty array to disable pinning and clear existing pins.
    ///
    /// - SeeAlso: `ClientDelegate.client(_:didChangeProperty:)`
    /// - SeeAlso: `LightstreamerClient.connect()`
    public var certificatePins: [SecKey] {
        get {
            client.synchronized {
                m_certificatePins
            }
        }
        
        set(pins) {
            client.synchronized {
                if (pins == m_certificatePins) {
                    return
                }
                if actionLogger.isInfoEnabled {
                    actionLogger.info("certificatePins changed")
                }
                m_certificatePins = pins
                client.fireDidChangeProperty("certificatePins")
            }
        }
    }

    /**
     Name of the Adapter Set (which defines the Metadata Adapter and one or several Data Adapters) mounted on Lightstreamer Server that supply all the items used in this application.
     
     An Adapter Set defines the Metadata Adapter and one or several Data Adapters. It is configured on the server side through an `adapters.xml` file; the name is configured through the `id` attribute in the `<adapters_conf>` element. The default Adapter Set, configured as `DEFAULT` on the Server.
     
     **Lifecycle:** the Adapter Set name should be set on the `LightstreamerClient.connectionDetails` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next time a new session is requested to the server.
     
     This setting can also be specified in the `LightstreamerClient` constructor. A nil value is equivalent to the `DEFAULT` name.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `adapterSet` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var adapterSet: String? {
        get {
            client.synchronized {
                m_adapterSet
            }
        }
        set {
            client.synchronized {
                if (newValue == m_adapterSet) {
                    return
                }
                if actionLogger.isInfoEnabled {
                    actionLogger.info("adapterSet changed: \(newValue ?? "nil")")
                }
                m_adapterSet = newValue
                client.fireDidChangeProperty("adapterSet")
            }
        }
    }

    /**
     Username to be used for the authentication on Lightstreamer Server when initiating the session.
     
     The Metadata Adapter is responsible for checking the credentials (username and password). If no username is supplied, no user information will be sent at session initiation. The Metadata Adapter, however, may still allow the session.
     
     **Lifecycle:** the username should be set on the `LightstreamerClient.connectionDetails` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next time a new session is requested to the server.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `user` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - SeeAlso: `setPassword(_:)`
     */
    public var user: String? {
        get {
            client.synchronized {
                m_user
            }
        }
        set {
            client.synchronized {
                if (newValue == m_user) {
                    return
                }
                if actionLogger.isInfoEnabled {
                    actionLogger.info("user changed: \(newValue ?? "nil")")
                }
                m_user = newValue
                client.fireDidChangeProperty("user")
            }
        }
    }

    /**
     Setter method that sets the password to be used for the authentication on Lightstreamer Server when initiating the session.
     
     The Metadata Adapter is responsible for checking the credentials (username and password). If no password is supplied, no password information will be sent at session initiation. The Metadata Adapter, however, may still allow the session.
     
     **Lifecycle:** the username should be set on the `LightstreamerClient.connectionDetails` object before calling the `LightstreamerClient.connect()` method. However, the property can be changed at any time: the supplied value will be used for the next time a new session is requested to the server.
     
     - Note: The password string will be stored in the current instance. That is necessary in order to allow automatic reconnection/reauthentication for fail-over. For maximum security, avoid using an actual private password to authenticate on Lightstreamer Server; rather use a session-id originated by your web/application server, that can be checked by your Metadata Adapter.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `password` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     
     - Parameter password: The password to be used for the authentication on Lightstreamer Server. The password can be nil.
     
     - SeeAlso: user
     */
    public func setPassword(_ password: String?) {
        client.synchronized {
            if (password == m_password) {
                return
            }
            if actionLogger.isInfoEnabled {
                actionLogger.info("password changed")
            }
            m_password = password
            client.fireDidChangeProperty("password")
        }
    }

    /**
     ID associated by the server to this client session.
     
     **Lifecycle:**  If a session is not currently active, nil is returned; soon after a session is established, the value will become available.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `sessionId` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var sessionId: String? {
        get {
            client.synchronized {
                m_sessionId
            }
        }
    }

    func setSessionId(_ sessionId: String?) {
        client.synchronized {
            if (sessionId == m_sessionId) {
                return
            }
            m_sessionId = sessionId
            client.fireDidChangeProperty("sessionId")
        }
    }

    /**
     Server address to be used to issue all requests related to the current session.
     
     In fact, when a Server cluster is in place, the Server address specified through `<serverAddress>` can identify various Server instances; in order to ensure that all requests related to a session are issued to the same Server instance, the Server can answer to the session opening request by providing an address which uniquely identifies its own instance. When this is the case, this address is returned as the value; otherwise, nil is returned.
     
     Note that the addresses will always have the http: or https: scheme. In case WebSockets are used, the specified scheme is internally converted to match the related WebSocket protocol (i.e. http becomes ws while https becomes wss).
     
     **Edition note:** server clustering is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** If a session is not currently active, nil is returned; soon after a session is established, the value may become available.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `serverInstanceAddress` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var serverInstanceAddress: String? {
        get {
            client.synchronized {
                m_serverInstanceAddress
            }
        }
    }

    func setServerInstanceAddress(_ serverInstanceAddress: String?) {
        client.synchronized {
            if (serverInstanceAddress == m_serverInstanceAddress) {
                return
            }
            m_serverInstanceAddress = serverInstanceAddress
            client.fireDidChangeProperty("serverInstanceAddress")
        }
    }

    /**
     Instance name of the Server which is serving the current session.
     
     To be more precise, each answering port configured on a Server instance (through a &lt;http_server&gt; or &lt;https_server&gt; element in the Server configuration file) can be given a different name; the name related to the port to which the session opening request has been issued is returned.
     
     Note that each rebind to the same session can, potentially, reach the Server on a port different than the one used for the previous request, depending on the behavior of intermediate nodes. However, the only meaningful case is when a Server cluster is in place and it is configured in such a way that the port used for all `bind_session` requests differs from the port used for the initial `create_session` request.
     
     **Edition note:** server clustering is an optional feature, available depending on Edition and License Type. To know what features are enabled by your license, please see the License tab of the Monitoring Dashboard (by default, available at &#47;dashboard).

     **Lifecycle:** If a session is not currently active, nil is returned; soon after a session is established, the value will become available.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `serverSocketName` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var serverSocketName: String? {
        get {
            client.synchronized {
                m_serverSocketName
            }
        }
    }

    func setServerSocketName(_ serverSocketName: String?) {
        client.synchronized {
            if (serverSocketName == m_serverSocketName) {
                return
            }
            m_serverSocketName = serverSocketName
            client.fireDidChangeProperty("serverSocketName")
        }
    }

    /**
     IP address of this client as seen by the Server which is serving the current session as the client remote address (note that it may not correspond to the client host; for instance it may refer to an intermediate proxy).
     
     If, upon a new session, this address changes, it may be a hint that the intermediary network nodes handling the connection have changed, hence the network capabilities may be different. The library uses this information to optimize the connection.
     
     Note that in case of polling or in case rebind requests are needed, subsequent requests related to the same session may, in principle, expose a different IP address to the Server; these changes would not be reported.
     
     **Lifecycle:** if a session is not currently active, nil is returned; soon after a session is established, the value may become available.
     
     **Related notifications:** a change to this setting will be notified through a call to `ClientDelegate.client(_:didChangeProperty:)` with argument `clientIp` on any `ClientDelegate` listening to the related `LightstreamerClient`.
     */
    public var clientIp: String? {
        get {
            client.synchronized {
                m_clientIp
            }
        }
    }

    func setClientIp(_ clientIp: String?) {
        client.synchronized {
            if (clientIp == m_clientIp) {
                return
            }
            m_clientIp = clientIp
            client.fireDidChangeProperty("clientIp")
        }
    }
    
    public var description: String {
        client.synchronized {
            var map = OrderedDictionary<String, CustomStringConvertible>()
            map["serverAddress"] = m_serverAddress
            map["adapterSet"] = m_adapterSet
            map["user"] = m_user
            map["sessionId"] = m_sessionId
            map["serverInstanceAddress"] = m_serverInstanceAddress
            map["serverSocketName"] = m_serverSocketName
            map["clientIp"] = m_clientIp
            map["libVersion"] = LightstreamerClient.LIB_NAME + " " + LightstreamerClient.LIB_VERSION
            return String(describing: map)
        }
    }
}
