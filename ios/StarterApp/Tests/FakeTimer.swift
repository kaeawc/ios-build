import Foundation

@testable import StarterApp

final class FakeTimer: TimerProvider {
    private(set) var sleepCallCount = 0
    private(set) var sleepDurations: [Duration] = []
    var shouldThrow: Error?

    func sleep(for duration: Duration) async throws {
        sleepCallCount += 1
        sleepDurations.append(duration)
        if let error = shouldThrow {
            throw error
        }
        // Returns immediately — no real sleep
    }
}
