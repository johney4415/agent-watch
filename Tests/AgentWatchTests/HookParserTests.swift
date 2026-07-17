import Foundation
import Testing
@testable import AgentWatch

@Test func parsesCodexCompletion() throws {
    let input = Data(#"{"type":"agent-turn-complete","thread-id":"thread-1","cwd":"/tmp/project","last-assistant-message":"Done"}"#.utf8)
    let event = try HookParser.codex(input, environment: [:])
    #expect(event.sessionID == "thread-1")
    #expect(event.provider == .codex)
    #expect(event.status == .completed)
    #expect(event.summary == "Done")
}

@Test func parsesClaudePermissionPrompt() throws {
    let input = Data(#"{"session_id":"session-1","cwd":"/tmp/project","hook_event_name":"Notification","notification_type":"permission_prompt","message":"Permission required"}"#.utf8)
    let event = try HookParser.claude(input, environment: [:])
    #expect(event.sessionID == "session-1")
    #expect(event.provider == .claude)
    #expect(event.status == .needsInput)
}

@Test func storeKeepsLatestSessionEvent() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let store = EventStore(baseDirectory: directory)
    try store.append(SessionEvent(sessionID: "one", provider: .claude, status: .running, cwd: "/tmp", summary: "Working"))
    try store.append(SessionEvent(sessionID: "one", provider: .claude, status: .completed, cwd: "/tmp", summary: "Done"))
    let sessions = try store.sessions()
    #expect(sessions.count == 1)
    #expect(sessions.first?.status == .completed)
    #expect(sessions.first?.summary == "Done")
}

@Test func installerPreservesExistingCodexNotifier() throws {
    let original = #"""
    notify = ["/existing/notifier", "turn-ended"]
    model = "codex"
    """#
    let result = try HookInstaller.codexConfig(original, executablePath: "/bin/agent-watch")
    #expect(result.contains(#"notify = ["/bin/agent-watch","codex-hook","--forward","/existing/notifier","turn-ended"]"#))
    #expect(result.contains(#"model = "codex""#))
}

@Test func installerMergesClaudeHooks() throws {
    let original = Data(#"{"permissions":{"allow":["Read"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"existing"}]}]}}"#.utf8)
    let output = try HookInstaller.claudeConfig(original, executablePath: "/bin/agent-watch")
    let root = try #require(try JSONSerialization.jsonObject(with: output) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: Any])
    #expect((hooks["SessionStart"] as? [Any])?.count == 1)
    #expect((hooks["Stop"] as? [Any])?.count == 2)
    #expect(root["permissions"] != nil)
}

@Test func uninstallerRestoresForwardedCodexNotifier() throws {
    let configured = #"""
    notify = ["/bin/agent-watch","codex-hook","--forward","/existing/notifier","turn-ended"]
    model = "codex"
    """#
    let result = try HookInstaller.codexConfigRemovingAgentWatch(configured)
    #expect(result.contains(#"notify = ["/existing/notifier","turn-ended"]"#))
    #expect(result.contains(#"model = "codex""#))
}

@Test func uninstallerRemovesOnlyAgentWatchClaudeHandlers() throws {
    let installed = try HookInstaller.claudeConfig(Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"existing"}]}]}}"#.utf8), executablePath: "/bin/agent-watch")
    let output = try HookInstaller.claudeConfigRemovingAgentWatch(installed, executablePath: "/bin/agent-watch")
    let root = try #require(try JSONSerialization.jsonObject(with: output) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: Any])
    #expect(hooks["SessionStart"] == nil)
    #expect((hooks["Stop"] as? [Any])?.count == 1)
}

@Test func installerMigratesAgentWatchExecutableWithoutChainingItself() throws {
    let original = #"notify = ["/Users/me/.local/bin/agent-watch","codex-hook","--forward","/existing/notifier","turn-ended"]"#
    let result = try HookInstaller.codexConfig(original, executablePath: "/opt/homebrew/bin/agent-watch")
    #expect(result.contains(#"["/opt/homebrew/bin/agent-watch","codex-hook","--forward","/existing/notifier","turn-ended"]"#))
    #expect(!result.contains(".local/bin/agent-watch"))
}

@Test func installerReplacesOldClaudeExecutablePath() throws {
    let installed = try HookInstaller.claudeConfig(nil, executablePath: "/Users/me/.local/bin/agent-watch")
    let migrated = try HookInstaller.claudeConfig(installed, executablePath: "/opt/homebrew/bin/agent-watch")
    let text = String(decoding: migrated, as: UTF8.self)
    #expect(!text.contains(".local/bin/agent-watch"))
    #expect(text.components(separatedBy: "/opt/homebrew/bin/agent-watch claude-hook").count - 1 == 6)
}
