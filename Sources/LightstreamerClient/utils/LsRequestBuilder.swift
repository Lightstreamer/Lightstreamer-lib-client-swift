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

class LsRequestBuilder: CustomStringConvertible {
    
    var params = [URLQueryItem]()
    
    public var description: String {
        String(describing: params)
    }
    
    func LS_reqId(_ val: Int) {
        addParam("LS_reqId", val)
    }
    
    func LS_message(_ val: String) {
        addParam("LS_message", val)
    }
    
    func LS_sequence(_ val: String) {
        addParam("LS_sequence", val)
    }
    
    func LS_msg_prog(_ val: Int) {
        addParam("LS_msg_prog", val)
    }
    
    func LS_max_wait(_ val: Int) {
        addParam("LS_max_wait", val)
    }
    
    func LS_outcome(_ val: Bool) {
        addParam("LS_outcome", val)
    }
    
    func LS_ack(_ val: Bool) {
        addParam("LS_ack", val)
    }
    
    func LS_op(_ val: String) {
        addParam("LS_op", val)
    }
    
    func LS_subId(_ val: Int) {
        addParam("LS_subId", val)
    }
    
    func LS_mode(_ val: String) {
        addParam("LS_mode", val)
    }
    
    func LS_group(_ val: String) {
        addParam("LS_group", val)
    }
    
    func LS_schema(_ val: String) {
        addParam("LS_schema", val)
    }
    
    func LS_data_adapter(_ val: String) {
        addParam("LS_data_adapter", val)
    }
    
    func PN_deviceId(_ val: String) {
        addParam("PN_deviceId", val)
    }
    
    func PN_notificationFormat(_ val: String) {
        addParam("PN_notificationFormat", val)
    }
    
    func PN_trigger(_ val: String) {
        addParam("PN_trigger", val)
    }
    
    func PN_coalescing(_ val: Bool) {
        addParam("PN_coalescing", val)
    }
    
    func LS_requested_max_frequency(_ val: String) {
        addParam("LS_requested_max_frequency", val)
    }
    
    func LS_requested_max_frequency(_ val: Double) {
        addParam("LS_requested_max_frequency", val)
    }
    
    func LS_requested_buffer_size(_ val: String) {
        addParam("LS_requested_buffer_size", val)
    }
    
    func LS_requested_buffer_size(_ val: Int) {
        addParam("LS_requested_buffer_size", val)
    }
    
    func PN_subscriptionId(_ val: String) {
        addParam("PN_subscriptionId", val)
    }
    
    func PN_type(_ val: String) {
        addParam("PN_type", val)
    }
    
    func PN_appId(_ val: String) {
        addParam("PN_appId", val)
    }
    
    func PN_deviceToken(_ val: String) {
        addParam("PN_deviceToken", val)
    }
    
    func PN_newDeviceToken(_ val: String) {
        addParam("PN_newDeviceToken", val)
    }
    
    func PN_subscriptionStatus(_ val: String) {
        addParam("PN_subscriptionStatus", val)
    }
    
    func LS_cause(_ val: String) {
        addParam("LS_cause", val)
    }
    
    func LS_keepalive_millis(_ val: Int) {
        addParam("LS_keepalive_millis", val)
    }
    
    func LS_inactivity_millis(_ val: Int) {
        addParam("LS_inactivity_millis", val)
    }
    
    func LS_requested_max_bandwidth(_ val: String) {
        addParam("LS_requested_max_bandwidth", val)
    }
    
    func LS_requested_max_bandwidth(_ val: Double) {
        addParam("LS_requested_max_bandwidth", val)
    }
    
    func LS_adapter_set(_ val: String) {
        addParam("LS_adapter_set", val)
    }
    
    func LS_user(_ val: String) {
        addParam("LS_user", val)
    }
    
    func LS_password(_ val: String) {
        addParam("LS_password", val)
    }
    
    func LS_cid(_ val: String) {
        addParam("LS_cid", val)
    }
    
    func LS_old_session(_ val: String) {
        addParam("LS_old_session", val)
    }
    
    func LS_session(_ val: String) {
        addParam("LS_session", val)
    }
    
    func LS_send_sync(_ val: Bool) {
        addParam("LS_send_sync", val)
    }
    
    func LS_polling(_ val: Bool) {
        addParam("LS_polling", val)
    }
    
    func LS_polling_millis(_ val: Int) {
        addParam("LS_polling_millis", val)
    }
    
    func LS_idle_millis(_ val: Int) {
        addParam("LS_idle_millis", val)
    }
    
    func LS_content_length(_ val: UInt64) {
        addParam("LS_content_length", "\(val)")
    }
    
    func LS_ttl_millis(_ val: String) {
        addParam("LS_ttl_millis", val)
    }
    
    func LS_recovery_from(_ val: Int) {
        addParam("LS_recovery_from", val)
    }
    
    func LS_close_socket(_ val: Bool) {
        addParam("LS_close_socket", val)
    }
    
    func LS_selector(_ val: String) {
        addParam("LS_selector", val)
    }
    
    func LS_snapshot(_ val: Bool) {
        addParam("LS_snapshot", val)
    }
    
    func LS_snapshot(_ val: Int) {
        addParam("LS_snapshot", val)
    }
    
    func addParam(_ key: String, _ val: String) {
        params.append(URLQueryItem(name: key, value: val))
    }
    
    func addParam(_ key: String, _ val: Int) {
        addParam(key, "\(val)")
    }
    
    func addParam(_ key: String, _ val: Double) {
        addParam(key, "\(val)")
    }
    
    func addParam(_ key: String, _ val: Bool) {
        addParam(key, val ? "true" : "false")
    }
    
    var encodedString: String {
        var components = URLComponents()
        components.queryItems = params
        return components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
    }
}
