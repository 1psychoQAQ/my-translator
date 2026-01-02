// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NativeMessagingHost",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NativeMessagingHost", targets: ["NativeMessagingHost"])
    ],
    targets: [
        .executableTarget(
            name: "NativeMessagingHost",
            path: ".",
            exclude: [
                "Package.swift",
                "install-native-host.sh",
                "com.translator.app.json",
                "README.md"
            ],
            sources: [
                "main.swift",
                "MessageHandler.swift",
                "HostTranslationService.swift",
                "HostWordBookService.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
