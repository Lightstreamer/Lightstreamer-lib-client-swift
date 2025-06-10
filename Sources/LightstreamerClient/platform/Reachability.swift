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
//import Alamofire

typealias ReachabilityServiceFactory = (String) -> ReachabilityService

func createReachabilityManager(host: String) -> ReachabilityService {
    ReachabilityManager(host: host)
}

enum ReachabilityStatus {
    case reachable, notReachable
}

protocol ReachabilityService {
    func startListening(_ onUpdatePerforming: @escaping (ReachabilityStatus) -> Void)
    func stopListening()
}

#if os(watchOS)
class ReachabilityManager: ReachabilityService {
    init(host: String) {}
    func startListening(_ onUpdatePerforming: @escaping (ReachabilityStatus) -> Void) {}
    func stopListening() {}
}
#else
class ReachabilityManager: ReachabilityService {
//    let manager: NetworkReachabilityManager?
    
    init(host: String) {
//        manager = NetworkReachabilityManager(host: host)
    }
    
    func startListening(_ onUpdatePerforming: @escaping (ReachabilityStatus) -> Void) {
//        manager?.startListening(onUpdatePerforming: { status in
//            switch status {
//            case .notReachable, .unknown:
//                onUpdatePerforming(.notReachable)
//            case .reachable(_):
//                onUpdatePerforming(.reachable)
//            }
//        })
    }
    
    func stopListening() {
//        manager?.stopListening()
    }
}
#endif
