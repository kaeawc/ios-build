import XCTest

@testable import StarterApp

final class StarterAppTests: XCTestCase {
    func testExample() throws {
        // Basic test to verify the module loads correctly.
        XCTAssertTrue(true)
    }

    func testContentViewCreation() throws {
        // Verify ContentView can be instantiated without crashing.
        let view = ContentView()
        XCTAssertNotNil(view)
    }
}
