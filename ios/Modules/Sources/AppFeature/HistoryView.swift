import SwiftUI

struct HistoryView: View {
    let model: AppModel

    var body: some View {
        List {
            Section {
                LabeledContent("Total launches") {
                    Text(model.history.total, format: .number)
                        .accessibilityIdentifier("history.total")
                }
            }

            Section("Recent") {
                ForEach(model.history.recent) { session in
                    Text(session.launchedAt, format: .dateTime.weekday().month().day().hour().minute())
                }
            }

            Section {
                Button("Clear History", systemImage: "trash", role: .destructive) {
                    Task { await model.clearHistory() }
                }
                .disabled(model.history.total == 0)
            }
        }
        .navigationTitle("Launch History")
        .animation(.default, value: model.history)
    }
}

#Preview {
    let model = AppModel()
    NavigationStack {
        HistoryView(model: model)
    }
    .task { await model.observeHistory() }
}
