// swift-tools-version: 6.2

// All app code lives in this local package; the Xcode project in ios/StarterApp is only a thin shell
// around `AppFeature` for each platform. Add a new module by adding a `.target` (and a matching
// `.testTarget`) below, then list the test target in the schemes in ios/StarterApp/project.yml.

import PackageDescription

let package = Package(
    name: "Modules",
    // Keep in sync with the deployment targets in ios/StarterApp/Configurations/Shared.xcconfig.
    // macOS is listed only so `swift test` works on a Mac without a simulator; there is no Mac app.
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .visionOS(.v2),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "Connectivity", targets: ["Connectivity"]),
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.12.2"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.2"),
    ],
    targets: [
        // MARK: Features (SwiftUI, main-actor isolated by default)

        .target(
            name: "AppFeature",
            dependencies: [
                "Connectivity",
                "Persistence",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ],
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                "Connectivity",
                "Persistence",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ],
        ),

        // MARK: Clients & data (no UI, nonisolated by default)

        .target(
            name: "Connectivity",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
        ),
        .testTarget(
            name: "ConnectivityTests",
            dependencies: [
                "Connectivity",
                .product(name: "Alamofire", package: "Alamofire"),
            ],
        ),

        .target(
            name: "Persistence",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)

// Settings shared by every module. These match what the Xcode project enables for the app targets
// (see ios/StarterApp/Configurations/Shared.xcconfig), so code behaves the same wherever it lives.
for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        // "Approachable concurrency" (Swift 6.2): async functions run on the caller's actor, and
        // conformances inherit the isolation of the type that declares them.
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        // Require `any` for existential types and an explicit import for every module whose
        // members are used.
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
}
