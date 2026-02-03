// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "studio-operator",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "StudioCore", targets: ["StudioCore"]),
    .executable(name: "wub", targets: ["wub"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
  ],
  targets: [
    .target(
      name: "StudioCore",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Yams", package: "Yams")
      ],
      path: "Sources/StudioCore"
    ),
    .executableTarget(
      name: "wub",
      dependencies: [
        "StudioCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Yams", package: "Yams")
      ],
      path: "Sources/wub"
    ),
    .testTarget(
      name: "StudioCoreTests",
      dependencies: ["StudioCore"],
      resources: [.process("Fixtures")]
    )
  ]
)
