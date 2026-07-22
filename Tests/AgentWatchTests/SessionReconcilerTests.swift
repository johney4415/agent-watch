import Foundation
import Testing
@testable import AgentWatch

@Test func closesSessionWhenRecordedAgentProcessExited() {
    let session = makeSession(processID: 42)
    #expect(SessionReconciler.shouldClose(session, processIsAlive: { _ in false }))
    #expect(!SessionReconciler.shouldClose(session, processIsAlive: { _ in true }))
}

@Test func expiresOldUnlocatedRunningSession() {
    let now = Date()
    let old = makeSession(updatedAt: now.addingTimeInterval(-SessionReconciler.unlocatedSessionTimeout - 1))
    #expect(SessionReconciler.shouldClose(old, now: now))
}

@Test func keepsLocatedOrRecentSessionWithoutPID() {
    let now = Date()
    var located = makeSession(updatedAt: now.addingTimeInterval(-3600))
    located.terminal.itermSessionID = "live-pane"
    #expect(!SessionReconciler.shouldClose(located, now: now))
    #expect(!SessionReconciler.shouldClose(makeSession(updatedAt: now), now: now))
}

private func makeSession(updatedAt: Date = .now, processID: Int32? = nil) -> AgentSession {
    AgentSession(
        id: "test", provider: .claude, status: .running, cwd: "/tmp",
        summary: "Working", updatedAt: updatedAt,
        terminal: .init(app: nil, itermSessionID: nil, tty: nil, tmuxPane: nil),
        processID: processID
    )
}
