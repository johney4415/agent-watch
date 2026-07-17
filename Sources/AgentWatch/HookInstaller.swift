import Foundation

enum HookInstaller {
    private static let claudeEvents = [
        "SessionStart", "UserPromptSubmit", "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    static func install(executablePath: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        try installCodex(executablePath: executablePath, home: home)
        try installClaude(executablePath: executablePath, home: home)
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
               let existing = try JSONSerialization.jsonObject(with: data) as? [String],
               !existing.contains(executablePath) {
                command += ["--forward"] + existing
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
            let exists = groups.contains { group in
                guard let entries = group["hooks"] as? [[String: Any]] else { return false }
                return entries.contains { $0["command"] as? String == command }
            }
            if !exists { groups.append(handler) }
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) + Data([0x0A])
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
