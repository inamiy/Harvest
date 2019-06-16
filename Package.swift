// swift-tools-version:5.1

import Foundation
import PackageDescription

let package = Package(
    name: "Harvest",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Harvest",
            targets: ["Harvest"]),
    ],
    dependencies:  [
    ],
    targets: [
        .target(
            name: "Harvest",
            dependencies: [],
            path: "Sources"),
    ]
)

// `$ HARVEST_SPM_TEST=1 swift test`
if ProcessInfo.processInfo.environment.keys.contains("HARVEST_SPM_TEST") {
    package.targets.append(
        .testTarget(
            name: "HarvestTests",
            dependencies: ["Harvest", "Quick", "Nimble"])
    )

    package.dependencies.append(
        contentsOf: [
            .package(url: "https://github.com/Quick/Quick.git", from: "2.1.0"),
            .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0"),
        ]
    )
}
