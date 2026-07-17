# Agent Watch

A native macOS menu bar inbox for local coding-agent sessions. See which Codex and Claude Code sessions are running, waiting for you, completed, failed, or closed—and jump back to the matching iTerm2 session with one click.

> Early preview: Claude Code lifecycle tracking is complete. Codex currently exposes reliable turn-complete events; richer Codex running and approval tracking is planned.

## What it does

- Tracks multiple Codex and Claude Code sessions by their stable session IDs.
- Shows `Running`, `Needs input`, `Completed`, `Failed`, and `Closed` states.
- Stores events even while the menu bar app is not running.
- Focuses the matching iTerm2 tab or pane when you click a session.
- Acknowledges a completed session when clicked, removing it from the list until a new event arrives.
- Uses only local files. No telemetry and no network service.

## Requirements

- macOS 14 or newer
- Xcode 16 or a compatible Swift 6 toolchain
- iTerm2 for precise one-click session focusing
- Codex CLI and/or Claude Code

## Install

```sh
git clone https://github.com/johney4415/agent-watch.git
cd agent-watch
make install
open "$HOME/Applications/Agent Watch.app"
```

Ensure `~/.local/bin` is on your `PATH` before configuring hooks.

Install both hooks automatically (existing configuration is backed up and merged):

```sh
agent-watch install-hooks
```

The installer preserves an existing Codex notifier by forwarding the original payload to it.

## Configure Codex

Add this top-level setting to `~/.codex/config.toml`:

```toml
notify = ["/Users/YOU/.local/bin/agent-watch", "codex-hook"]
```

Codex invokes the helper with a JSON argument when an agent turn completes. The payload includes the thread ID, working directory, input messages, and final assistant message.

## Configure Claude Code

Merge the following into `~/.claude/settings.json`. If you already have hooks for an event, append the new handler instead of replacing the existing array.

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }],
    "SessionEnd": [{ "hooks": [{ "type": "command", "command": "$HOME/.local/bin/agent-watch claude-hook" }] }]
  }
}
```

Claude sends hook JSON over standard input. Agent Watch maps lifecycle events as follows:

| Claude event | Agent Watch status |
| --- | --- |
| `SessionStart`, `UserPromptSubmit` | Running |
| `Notification` (`permission_prompt`, `idle_prompt`) | Needs input |
| `Stop` | Completed |
| `StopFailure` | Failed |
| `SessionEnd` | Closed |

## Try it without changing config

```sh
agent-watch emit-demo claude
open "$HOME/Applications/Agent Watch.app"
```

## How it works

The CLI helper appends hook payloads as normalized events to `~/.agent-watch/events.ndjson`. The menu bar process reads that append-only log and reduces it to the latest event for every session. Terminal identity comes from inherited iTerm2 and tmux environment variables, so no shell wrapper is required.

Clicking a row uses iTerm2's AppleScript interface to select the matching session. macOS may ask for Automation permission on the first click.

## Development

```sh
swift build
swift test
swift run agent-watch
```

The project intentionally has no third-party runtime dependencies.

## Roadmap

- Codex approval and turn-start detection
- Apple Terminal, Warp, and WezTerm navigation adapters
- Native notifications and unread acknowledgement
- Launch at login
- Signed and notarized releases
- Homebrew cask

## Privacy

Agent Watch stores short event summaries and project paths locally in `~/.agent-watch/events.ndjson`. It does not transmit data. Remove that file at any time to clear history.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
