import Connectivity
import Dependencies
import Foundation
import Observation
import OSLog
import Persistence

/// State and behavior behind ``AppView``.
///
/// An `@Observable` class: SwiftUI re-renders exactly the views that read a property when it
/// changes. Its collaborators come from `swift-dependencies`, so tests replace them with
/// `withDependencies { ... } operation: { AppModel() }`.
@Observable
public final class AppModel {
    public enum CheckState: Equatable {
        case idle
        case checking
        case finished([HostCheck])
    }

    /// The hosts ``runChecks()`` sends a `HEAD` request to.
    public static let defaultHosts = [
        URL(string: "https://www.apple.com")!,
        URL(string: "https://example.com")!,
    ]

    public let hosts: [URL]
    public private(set) var history = SessionHistory()
    public private(set) var pathStatus: PathStatus?
    public private(set) var checkState = CheckState.idle

    @ObservationIgnored @Dependency(\.appDatabase) private var database
    @ObservationIgnored @Dependency(\.connectivity) private var connectivity
    @ObservationIgnored @Dependency(\.date.now) private var now

    public init(hosts: [URL] = AppModel.defaultHosts) {
        self.hosts = hosts
    }

    /// Everything the root view does while it is on screen: records the launch, then keeps the
    /// history and network status current until the calling task is cancelled.
    public func task() async {
        await recordLaunch()
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeHistory() }
            group.addTask { await self.observePath() }
            group.addTask { await self.runChecks() }
        }
    }

    public func recordLaunch() async {
        do {
            try await database.recordLaunch(at: now)
        } catch {
            logger.error("Failed to record launch: \(error, privacy: .public)")
        }
    }

    public func clearHistory() async {
        do {
            try await database.deleteAllSessions()
        } catch {
            logger.error("Failed to clear history: \(error, privacy: .public)")
        }
    }

    /// Checks every host concurrently and publishes the results in ``hosts`` order.
    public func runChecks() async {
        checkState = .checking
        let connectivity = connectivity
        let results = await withTaskGroup(of: HostCheck.self) { group in
            for url in hosts {
                group.addTask { await connectivity.check(url) }
            }
            var results: [URL: HostCheck] = [:]
            for await check in group {
                results[check.url] = check
            }
            return results
        }
        checkState = .finished(hosts.compactMap { results[$0] })
    }

    /// Keeps ``history`` in sync with the database until the calling task is cancelled.
    public func observeHistory() async {
        do {
            for try await history in database.observeSessionHistory() {
                self.history = history
            }
        } catch {
            logger.error("Launch history observation failed: \(error, privacy: .public)")
        }
    }

    /// Keeps ``pathStatus`` current until the calling task is cancelled.
    public func observePath() async {
        for await status in connectivity.pathUpdates() {
            pathStatus = status
        }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppFeature", category: "AppModel")
