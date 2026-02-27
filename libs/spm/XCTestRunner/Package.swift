// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XCTestRunner",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "XCTestRunner",
            targets: ["XCTestRunner"]
        ),
    ],
    targets: [
        .target(
            name: "XCTestRunner",
            path: "Sources/XCTestRunner"
        ),
    ]
)
