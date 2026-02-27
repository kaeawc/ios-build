import XCTest
import XCTestRunner

final class AppLaunchAutoMobileTests: AutoMobileTestCase {
    override var planPath: String {
        "test-plans/launch-app.yaml"
    }

    override var cleanupOptions: AutoMobilePlanExecutor.CleanupOptions? {
        AutoMobilePlanExecutor.CleanupOptions(appId: "dev.jasonpearson.ios.StarterApp", clearAppData: true)
    }

    override func setUpAutoMobile() throws {
        let daemonReady = DaemonManager.ensureDaemonRunning()
        guard daemonReady else {
            throw XCTSkip("AutoMobile daemon is not running and could not be started")
        }
    }

    func testAppLaunchesWithoutCrashing() throws {
        let result = try executePlan()
        XCTAssertTrue(result.success, "Plan failed: \(result.error ?? "unknown error")")
        XCTAssertGreaterThan(result.executedSteps, 0)
    }
}
