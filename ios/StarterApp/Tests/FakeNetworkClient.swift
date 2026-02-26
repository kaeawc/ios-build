import Foundation

@testable import StarterApp

struct FakeNetworkClient: NetworkClient {
    var results: [NetworkCheckResult]

    init(results: [NetworkCheckResult] = []) {
        self.results = results
    }

    func checkAll() async -> [NetworkCheckResult] {
        results
    }
}
