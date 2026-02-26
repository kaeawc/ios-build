import Dependencies
import SQLiteData
import SwiftUI

@main
struct StarterApp: App {
    private let database: DatabaseQueue
    @State private var networkState: NetworkState = .idle
    @Dependency(\.date) var date
    @Dependency(\.networkClient) var networkClient

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
            ContentView(networkState: networkState)
                .task {
                    do {
                        try await database.write { db in
                            try Session.insert {
                                Session(id: UUID(), launchedAt: date.now)
                            }
                            .execute(db)
                        }
                    } catch {
                        print("Session insert failed: \(error)")
                    }
                    withAnimation {
                        networkState = .checking
                    }
                    let results = await networkClient.checkAll()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        networkState = .complete(results)
                    }
                }
        }
    }
}
