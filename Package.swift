// swift-tools-version: 5.9
// 5.9 (not 6.0) so the same package also opens in Xcode 15 for the CI matrix.
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
