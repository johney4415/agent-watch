import Foundation
import Testing
@testable import AgentWatch

@Test func closedEventHidesCompletedSessionFromActiveState() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let store = EventStore(baseDirectory: directory)
    try store.append(SessionEvent(sessionID: "one", provider: .codex, status: .completed, cwd: "/tmp", summary: "Done"))
    try store.append(SessionEvent(sessionID: "one", provider: .codex, status: .closed, cwd: "/tmp", summary: "Acknowledged"))
    #expect(try store.sessions().first?.status == .closed)
}

@Test func newEventReopensAcknowledgedSession() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let store = EventStore(baseDirectory: directory)
    try store.append(SessionEvent(sessionID: "one", provider: .claude, status: .closed, cwd: "/tmp", summary: "Acknowledged"))
    try store.append(SessionEvent(sessionID: "one", provider: .claude, status: .running, cwd: "/tmp", summary: "Working"))
    #expect(try store.sessions().first?.status == .running)
}
