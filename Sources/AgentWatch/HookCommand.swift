import Foundation

enum HookCommand {
    static func run(arguments: [String]) throws {
        guard let command = arguments.first else { return }
        let data: Data
        let event: SessionEvent

        switch command {
        case "codex-hook":
            guard let payload = arguments.last, arguments.count > 1 else { throw HookParserError.invalidJSON }
            data = Data(payload.utf8)
            event = try HookParser.codex(data)
            try EventStore.shared.append(event)
            try forwardCodexNotification(arguments: arguments, payload: payload)
            return
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
        case "install-hooks":
            try HookInstaller.install(executablePath: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path)
            print("Installed Codex and Claude Code hooks. Backups use the .agent-watch-backup suffix.")
            return
        case "uninstall-hooks":
            try HookInstaller.uninstall(executablePath: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path)
            print("Removed Agent Watch hooks without changing unrelated configuration.")
            return
        default:
            throw NSError(domain: "AgentWatch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown command: \(command)"])
        }
        try EventStore.shared.append(event)
    }

    private static func forwardCodexNotification(arguments: [String], payload: String) throws {
        guard let marker = arguments.firstIndex(of: "--forward"), marker + 1 < arguments.count - 1 else { return }
        let forwarded = Array(arguments[(marker + 1)..<(arguments.count - 1)])
        guard let executable = forwarded.first else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(forwarded.dropFirst()) + [payload]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AgentWatch", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Forwarded Codex notifier failed"])
        }
    }
}
