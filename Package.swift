// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentWatch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "agent-watch", targets: ["AgentWatch"]),
    ],
    targets: [
        .executableTarget(name: "AgentWatch"),
        .testTarget(name: "AgentWatchTests", dependencies: ["AgentWatch"]),
    ]
)
