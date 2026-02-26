# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Setup
```bash
brew bundle                          # Install required tools (shellcheck, swiftformat, swiftlint, xmlstarlet, xcodegen, yamllint)
git config core.hooksPath .githooks  # Install git hooks
bash scripts/ios/xcodegen-generate.sh  # Generate .xcodeproj from project.yml (required before opening in Xcode)
```

### Building
```bash
bash scripts/ios/xcode-build.sh              # Debug build for iOS Simulator
bash scripts/ios/xcode-build-for-testing.sh  # Build test artifacts
bash scripts/ios/xcode-build-release.sh      # Release build
bash scripts/ios/create-ipa.sh <output.ipa>  # Package IPA from Debug build
```

### Testing
```bash
bash scripts/ios/xcode-test.sh                   # Build and run unit tests
bash scripts/ios/xcode-test-without-building.sh  # Run tests against pre-built binaries
```

### Validation
```bash
ONLY_TOUCHED_FILES=false bash scripts/shellcheck/validate_shell_scripts.sh  # Validate all shell scripts + git hooks
ONLY_TOUCHED_FILES=false bash scripts/swiftformat/validate_swiftformat.sh   # Check Swift formatting
ONLY_TOUCHED_FILES=false bash scripts/swiftlint/validate_swiftlint.sh       # Lint Swift files
bash scripts/xml/validate_xml.sh    # Validate XML and plist files
bash scripts/yaml/validate_yaml.sh  # Validate YAML files
```

## Architecture

### Project Generation
The `.xcodeproj` is **not committed**. It is generated from `ios/StarterApp/project.yml` using XcodeGen. Always regenerate after changing `project.yml` or after `post-checkout`/`post-merge` git hooks do it automatically.

### iOS App (`ios/StarterApp/`)
Small starter app used to validate build infrastructure. Key source files:

- **`StarterApp.swift`** — `@main` entry point; initializes `AppDatabase`, records a `Session`, and kicks off network checks
- **`ContentView.swift`** — SwiftUI view showing session count (via `@FetchOne`) and animated network status indicators
- **`AppDatabase.swift`** — Creates `DatabaseQueue` with SQLiteData migrations; injectable via `swift-dependencies`
- **`Session.swift`** — `@Table` SQLiteData model representing an app launch (UUID + timestamp)
- **`NetworkChecker.swift`** — Async utilities for DNS reachability (8.8.8.8) and HTTP reachability (example.com) using Alamofire

### Dependencies (SPM, declared in `project.yml`)
- **Alamofire** 5.9.1+ — HTTP networking
- **SQLiteData** 1.6.0+ — Type-safe SQLite wrapper (Point-Free, wraps GRDB)
- **swift-dependencies** 1.0.0+ — Dependency injection (test target only)

### Dependency Injection Pattern
`AppDatabase` is registered as a dependency with `swift-dependencies`. Tests use `withDependencies { $0.database = .inMemory } operation: { ... }` to inject an in-memory database.

### Build Configurations
- **`Configurations/Debug.xcconfig`** — `-Onone`, single-file compilation, testability enabled, active arch only
- **`Configurations/Release.xcconfig`** — `-O`, whole-module optimization, dSYM output, all architectures

Notable build flags applied in scripts (all build/test scripts):
- `-skipMacroValidation` — Skips macro validation for faster CI builds
- `COMPILER_INDEX_STORE_ENABLE=NO`, `INDEX_ENABLE_DATA_STORE=NO` — Reduce DerivedData size (~40%) in CI
- `CODE_SIGN_IDENTITY=""` / `CODE_SIGNING_REQUIRED=NO` — Simulator-only; no signing needed
- `SWIFT_ENABLE_EXPLICIT_MODULES=NO` — Applied in test scripts for compatibility

### CI/CD (`.github/workflows/commit.yml`)
Jobs run on every push/PR:

1. **Static analysis** (Ubuntu): `shellcheck`, `validate-xml` (covers `.xml` + `.plist`), `validate-yaml`
2. **Swift quality** (macOS 15): `swiftformat`, `swiftlint`
3. **XcodeGen validation** (macOS 15): generates project, uploads as `xcode-projects` artifact
4. **Build matrix** (macOS 15 + macOS 26, Xcode 16 + Xcode 26.2): downloads xcodeproj artifact, runs `build-for-testing`, uploads build products
5. **Simulator tests** (macOS 26 / Xcode 26.2): downloads artifact, streams simulator logs, runs `test-without-building`; on failure uploads `.xcresult`, simulator logs, crash logs, and build logs
6. **IPA diff** (macOS 15 + Ubuntu): builds IPA for current branch and PR base, posts binary size diff as PR comment

**Caching strategy**: All three build jobs (`build-for-testing`, `build-ipa`, `build-base-ipa`) cache:
- Homebrew downloads — keyed on `Brewfile`
- SPM packages (`build/DerivedData/SourcePackages`) — keyed on `project.yml`
- DerivedData intermediates (`build/DerivedData/Build/Intermediates.noindex`) — keyed on Xcode version + source/config hashes; `build-for-testing` and `build-ipa` share the same key on macOS 15

### YAML Linting
`.yamllint.yml` extends yamllint's default config with:
- `truthy.check-keys: false` — allows unquoted `YES`/`NO` as map keys (only values are checked)
- `braces.max-spaces-inside: 1` — permits `${{ expr }}` style in GitHub Actions
- `line-length.max: 200` — accommodates long `xcodebuild` flag lists
- `document-start: disable` — does not require `---` at the top of files

### Code Style
- **SwiftFormat**: 120-char line width, 4-space indent, import sorting enabled. Config in `.swiftformat`.
- **SwiftLint**: 25+ opt-in rules; formatting rules disabled (delegated to SwiftFormat). Config in `.swiftlint.yml`.
- Pre-commit hook runs shellcheck (touched files only), swiftformat, and swiftlint on touched files.

## Logging & Debugging

### OSLog / Logger (Swift)
Use `Logger` from `import OSLog` (iOS 14+). Organize by subsystem (bundle ID) and category:

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
  --predicate 'subsystem BEGINSWITH "dev.jasonpearson.ios"'

# Historical logs from the last hour
xcrun simctl spawn booted log show \
  --last 1h --style compact \
  --predicate 'subsystem BEGINSWITH "dev.jasonpearson.ios"'

# Collect a .logarchive as an artifact
xcrun simctl spawn booted log collect \
  --output build/simulator.logarchive --last 30m
```

### Useful simctl Commands
```bash
xcrun simctl launch booted dev.jasonpearson.ios.StarterApp      # launch app
xcrun simctl launch --console booted dev.jasonpearson.ios.StarterApp  # with stdout
xcrun simctl get_app_container booted dev.jasonpearson.ios.StarterApp data  # data dir
xcrun simctl privacy booted grant location dev.jasonpearson.ios.StarterApp  # permissions
xcrun simctl delete unavailable                                  # free disk space
```

### Test Result Bundles (Xcode 16+ API)
```bash
# Pass/fail summary
xcrun xcresulttool get test-results summary --path build/test.xcresult

# All tests with status
xcrun xcresulttool get test-results tests --path build/test.xcresult

# Extract failing test identifiers
xcrun xcresulttool get test-results tests \
  --path build/test.xcresult --format json \
  | jq '[.. | objects | select(.testStatus? == "Failure") | .nodeIdentifier]'
```

Crash logs for simulator runs land in `~/Library/Logs/DiagnosticReports/StarterApp*.crash`.
