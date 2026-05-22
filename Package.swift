// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Echoform",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "EchoformKit", targets: ["EchoformKit"]),
        .executable(name: "Echoform", targets: ["Echoform"]),
    ],
    targets: [
        .target(name: "EchoformKit"),
        .executableTarget(
            name: "Echoform",
            dependencies: ["EchoformKit"]
        ),
        .testTarget(
            name: "EchoformKitTests",
            dependencies: ["EchoformKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
