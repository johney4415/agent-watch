import AppKit
import Foundation

@MainActor
final class TerminalSessionRegistry {
    private var cachedIDs: Set<String>?
    private var lastRefresh = Date.distantPast
    private let refreshInterval: TimeInterval

    init(refreshInterval: TimeInterval = 3) {
        self.refreshInterval = refreshInterval
    }

    func liveITermSessionIDs(now: Date = .now, force: Bool = false) -> Set<String>? {
        guard force || now.timeIntervalSince(lastRefresh) >= refreshInterval else { return cachedIDs }
        lastRefresh = now

        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2").isEmpty
        guard running else {
            cachedIDs = []
            return cachedIDs
        }

        let source = """
        tell application "iTerm2"
          set sessionIDs to {}
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                set end of sessionIDs to unique ID of s
              end repeat
            end repeat
          end repeat
          set AppleScript's text item delimiters to linefeed
          return sessionIDs as text
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return cachedIDs }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let text = result.stringValue else { return cachedIDs }
        cachedIDs = Set(text.split(whereSeparator: \Character.isNewline).map(String.init))
        return cachedIDs
    }

    nonisolated static func normalizedITermID(_ environmentID: String) -> String {
        environmentID.split(separator: ":").last.map(String.init) ?? environmentID
    }

    nonisolated static func isLive(_ terminal: TerminalIdentity, in liveIDs: Set<String>) -> Bool {
        guard let id = terminal.itermSessionID, !id.isEmpty else { return true }
        return liveIDs.contains(normalizedITermID(id))
    }
}
