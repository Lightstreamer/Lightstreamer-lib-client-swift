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

let streamLogger = LogManager.getLogger("lightstreamer.stream")
let protocolLogger = LogManager.getLogger("lightstreamer.protocol")
let internalLogger = LogManager.getLogger("lightstreamer.internal")
let sessionLogger = LogManager.getLogger("lightstreamer.session")
let actionLogger = LogManager.getLogger("lightstreamer.actions")
let reachabilityLogger = LogManager.getLogger("lightstreamer.reachability")
let subscriptionLogger = LogManager.getLogger("lightstreamer.subscriptions")
let messageLogger = LogManager.getLogger("lightstreamer.messages")
let mpnDeviceLogger = LogManager.getLogger("lightstreamer.mpn.device")
let mpnSubscriptionLogger = LogManager.getLogger("lightstreamer.mpn.subscriptions")

/// :nodoc:
public class LogManager {
    static let lock = NSLock()
    static var logInstances = [String:LSLog]()
    static var currentLoggerProvider: LSLoggerProvider?
    
    static func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    static func setLoggerProvider(_ provider: LSLoggerProvider?) {
        synchronized {
            currentLoggerProvider = provider
            for (category, log) in logInstances {
                log.setWrappedInstance(provider?.loggerWithCategory(category))
            }
        }
    }
    
    public static func getLogger(_ category: String) -> LSLogger {
        synchronized {
            if let log = logInstances[category] {
                return log
            } else {
                let log = LSLog(currentLoggerProvider?.loggerWithCategory(category))
                logInstances[category] = log
                return log
            }
        }
    }
}

class LSLog: LSLogger {
    
    let lock = NSLock()
    var wrappedLogger: LSLogger?
    
    init(_ logger: LSLogger?) {
        wrappedLogger = logger
    }
    
    private func synchronized<T>(_ block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
    
    func setWrappedInstance(_ logger: LSLogger?) {
        synchronized {
            wrappedLogger = logger
        }
    }
    
    func error(_ line: String) {
        synchronized {
            wrappedLogger?.error(line)
        }
    }
    
    func error(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.error(line, withException: exception)
        }
    }
    
    func warn(_ line: String) {
        synchronized {
            wrappedLogger?.warn(line)
        }
    }
    
    func warn(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.warn(line, withException: exception)
        }
    }
    
    func info(_ line: String) {
        synchronized {
            wrappedLogger?.info(line)
        }
    }
    
    func info(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.info(line, withException: exception)
        }
    }
    
    func debug(_ line: String) {
        synchronized {
            wrappedLogger?.debug(line)
        }
    }
    
    func debug(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.debug(line, withException: exception)
        }
    }
    
    func trace(_ line: String) {
        synchronized {
            wrappedLogger?.trace(line)
        }
    }
    
    func trace(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.trace(line, withException: exception)
        }
    }
    
    func fatal(_ line: String) {
        synchronized {
            wrappedLogger?.fatal(line)
        }
    }
    
    func fatal(_ line: String, withException exception: Error) {
        synchronized {
            wrappedLogger?.fatal(line, withException: exception)
        }
    }
    
    var isTraceEnabled: Bool {
        synchronized {
            wrappedLogger?.isTraceEnabled ?? false
        }
    }
    
    var isDebugEnabled: Bool {
        synchronized {
            wrappedLogger?.isDebugEnabled ?? false
        }
    }
    
    var isInfoEnabled: Bool {
        synchronized {
            wrappedLogger?.isInfoEnabled ?? false
        }
    }
    
    var isWarnEnabled: Bool {
        synchronized {
            wrappedLogger?.isWarnEnabled ?? false
        }
    }
    
    var isErrorEnabled: Bool {
        synchronized {
            wrappedLogger?.isErrorEnabled ?? false
        }
    }
    
    var isFatalEnabled: Bool {
        synchronized {
            wrappedLogger?.isFatalEnabled ?? false
        }
    }
}
