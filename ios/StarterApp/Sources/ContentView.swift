import SwiftUI

struct ContentView: View {
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
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
