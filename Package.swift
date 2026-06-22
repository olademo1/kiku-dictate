// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KikuDictate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KikuDictate", targets: ["KikuDictateApp"])
    ],
    targets: [
        .executableTarget(
            name: "KikuDictateApp",
            path: "Sources/KikuDictateApp"
        ),
        .testTarget(
            name: "KikuDictateAppTests",
            dependencies: ["KikuDictateApp"],
            path: "Tests/KikuDictateAppTests"
        )
    ]
)
