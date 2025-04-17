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

/**
 Simple interface to be implemented to provide custom log consumers to the library.
 
 An instance of the custom implemented class has to be passed to the library through the `LightstreamerClient.setLoggerProvider(...)`.
 */
public protocol LSLoggerProvider {
    /**
     Request for a Logger instance that will be used for logging occuring on the given category.
     
     It is suggested, but not mandatory, that subsequent calls to this method related to the same category return the same Logger instance.
     
     - Parameter category: The log category all messages passed to the given `LSLogger` instance will pertain to.
     
     - Returns: An `LSLogger` instance that will receive log lines related to the given category.
     */
    func loggerWithCategory(_ category: String) -> LSLogger
}

/**
 Simple concrete logging provider that logs on the system console.
 
 To be used, an instance of this class has to be passed to the library through the `LightstreamerClient.setLoggerProvider(...)`.
 */
public class ConsoleLoggerProvider: LSLoggerProvider {
    let level: ConsoleLogLevel
    
    /**
     Creates an instace of the concrete system console logger.
     
     - Parameter level: The desired logging level for this `ConsoleLoggerProvider` instance.
     */
    public init(level: ConsoleLogLevel) {
        self.level = level
    }
    
    public func loggerWithCategory(_ category: String) -> LSLogger {
        ConsoleLogger(level: level, category: category)
    }
}
