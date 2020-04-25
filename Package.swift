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

        .library(
            name: "HarvestStore",
            targets: ["HarvestStore"]),

        .library(
            name: "HarvestOptics",
            targets: ["HarvestOptics"]),
    ],
    dependencies: [
        .package(url: "https://github.com/inamiy/FunOptics", .branch("swift-case-paths")),
    ],
    targets: [
        .target(
            name: "Harvest",
            dependencies: []),

        .target(
            name: "HarvestStore",
            dependencies: ["Harvest"]),

        .target(
            name: "HarvestOptics",
            dependencies: ["Harvest", "FunOptics"]),
    ]
)

//----------------------------------------
// Dev Dependencies
//----------------------------------------
// `$ HARVEST_SPM_TEST=1 swift package generate-xcodeproj`
if ProcessInfo.processInfo.environment.keys.contains("HARVEST_SPM_TEST") {
    package.targets.append(
        .testTarget(
            name: "HarvestTests",
            dependencies: ["Harvest", "Quick", "Nimble", "Thresher"])
    )

    package.dependencies.append(
        contentsOf: [
            .package(url: "https://github.com/Quick/Quick.git", from: "2.1.0"),

            // NOTE: Avoid using Nimble 8.0.3 or above which `CwlPreconditionTesting` dependency doesn't work.
            // https://github.com/Quick/Nimble/issues/696
            .package(url: "https://github.com/Quick/Nimble.git", "8.0.0" ... "8.0.2"),

            .package(url: "https://github.com/mluisbrown/Thresher.git", .branch("master"))
        ]
    )
}
