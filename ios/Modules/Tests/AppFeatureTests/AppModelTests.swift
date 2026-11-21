import AppFeature
import Connectivity
import Dependencies
import DependenciesTestSupport
import Foundation
import Persistence
import Testing

/// Each test gets a fresh in-memory database (`AppDatabase.testValue`). Network access fails the
/// test unless it is overridden, so the suite starts every test online.
@Suite(.dependencies {
    $0.connectivity = .online
    $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
})
struct AppModelTests {
    @Test
    func `records a launch at the current date`() async throws {
        let model = AppModel()

        await model.recordLaunch()

        @Dependency(\.appDatabase) var database
        let history = try await database.sessionHistory()
        #expect(history.total == 1)
        #expect(history.recent.first?.launchedAt == Date(timeIntervalSince1970: 1_234_567_890))
    }

    @Test
    func `history follows the database`() async throws {
        let model = AppModel()
        let observation = Task { await model.observeHistory() }
        defer { observation.cancel() }

        await model.recordLaunch()
        try await waitUntil { model.history.total == 1 }

        await model.clearHistory()
        try await waitUntil { model.history.recent.isEmpty }
        #expect(model.history.total == 0)
    }

    @Test
    func `checks every host and keeps their order`() async throws {
        let reachable = try #require(URL(string: "https://up.test"))
        let unreachable = try #require(URL(string: "https://down.test"))
        let model = withDependencies {
            $0.connectivity.check = { url in
                url == unreachable
                    ? HostCheck(url: url, outcome: .unreachable(reason: "Timed out"))
                    : HostCheck(url: url, outcome: .reachable(statusCode: 200))
            }
        } operation: {
            AppModel(hosts: [unreachable, reachable])
        }
        #expect(model.checkState == .idle)

        await model.runChecks()

        #expect(model.checkState == .finished([
            HostCheck(url: unreachable, outcome: .unreachable(reason: "Timed out")),
            HostCheck(url: reachable, outcome: .reachable(statusCode: 200)),
        ]))
    }

    @Test(.dependency(\.connectivity, .offline))
    func `publishes the path status`() async {
        let model = AppModel()
        #expect(model.pathStatus == nil)

        await model.observePath()

        #expect(model.pathStatus == .offline)
    }
}

/// Polls `condition` until it holds, recording an issue if it doesn't within `timeout`.
private func waitUntil(
    timeout: Duration = .seconds(5),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool,
)
    async throws
{
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(timeout)", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
