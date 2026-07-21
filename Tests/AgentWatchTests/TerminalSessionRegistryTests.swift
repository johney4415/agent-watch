import Testing
@testable import AgentWatch

@Test func itermEnvironmentIDMatchesAppleScriptUniqueID() {
    let terminal = TerminalIdentity(
        app: "iTerm.app",
        itermSessionID: "w0t1p0:0599ABFE-A85C-4256-A2BB-9A141EE557FF",
        tty: nil,
        tmuxPane: nil
    )
    #expect(TerminalSessionRegistry.isLive(terminal, in: ["0599ABFE-A85C-4256-A2BB-9A141EE557FF"]))
    #expect(!TerminalSessionRegistry.isLive(terminal, in: ["another-session"]))
}

@Test func sessionsWithoutITermIdentityAreNotClosedByRegistry() {
    let terminal = TerminalIdentity(app: nil, itermSessionID: nil, tty: nil, tmuxPane: nil)
    #expect(TerminalSessionRegistry.isLive(terminal, in: []))
}
