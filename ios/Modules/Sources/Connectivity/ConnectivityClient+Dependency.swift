import Dependencies
import Foundation

extension ConnectivityClient: DependencyKey {
    public static let liveValue = ConnectivityClient.live()

    public static let previewValue = ConnectivityClient.online

    /// Fails any test that reaches the network without overriding this dependency first.
    public static let testValue = ConnectivityClient(
        pathUpdates: {
            reportIssue("Unimplemented: ConnectivityClient.pathUpdates")
            return AsyncStream { $0.finish() }
        },
        check: { url in
            reportIssue("Unimplemented: ConnectivityClient.check(\(url))")
            return HostCheck(url: url, outcome: .unreachable(reason: "Unimplemented"))
        },
    )
}

extension DependencyValues {
    public var connectivity: ConnectivityClient {
        get { self[ConnectivityClient.self] }
        set { self[ConnectivityClient.self] = newValue }
    }
}
