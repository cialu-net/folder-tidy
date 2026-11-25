// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FolderTidy",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FolderTidy", targets: ["FolderTidy"])],
    targets: [
        .executableTarget(name: "FolderTidy", resources: [.process("Resources")]),
        .testTarget(name: "FolderTidyTests", dependencies: ["FolderTidy"])
    ]
)
