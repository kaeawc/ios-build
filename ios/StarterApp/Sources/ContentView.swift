import SQLiteData
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    let networkState: NetworkState

    @FetchOne(Session.count()) var sessionCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                    .padding(.top, 16)
                sessionCard
                networkCard
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "swift")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("iOS Build")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("A starter iOS app for experimenting\nwith build tooling and CI.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var sessionCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("App Launches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(sessionCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                    .animation(.default, value: sessionCount)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            networkCardHeader
            networkCardBody
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var networkCardHeader: some View {
        HStack {
            Label("Network", systemImage: "network")
                .font(.headline)
            Spacer()
            networkOverallStatus
        }
    }

    @ViewBuilder private var networkOverallStatus: some View {
        switch networkState {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .controlSize(.mini)
        case let .complete(results):
            Image(
                systemName: results.allSatisfy(\.isReachable)
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle.fill"
            )
            .foregroundStyle(results.allSatisfy(\.isReachable) ? Color.green : Color.yellow)
        }
    }

    @ViewBuilder private var networkCardBody: some View {
        switch networkState {
        case .idle:
            Text("Waiting to check…")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .checking:
            networkRows(for: nil)
        case let .complete(results):
            networkRows(for: results)
        }
    }

    private func networkRows(for results: [NetworkCheckResult]?) -> some View {
        VStack(spacing: 0) {
            NetworkRow(host: "8.8.8.8", result: results?.first { $0.host == "8.8.8.8" })
            Divider().padding(.leading, 44)
            NetworkRow(host: "example.com", result: results?.first { $0.host == "example.com" })
        }
    }
}

// MARK: - NetworkRow

struct NetworkRow: View {
    let host: String
    let result: NetworkCheckResult?

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(host)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let code = result?.statusCode {
                    Text("HTTP \(code)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let result {
                Text(result.isReachable ? "Online" : "Offline")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(result.isReachable ? Color.green : Color.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var statusIcon: some View {
        if let result {
            Image(systemName: result.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.isReachable ? Color.green : Color.red)
                .font(.system(size: 20))
                .transition(.scale.combined(with: .opacity))
        } else {
            PulsingIndicator()
        }
    }
}

// MARK: - PulsingIndicator

struct PulsingIndicator: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.25))
                .scaleEffect(animate ? 1.8 : 1.0)
                .opacity(animate ? 0.0 : 1.0)
            Circle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 14, height: 14)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
    ContentView(networkState: .idle)
}

#Preview("Checking") {
    ContentView(networkState: .checking)
}

#Preview("Online") {
    ContentView(networkState: .complete([
        NetworkCheckResult(host: "8.8.8.8", isReachable: true, statusCode: nil),
        NetworkCheckResult(host: "example.com", isReachable: true, statusCode: 200),
    ]))
}

#Preview("Offline") {
    ContentView(networkState: .complete([
        NetworkCheckResult(host: "8.8.8.8", isReachable: false, statusCode: nil),
        NetworkCheckResult(host: "example.com", isReachable: false, statusCode: nil),
    ]))
}
