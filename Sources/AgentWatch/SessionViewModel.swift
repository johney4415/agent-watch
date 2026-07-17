import Combine
import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var errorMessage: String?
    private var timer: Timer?

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

    func refresh() {
        do {
            sessions = try EventStore.shared.sessions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ session: AgentSession) {
        TerminalNavigator.focus(session)
        guard session.status == .completed else { return }
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
}
