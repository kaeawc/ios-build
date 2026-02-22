import XCTest

@testable import StarterApp

final class StarterAppTests: XCTestCase {
    func testExample() {
        // Basic test to verify the module loads correctly.
        XCTAssertTrue(true)
    }

    func testContentViewCreation() {
        // Verify ContentView can be instantiated without crashing.
        let view = ContentView()
        XCTAssertNotNil(view)
    }
}
