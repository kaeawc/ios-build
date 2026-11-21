# iOS Experiments & Template

A starting point for new Apple-platform apps: one SwiftUI codebase for **iPhone, iPad, Apple Watch,
Apple TV and Apple Vision Pro**, organized as local Swift packages, with Swift 6 strict concurrency,
Swift Testing, linting, and GitHub Actions CI that builds and tests on every platform.

| | |
| --- | --- |
| Toolchain | Xcode 26 (CI uses 26.6), Swift 6 language mode, approachable concurrency |
| Platforms | iOS/iPadOS 18, watchOS 11, tvOS 18, visionOS 2 |
| UI & state | SwiftUI, `@Observable` (Swift Observation), `NavigationSplitView` |
| Libraries | [GRDB](https://github.com/groue/GRDB.swift) (SQLite), [Alamofire](https://github.com/Alamofire/Alamofire) (HTTP), [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) (dependency injection) |
| Tests | Swift Testing for modules, XCTest for UI tests |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) + xcconfig files (no `.xcodeproj` in git) |
| Tooling | SwiftFormat, SwiftLint, ShellCheck, actionlint, pinned with [mise](https://mise.jdx.dev) |
| Automation | GitHub Actions (macOS 26 runners), [Renovate](https://docs.renovatebot.com) |

The sample app records each launch in a SQLite database and checks network reachability. It's
deliberately small: it exists to show how the pieces fit together, and you'll replace it.

## Start a new project

1. Click **Use this template** on GitHub (or clone the repository) and clone your new repository.
2. Rename the app and set your bundle identifier prefix:

   ```sh
   bash scripts/rename.sh Weather com.acme "Acme Weather"
   ```

   This replaces `StarterApp` everywhere (targets, schemes, files, directories) and sets
   `BUNDLE_ID_PREFIX` and `APP_DISPLAY_NAME` in
   [`Shared.xcconfig`](ios/StarterApp/Configurations/Shared.xcconfig). The app's bundle ID
   becomes `com.acme.Weather` and the watch app's `com.acme.Weather.watchkitapp`.
3. Install the tools and the git hooks:

   ```sh
   brew bundle            # mise, yamllint
   mise install           # XcodeGen, SwiftLint, SwiftFormat, ShellCheck, actionlint (versions in mise.toml)
   git config core.hooksPath .githooks
   ```

4. Generate the Xcode project and open it:

   ```sh
   bash scripts/ios/xcodegen-generate.sh
   open ios/Weather/Weather.xcodeproj
   ```

5. To run on a device, set `DEVELOPMENT_TEAM` in `Shared.xcconfig`, or in an untracked
   `Local.xcconfig` (copy `Local.xcconfig.example`).
6. Update the copyright holder in [`LICENSE`](LICENSE), rewrite this README, and delete the
   platforms you don't need (see [Platforms](#platforms)).

## Project structure

```
ios/
  Modules/                      Local Swift package: all app code lives here
    Package.swift               Modules, dependencies, platforms, Swift settings
    Sources/
      AppFeature/               SwiftUI views + @Observable model (main-actor by default)
      Connectivity/             Network reachability client (NWPathMonitor + Alamofire)
      Persistence/              GRDB database, records, migrations
    Tests/                      One Swift Testing target per module
  StarterApp/                   Thin app shells, generated into StarterApp.xcodeproj
    project.yml                 XcodeGen spec: targets, schemes
    Configurations/             xcconfig files: the single source of build settings
    App/                        @main for iPhone, iPad, Apple TV, Apple Vision Pro
    Watch/                      @main for Apple Watch
    UITests/                    XCTest UI tests
scripts/
  ios/                          xcodegen-generate, build, test, find-simulator
  lint.sh, format.sh            Run every check / fix formatting
  rename.sh                     Rename the template
.github/
  workflows/ci.yml              Lint, package tests, per-platform build + test
  renovate.json                 Dependency updates
.githooks/                      pre-commit (lint staged files), post-checkout/merge (regenerate project)
mise.toml                       Pinned developer tool versions
```

## Architecture

**Everything is a module.** App code lives in the `ios/Modules` package; each app target is a few
lines that put `AppView` in a `WindowGroup`. Modules build in isolation, can be tested with
`swift test` without a simulator, and make dependencies explicit (`Persistence` can't import
SwiftUI by accident). They are split by role:

- **Feature modules** (`AppFeature`) hold SwiftUI views and `@Observable` models. They use
  `.defaultIsolation(MainActor.self)`, so everything is main-actor isolated unless marked otherwise.
- **Client modules** (`Connectivity`, `Persistence`) have no UI and are nonisolated by default.
  Each exposes a small API and a `swift-dependencies` key with live, preview and test values.

**State** lives in `@Observable` models created with `@State` in views. Models get their
collaborators from `@Dependency`, so tests swap them with `withDependencies` or the
`.dependency`/`.dependencies` test traits. Unconfigured dependencies fail tests, so nothing reaches
the network or disk by accident.

**Persistence** uses GRDB directly: `Codable` records (`FetchableRecord`, `PersistableRecord`),
a `DatabaseMigrator` for schema history, and `ValueObservation` exposed as an `AsyncSequence` that
the model iterates to stay in sync. The database lives in Application Support (Caches on tvOS); tests
and previews get an in-memory one.

**Concurrency** is Swift 6 language mode (complete data-race checking) plus the Swift 6.2
*approachable concurrency* features (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`),
`ExistentialAny` and `MemberImportVisibility`, enabled the same way for the package (`Package.swift`)
and the app targets (`Shared.xcconfig`).

### Add a module

1. In [`Package.swift`](ios/Modules/Package.swift), add a `.target` (and a `.library` product if
   app targets import it directly) and a matching `.testTarget`.
2. Add the test target to both schemes in [`project.yml`](ios/StarterApp/project.yml)
   (`package: Modules/<Name>Tests`), so it runs in Xcode and CI.
3. Regenerate the project.

### Why XcodeGen?

Xcode project files cause merge conflicts and hide settings in a format nobody reviews. Generating
the project from a short YAML spec, with build settings in xcconfig files, avoids both. Options
considered:

- **XcodeGen** (chosen): one small spec file, no build-time dependency, mature support for
  multi-platform targets, embedded watch apps and local-package test targets in schemes.
- **Tuist**: more powerful (module graph generation, binary caching), but brings a Swift-DSL
  manifest per project, its own CLI lifecycle, and features tied to its hosted service. Worth it
  for large modular codebases; heavier than a template needs.
- **A committed `.xcodeproj` with Xcode 16 synchronized folders**: no generator, and adding files
  no longer touches the project, but target and setting changes still conflict, and settings stay in
  the project file.

Because app code lives in Swift packages, the spec stays tiny and switching generators later is cheap.

## Build and test

From Xcode: open `ios/StarterApp/StarterApp.xcodeproj`, pick the **StarterApp** scheme (iPhone,
iPad, Apple TV, Vision Pro) or **StarterAppWatch**, then build (⌘B) or test (⌘U). The test action
runs every module's Swift Testing suite plus the UI tests.

From the command line (the same scripts CI runs):

```sh
bash scripts/ios/xcodegen-generate.sh       # after changing project.yml or switching branches
bash scripts/ios/build.sh                   # iOS simulator, Debug (also builds the watch app)
bash scripts/ios/build.sh tvOS Release      # any platform: iOS, iPadOS, tvOS, visionOS, watchOS
bash scripts/ios/test.sh iPadOS             # build + run all tests on a simulator
UNIT_TESTS_ONLY=true bash scripts/ios/test.sh visionOS

cd ios/Modules && swift test                # module tests on the Mac itself, no simulator
```

Test results go to `build/<platform>.xcresult`; open them in Xcode or inspect them with
`xcrun xcresulttool get test-results summary --path build/iOS.xcresult`.

## Platforms

One app target (`StarterApp`) builds for iPhone, iPad, Apple TV and Apple Vision Pro
(`supportedDestinations` in `project.yml`); `[sdk=...]` conditions in
[`App.xcconfig`](ios/StarterApp/Configurations/App.xcconfig) handle per-platform settings. The
watch app is a separate target that ships inside the iOS app and also runs independently.

- **iPad**: all orientations are enabled so the app supports Split View and Stage Manager;
  `NavigationSplitView` shows a sidebar in regular width and collapses to a stack in compact width.
- **Apple Watch**: shares `AppView`. `WKRunsIndependentlyOfCompanionApp` is on, so the watch app
  works without the phone nearby.
- **Apple TV**: there is no persistent local storage on tvOS, so the database lives in Caches.
  Before shipping, add an "App Icon & Top Shelf Image" brand asset.
- **Apple Vision Pro**: runs as a native visionOS app in a window. Before shipping, add a layered
  visionOS app icon.

To drop a platform, remove it from `supportedDestinations` (or delete the `StarterAppWatch`
target and its dependency), from the CI matrix, and from `platforms` in `Package.swift`.

## Configuration

Build settings live in [`ios/StarterApp/Configurations`](ios/StarterApp/Configurations), not in
the generated project:

| File | Purpose |
| --- | --- |
| `Shared.xcconfig` | Identity (name, bundle ID prefix, version, team), deployment targets, Swift settings |
| `Debug.xcconfig`, `Release.xcconfig` | Per-configuration settings; both include `Shared.xcconfig` |
| `App.xcconfig`, `Watch.xcconfig`, `UITests.xcconfig` | Per-target settings, including generated Info.plist keys |
| `Local.xcconfig` | Optional and untracked: per-developer overrides such as `DEVELOPMENT_TEAM` |

`project.yml` uses `settingPresets: targets`, so XcodeGen only adds per-target platform defaults
(SDK, device family, runpath search paths). Keep the deployment targets in `Shared.xcconfig` and
`platforms` in `Package.swift` in sync.

## Code quality

```sh
bash scripts/lint.sh     # SwiftFormat (lint), SwiftLint (strict), ShellCheck, actionlint, yamllint, plist/XML
bash scripts/format.sh   # apply SwiftFormat and SwiftLint auto-fixes
```

SwiftFormat owns formatting ([`.swiftformat`](.swiftformat)); SwiftLint ([`.swiftlint.yml`](.swiftlint.yml))
has its formatting rules disabled and checks everything else. The pre-commit hook runs both on staged
Swift files, plus ShellCheck on staged scripts.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every pull request and push to `main`:

| Job | Runner | What it does |
| --- | --- | --- |
| Lint | `ubuntu-latest` | `scripts/lint.sh` with the tool versions from `mise.toml` |
| Package tests | `macos-26` | `swift test` in `ios/Modules` on the macOS host |
| Test (iOS, iPadOS, tvOS, visionOS, watchOS) | `macos-26` | Generates the project, runs module and UI tests on that platform's simulator; the iOS job also builds Release |

SwiftPM checkouts and mise tools are cached. Test results and crash logs are uploaded when a job fails.
To move to a new Xcode, change `XCODE_VERSION` at the top of the workflow (see the
[runner images](https://github.com/actions/runner-images/tree/main/images/macos) for what is installed).

## Dependency updates

[Renovate](https://docs.renovatebot.com) ([config](.github/renovate.json)) opens weekly pull
requests for Swift packages in `Package.swift`, GitHub Actions, and the tools in `mise.toml`.
[Install the Renovate GitHub App](https://github.com/apps/renovate) on your repository to enable it.
Package versions use `from:` (up to the next major version) and Renovate raises the lower bound
as new releases ship. `Package.resolved` isn't committed because the Xcode project is generated;
pin with `exact:` if you need fully reproducible builds.

## License

[MIT](LICENSE).
