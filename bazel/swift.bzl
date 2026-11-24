"""Swift settings shared by every BUILD file, matching ios/Modules/Package.swift.

Apply them per package with `package(features = SWIFT_FEATURES)` rather than in .bazelrc, so
they don't leak into the external Swift packages (rules_swift_package_manager builds those with the
settings from their own manifests).
"""

load("@rules_apple//apple:ios.bzl", "ios_unit_test")
load("@rules_swift//swift:swift_library.bzl", "swift_library")
load("@rules_swift//swift:swift_test.bzl", "swift_test")

# Swift 6 language mode (complete data-race checking), the Swift 6.2 "approachable concurrency"
# features, `any` for existentials, and an explicit import for every module whose members are used.
SWIFT_FEATURES = [
    "swift.enable_v6",
    "swift.upcoming.NonisolatedNonsendingByDefault",
    "swift.upcoming.InferIsolatedConformances",
    "swift.upcoming.ExistentialAny",
    "swift.upcoming.MemberImportVisibility",
]

# `.defaultIsolation(MainActor.self)` in Package.swift. rules_swift has no feature for it, so pass
# the same compiler flag SwiftPM does. Use it for feature (UI) modules and their tests.
MAIN_ACTOR_COPTS = [
    "-default-isolation",
    "MainActor",
]

def swift_module_tests(name, srcs, deps = [], copts = [], ios_runners = {}, ios_minimum_os = None):
    """Declares a module's Swift Testing suite for the macOS host and, optionally, iOS simulators.

    Creates:
      - `<name>`: `swift_test` on the macOS host (no simulator), like `swift test`.
      - `<name>Lib`: the test sources as a testonly `swift_library`.
      - `<name>_<suffix>`: an `ios_unit_test` per entry in `ios_runners`, run on that simulator
        and tagged with the lowercased suffix.

    Args:
        name: test target name, matching the `.testTarget` in Package.swift.
        srcs: test sources.
        deps: test dependencies.
        copts: extra Swift compiler flags (e.g. MAIN_ACTOR_COPTS).
        ios_runners: dict of target-name suffix to `ios_xctestrun_runner` label.
        ios_minimum_os: minimum iOS version for the `ios_unit_test` targets.
    """
    swift_test(
        name = name,
        srcs = srcs,
        copts = copts,
        module_name = name,
        deps = deps,
    )
    if not ios_runners:
        return
    swift_library(
        name = name + "Lib",
        testonly = True,
        srcs = srcs,
        # The test bundle references nothing in the library; keep every test in the link.
        alwayslink = True,
        copts = copts,
        module_name = name,
        deps = deps,
    )
    for suffix, runner in ios_runners.items():
        ios_unit_test(
            name = name + "_" + suffix,
            minimum_os_version = ios_minimum_os,
            runner = runner,
            # e.g. `bazel test --test_tag_filters=iphone //...` runs everything on the iPhone simulator.
            tags = [suffix.lower()],
            deps = [":" + name + "Lib"],
        )
