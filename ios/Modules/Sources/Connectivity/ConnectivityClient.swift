import Foundation

/// Whether the device currently has a usable network route, as reported by the system.
public enum PathStatus: Equatable, Sendable {
    case online
    case offline
    /// Not connected now, but a connection (e.g. VPN on demand, cellular activation) can be made.
    case requiresConnection
}

/// The result of asking a host for its headers.
public struct HostCheck: Equatable, Identifiable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case reachable(statusCode: Int)
        case unreachable(reason: String)
    }

    public var url: URL
    public var outcome: Outcome

    public init(url: URL, outcome: Outcome) {
        self.url = url
        self.outcome = outcome
    }

    public var id: URL {
        url
    }

    public var isReachable: Bool {
        if case .reachable = outcome {
            true
        } else {
            false
        }
    }
}

/// Answers "can this device reach the internet?".
///
/// A struct of closures rather than a protocol, so tests and previews can replace a single
/// endpoint inline: `$0.connectivity.check = { url in HostCheck(url: url, outcome: .reachable(statusCode: 200)) }`.
public struct ConnectivityClient: Sendable {
    /// Emits the current path status immediately, then every time it changes.
    public var pathUpdates: @Sendable () -> AsyncStream<PathStatus>
    /// Sends a `HEAD` request to `url`.
    public var check: @Sendable (_ url: URL) async -> HostCheck

    public init(
        pathUpdates: @escaping @Sendable () -> AsyncStream<PathStatus>,
        check: @escaping @Sendable (_ url: URL) async -> HostCheck,
    ) {
        self.pathUpdates = pathUpdates
        self.check = check
    }
}

// MARK: - Stubs

extension ConnectivityClient {
    /// Always online; every host answers `200`.
    public static let online = ConnectivityClient.stub(path: .online, outcome: .reachable(statusCode: 200))

    /// Always offline; every host fails.
    public static let offline = ConnectivityClient.stub(
        path: .offline,
        outcome: .unreachable(reason: "The Internet connection appears to be offline."),
    )

    /// A client that reports `path` once and answers every check with `outcome`.
    public static func stub(path: PathStatus, outcome: HostCheck.Outcome) -> ConnectivityClient {
        ConnectivityClient(
            pathUpdates: {
                AsyncStream { continuation in
                    continuation.yield(path)
                    continuation.finish()
                }
            },
            check: { url in HostCheck(url: url, outcome: outcome) },
        )
    }
}
