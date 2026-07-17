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
