import Dependencies
import Foundation
import GRDB

extension AppDatabase: DependencyKey {
    public static let liveValue: AppDatabase = {
        do {
            return try .onDisk()
        } catch {
            // Replace this with recovery that suits your app, e.g. moving the damaged file aside and
            // starting over, before shipping.
            fatalError("Unable to open the app database: \(error)")
        }
    }()

    /// Every test gets its own empty database.
    public static var testValue: AppDatabase {
        makeInMemory()
    }

    /// Previews start with a few launches so there is something to look at.
    public static var previewValue: AppDatabase {
        let database = makeInMemory()
        do {
            try database.writer.write { db in
                for hoursAgo in [1.0, 26.0, 74.0] {
                    try Session(launchedAt: Date(timeIntervalSinceNow: -hoursAgo * 3600)).insert(db)
                }
            }
        } catch {
            fatalError("Unable to seed the preview database: \(error)")
        }
        return database
    }

    private static func makeInMemory() -> AppDatabase {
        do {
            return try .inMemory()
        } catch {
            fatalError("Unable to open an in-memory database: \(error)")
        }
    }
}

extension DependencyValues {
    /// The app's database. Override it in tests with `.dependency(\.appDatabase, try .inMemory())`.
    public var appDatabase: AppDatabase {
        get { self[AppDatabase.self] }
        set { self[AppDatabase.self] = newValue }
    }
}
