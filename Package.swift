// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PowerInfoReborn",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PowerInfoReborn",
            path: "Sources/PowerInfoReborn",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
