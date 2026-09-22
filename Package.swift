// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "File2File",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "File2File",
            targets: ["File2File"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "File2File",
            dependencies: [
                .product(name: "CoreXLSX", package: "CoreXLSX")
            ],
            path: "Sources/File2File",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "File2FileTests",
            dependencies: ["File2File"],
            path: "Tests/File2FileTests"
        )
    ]
)
