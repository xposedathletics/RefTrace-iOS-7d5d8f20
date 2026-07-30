// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RefTrace",
    platforms: [.iOS(.v17), .macOS(.v11)],
    products: [
        .library(name: "RefTrace", targets: ["RefTrace"])
    ],
    targets: [
        .target(
            name: "RefTrace",
            path: "Sources"
        )
    ]
)
