import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum SessionReconciler {
    static let unlocatedSessionTimeout: TimeInterval = 10 * 60

    static func isProcessAlive(_ processID: Int32) -> Bool {
        guard processID > 1 else { return false }
        if kill(processID, 0) == 0 { return true }
        return errno == EPERM
    }

    static func shouldClose(
        _ session: AgentSession,
        now: Date = .now,
        processIsAlive: (Int32) -> Bool = isProcessAlive
    ) -> Bool {
        guard session.status == .running || session.status == .needsInput else { return false }
        if let processID = session.processID {
            return !processIsAlive(processID)
        }
        let hasLocation = session.terminal.itermSessionID != nil
            || session.terminal.tty != nil
            || session.terminal.tmuxPane != nil
        return !hasLocation && now.timeIntervalSince(session.updatedAt) > unlocatedSessionTimeout
    }
}
