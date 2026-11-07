// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "FireTVRemote",
    // Liquid Glass (.glassEffect, GlassEffectContainer) exige macOS 26.
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "FireTVRemote",
            path: "Sources/FireTVRemote",
            // O codigo e Swift 5; migrar a concorrencia para o modo 6 fica
            // para uma mudanca propria, separada do layout.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
