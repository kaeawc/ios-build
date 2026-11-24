# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A template for new Apple-platform apps: one SwiftUI codebase for iPhone, iPad, Apple Watch, Apple TV
and Apple Vision Pro. README.md is the user-facing guide; this file is the short version for agents.

## Common Commands

### Setup
```bash
brew bundle && mise install            # tools; versions pinned in mise.toml
git config core.hooksPath .githooks    # pre-commit lint, regenerate project on checkout/merge
bash scripts/ios/xcodegen-generate.sh  # generate ios/StarterApp/StarterApp.xcodeproj (never committed)
```

### Build and test (platform: iOS | iPadOS | tvOS | visionOS | watchOS, default iOS)
```bash
bash scripts/ios/build.sh [platform] [Debug|Release]  # simulator build
bash scripts/ios/test.sh [platform]                   # module tests + UI tests on a simulator
UNIT_TESTS_ONLY=true bash scripts/ios/test.sh tvOS    # skip UI tests
(cd ios/Modules && swift test)                        # module tests on the Mac host, no simulator
bazel test //ios/Modules/...                          # same module tests via Bazel (bazelisk, .bazelversion)
```

### Lint and format
```bash
bash scripts/lint.sh    # everything CI's Lint job runs
bash scripts/format.sh  # SwiftFormat + SwiftLint --fix + buildifier
```

## Architecture

- **`ios/Modules`** — local Swift package holding all app code:
  - `AppFeature` — SwiftUI views (`AppView`, an adaptive `TabView`; `StatusView`; `HistoryView`) and the `@Observable` `AppModel`;
    `.defaultIsolation(MainActor.self)`. `AppEnvironment.bootstrap()` swaps in fakes for `--ui-testing`.
  - `Connectivity` — `ConnectivityClient` (struct of closures): `NWPathMonitor` path updates + Alamofire `HEAD` checks.
  - `Persistence` — `AppDatabase` over GRDB: `Session` record, `DatabaseMigrator`, `ValueObservation` as `AsyncSequence`.
  - Each client module registers a `swift-dependencies` key with live/preview/test values. Test values
    fail on use (connectivity) or are fresh in-memory databases (persistence).
- **Bazel** (migration in progress, issue #14): `MODULE.bazel` (rules_swift/rules_apple/apple_support +
  rules_swift_package_manager reading `Package.swift` + committed `Package.resolved`), `ios/Modules/BUILD.bazel`
  (`swift_library` + `swift_test` per module), shared Swift features in `bazel/swift.bzl`. A new module needs
  entries in both `Package.swift` and `BUILD.bazel`. Regenerate `MODULE.bazel.lock` on a Mac (`bazel mod deps`).
- **`ios/StarterApp`** — XcodeGen spec (`project.yml`) and thin app shells:
  - `StarterApp` target: iOS/iPadOS + tvOS + visionOS via `supportedDestinations`; embeds the watch app (iOS only).
  - `StarterAppWatch` target: watchOS app, independent of the phone.
  - `StarterAppUITests`: XCTest UI tests; the app is launched with `--ui-testing`.
  - Schemes `StarterApp` and `StarterAppWatch` list the package test targets (`package: Modules/<Name>Tests`);
    add new test targets there.
- **Build settings** live in `ios/StarterApp/Configurations/*.xcconfig` (`settingPresets: targets` keeps
  XcodeGen out of project-level settings). Identity (`APP_NAME`, `BUNDLE_ID_PREFIX`, ...) is in `Shared.xcconfig`.
  Deployment targets there must match `platforms` in `Package.swift`.
- **Swift settings** (same in Package.swift and Shared.xcconfig): Swift 6 language mode, approachable
  concurrency (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`), `ExistentialAny`,
  `MemberImportVisibility` (every module whose members you use needs an explicit `import`).
- **Tests**: Swift Testing (`@Test`, `#expect`, raw-identifier names) for modules; XCTest only for UI tests.

## CI (`.github/workflows/ci.yml`)

- **Lint** (ubuntu): `scripts/lint.sh` with mise-installed tools (`swiftlint-static` on Linux).
- **Package tests** (macos-26): `swift test` in `ios/Modules`; fails if `Package.resolved` changes.
- **Bazel (macOS host)** (macos-26): `bazel test //ios/Modules/...`; fails if `MODULE.bazel.lock` is stale.
- **Test** matrix (macos-26, Xcode `XCODE_VERSION`): iOS, iPadOS, tvOS, visionOS, watchOS — generate project,
  `scripts/ios/test.sh <platform>`; iOS also builds Release. xcresult + crash logs uploaded on failure.
- Renovate (`.github/renovate.json`) updates Package.swift, MODULE.bazel, GitHub Actions and mise.toml. Xcode is bumped by hand.

## Code Style
- **SwiftFormat** (`.swiftformat`): 120 columns, 4-space indent, Swift 6.2 rules. Owns all formatting.
- **SwiftLint** (`.swiftlint.yml`): formatting rules disabled; run with `--strict` in CI.
- Shell scripts must work with macOS's bash 3.2 (no `mapfile`; guard empty arrays under `set -u`).

## Logging & Debugging

### OSLog / Logger (Swift)
Use `Logger` from `import OSLog`. Organize by subsystem (bundle ID) and category; each module keeps a private logger:

```swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    static let network  = Logger(subsystem: subsystem, category: "network")
    static let database = Logger(subsystem: subsystem, category: "database")
    static let session  = Logger(subsystem: subsystem, category: "session")
}

Logger.network.info("Status: \(statusCode, privacy: .public)")           // always visible
Logger.session.debug("User: \(userID, privacy: .private(mask: .hash))") // hashed in Console
Logger.database.error("Migration failed: \(error, privacy: .public)")
```

All dynamic values are redacted (`<private>`) outside a debugger unless marked `.public`. Use `.debug`/`.info` freely — they are no-ops in release. Use `.error`/`.fault` for real problems.

Detect test environment at runtime:
```swift
extension ProcessInfo {
    static var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
```

### Simulator Log Streaming (CLI)
```bash
# Stream live logs from the booted simulator, filtered to this app
xcrun simctl spawn booted log stream \
  --level debug --style compact \
  --predicate 'subsystem BEGINSWITH "com.example.StarterApp"'

# Historical logs from the last hour
xcrun simctl spawn booted log show \
  --last 1h --style compact \
  --predicate 'subsystem BEGINSWITH "com.example.StarterApp"'

# Collect a .logarchive as an artifact
xcrun simctl spawn booted log collect \
  --output build/simulator.logarchive --last 30m
```

### Useful simctl Commands
```bash
xcrun simctl launch booted com.example.StarterApp      # launch app
xcrun simctl launch --console booted com.example.StarterApp  # with stdout
xcrun simctl get_app_container booted com.example.StarterApp data  # data dir
xcrun simctl privacy booted grant location com.example.StarterApp  # permissions
xcrun simctl delete unavailable                                  # free disk space
```

### Test Result Bundles (Xcode 16+ API)
```bash
# Pass/fail summary
xcrun xcresulttool get test-results summary --path build/iOS.xcresult

# All tests with status
xcrun xcresulttool get test-results tests --path build/iOS.xcresult

# Extract failing test identifiers
xcrun xcresulttool get test-results tests \
  --path build/iOS.xcresult --format json \
  | jq '[.. | objects | select(.testStatus? == "Failure") | .nodeIdentifier]'
```

Crash logs for simulator runs land in `~/Library/Logs/DiagnosticReports/StarterApp*.crash`.
