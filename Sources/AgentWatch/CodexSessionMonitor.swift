import Foundation

final class CodexSessionMonitor: @unchecked Sendable {
    private let sessionsDirectory: URL
    private let decoder = JSONDecoder()
    private let iso8601 = ISO8601DateFormatter()
    private let recentInterval: TimeInterval

    init(
        sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex/sessions", directoryHint: .isDirectory),
        recentInterval: TimeInterval = 48 * 60 * 60
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.recentInterval = recentInterval
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func sessions(now: Date = .now) -> [AgentSession] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = now.addingTimeInterval(-recentInterval)
        var results: [AgentSession] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff,
                  let data = try? Data(contentsOf: url),
                  let session = parse(data: data),
                  session.updatedAt >= cutoff else { continue }
            results.append(session)
        }
        return results.sorted { $0.updatedAt > $1.updatedAt }
    }

    func parse(data: Data) -> AgentSession? {
        var sessionID: String?
        var cwd = ""
        var status: SessionStatus?
        var summary = ""
        var updatedAt: Date?
        var pendingApprovals = Set<String>()
        var isInteractiveCLI = true

        for line in data.split(separator: 0x0A) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let type = object["type"] as? String,
                  let payload = object["payload"] as? [String: Any] else { continue }
            let timestamp = (object["timestamp"] as? String).flatMap(iso8601.date(from:))

            if type == "session_meta" {
                sessionID = payload["session_id"] as? String ?? payload["id"] as? String
                cwd = payload["cwd"] as? String ?? cwd
                // ~/.codex/sessions also contains one-shot `codex exec` and
                // app-server work. They are not terminal sessions and cannot
                // be focused from the menu bar.
                if let originator = payload["originator"] as? String {
                    isInteractiveCLI = originator == "codex-tui"
                } else if let source = payload["source"] as? String {
                    isInteractiveCLI = source == "cli"
                }
                continue
            }

            guard type == "event_msg" || type == "response_item" else { continue }
            let eventType = payload["type"] as? String ?? ""
            switch eventType {
            case "task_started":
                status = .running
                summary = "Codex is working"
                updatedAt = timestamp ?? updatedAt
                pendingApprovals.removeAll()
            case "user_message":
                if let message = payload["message"] as? String {
                    summary = compact(message)
                }
            case "task_complete":
                status = .completed
                summary = compact(payload["last_agent_message"] as? String ?? "Turn completed")
                updatedAt = timestamp ?? updatedAt
                pendingApprovals.removeAll()
            case "turn_aborted":
                status = .failed
                summary = "Turn aborted"
                updatedAt = timestamp ?? updatedAt
                pendingApprovals.removeAll()
            case "custom_tool_call", "function_call":
                let input = payload["input"] as? String ?? ""
                let toolName = payload["name"] as? String ?? payload["tool_name"] as? String ?? ""
                if (input.contains(#""sandbox_permissions":"require_escalated""#)
                    || toolName == "request_user_input"),
                   let callID = payload["call_id"] as? String {
                    pendingApprovals.insert(callID)
                    status = .needsInput
                    summary = toolName == "request_user_input" ? "Codex is waiting for your answer" : "Codex needs approval"
                    updatedAt = timestamp ?? updatedAt
                }
            case "custom_tool_call_output", "function_call_output":
                if let callID = payload["call_id"] as? String,
                   pendingApprovals.remove(callID) != nil,
                   status == .needsInput {
                    status = .running
                    summary = "Codex is working"
                    updatedAt = timestamp ?? updatedAt
                }
            default:
                break
            }
        }

        guard isInteractiveCLI, let sessionID, let status, let updatedAt else { return nil }
        return AgentSession(
            id: sessionID,
            provider: .codex,
            status: status,
            cwd: cwd,
            summary: summary,
            updatedAt: updatedAt,
            terminal: .init(app: nil, itermSessionID: nil, tty: nil, tmuxPane: nil),
            processID: nil
        )
    }

    private func compact(_ text: String) -> String {
        String(text.split(whereSeparator: \Character.isNewline).joined(separator: " ").prefix(160))
    }
}
