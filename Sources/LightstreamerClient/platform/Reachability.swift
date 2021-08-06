import Foundation
import Alamofire

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
    let manager: NetworkReachabilityManager?
    
    init(host: String) {
        manager = NetworkReachabilityManager(host: host)
    }
    
    func startListening(_ onUpdatePerforming: @escaping (ReachabilityStatus) -> Void) {
        manager?.startListening(onUpdatePerforming: { status in
            switch status {
            case .notReachable, .unknown:
                onUpdatePerforming(.notReachable)
            case .reachable(_):
                onUpdatePerforming(.reachable)
            }
        })
    }
    
    func stopListening() {
        manager?.stopListening()
    }
}
#endif
