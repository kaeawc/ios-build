import Dependencies
import SQLiteData
import XCTest

@testable import StarterApp

final class StarterAppTests: XCTestCase {
    // MARK: - Session Tests

    func testSessionInsert() async throws {
        let queue = try DatabaseQueue.makeInMemoryDatabase()
        let session = Session(id: UUID(), launchedAt: Date())
        try await queue.write { database in
            try Session.insert { session }.execute(database)
        }
        let count = try await queue.read { try Session.count().fetchOne($0) }
        XCTAssertEqual(count, 1)
    }

    func testMultipleSessionInserts() async throws {
        let queue = try DatabaseQueue.makeInMemoryDatabase()
        for _ in 0 ..< 3 {
            try await queue.write { database in
                try Session.insert { Session(id: UUID(), launchedAt: Date()) }.execute(database)
            }
        }
        let count = try await queue.read { try Session.count().fetchOne($0) }
        XCTAssertEqual(count, 3)
    }

    // MARK: - Network Tests

    func testFakeNetworkClientReturnsConfiguredResults() async {
        let expected = [
            NetworkCheckResult(host: "8.8.8.8", isReachable: true, statusCode: nil),
            NetworkCheckResult(host: "example.com", isReachable: true, statusCode: 200),
        ]
        let client = FakeNetworkClient(results: expected)
        let actual = await client.checkAll()
        XCTAssertEqual(actual, expected)
    }

    func testFakeNetworkClientOfflineResults() async {
        let client = FakeNetworkClient(results: [
            NetworkCheckResult(host: "8.8.8.8", isReachable: false, statusCode: nil),
            NetworkCheckResult(host: "example.com", isReachable: false, statusCode: nil),
        ])
        let results = await client.checkAll()
        XCTAssertFalse(results.allSatisfy(\.isReachable))
    }

    func testNetworkClientDependencyCanBeOverridden() async throws {
        let fake = FakeNetworkClient(results: [
            NetworkCheckResult(host: "8.8.8.8", isReachable: true, statusCode: nil),
        ])
        try await withDependencies {
            $0.networkClient = fake
            $0.defaultDatabase = try DatabaseQueue()
        } operation: {
            @Dependency(\.networkClient) var client
            let results = await client.checkAll()
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results[0].host, "8.8.8.8")
            XCTAssertTrue(results[0].isReachable)
        }
    }

    // MARK: - Timer Tests

    func testFakeTimerRecordsSleepDuration() async throws {
        let timer = FakeTimer()
        try await timer.sleep(for: .seconds(5))
        XCTAssertEqual(timer.sleepCallCount, 1)
        XCTAssertEqual(timer.sleepDurations, [.seconds(5)])
    }

    func testFakeTimerCanThrow() async {
        let timer = FakeTimer()
        timer.shouldThrow = CancellationError()
        do {
            try await timer.sleep(for: .seconds(10))
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(timer.sleepCallCount, 1)
        }
    }

    func testTimerProviderDependencyCanBeOverridden() async throws {
        let timer = FakeTimer()
        try await withDependencies {
            $0.timerProvider = timer
        } operation: {
            @Dependency(\.timerProvider) var provider
            try await provider.sleep(for: .seconds(999))
            XCTAssertEqual(timer.sleepCallCount, 1)
            XCTAssertEqual(timer.sleepDurations, [.seconds(999)])
        }
    }
}
