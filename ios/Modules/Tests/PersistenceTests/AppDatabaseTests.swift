import Foundation
import GRDB
import Persistence
import Testing

struct AppDatabaseTests {
    let database: AppDatabase

    init() throws {
        database = try .inMemory()
    }

    @Test
    func `migrates to latest schema`() throws {
        let columns = try database.reader.read { db in
            try db.columns(in: "session").map(\.name)
        }
        #expect(columns == ["id", "launchedAt"])
    }

    @Test
    func `records launches newest first`() async throws {
        let first = try await database.recordLaunch(at: Date(timeIntervalSince1970: 1000))
        let second = try await database.recordLaunch(at: Date(timeIntervalSince1970: 2000))

        let history = try await database.sessionHistory()

        #expect(history.total == 2)
        #expect(history.recent == [second, first])
    }

    @Test
    func `limits recent sessions but counts all`() async throws {
        for second in 1 ... 5 {
            try await database.recordLaunch(at: Date(timeIntervalSince1970: Double(second)))
        }

        let history = try await database.sessionHistory(recentLimit: 3)

        #expect(history.total == 5)
        #expect(history.recent.map(\.launchedAt.timeIntervalSince1970) == [5, 4, 3])
    }

    @Test
    func `deletes all sessions`() async throws {
        try await database.recordLaunch(at: Date(timeIntervalSince1970: 1))
        try await database.recordLaunch(at: Date(timeIntervalSince1970: 2))

        try await database.deleteAllSessions()

        #expect(try await database.sessionHistory() == SessionHistory())
    }

    @Test
    func `observation emits on every change`() async throws {
        var updates = database.observeSessionHistory().makeAsyncIterator()
        #expect(try await updates.next()?.total == 0)

        try await database.recordLaunch(at: Date(timeIntervalSince1970: 1))
        #expect(try await updates.next()?.total == 1)

        try await database.deleteAllSessions()
        #expect(try await updates.next()?.total == 0)
    }

    @Test
    func `in memory databases are isolated`() async throws {
        let other = try AppDatabase.inMemory()

        try await database.recordLaunch(at: Date(timeIntervalSince1970: 1))

        #expect(try await database.sessionHistory().total == 1)
        #expect(try await other.sessionHistory().total == 0)
    }
}
