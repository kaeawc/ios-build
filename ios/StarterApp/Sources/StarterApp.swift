import SQLiteData
import SwiftUI

@main
struct StarterApp: App {
    private let database: DatabaseQueue
    @State private var networkResults: [NetworkCheckResult] = []

    init() {
        do {
            database = try DatabaseQueue.makeAppDatabase()
        } catch {
            fatalError("Failed to open app database: \(error)")
        }
        prepareDependencies {
            $0.defaultDatabase = database
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(networkResults: networkResults)
                .task {
                    do {
                        try await database.write { db in
                            try Session.insert {
                                Session(id: UUID(), launchedAt: Date())
                            }
                            .execute(db)
                        }
                    } catch {
                        print("Session insert failed: \(error)")
                    }
                    networkResults = await NetworkChecker.checkAll()
                }
        }
    }
}
