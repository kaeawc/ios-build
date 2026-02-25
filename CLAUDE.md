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
bash scripts/ios/create-ipa.sh <output.ipa>  # Package IPA from release build
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
3. **XcodeGen validation** (macOS 15): generates projects as a cheap pre-check before the build matrix
4. **Build matrix** (macOS 15 + macOS 26, Xcode 16 + Xcode 26.2): `build-for-testing` uploads build products as artifacts
5. **Simulator tests** (macOS 15 / Xcode 16 only): downloads artifact, runs `test-without-building`
6. **IPA diff** (macOS 15 + Ubuntu): builds IPA for current branch and PR base, posts binary size diff as PR comment

**Caching strategy**: All three build jobs (`build-for-testing`, `build-ipa`, `build-base-ipa`) cache:
- Homebrew downloads — keyed on `Brewfile`
- SPM packages (`build/DerivedData/SourcePackages`) — keyed on `project.yml`
- DerivedData intermediates (`build/DerivedData/Build/Intermediates.noindex`) — keyed on Xcode version + source/config hashes; `build-ipa`/`build-base-ipa` use a separate `release-intermediates-` key to avoid collision with debug builds

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
