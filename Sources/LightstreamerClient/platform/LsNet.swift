/*
 * Copyright (C) 2025 Lightstreamer Srl
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

/// Wrapper of URLSession
class LsSession: NSObject, URLSessionWebSocketDelegate {
    public static let shared = LsSession()
    
    private let lock = NSRecursiveLock()
    private let urlSession: URLSession
    // URLSessionDataTask does not notify when portions of data arrive.
    // To track these events, a URLSessionTaskDelegate is attached to URLSession.
    // When URLSession triggers such an event for a URLSessionDataTask,
    // this map helps retrieve the corresponding LsHttpTask wrapper.
    private var httpTaskMap = [URLSessionDataTask: LsHttpTask]()
    // URLSessionWebSocketTask does not provide event notifications for Websocket connection openings or disconnections.
    // To track these events, I attach a URLSessionWebSocketDelegate to URLSession.
    // When URLSession notifies such an event for a URLSessionWebSocketTask, this map helps retrieve the corresponding LsWebsocketTask wrapper.
    private var wsTaskMap = [URLSessionWebSocketTask: LsWebsocketTask]()
    private var delegate = LsSessionDelegate()
    
    public override init() {
        urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        super.init()
        delegate.setSession(self)
    }
    
    public func createHttpTask(with request: URLRequest) -> LsHttpTask {
        synchronized {
            let task = urlSession.dataTask(with: request)
            return LsHttpTask(task: task, session: self)
        }
    }
    
    public func createWsTask(with request: URLRequest) -> LsWebsocketTask {
        synchronized {
            let task = urlSession.webSocketTask(with: request)
            return LsWebsocketTask(task: task, session: self)
        }
    }
    
    func setHttpWrapper(task: URLSessionDataTask, wrapper: LsHttpTask) {
        synchronized {
            httpTaskMap[task] = wrapper
        }
    }
    
    func getHttpWrapper(_ task: URLSessionDataTask) -> LsHttpTask? {
        synchronized {
            return httpTaskMap[task]
        }
    }
    
    func disposeHttpWrapper(_ task: URLSessionDataTask) {
        synchronized {
            httpTaskMap.removeValue(forKey: task)
            return
        }
    }
    
    func setWsWrapper(task: URLSessionWebSocketTask, wrapper: LsWebsocketTask) {
        synchronized {
            wsTaskMap[task] = wrapper
        }
    }
    
    func getWsWrapper(_ task: URLSessionWebSocketTask) -> LsWebsocketTask? {
        synchronized {
            return wsTaskMap[task]
        }
    }
    
    func disposeWsWrapper(_ task: URLSessionWebSocketTask) {
        synchronized {
            wsTaskMap.removeValue(forKey: task)
            return
        }
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
}

/// Delegate for URLSession
class LsSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionWebSocketDelegate {
    private let lock = NSRecursiveLock()
    private weak var session: LsSession?
    
    func setSession(_ session: LsSession) {
        synchronized {
            self.session = session
        }
    }
    
    func getSession() -> LsSession? {
        synchronized {
            return self.session
        }
    }
    
    // URLSessionWebSocketDelegate events to be forwarded to LsWebsocketTask
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard let taskWrapper = getSession()?.getWsWrapper(webSocketTask) else { return }
        if streamLogger.isDebugEnabled {
            streamLogger.debug("WS event: open")
        }
        taskWrapper.getDelegate()?.onTaskOpen()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard let taskWrapper = getSession()?.getWsWrapper(webSocketTask) else { return }
        if streamLogger.isDebugEnabled {
            streamLogger.debug("WS event: closed(\(closeCode) - \(String(describing: reason)))")
        }
        taskWrapper.getDelegate()?.onTaskError("unexpected disconnection: \(closeCode) - \(String(describing: reason))")
    }
    
    // URLSessionDelegate, URLSessionTaskDelegate and URLSessionDataDelegate events to be forwarded to LsHttpTask
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let taskWrapper = getSession()?.getHttpWrapper(dataTask) else { return }
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            taskWrapper.getDelegate()?.onTaskError("Unexpected response type")
            return
        }
        if !(200...299).contains(response.statusCode) {
            completionHandler(.cancel)
            taskWrapper.getDelegate()?.onTaskError("Unexpected HTTP status code:\(response.statusCode)")
        } else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskWrapper = getSession()?.getHttpWrapper(dataTask) else { return }
        if let txt = String(data: data, encoding: .utf8) {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("HTTP event: text(\(txt))")
            }
            taskWrapper.getDelegate()?.onTaskText(txt)
        } else {
            taskWrapper.getDelegate()?.onTaskError("Unable to decode received data as UTF-8: \(data)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Both URLSessionDataTask and URLSessionWebSocketTask inherit from URLSessionTask,
        // but I am only interested in URLSessionDataTask events
        guard let task = task as? URLSessionDataTask else { return }
        guard let taskWrapper = getSession()?.getHttpWrapper(task) else { return }
        if let error = error {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("HTTP event: error(\(error.localizedDescription))")
            }
            taskWrapper.getDelegate()?.onTaskError(error.localizedDescription)
        } else {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("HTTP event: complete")
            }
            taskWrapper.getDelegate()?.onTaskDone()
        }
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
}

/// Wrapper of URLSessionWebSocketTask
class LsWebsocketTask {
    private let lock = NSRecursiveLock()
    private let session: LsSession
    private let task: URLSessionWebSocketTask
    private var delegate: LsWebSocketTaskDelegate?
    
    public init(task: URLSessionWebSocketTask, session: LsSession) {
        self.session = session
        self.task = task
        session.setWsWrapper(task: task, wrapper: self)
    }
    
    public func setDelegate(_ delegate: LsWebSocketTaskDelegate) {
        synchronized {
            self.delegate = delegate
        }
    }
    
    public func getDelegate() -> LsWebSocketTaskDelegate? {
        synchronized {
            return self.delegate
        }
    }
    
    public func connect() {
        task.resume()
        listen()
    }
    
    private func listen()  {
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let chunk):
                    if streamLogger.isDebugEnabled {
                        streamLogger.debug("WS event: text(\(chunk))")
                    }
                    for line in chunk.split(separator: "\r\n") {
                        self.getDelegate()?.onTaskText(String(line))
                    }
                case .data(_):
                    fatalError("Unexpect message type")
                @unknown default:
                    fatalError("Unexpect message type")
                }
            case .failure(let error):
                if streamLogger.isDebugEnabled {
                    streamLogger.debug("WS event: error(\(error.localizedDescription))")
                }
                self.getDelegate()?.onTaskError(error.localizedDescription)
            }
            self.listen()
        }
    }
    
    public func disconnect() {
        task.cancel()
        session.disposeWsWrapper(task)
    }
    
    public func write(string text: String) {
        task.send(.string(text)) { [weak self] error in
            guard let error = error, let self = self else { return }
            self.getDelegate()?.onTaskError(error.localizedDescription)
        }
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
}

/// Delegate responsible for publishing events from LsWebsocketTask
protocol LsWebSocketTaskDelegate: AnyObject {
    func onTaskOpen()
    func onTaskText(_ text: String)
    func onTaskError(_ error: String)
}

/// Wrapper of URLSessionDataTask
class LsHttpTask {
    private let lock = NSRecursiveLock()
    private let session: LsSession
    private let task: URLSessionDataTask
    private var delegate: LsHttpTaskDelegate?
    
    public init(task: URLSessionDataTask, session: LsSession) {
        self.session = session
        self.task = task
        session.setHttpWrapper(task: task, wrapper: self)
    }
    
    public func setDelegate(_ delegate: LsHttpTaskDelegate) {
        synchronized {
            self.delegate = delegate
        }
    }
    
    public func getDelegate() -> LsHttpTaskDelegate? {
        synchronized {
            return self.delegate
        }
    }
    
    public func open() {
        task.resume()
    }
    
    public func cancel() {
        task.cancel()
        session.disposeHttpWrapper(task)
    }
    
    private func synchronized<T>(block: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return block()
    }
}

/// Delegate responsible for publishing events from LsHttpTask
protocol LsHttpTaskDelegate: AnyObject {
    func onTaskText(_ chunk: String)
    func onTaskError(_ error: String)
    func onTaskDone()
}
