// swift-tools-version:5.9
// This package exists only so the platform-independent core of EveryMango2
// (models, store, scheduling) can be compiled and unit-tested without Xcode:
//     swift test
// The iOS app itself is built from EveryMango2.xcodeproj.
import PackageDescription

let package = Package(
    name: "MangoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "MangoCore", path: "EveryMango2/Core"),
        .testTarget(name: "MangoCoreTests", dependencies: ["MangoCore"], path: "CoreTests"),
    ]
)
