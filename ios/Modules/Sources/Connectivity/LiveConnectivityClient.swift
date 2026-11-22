import Alamofire
import Dispatch
import Foundation
import Network

extension ConnectivityClient {
    /// The real client: `NWPathMonitor` for path status and Alamofire for HTTP.
    ///
    /// - Parameter session: The Alamofire session used for checks. Tests pass one whose
    ///   `URLSessionConfiguration.protocolClasses` contains a stub `URLProtocol`.
    public static func live(session: Alamofire.Session = .connectivity) -> ConnectivityClient {
        ConnectivityClient(
            pathUpdates: {
                AsyncStream { continuation in
                    let monitor = NWPathMonitor()
                    monitor.pathUpdateHandler = { path in
                        continuation.yield(PathStatus(path.status))
                    }
                    continuation.onTermination = { _ in monitor.cancel() }
                    monitor.start(queue: DispatchQueue(label: "Connectivity.NWPathMonitor"))
                }
            },
            check: { url in
                let response = await session.request(url, method: .head).serializingData().response
                if let statusCode = response.response?.statusCode {
                    return HostCheck(url: url, outcome: .reachable(statusCode: statusCode))
                }
                let reason = response.error.map { $0.underlyingError?.localizedDescription ?? $0.localizedDescription }
                return HostCheck(url: url, outcome: .unreachable(reason: reason ?? "No response"))
            },
        )
    }
}

extension PathStatus {
    init(_ status: NWPath.Status) {
        switch status {
        case .satisfied: self = .online
        case .requiresConnection: self = .requiresConnection
        case .unsatisfied: self = .offline
        @unknown default: self = .offline
        }
    }
}

extension Alamofire.Session {
    /// A session tuned for quick reachability checks: short timeouts and no waiting for a
    /// connection to appear.
    public static let connectivity: Alamofire.Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 10
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Alamofire.Session(configuration: configuration)
    }()
}
