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
import Starscream

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

class LsWebsocket: LsWebsocketClient {
    let lock: NSRecursiveLock
    let socket: WebSocket
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
            streamLogger.debug("WS connecting: \(request) \(request.headers)")
        }
        socket = WebSocket(request: request)
        socket.callbackQueue = defaultQueue
        socket.onEvent = { [weak self] e in
            self?.onEvent(e)
        }
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
    
    private func onEvent(_ event: WebSocketEvent) {
        synchronized {
            guard !m_disposed else {
                return
            }
            if streamLogger.isDebugEnabled {
                streamLogger.debug("WS event: \(event)")
            }
            switch event {
            case .connected(_):
                onOpen(self)
            case .text(let chunk):
                for line in chunk.split(separator: "\r\n") {
                    onText(self, String(line))
                }
            case .error(let error):
                onError(self, error?.localizedDescription ?? "n.a.")
            case .cancelled:
                onError(self, "unexpected cancellation")
            case let .disconnected(reason, code):
                onError(self, "unexpected disconnection: \(code) - \(reason)")
            default:
                break
            /*
            case .binary(let data):
                break
            case .ping(_):
                break
            case .pong(_):
                break
            case .viabilityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            */
            }
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
