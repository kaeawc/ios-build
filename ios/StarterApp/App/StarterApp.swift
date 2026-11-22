import AppFeature
import SwiftUI

/// Entry point for iPhone, iPad, Apple TV and Apple Vision Pro. All app code lives in the
/// `AppFeature` module (ios/Modules); this target only hosts it.
@main
struct StarterApp: App {
    init() {
        AppEnvironment.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
