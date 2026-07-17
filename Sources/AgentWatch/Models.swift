import Foundation

enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude

    var displayName: String { rawValue.capitalized }
}

enum SessionStatus: String, Codable, Sendable {
    case running
    case needsInput
    case completed
    case failed
    case closed

    var label: String {
        switch self {
        case .running: "Running"
        case .needsInput: "Needs input"
        case .completed: "Completed"
        case .failed: "Failed"
        case .closed: "Closed"
        }
    }

    var symbol: String {
        switch self {
        case .running: "circle.fill"
        case .needsInput: "exclamationmark.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .closed: "circle"
        }
    }
}

struct TerminalIdentity: Codable, Hashable, Sendable {
    var app: String?
    var itermSessionID: String?
    var tty: String?
    var tmuxPane: String?

    static func environment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        .init(
            app: environment["AGENTWATCH_TERMINAL_APP"] ?? environment["TERM_PROGRAM"],
            itermSessionID: environment["AGENTWATCH_ITERM_SESSION_ID"] ?? environment["ITERM_SESSION_ID"],
            tty: environment["AGENTWATCH_TTY"],
            tmuxPane: environment["AGENTWATCH_TMUX_PANE"] ?? environment["TMUX_PANE"]
        )
    }
}

struct AgentSession: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var provider: AgentProvider
    var status: SessionStatus
    var cwd: String
    var summary: String
    var updatedAt: Date
    var terminal: TerminalIdentity
    var processID: Int32?

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent.isEmpty ? cwd : URL(fileURLWithPath: cwd).lastPathComponent
    }
}

struct SessionEvent: Codable, Sendable {
    var sessionID: String
    var provider: AgentProvider
    var status: SessionStatus
    var cwd: String
    var summary: String
    var timestamp: Date = .now
    var terminal: TerminalIdentity = .environment()
    var processID: Int32? = nil
}
