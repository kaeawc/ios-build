import XCTest

/// End-to-end tests against the real app. `--ui-testing` makes the app use an empty in-memory
/// database and a network stub that is always online (see `AppEnvironment.bootstrap`), so results
/// don't depend on the machine or its connection.
final class StarterAppUITests: XCTestCase {
    @MainActor
    func testShowsNetworkStatusOnLaunch() {
        let app = launchApp()

        // Match by substring: tvOS merges a LabeledContent row into one element ("Connection, Online").
        XCTAssertTrue(app.staticTexts.firstMatch(labelContaining: "Online").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.firstMatch(labelContaining: "HTTP 200").waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "Status")
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
            // The label is "1", or "Total launches, 1" where the row is merged into one element.
            XCTAssertEqual(total.label.components(separatedBy: ", ").last, "1")
            attachScreenshot(of: app, named: "Launch History")
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

    /// Keeps a screenshot in the result bundle even when the test passes; CI exports them as the
    /// `screenshots-<platform>` artifact.
    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElementQuery {
    /// The first element whose label contains `text`.
    fileprivate func firstMatch(labelContaining text: String) -> XCUIElement {
        matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
