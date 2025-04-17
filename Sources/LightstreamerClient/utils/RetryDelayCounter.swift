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

// not thread-safe
class RetryDelayCounter {
    var attempt: Int
    var currentRetryDelay: Millis

    init() {
        attempt = 1
        currentRetryDelay = 0
    }

    func increase() {
        if attempt > 10 {
            if currentRetryDelay < 60_000 {
                if currentRetryDelay * 2 < 60_000 {
                    currentRetryDelay *= 2
                } else {
                    currentRetryDelay = 60_000
                }
            }
        } else {
            attempt += 1
        }
    }

    func reset(_ retryDelay: Millis) {
        attempt = 1
        currentRetryDelay = retryDelay
    }
}
