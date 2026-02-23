import Dependencies
import SQLiteData
import XCTest

@testable import StarterApp

final class StarterAppTests: XCTestCase {
    func testExample() {
        // Basic test to verify the module loads correctly.
        XCTAssertTrue(true)
    }

    func testContentViewCreation() throws {
        // Verify ContentView can be instantiated with an in-memory test database.
        try withDependencies {
            $0.defaultDatabase = try DatabaseQueue()
        } operation: {
            let view = ContentView(networkState: .idle)
            XCTAssertNotNil(view)
        }
    }
}
