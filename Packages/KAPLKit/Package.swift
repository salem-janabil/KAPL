// swift-tools-version: 6.0
import PackageDescription

// Layering (enforced by target dependencies):
//
//   KAPLCore    — domain: lock state machine, coordinator, ports. No AppKit.
//   KAPLSystem  — macOS adapters for the ports (LocalAuthentication, IOKit, ...).
//   KAPLUI      — AppKit windows + SwiftUI views for the shield and menu bar.
//
// KAPLSystem and KAPLUI depend only on KAPLCore, never on each other.
// The app target is the composition root that wires them together.
let package = Package(
    name: "KAPLKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KAPLCore", targets: ["KAPLCore"]),
        .library(name: "KAPLSystem", targets: ["KAPLSystem"]),
        .library(name: "KAPLUI", targets: ["KAPLUI"]),
    ],
    targets: [
        .target(name: "KAPLCore"),
        .target(
            name: "KAPLSystem",
            dependencies: ["KAPLCore"],
            linkerSettings: [
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("IOKit"),
            ]
        ),
        .target(name: "KAPLUI", dependencies: ["KAPLCore"]),
        .testTarget(name: "KAPLCoreTests", dependencies: ["KAPLCore"]),
    ]
)
