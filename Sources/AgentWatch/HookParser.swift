import Foundation

enum HookParserError: Error, LocalizedError {
    case invalidJSON
    case missingSessionID

    var errorDescription: String? {
        switch self {
        case .invalidJSON: "Hook input is not a JSON object"
        case .missingSessionID: "Hook input does not contain a session ID"
        }
    }
}

enum HookParser {
    static func codex(_ data: Data, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> SessionEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookParserError.invalidJSON
        }
        guard let sessionID = object["thread-id"] as? String else { throw HookParserError.missingSessionID }
        let messages = object["input-messages"] as? [String] ?? []
        let lastMessage = object["last-assistant-message"] as? String
        return SessionEvent(
            sessionID: sessionID,
            provider: .codex,
            status: .completed,
            cwd: object["cwd"] as? String ?? environment["PWD"] ?? "",
            summary: compact(lastMessage ?? (messages.isEmpty ? "Turn completed" : messages.joined(separator: " "))),
            terminal: .environment(environment)
        )
    }

    static func claude(_ data: Data, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> SessionEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookParserError.invalidJSON
        }
        guard let sessionID = object["session_id"] as? String else { throw HookParserError.missingSessionID }
        let eventName = object["hook_event_name"] as? String ?? ""
        let notificationType = object["notification_type"] as? String
        let status: SessionStatus = switch eventName {
        case "UserPromptSubmit", "SessionStart": .running
        case "Notification" where notificationType == "permission_prompt" || notificationType == "idle_prompt": .needsInput
        case "Stop": .completed
        case "StopFailure": .failed
        case "SessionEnd": .closed
        default: .running
        }
        let message = object["message"] as? String
            ?? object["last_assistant_message"] as? String
            ?? eventName
        return SessionEvent(
            sessionID: sessionID,
            provider: .claude,
            status: status,
            cwd: object["cwd"] as? String ?? environment["PWD"] ?? "",
            summary: compact(message),
            terminal: .environment(environment)
        )
    }

    private static func compact(_ text: String) -> String {
        let singleLine = text.split(whereSeparator: \Character.isNewline).joined(separator: " ")
        return String(singleLine.prefix(160))
    }
}
