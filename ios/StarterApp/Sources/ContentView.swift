import SQLiteData
import SwiftUI

struct ContentView: View {
    let networkResults: [NetworkCheckResult]

    @FetchOne(Session.count()) var sessionCount = 0

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "swift")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("iOS Build")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A starter iOS app for experimenting\nwith build tooling and CI.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.horizontal)

            HStack {
                Image(systemName: "number.circle")
                    .foregroundStyle(.secondary)
                Text("Launch \(sessionCount)")
                    .font(.headline)
            }

            if !networkResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(networkResults, id: \.host) { result in
                        HStack(spacing: 8) {
                            Image(systemName: result.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.isReachable ? Color.green : Color.red)
                            Text(result.host)
                                .font(.subheadline)
                            Spacer()
                            if let code = result.statusCode {
                                Text("HTTP \(code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(networkResults: [])
}
