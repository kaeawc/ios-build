import XCTest

/// End-to-end tests against the real app. `--ui-testing` makes the app use an empty in-memory
/// database and a network stub that is always online (see `AppEnvironment.bootstrap`), so results
/// don't depend on the machine or its connection.
final class StarterAppUITests: XCTestCase {
    @MainActor
    func testShowsNetworkStatusOnLaunch() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Online"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["HTTP 200"].firstMatch.waitForExistence(timeout: 10))
    }

    #if !os(tvOS) // tvOS has no touch input; drive it with XCUIRemote instead.
        @MainActor
        func testRecordsTheLaunchInHistory() {
            let app = launchApp()

            let historyLink = app.buttons["Launch History"]
            if !historyLink.waitForExistence(timeout: 2) {
                // Compact width (iPhone): the detail column is showing, so go back to the sidebar.
                app.navigationBars.buttons.firstMatch.tap()
            }
            historyLink.tap()

            let total = app.staticTexts["history.total"]
            XCTAssertTrue(total.waitForExistence(timeout: 10))
            XCTAssertEqual(total.label, "1")
        }
    #endif

    @MainActor
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }
}
