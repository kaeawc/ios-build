import Dependencies
import SwiftUI

/// The root view on every platform.
///
/// `NavigationSplitView` adapts on its own: a sidebar next to the detail on iPad, Apple TV and
/// Apple Vision Pro, and a navigation stack on iPhone, Apple Watch and narrow iPad windows.
public struct AppView: View {
    enum Destination: String, CaseIterable, Identifiable {
        case status
        case history

        var id: Self {
            self
        }

        var title: LocalizedStringKey {
            switch self {
            case .status: "Status"
            case .history: "Launch History"
            }
        }

        var systemImage: String {
            switch self {
            case .status: "network"
            case .history: "clock.arrow.circlepath"
            }
        }
    }

    @State private var model = AppModel()
    @State private var selection: Destination? = .status
    @State private var preferredColumn = NavigationSplitViewColumn.detail

    public init() {}

    public var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            List(Destination.allCases, selection: $selection) { destination in
                NavigationLink(value: destination) {
                    Label(destination.title, systemImage: destination.systemImage)
                }
            }
            .navigationTitle("StarterApp")
        } detail: {
            switch selection {
            case .status:
                StatusView(model: model)
            case .history:
                HistoryView(model: model)
            case nil:
                ContentUnavailableView("Choose a section", systemImage: "sidebar.left")
            }
        }
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
