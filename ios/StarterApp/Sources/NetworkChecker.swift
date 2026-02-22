import Alamofire
import Foundation

struct NetworkCheckResult {
    let host: String
    let isReachable: Bool
    let statusCode: Int?
}

enum NetworkChecker {
    /// Checks connectivity to 8.8.8.8 (network layer) and example.com (HTTP).
    static func checkAll() async -> [NetworkCheckResult] {
        async let dns = check8888()
        async let http = checkExampleCom()
        return await [dns, http]
    }

    // Uses NetworkReachabilityManager (SCNetworkReachability) — no HTTP needed.
    private static func check8888() async -> NetworkCheckResult {
        let isReachable = NetworkReachabilityManager(host: "8.8.8.8")?.isReachable ?? false
        return NetworkCheckResult(host: "8.8.8.8", isReachable: isReachable, statusCode: nil)
    }

    // Makes a HEAD request to verify application-layer HTTP connectivity.
    private static func checkExampleCom() async -> NetworkCheckResult {
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
