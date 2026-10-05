// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PreActionDemo",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "Greeter", targets: ["Greeter"]),
    ],
    targets: [
        .target(name: "Greeter"),
    ]
)
