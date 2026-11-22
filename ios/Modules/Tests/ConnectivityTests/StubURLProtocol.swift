import Alamofire
import Foundation
import Synchronization

/// A `URLProtocol` that answers every request from an in-process handler.
final class StubURLProtocol: URLProtocol {
    /// A status code to respond with, or an error to fail with.
    typealias Handler = @Sendable (URLRequest) -> Result<Int, URLError>

    private struct State {
        var handler: Handler?
        var requests: [URLRequest] = []
    }

    private static let state = Mutex(State())

    /// Every request received since the last call to ``session(handler:)``.
    static var requests: [URLRequest] {
        state.withLock(\.requests)
    }

    /// An Alamofire session whose requests are all answered by `handler`.
    static func session(handler: @escaping Handler) -> Alamofire.Session {
        state.withLock { $0 = State(handler: handler) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return Alamofire.Session(configuration: configuration)
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.state.withLock { state in
            state.requests.append(request)
            return state.handler
        }
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request) {
        case let .success(statusCode):
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
