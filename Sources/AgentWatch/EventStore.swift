import Foundation

final class EventStore: @unchecked Sendable {
    static let shared = EventStore()

    let eventsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".agent-watch", directoryHint: .isDirectory)
        eventsURL = base.appending(path: "events.ndjson")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func append(_ event: SessionEvent) throws {
        try FileManager.default.createDirectory(
            at: eventsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var data = try encoder.encode(event)
        data.append(0x0A)

        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            _ = FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: eventsURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    func sessions() throws -> [AgentSession] {
        guard FileManager.default.fileExists(atPath: eventsURL.path) else { return [] }
        let data = try Data(contentsOf: eventsURL)
        var latest: [String: AgentSession] = [:]

        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(SessionEvent.self, from: Data(line)) else { continue }
            latest[event.sessionID] = AgentSession(
                id: event.sessionID,
                provider: event.provider,
                status: event.status,
                cwd: event.cwd,
                summary: event.summary,
                updatedAt: event.timestamp,
                terminal: event.terminal,
                processID: event.processID
            )
        }
        return latest.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
