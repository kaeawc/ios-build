# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Setup
```bash
brew bundle                          # Install required tools (shellcheck, swiftformat, swiftlint, xmlstarlet, xcodegen)
git config core.hooksPath .githooks  # Install git hooks
bash scripts/ios/xcodegen-generate.sh  # Generate .xcodeproj from project.yml (required before opening in Xcode)
```

### Building
```bash
bash scripts/ios/xcode-build.sh              # Debug build for iOS Simulator
bash scripts/ios/xcode-build-for-testing.sh  # Build test artifacts
bash scripts/ios/xcode-build-release.sh      # Release build
bash scripts/ios/create-ipa.sh               # Package IPA from release build
```

### Testing
```bash
bash scripts/ios/xcode-test.sh                      # Build and run unit tests
bash scripts/ios/xcode-test-without-building.sh     # Run tests against pre-built binaries
```

### Linting & Formatting
```bash
bash scripts/swiftformat/run.sh    # Format Swift files
bash scripts/swiftlint/run.sh      # Lint Swift files
bash scripts/shellcheck/run.sh     # Validate shell scripts
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

Notable build flags applied in scripts:
- `SWIFT_ENABLE_EXPLICIT_MODULES=NO` — Workaround for Xcode 26.3 RC bug
- `-skipMacroValidation` — Passed as `OTHER_SWIFT_FLAGS` to work around Xcode 26.3 RC macro validation
- `COMPILER_INDEX_STORE_ENABLE=NO`, `INDEX_ENABLE_DATA_STORE=NO` — Reduce DerivedData size in CI
- `CODE_SIGN_IDENTITY=""` / `CODE_SIGNING_REQUIRED=NO` — Simulator-only; no signing needed

### CI/CD (`.github/workflows/commit.yml`)
Jobs run on every push/PR in this order:

1. **Static analysis** (Ubuntu): `shellcheck`, `validate-xml`
2. **Swift quality** (macOS 15): `swiftformat`, `swiftlint`
3. **Build matrix** (macOS 15 + macOS 26, Xcode 16 + Xcode 26): `xcodegen`, `build-for-testing`, `simulator-tests`
4. **IPA diff** (macOS 15): builds IPA for current branch and PR base, posts binary size diff as PR comment

DerivedData intermediates are cached per Xcode version + source hash to enable incremental CI builds.

### Code Style
- **SwiftFormat**: 120-char line width, 4-space indent, import sorting enabled. Config in `.swiftformat`.
- **SwiftLint**: 25+ opt-in rules; formatting rules disabled (delegated to SwiftFormat). Config in `.swiftlint.yml`.
- Pre-commit hook runs both tools on touched files only.
