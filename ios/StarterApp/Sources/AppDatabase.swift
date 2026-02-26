import Foundation
import SQLiteData

extension DatabaseQueue {
    static func makeAppDatabase() throws -> DatabaseQueue {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "StarterApp",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let db = try DatabaseQueue(path: dir.appendingPathComponent("app.sqlite").path)
        try migrate(db)
        return db
    }

    static func makeInMemoryDatabase() throws -> DatabaseQueue {
        let db = try DatabaseQueue()
        try migrate(db)
        return db
    }

    private static func migrate(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "session") { t in
                t.primaryKey("id", .text)
                t.column("launchedAt", .datetime).notNull()
            }
        }
        try migrator.migrate(db)
    }
}
