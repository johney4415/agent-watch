import Foundation
import Testing
@testable import AgentWatch

@Test func codexMonitorTracksRunningAndCompletion() throws {
    let monitor = CodexSessionMonitor(sessionsDirectory: URL(fileURLWithPath: "/nonexistent"))
    let running = Data("""
    {"timestamp":"2026-07-20T01:00:00.000Z","type":"session_meta","payload":{"session_id":"thread-1","cwd":"/tmp/project"}}
    {"timestamp":"2026-07-20T01:01:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}
    {"timestamp":"2026-07-20T01:01:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"Fix the bug"}}
    """.utf8)
    let runningSession = try #require(monitor.parse(data: running))
    #expect(runningSession.status == .running)
    #expect(runningSession.id == "thread-1")
    #expect(runningSession.cwd == "/tmp/project")

    let completed = running + Data("""

    {"timestamp":"2026-07-20T01:02:00.000Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":"Fixed"}}
    """.utf8)
    let completedSession = try #require(monitor.parse(data: completed))
    #expect(completedSession.status == .completed)
    #expect(completedSession.summary == "Fixed")
}

@Test func codexMonitorTracksPendingApproval() throws {
    let monitor = CodexSessionMonitor(sessionsDirectory: URL(fileURLWithPath: "/nonexistent"))
    let pending = Data(#"""
    {"timestamp":"2026-07-20T01:00:00.000Z","type":"session_meta","payload":{"session_id":"thread-2","cwd":"/tmp"}}
    {"timestamp":"2026-07-20T01:01:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
    {"timestamp":"2026-07-20T01:01:30.000Z","type":"response_item","payload":{"type":"custom_tool_call","call_id":"call-1","input":"{\"sandbox_permissions\":\"require_escalated\"}"}}
    """#.utf8)
    #expect(try #require(monitor.parse(data: pending)).status == .needsInput)

    let resumed = pending + Data("""

    {"timestamp":"2026-07-20T01:02:00.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"call-1","output":"ok"}}
    """.utf8)
    #expect(try #require(monitor.parse(data: resumed)).status == .running)
}

@Test func codexMonitorTracksRequestedUserAnswer() throws {
    let monitor = CodexSessionMonitor(sessionsDirectory: URL(fileURLWithPath: "/nonexistent"))
    let pending = Data(#"""
    {"timestamp":"2026-07-23T01:00:00.000Z","type":"session_meta","payload":{"id":"thread-question","cwd":"/tmp","originator":"codex-tui","source":"cli"}}
    {"timestamp":"2026-07-23T01:01:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
    {"timestamp":"2026-07-23T01:01:30.000Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","call_id":"question-1","input":"{}"}}
    """#.utf8)
    let session = try #require(monitor.parse(data: pending))
    #expect(session.status == .needsInput)
    #expect(session.summary == "Codex is waiting for your answer")
}

@Test func codexMonitorIgnoresNonInteractiveExecSessions() {
    let monitor = CodexSessionMonitor(sessionsDirectory: URL(fileURLWithPath: "/nonexistent"))
    let execSession = Data("""
    {"timestamp":"2026-07-22T01:00:00.000Z","type":"session_meta","payload":{"id":"exec-1","cwd":"/tmp","originator":"codex_exec","source":"exec"}}
    {"timestamp":"2026-07-22T01:01:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
    """.utf8)
    #expect(monitor.parse(data: execSession) == nil)
}

@Test func codexMonitorKeepsInteractiveTUISessions() throws {
    let monitor = CodexSessionMonitor(sessionsDirectory: URL(fileURLWithPath: "/nonexistent"))
    let tuiSession = Data("""
    {"timestamp":"2026-07-22T01:00:00.000Z","type":"session_meta","payload":{"id":"tui-1","cwd":"/tmp","originator":"codex-tui","source":"cli"}}
    {"timestamp":"2026-07-22T01:01:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
    """.utf8)
    #expect(try #require(monitor.parse(data: tuiSession)).id == "tui-1")
}
