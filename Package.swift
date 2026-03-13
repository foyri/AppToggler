// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppToggler",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AppToggler", targets: ["AppToggler"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.10.0")
    ],
    targets: [
        .executableTarget(
            name: "AppToggler",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: ".",
            exclude: [
                "dist",
                "build-app.sh"
            ]
        )
    ]
)
