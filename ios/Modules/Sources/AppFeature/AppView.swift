import Connectivity
import Dependencies
import SwiftUI

/// The root view on every platform.
///
/// A `TabView` of top-level sections adapts to each platform: a tab bar on iPhone, a tab bar that
/// turns into a sidebar on iPad (`.sidebarAdaptable`), a top tab bar on Apple TV, an ornament on
/// Apple Vision Pro, and vertical pages on Apple Watch.
public struct AppView: View {
    enum Destination: Hashable {
        case status
        case history
    }

    @State private var model = AppModel()
    @State private var selection = Destination.status

    public init() {}

    public var body: some View {
        TabView(selection: $selection) {
            Tab("Status", systemImage: "network", value: .status) {
                NavigationStack {
                    StatusView(model: model)
                }
            }
            Tab("Launch History", systemImage: "clock.arrow.circlepath", value: .history) {
                NavigationStack {
                    HistoryView(model: model)
                }
            }
        }
        #if os(iOS)
        .tabViewStyle(.sidebarAdaptable)
        #endif
        .task { await model.task() }
    }
}

#Preview("Online") {
    AppView()
}

#Preview("Offline") {
    // swiftlint:disable:next redundant_discardable_let
    let _ = prepareDependencies { $0.connectivity = .offline }
    AppView()
}
