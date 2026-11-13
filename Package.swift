// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Projektfach",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Projektfach", targets: ["Projektfach"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "FachCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "Projektfach", dependencies: ["FachCore"]),
        .executableTarget(name: "FachChecks", dependencies: ["FachCore"], path: "Tests/FachCoreTests")
    ]
)
