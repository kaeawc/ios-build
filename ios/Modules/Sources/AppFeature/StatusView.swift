import Connectivity
import SwiftUI

struct StatusView: View {
    let model: AppModel

    var body: some View {
        List {
            Section("Network") {
                LabeledContent("Connection") {
                    PathStatusLabel(status: model.pathStatus)
                }
            }

            Section("Hosts") {
                ForEach(model.hosts, id: \.self) { url in
                    HostRow(url: url, check: check(for: url))
                }
            }

            Section {
                Button("Check Again", systemImage: "arrow.clockwise") {
                    Task { await model.runChecks() }
                }
                .disabled(model.checkState == .checking)
            }
        }
        .navigationTitle("Status")
        .animation(.default, value: model.checkState)
    }

    private func check(for url: URL) -> HostCheck? {
        guard case let .finished(checks) = model.checkState else { return nil }
        return checks.first { $0.url == url }
    }
}

private struct PathStatusLabel: View {
    let status: PathStatus?

    var body: some View {
        switch status {
        case .online:
            Text("Online").foregroundStyle(.green)
        case .offline:
            Text("Offline").foregroundStyle(.red)
        case .requiresConnection:
            Text("Waiting").foregroundStyle(.orange)
        case nil:
            ProgressView()
        }
    }
}

private struct HostRow: View {
    let url: URL
    let check: HostCheck?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(url.host() ?? url.absoluteString)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusIcon
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String? {
        switch check?.outcome {
        case let .reachable(statusCode): "HTTP \(statusCode)"
        case let .unreachable(reason): reason
        case nil: nil
        }
    }

    @ViewBuilder private var statusIcon: some View {
        if let check {
            Image(systemName: check.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(check.isReachable ? .green : .red)
                .accessibilityLabel(check.isReachable ? "Reachable" : "Unreachable")
                .transition(.scale.combined(with: .opacity))
        } else {
            ProgressView()
        }
    }
}

#Preview {
    NavigationStack {
        StatusView(model: AppModel())
    }
}
