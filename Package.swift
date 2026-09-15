// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Blocks",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Blocks", targets: ["Blocks"])],
    targets: [
        .target(name: "BlocksCore"),
        .executableTarget(name: "Blocks", dependencies: ["BlocksCore"]),
        .executableTarget(name: "BlocksCoreChecks", dependencies: ["BlocksCore"], path: "Tests/BlocksCoreTests")
    ]
)
