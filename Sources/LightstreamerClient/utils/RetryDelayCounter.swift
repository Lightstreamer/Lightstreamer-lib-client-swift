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
