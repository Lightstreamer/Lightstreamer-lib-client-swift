import Foundation
import os.log

/**
 Interface to be implemented to consume log from the library.
 
 Instances of implemented classes are obtained by the library through the `LSLoggerProvider` instance set on `LightstreamerClient.setLoggerProvider(...)`.
 */
public protocol LSLogger {
    /**
     Receives log messages at Error level.
     
     - Parameter line: The message to be logged.
     */
    func error(_ line: String)
    /**
     Receives log messages at Error level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func error(_ line: String, withException exception: Error)
    /**
     Receives log messages at Warn level.
     
     - Parameter line: The message to be logged.
     */
    func warn(_ line: String)
    /**
     Receives log messages at Warn level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func warn(_ line: String, withException exception: Error)
    /**
     Receives log messages at Info level.
     
     - Parameter line: The message to be logged.
     */
    func info(_ line: String)
    /**
     Receives log messages at Info level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func info(_ line: String, withException exception: Error)
    /**
     Receives log messages at Debug level.
     
     - Parameter line: The message to be logged.
     */
    func debug(_ line: String)
    /**
     Receives log messages at Debug level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func debug(_ line: String, withException exception: Error)
    /**
     Receives log messages at Trace level.
     
     - Parameter line: The message to be logged.
     */
    func trace(_ line: String)
    /**
     Receives log messages at Trace level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func trace(_ line: String, withException exception: Error)
    /**
     Receives log messages at Fatal level.
     
     - Parameter line: The message to be logged.
     */
    func fatal(_ line: String)
    /**
     Receives log messages at Fatal level and a related exception.
     
     - Parameter line: The message to be logged.
     
     - Parameter exception: An Error instance related to the current log message.
     */
    func fatal(_ line: String, withException exception: Error)
    /**
     Checks if this logger is enabled for the Trace level.
     
     The property should be `true` if this logger is enabled for Trace events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Trace statements. Note that even if the property is `false`, Trace log lines
     may be received anyway by the Trace methods.
     */
    var isTraceEnabled: Bool {get}
    /**
     Checks if this logger is enabled for the Debug level.
     
     The property should be `true` if this logger is enabled for Debug events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Debug statements. Note that even if the property is `false`, Debug log lines
     may be received anyway by the Debug methods.
     */
    var isDebugEnabled: Bool {get}
    /**
     Checks if this logger is enabled for the Info level.
     
     The property should be `true` if this logger is enabled for Info events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Info statements. Note that even if the property is `false`, Info log lines
     may be received anyway by the Info methods.
     */
    var isInfoEnabled: Bool {get}
    /**
     Checks if this logger is enabled for the Warn level.
     
     The property should be `true` if this logger is enabled for Warn events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Warn statements. Note that even if the property is `false`, Warn log lines
     may be received anyway by the Warn methods.
     */
    var isWarnEnabled: Bool {get}
    /**
     Checks if this logger is enabled for the Error level.
     
     The property should be `true` if this logger is enabled for Error events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Error statements. Note that even if the property is `false`, Error log lines
     may be received anyway by the Error methods.
     */
    var isErrorEnabled: Bool {get}
    /**
     Checks if this logger is enabled for the Fatal level.
     
     The property should be `true` if this logger is enabled for Fatal events, `false` otherwise.
     
     This property is intended to lessen the computational cost of disabled log Fatal statements. Note that even if the property is `false`, Fatal log lines
     may be received anyway by the Fatal methods.
     */
    var isFatalEnabled: Bool {get}
}

/**
 Logging level.
 */
public enum ConsoleLogLevel: Int {
    /**
     Trace logging level.
     
     This level enables all logging.
     */
    case trace = -10
    /**
     Debug logging level.
     
     This level enables all logging except tracing.
     */
    case debug = 0
    /**
     Info logging level.
     
     This level enables logging for information, warnings, errors and fatal errors.
     */
    case info = 10
    /**
     Warn logging level.
     
     This level enables logging for warnings, errors and fatal errors.
     */
    case warn = 25
    /**
     Error logging level.
     
     This level enables logging for errors and fatal errors.
     */
    case error = 50
    /**
     Fatal logging level.
     
     This level enables logging for fatal errors only.
     */
    case fatal = 100
}

