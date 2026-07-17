import Foundation

enum HookCommand {
    static func run(arguments: [String]) throws {
        guard let command = arguments.first else { return }
        let data: Data
        let event: SessionEvent

        switch command {
        case "codex-hook":
            guard arguments.count > 1 else { throw HookParserError.invalidJSON }
            data = Data(arguments[1].utf8)
            event = try HookParser.codex(data)
        case "claude-hook":
            data = FileHandle.standardInput.readDataToEndOfFile()
            event = try HookParser.claude(data)
        case "emit-demo":
            let provider = AgentProvider(rawValue: arguments.dropFirst().first ?? "claude") ?? .claude
            event = SessionEvent(
                sessionID: "demo-\(provider.rawValue)",
                provider: provider,
                status: .needsInput,
                cwd: FileManager.default.currentDirectoryPath,
                summary: "Demo session needs your input"
            )
        default:
            throw NSError(domain: "AgentWatch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown command: \(command)"])
        }
        try EventStore.shared.append(event)
    }
}
