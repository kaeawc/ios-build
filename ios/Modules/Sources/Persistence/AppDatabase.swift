import Foundation
import GRDB
import OSLog

/// The app's SQLite database, built on GRDB.
///
/// `AppDatabase` owns the schema (see ``migrator``) and exposes the only ways the rest of the app
/// reads and writes data, so SQL never leaks into features. Get it from the dependency system with
/// `@Dependency(\.appDatabase)`; the app gets an on-disk database, while tests and previews each get
/// a fresh in-memory one.
public struct AppDatabase: Sendable {
    let writer: any DatabaseWriter

    /// Wraps `writer` and migrates it to the latest schema.
    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Read-only access, e.g. for custom observations.
    public var reader: any DatabaseReader {
        writer
    }

    /// The schema history. Never edit a migration that has shipped; append a new one instead.
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
            // Speeds up development by recreating the database whenever a migration changes.
            migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create sessions") { db in
            try db.create(table: Session.databaseTableName) { table in
                table.primaryKey(Session.Columns.id.name, .blob)
                table.column(Session.Columns.launchedAt.name, .datetime).notNull().indexed()
            }
        }
        return migrator
    }
}

// MARK: - Opening

extension AppDatabase {
    /// Opens (creating if needed) the database file in the app's support directory.
    public static func onDisk(fileManager: FileManager = .default) throws -> AppDatabase {
        #if os(tvOS)
            // tvOS has no persistent local storage; the system may purge Caches when space is low.
            // Sync anything you can't afford to lose with iCloud.
            let base = try fileManager.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true,
            )
        #else
            let base = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true,
            )
        #endif
        let folder = base.appending(path: "Database", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appending(path: "db.sqlite").path(percentEncoded: false)

        let pool = try DatabasePool(path: path, configuration: makeConfiguration())
        logger.info("Opened database at \(path, privacy: .public)")
        return try AppDatabase(pool)
    }

    /// A fresh, empty database that lives only as long as the returned value.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: makeConfiguration()))
    }

    private static func makeConfiguration() -> Configuration {
        var configuration = Configuration()
        #if DEBUG
            configuration.prepareDatabase { db in
                db.trace { logger.debug("\($0, privacy: .public)") }
            }
        #endif
        return configuration
    }
}

// MARK: - Writes

extension AppDatabase {
    /// Records that the app launched at `date`.
    @discardableResult
    public func recordLaunch(at date: Date) async throws -> Session {
        let session = Session(launchedAt: date)
        try await writer.write { db in
            try session.insert(db)
        }
        return session
    }

    /// Deletes every recorded launch.
    public func deleteAllSessions() async throws {
        _ = try await writer.write { db in
            try Session.deleteAll(db)
        }
    }
}

// MARK: - Reads

extension AppDatabase {
    /// The launch history, re-emitted every time the `session` table changes.
    public func observeSessionHistory(recentLimit: Int = 20) -> AsyncValueObservation<SessionHistory> {
        ValueObservation
            .tracking { db in
                try SessionHistory(
                    total: Session.fetchCount(db),
                    recent: Session
                        .order(Session.Columns.launchedAt.desc)
                        .limit(recentLimit)
                        .fetchAll(db),
                )
            }
            .removeDuplicates()
            .values(in: writer)
    }

    /// A one-off read of the launch history.
    public func sessionHistory(recentLimit: Int = 20) async throws -> SessionHistory {
        try await writer.read { db in
            try SessionHistory(
                total: Session.fetchCount(db),
                recent: Session.order(Session.Columns.launchedAt.desc).limit(recentLimit).fetchAll(db),
            )
        }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Persistence", category: "Database")
