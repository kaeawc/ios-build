import Connectivity
import Dependencies
import Foundation
import Persistence

/// Process-wide setup that must happen before any dependency is used.
public enum AppEnvironment {
    /// Launch argument that UI tests pass to get a deterministic app: an empty in-memory database
    /// and a network that is always online.
    public static let uiTestingArgument = "--ui-testing"

    /// Call once from the `App` initializer.
    public static func bootstrap(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains(uiTestingArgument) else { return }
        let database: AppDatabase
        do {
            database = try .inMemory()
        } catch {
            fatalError("Unable to open an in-memory database for UI tests: \(error)")
        }
        prepareDependencies {
            $0.appDatabase = database
            $0.connectivity = .online
        }
    }
}
