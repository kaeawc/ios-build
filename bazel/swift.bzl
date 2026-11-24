"""Swift settings shared by every BUILD file, matching ios/Modules/Package.swift.

Apply them per package with `package(features = SWIFT_FEATURES)` rather than in .bazelrc, so
they don't leak into the external Swift packages (rules_swift_package_manager builds those with the
settings from their own manifests).
"""

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
