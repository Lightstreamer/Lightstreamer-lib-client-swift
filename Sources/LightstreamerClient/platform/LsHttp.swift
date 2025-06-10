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

typealias HTTPFactoryService = (NSRecursiveLock, String,
                                String,
                                [String:String],
                                @escaping (LsHttpClient, String) -> Void,
                                @escaping (LsHttpClient, String) -> Void,
                                @escaping (LsHttpClient) -> Void) -> LsHttpClient

func createHTTP(_ lock: NSRecursiveLock, _ url: String,
                body: String,
                headers: [String:String],
                onText: @escaping (LsHttpClient, String) -> Void,
                onError: @escaping (LsHttpClient, String) -> Void,
                onDone: @escaping (LsHttpClient) -> Void) -> LsHttpClient {
    return LsHttp(lock, url,
                  body: body,
                  headers: headers,
                  onText: onText,
                  onError: onError,
                  onDone: onDone)
}

protocol LsHttpClient: AnyObject {
    var disposed: Bool { get }
    func dispose()
}

class LsHttp: LsHttpClient, LsHttpTaskDelegate {
    let lock: NSRecursiveLock
    let request: LsHttpTask
    let assembler = LineAssembler()
    let onText: (LsHttp, String) -> Void
    let onError: (LsHttp, String) -> Void
    let onDone: (LsHttp) -> Void
    var m_disposed = false
  
    init(_ lock: NSRecursiveLock, _ url: String,
         body: String,
         headers: [String:String] = [:],
         onText: @escaping (LsHttp, String) -> Void,
         onError: @escaping (LsHttp, String) -> Void,
         onDone: @escaping (LsHttp) -> Void) {
        self.lock = lock
        self.onText = onText
        self.onError = onError
        self.onDone = onDone
        var headers = headers
        headers["Content-Type"] = "text/plain; charset=utf-8"
        if streamLogger.isDebugEnabled {
            if headers.isEmpty {
                streamLogger.debug("HTTP sending: \(url) \(String(reflecting: body))")
            } else {
                streamLogger.debug("HTTP sending: \(url) \(String(reflecting: body)) \(headers)")
            }
        }
        var urlRequest = URLRequest(url: URL(string: url)!)
        urlRequest.httpMethod = "POST"
        for (key, val) in headers {
            urlRequest.setValue(val, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = Data(body.utf8)
        self.request = LsSession.shared.createHttpTask(with: urlRequest)
        request.setDelegate(self)
        request.open()
    }
    
    var disposed: Bool {
        synchronized {
            m_disposed
        }
    }
    
    func dispose() {
        synchronized {
            if streamLogger.isDebugEnabled {
                streamLogger.debug("HTTP disposing")
            }
            m_disposed = true
            request.cancel()
        }
    }
    
    func onTaskText(_ chunk: String) {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            for line in self.assembler.process(chunk) {
                onText(self, line)
            }
        }
    }
    
    func onTaskError(_ error: String) {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            onError(self, error)
        }
    }
    
    func onTaskDone() {
        defaultQueue.async { [weak self] in
            guard let self = self else { return }
            onDone(self)
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
