import Dependencies
import Foundation

// MARK: - TimerProvider

protocol TimerProvider: Sendable {
    func sleep(for duration: Duration) async throws
}

// MARK: - LiveTimerProvider

struct LiveTimerProvider: TimerProvider {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

// MARK: - DependencyValues

extension DependencyValues {
    var timerProvider: any TimerProvider {
        get { self[TimerProviderKey.self] }
        set { self[TimerProviderKey.self] = newValue }
    }
}

private enum TimerProviderKey: DependencyKey {
    static let liveValue: any TimerProvider = LiveTimerProvider()
}
