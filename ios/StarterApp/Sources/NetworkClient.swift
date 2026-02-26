import Alamofire
import Dependencies
import Foundation

// MARK: - NetworkCheckResult

struct NetworkCheckResult: Sendable, Equatable {
    let host: String
    let isReachable: Bool
    let statusCode: Int?
}

// MARK: - NetworkState

enum NetworkState {
    case idle
    case checking
    case complete([NetworkCheckResult])
}

// MARK: - NetworkClient

protocol NetworkClient: Sendable {
    func checkAll() async -> [NetworkCheckResult]
}

// MARK: - LiveNetworkClient

struct LiveNetworkClient: NetworkClient {
    func checkAll() async -> [NetworkCheckResult] {
        async let dns = checkDNS()
        async let http = checkHTTP()
        return await [dns, http]
    }

    /// Uses NetworkReachabilityManager (SCNetworkReachability) — no HTTP needed.
    private func checkDNS() async -> NetworkCheckResult {
        let isReachable = NetworkReachabilityManager(host: "8.8.8.8")?.isReachable ?? false
        return NetworkCheckResult(host: "8.8.8.8", isReachable: isReachable, statusCode: nil)
    }

    /// Makes a HEAD request to verify application-layer HTTP connectivity.
    private func checkHTTP() async -> NetworkCheckResult {
        let response = await AF.request("https://example.com", method: .head)
            .serializingData()
            .response
        return NetworkCheckResult(
            host: "example.com",
            isReachable: response.response != nil,
            statusCode: response.response?.statusCode
        )
    }
}

// MARK: - DependencyValues

extension DependencyValues {
    var networkClient: any NetworkClient {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }
}

private enum NetworkClientKey: DependencyKey {
    static let liveValue: any NetworkClient = LiveNetworkClient()
}
