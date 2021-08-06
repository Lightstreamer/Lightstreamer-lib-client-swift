import Foundation

protocol ScheduledTask {
    var item: DispatchWorkItem? {get}
    func cancel()
}

protocol ScheduleService: AnyObject {
    var now: Timestamp { get }
    func schedule(_ id: String, _ timeout: Millis, _ task: ScheduledTask)
    func cancel(_ id: String, _ task: ScheduledTask)
}

class Scheduler: ScheduleService {
    
    class Task: ScheduledTask {
        weak var lock: NSRecursiveLock?
        var isCancelled = false
        var item: DispatchWorkItem?
        
        init(_ lock: NSRecursiveLock?, _ block: @escaping () -> Void) {
            self.lock = lock
            self.item = DispatchWorkItem { [weak self] in
                guard let self = self else {
                    return
                }
                self.synchronized {
                    if !self.isCancelled {
                        block()
                    }
                    self.item = nil
                }
            }
        }
        
        func cancel() {
            self.synchronized {
                item?.cancel()
                isCancelled = true
                item = nil
            }
        }
        
        private func synchronized(block: () -> Void) {
            guard let lock = lock else {
                return
            }
            lock.lock()
            defer {
                lock.unlock()
            }
            block()
        }
    }
    
    let callbackQueue = DispatchQueue.main
    
    var now: Timestamp {
        DispatchTime.now().uptimeNanoseconds / NSEC_PER_MSEC
    }
    
    func schedule(_ id: String, _ timeout: Millis, _ task: ScheduledTask) {
        callbackQueue.asyncAfter(deadline: .now() + .milliseconds(timeout), execute: task.item!)
    }
    
    func cancel(_ id: String, _ task: ScheduledTask) {
        task.cancel()
    }
}
