// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MovieCapture",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CaptureEngine", targets: ["CaptureEngine"]),
        .executable(name: "moviecapture", targets: ["MovieCaptureCLI"]),
        .executable(name: "moviecapture-mcp", targets: ["MovieCaptureMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.9.0"),
    ],
    targets: [
        // CaptureEngine library
        .target(
            name: "CaptureEngine",
            dependencies: ["Yams"],
            path: "Sources/CaptureEngine"
        ),
        // CLI executable
        .executableTarget(
            name: "MovieCaptureCLI",
            dependencies: [
                "CaptureEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MovieCaptureCLI"
        ),
        // MCP Server executable
        .executableTarget(
            name: "MovieCaptureMCP",
            dependencies: [
                "CaptureEngine",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/MovieCaptureMCP"
        ),
        // Tests
        .testTarget(
            name: "CaptureEngineTests",
            dependencies: ["CaptureEngine"],
            path: "Tests/CaptureEngineTests"
        ),
        .testTarget(
            name: "MovieCaptureCLITests",
            dependencies: ["MovieCaptureCLI", "CaptureEngine"],
            path: "Tests/MovieCaptureCLITests"
        ),
    ]
)
