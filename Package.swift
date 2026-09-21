// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskAnalysis",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DiskAnalysis", targets: ["DiskAnalysis"]),
        .library(name: "DiskAnalysisCore", targets: ["DiskAnalysisCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DiskAnalysisCore",
            dependencies: [],
            path: "Sources/DiskAnalysisCore"
        ),
        .executableTarget(
            name: "DiskAnalysis",
            dependencies: ["DiskAnalysisCore"],
            path: "Sources/DiskAnalysis"
        ),
        .testTarget(
            name: "DiskAnalysisTests",
            dependencies: ["DiskAnalysisCore"],
            path: "Tests/DiskAnalysisTests"
        )
    ]
)
