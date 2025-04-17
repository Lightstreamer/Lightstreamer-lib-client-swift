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
    
    let callbackQueue = defaultQueue
    
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
