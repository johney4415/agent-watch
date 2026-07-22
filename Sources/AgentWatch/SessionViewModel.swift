import Combine
import AppKit
import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var errorMessage: String?
    private var timer: Timer?
    private let codexMonitor = CodexSessionMonitor()
    private let terminalRegistry = TerminalSessionRegistry()

    var attentionCount: Int {
        sessions.filter { $0.status == .needsInput || $0.status == .completed || $0.status == .failed }.count
    }

    var activeSessions: [AgentSession] {
        sessions.filter { $0.status != .closed }
    }

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(forceTerminalRefresh: Bool = false) {
        do {
            let persisted = try EventStore.shared.sessions()
            let inferred = codexMonitor.sessions()
            var latest = Dictionary(uniqueKeysWithValues: persisted.map { ($0.id, $0) })
            for session in inferred {
                if latest[session.id]?.updatedAt ?? .distantPast < session.updatedAt {
                    latest[session.id] = session
                }
            }
            if let liveIDs = terminalRegistry.liveITermSessionIDs(force: forceTerminalRefresh) {
                let closedIDs = latest.values
                    .filter { !TerminalSessionRegistry.isLive($0.terminal, in: liveIDs) }
                    .map(\.id)
                for id in closedIDs {
                    latest[id]?.status = .closed
                }
            }
            for session in latest.values where SessionReconciler.shouldClose(session) {
                latest[session.id]?.status = .closed
            }
            sessions = latest.values.sorted { $0.updatedAt > $1.updatedAt }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ session: AgentSession) {
        if session.status == .completed {
            do {
                try EventStore.shared.append(SessionEvent(
                    sessionID: session.id,
                    provider: session.provider,
                    status: .closed,
                    cwd: session.cwd,
                    summary: "Acknowledged",
                    terminal: session.terminal,
                    processID: session.processID
                ))
                refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        // MenuBarExtra's window otherwise remains key and continues receiving
        // keyboard input after iTerm's session has been selected.
        NSApplication.shared.keyWindow?.orderOut(nil)
        NSApplication.shared.deactivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TerminalNavigator.focus(session)
        }
    }
}
