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
    public init(_ level: ConsoleLogLevel) {
        self.level = level
    }
    
    public func loggerWithCategory(_ category: String) -> LSLogger {
        ConsoleLogger(level, category: category)
    }
}
