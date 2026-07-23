import Foundation

enum HookInstaller {
    private static let claudeEvents = [
        "SessionStart", "UserPromptSubmit", "Notification", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "Stop", "StopFailure", "SessionEnd",
    ]

    static func install(executablePath: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        try installCodex(executablePath: executablePath, home: home)
        try installClaude(executablePath: executablePath, home: home)
    }

    static func uninstall(executablePath: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let codexURL = home.appending(path: ".codex/config.toml")
        if let original = try? String(contentsOf: codexURL, encoding: .utf8) {
            try codexConfigRemovingAgentWatch(original).write(to: codexURL, atomically: true, encoding: .utf8)
        }

        let claudeURL = home.appending(path: ".claude/settings.json")
        if let original = try? Data(contentsOf: claudeURL) {
            try claudeConfigRemovingAgentWatch(original, executablePath: executablePath).write(to: claudeURL, options: .atomic)
        }
    }

    static func codexConfig(_ original: String, executablePath: String) throws -> String {
        let pattern = #"(?m)^notify\s*=\s*(\[[^\n]*\])\s*$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(original.startIndex..<original.endIndex, in: original)
        let match = regex.firstMatch(in: original, range: range)
        var command = [executablePath, "codex-hook"]

        if let match, let arrayRange = Range(match.range(at: 1), in: original) {
            let existingText = String(original[arrayRange])
            if let data = existingText.data(using: .utf8),
               let existing = try JSONSerialization.jsonObject(with: data) as? [String] {
                let originalNotifier = unwrapAgentWatchNotifiers(existing)
                if !originalNotifier.isEmpty { command += ["--forward"] + originalNotifier }
            }
        }

        let encoded = try JSONSerialization.data(withJSONObject: command, options: [.withoutEscapingSlashes])
        let line = "notify = " + String(decoding: encoded, as: UTF8.self)
        if let match, let fullRange = Range(match.range, in: original) {
            return original.replacingCharacters(in: fullRange, with: line)
        }
        return line + "\n" + original
    }

    static func claudeConfig(_ data: Data?, executablePath: String) throws -> Data {
        var root = ((data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = executablePath + " claude-hook"
        let handler: [String: Any] = ["hooks": [["type": "command", "command": command]]]

        for event in claudeEvents {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups = groups.compactMap { group -> [String: Any]? in
                var updated = group
                guard let entries = group["hooks"] as? [[String: Any]] else { return group }
                let retained = entries.filter { entry in
                    guard let existingCommand = entry["command"] as? String else { return true }
                    return !isAgentWatchClaudeCommand(existingCommand)
                }
                guard !retained.isEmpty else { return nil }
                updated["hooks"] = retained
                return updated
            }
            groups.append(handler)
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) + Data([0x0A])
    }

    static func codexConfigRemovingAgentWatch(_ original: String) throws -> String {
        let pattern = #"(?m)^notify\s*=\s*(\[[^\n]*\])\s*\n?"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(original.startIndex..<original.endIndex, in: original)
        guard let match = regex.firstMatch(in: original, range: range),
              let arrayRange = Range(match.range(at: 1), in: original),
              let fullRange = Range(match.range, in: original),
              let data = String(original[arrayRange]).data(using: .utf8),
              let command = try JSONSerialization.jsonObject(with: data) as? [String],
              command.count >= 2,
              command[1] == "codex-hook" else { return original }

        if let marker = command.firstIndex(of: "--forward"), marker + 1 < command.count {
            let forwarded = Array(command[(marker + 1)...])
            let encoded = try JSONSerialization.data(withJSONObject: forwarded, options: [.withoutEscapingSlashes])
            let replacement = "notify = " + String(decoding: encoded, as: UTF8.self) + "\n"
            return original.replacingCharacters(in: fullRange, with: replacement)
        }
        return original.replacingCharacters(in: fullRange, with: "")
    }

    static func claudeConfigRemovingAgentWatch(_ data: Data, executablePath: String) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookParserError.invalidJSON
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for event in claudeEvents {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            let retained = groups.compactMap { group -> [String: Any]? in
                var updated = group
                guard let entries = group["hooks"] as? [[String: Any]] else { return group }
                let keptEntries = entries.filter {
                    guard let existingCommand = $0["command"] as? String else { return true }
                    return !isAgentWatchClaudeCommand(existingCommand)
                }
                guard !keptEntries.isEmpty else { return nil }
                updated["hooks"] = keptEntries
                return updated
            }
            if retained.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = retained }
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) + Data([0x0A])
    }

    private static func isAgentWatchClaudeCommand(_ command: String) -> Bool {
        let executable = command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return URL(fileURLWithPath: executable).lastPathComponent == "agent-watch"
            && command.hasSuffix(" claude-hook")
    }

    private static func unwrapAgentWatchNotifiers(_ input: [String]) -> [String] {
        var command = input
        while command.count >= 2, command[1] == "codex-hook" {
            guard let marker = command.firstIndex(of: "--forward"), marker + 1 < command.count else { return [] }
            command = Array(command[(marker + 1)...])
        }
        return command
    }

    private static func installCodex(executablePath: String, home: URL) throws {
        let url = home.appending(path: ".codex/config.toml")
        let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try backup(url)
        try codexConfig(original, executablePath: executablePath).write(to: url, atomically: true, encoding: .utf8)
    }

    private static func installClaude(executablePath: String, home: URL) throws {
        let url = home.appending(path: ".claude/settings.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = try? Data(contentsOf: url)
        try backup(url)
        try claudeConfig(original, executablePath: executablePath).write(to: url, options: .atomic)
    }

    private static func backup(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backupURL = URL(fileURLWithPath: url.path + ".agent-watch-backup")
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.copyItem(at: url, to: backupURL)
    }
}
