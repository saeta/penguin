// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Penguin",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PenguinTables",
            targets: ["PenguinTables"]),
        .library(
            name: "PenguinCSV",
            targets: ["PenguinCSV"]),
        .library(
            name: "PenguinGraphs",
            targets: ["PenguinGraphs"]),
        .library(
            name: "PenguinParallel",
            targets: ["PenguinParallel"]),
        .library(
            name: "PenguinParallelWithFoundation",
            targets: ["PenguinParallelWithFoundation"]),
        .library(
            name: "PenguinStructures",
            targets: ["PenguinStructures"]),
        .library(
            name: "PenguinTesting",
            targets: ["PenguinTesting"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/google/swift-benchmark.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "PenguinTables",
            dependencies: ["PenguinCSV", "PenguinParallel"]),
        .testTarget(
            name: "PenguinTablesTests",
            dependencies: ["PenguinTables"]),
        .target(
            name: "PenguinCSV",
            dependencies: []),
        .testTarget(
            name: "PenguinCSVTests",
            dependencies: ["PenguinCSV"]),
        .target(
            name: "PenguinGraphs",
            dependencies: ["PenguinParallel", "PenguinStructures"]),
        .testTarget(
            name: "PenguinGraphTests",
            dependencies: ["PenguinGraphs", "PenguinParallelWithFoundation"]),
        .target(
            name: "PenguinPipeline",
            dependencies: ["PenguinParallel"]),
        .testTarget(
            name: "PenguinPipelineTests",
            dependencies: ["PenguinPipeline"]),
        .target(
            name: "PenguinParallelWithFoundation",
            dependencies: ["PenguinParallel"]),
        .target(
            name: "PenguinParallel",
            dependencies: ["PenguinStructures", "CPenguinParallel"]),
        .testTarget(
            name: "PenguinParallelTests",
            dependencies: ["PenguinParallel", "PenguinParallelWithFoundation"]),
        .target(
            name: "CPenguinParallel",
            dependencies: [],
            cSettings: [.define("SWIFT_OPT", .when(configuration: .release))]),
        .target(
            name: "PenguinStructures",
            dependencies: []),
        .testTarget(
            name: "PenguinStructuresTests",
            dependencies: ["PenguinStructures"]),
        .target(
            name: "PenguinTesting",
            dependencies: []),
        .target(
            name: "Benchmarks",
            dependencies: [
                "Benchmark",
                "PenguinParallelWithFoundation",
                "PenguinGraphs",
            ]),
    ]
)
