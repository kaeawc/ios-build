import Alamofire
import Connectivity
import Foundation
import Testing

/// Exercises the real Alamofire code path against a stub `URLProtocol`, so nothing leaves the
/// machine. Serialized because the stub's handler is shared state.
@Suite(.serialized)
struct LiveConnectivityClientTests {
    let url = URL(string: "https://host.test/health")!

    @Test
    func `reports the status code of a HEAD request`() async {
        let client = ConnectivityClient.live(session: StubURLProtocol.session { _ in .success(204) })

        let check = await client.check(url)

        #expect(check == HostCheck(url: url, outcome: .reachable(statusCode: 204)))
        #expect(StubURLProtocol.requests.map(\.httpMethod) == ["HEAD"])
        #expect(StubURLProtocol.requests.map(\.url) == [url])
    }

    @Test
    func `treats server errors as reachable`() async {
        let client = ConnectivityClient.live(session: StubURLProtocol.session { _ in .success(503) })

        let check = await client.check(url)

        #expect(check.outcome == .reachable(statusCode: 503))
    }

    @Test
    func `reports why a host is unreachable`() async {
        let client = ConnectivityClient.live(
            session: StubURLProtocol.session { _ in .failure(URLError(.notConnectedToInternet)) },
        )

        let check = await client.check(url)

        #expect(!check.isReachable)
        guard case let .unreachable(reason) = check.outcome else {
            Issue.record("Expected an unreachable outcome, got \(check.outcome)")
            return
        }
        #expect(reason == URLError(.notConnectedToInternet).localizedDescription)
    }
}

struct ConnectivityStubTests {
    @Test
    func `stub reports its path once and finishes`() async {
        var statuses: [PathStatus] = []
        for await status in ConnectivityClient.offline.pathUpdates() {
            statuses.append(status)
        }
        #expect(statuses == [.offline])
    }
}