private let LS_LOG_TRACE = ConsoleLogLevel.trace.rawValue
private let LS_LOG_DEBUG = ConsoleLogLevel.debug.rawValue
private let LS_LOG_INFO = ConsoleLogLevel.info.rawValue
private let LS_LOG_WARN = ConsoleLogLevel.warn.rawValue
private let LS_LOG_ERROR = ConsoleLogLevel.error.rawValue
private let LS_LOG_FATAL = ConsoleLogLevel.fatal.rawValue

private let OSLogType_TRACE = OSLogType(200)

/**
 Concrete logger class to provide logging on the system console.
 
 Instances of this classes are obtained by the library through the `LSLoggerProvider` instance set on `LightstreamerClient.setLoggerProvider(...)`.
 */
public class ConsoleLogger: LSLogger {
    let level: Int
    let category: OSLog
    let traceEnabled: Bool
    let debugEnabled: Bool
    let infoEnabled: Bool
    let warnEnabled: Bool
    let errorEnabled: Bool
    let fatalEnabled: Bool
    
    /**
     Creates an instace of the concrete system console logger.
     
     - Parameter level: The desired logging level for this `ConsoleLogger` instance.
     
     - Parameter category: The log category all messages passed to the given `ConsoleLogger` instance will pertain to.
     */
    public init(level: ConsoleLogLevel, category: String) {
        let level = level.rawValue
        self.level = level
        self.category = OSLog(subsystem: "com.lightstreamer", category: category)
        self.traceEnabled = level <= LS_LOG_TRACE
        self.debugEnabled = level <= LS_LOG_DEBUG
        self.infoEnabled = level <= LS_LOG_INFO
        self.warnEnabled = level <= LS_LOG_WARN
        self.errorEnabled = level <= LS_LOG_ERROR
        self.fatalEnabled = level <= LS_LOG_FATAL
    }
    
    public func error(_ line: String) {
        if errorEnabled {
            os_log("%@", log: category, type: .error, line)
        }
    }
    
    public func error(_ line: String, withException exception: Error) {
        if errorEnabled {
            os_log("%@\n%@", log: category, type: .error, line, String(describing: exception))
        }
    }
    
    public func warn(_ line: String) {
        if warnEnabled {
            os_log("%@", log: category, type: .default, line)
        }
    }
    
    public func warn(_ line: String, withException exception: Error) {
        if warnEnabled {
            os_log("%@\n%@", log: category, type: .default, line, String(describing: exception))
        }
    }
    
    public func info(_ line: String) {
        if infoEnabled {
            os_log("%@", log: category, type: .info, line)
        }
    }
    
    public func info(_ line: String, withException exception: Error) {
        if infoEnabled {
            os_log("%@\n%@", log: category, type: .info, line, String(describing: exception))
        }
    }
    
    public func debug(_ line: String) {
        if debugEnabled {
            os_log("%@", log: category, type: .debug, line)
        }
    }
    
    public func debug(_ line: String, withException exception: Error) {
        if debugEnabled {
            os_log("%@\n%@", log: category, type: .debug, line, String(describing: exception))
        }
    }
    
    public func trace(_ line: String) {
        if traceEnabled {
            os_log("%@", log: category, type: OSLogType_TRACE, line)
        }
    }
    
    public func trace(_ line: String, withException exception: Error) {
        if traceEnabled {
            os_log("%@\n%@", log: category, type: OSLogType_TRACE, line, String(describing: exception))
        }
    }
    
    public func fatal(_ line: String) {
        if fatalEnabled {
            os_log("%@", log: category, type: .fault, line)
        }
    }
    
    public func fatal(_ line: String, withException exception: Error) {
        if fatalEnabled {
            os_log("%@\n%@", log: category, type: .fault, line, String(describing: exception))
        }
    }
    
    public var isTraceEnabled: Bool {
        traceEnabled
    }
    
    public var isDebugEnabled: Bool {
        debugEnabled
    }
    
    public var isInfoEnabled: Bool {
        infoEnabled
    }
    
    public var isWarnEnabled: Bool {
        warnEnabled
    }
    
    public var isErrorEnabled: Bool {
        errorEnabled
    }
    
    public var isFatalEnabled: Bool {
        fatalEnabled
    }
}
