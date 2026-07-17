import AppKit
import Foundation

enum TerminalNavigator {
    @MainActor
    static func focus(_ session: AgentSession) {
        if let pane = session.terminal.tmuxPane, !pane.isEmpty {
            run("/opt/homebrew/bin/tmux", ["select-pane", "-t", pane])
        }

        if let sessionID = session.terminal.itermSessionID, !sessionID.isEmpty {
            focusITerm(sessionID: sessionID)
            return
        }

        let bundleID: String = switch session.terminal.app?.lowercased() {
        case "apple_terminal": "com.apple.Terminal"
        case "wezterm": "com.github.wez.wezterm"
        case "warpterminal": "dev.warp.Warp-Stable"
        default: "com.googlecode.iterm2"
        }
        NSWorkspace.shared.openApplication(
            at: NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) ?? URL(fileURLWithPath: "/Applications/iTerm.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    @MainActor
    private static func focusITerm(sessionID: String) {
        let escaped = sessionID.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "iTerm2"
          activate
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if "\(escaped)" ends with (unique ID of s) or (unique ID of s) is "\(escaped)" then
                  select t
                  select s
                  return
                end if
              end repeat
            end repeat
          end repeat
        end tell
        """
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                NSWorkspace.shared.openApplication(
                    at: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") ?? URL(fileURLWithPath: "/Applications/iTerm.app"),
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2")
            .first?
            .activate(options: [.activateAllWindows])
    }

    private static func run(_ executable: String, _ arguments: [String]) {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try? process.run()
    }
}
