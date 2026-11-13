// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Griffbereit",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Griffbereit", targets: ["Griffbereit"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "FachCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "Griffbereit", dependencies: ["FachCore"]),
        .executableTarget(name: "FachChecks", dependencies: ["FachCore"], path: "Tests/FachCoreTests")
    ]
)
