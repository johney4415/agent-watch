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
