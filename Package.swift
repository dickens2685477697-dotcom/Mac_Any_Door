// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAnyDoor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacAnyDoor", targets: ["MacAnyDoor"])
    ],
    targets: [
        .executableTarget(
            name: "MacAnyDoor",
            path: "Sources/MacAnyDoor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacAnyDoorTests",
            dependencies: ["MacAnyDoor"],
            path: "Tests/MacAnyDoorTests"
        )
    ]
)
