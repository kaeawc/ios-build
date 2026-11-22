import AppFeature
import SwiftUI

/// Entry point for Apple Watch. Shares `AppView` with every other platform.
@main
struct StarterAppWatch: App {
    init() {
        AppEnvironment.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
