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

typealias WSFactoryService = (NSRecursiveLock, String,
            String,
            [String:String],
            @escaping (LsWebsocketClient) -> Void,
            @escaping (LsWebsocketClient, String) -> Void,
            @escaping (LsWebsocketClient, String) -> Void) -> LsWebsocketClient

func createWS(_ lock: NSRecursiveLock, _ url: String,
                      protocols: String,
                      headers: [String:String],
                      onOpen: @escaping (LsWebsocketClient) -> Void,
                      onText: @escaping (LsWebsocketClient, String) -> Void,
                      onError: @escaping (LsWebsocketClient, String) -> Void) -> LsWebsocketClient {
    return LsWebsocket(lock, url,
                       protocols: protocols,
                       headers: headers,
                       onOpen: onOpen,
                       onText: onText,
                       onError: onError)
}

protocol LsWebsocketClient: AnyObject {
    var disposed: Bool { get }
    func send(_ text: String)
    func dispose()
}

class LsWebsocket: LsWebsocketClient, LsWebSocketTaskDelegate {
    let lock: NSRecursiveLock
    let socket: LsWebsocketTask
    let onOpen: (LsWebsocket) -> Void
    let onText: (LsWebsocket, String) -> Void
    let onError: (LsWebsocket, String) -> Void
    var m_disposed = false
  
    init(_ lock: NSRecursiveLock, _ url: String,
         protocols: String,
         headers: [String:String] = [:],
         onOpen: @escaping (LsWebsocket) -> Void,
         onText: @escaping (LsWebsocket, String) -> Void,
         onError: @escaping (LsWebsocket, String) -> Void) {
        self.lock = lock
        self.onOpen = onOpen
        self.onText = onText
        self.onError = onError
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(protocols, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        for (key, val) in headers {
            request.setValue(val, forHTTPHeaderField: key)
        }
        if streamLogger.isDebugEnabled {
            streamLogger.debug("WS connecting: \(request) \(request.allHTTPHeaderFields ?? [:])")
        }
        self.socket = LsSession.shared.createWsTask(with: request)
        socket.setDelegate(self)
        socket.connect()
    }
    
    var disposed: Bool {
        synchronized {
            m_disposed
        }
    }

    func send(_ text: String) {
        synchronized {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("WS sending: \(String(reflecting: text))")
            }
            socket.write(string: text)
        }
    }

    func dispose() {
        synchronized {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("WS disposing")
            }
            m_disposed = true
            socket.disconnect()
        }
    }
    
    func onTaskOpen() {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            onOpen(self)
        }
    }
    
    func onTaskText(_ text: String) {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            onText(self, text)
        }
    }
    
    func onTaskError(_ error: String) {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            onError(self, error)
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
