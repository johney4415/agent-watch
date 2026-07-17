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

## Quick start

```sh
git clone https://github.com/johney4415/agent-watch.git
cd agent-watch
make install
agent-watch install-hooks
open "$HOME/Applications/Agent Watch.app"
```

`make install` installs:

- CLI: `~/.local/bin/agent-watch`
- App: `~/Applications/Agent Watch.app`

Ensure `~/.local/bin` is on your `PATH`, or invoke the CLI using its absolute path.

`agent-watch install-hooks` is idempotent and configures both supported providers. It:

- Backs up existing files using the `.agent-watch-backup` suffix.
- Merges handlers into `~/.claude/settings.json` without replacing unrelated settings or hooks.
- Configures the top-level Codex `notify` command in `~/.codex/config.toml`.
- Preserves an existing Codex notifier by forwarding the original event to it.

Restart existing Codex and Claude Code sessions after installation. Newly opened sessions inherit the hooks and terminal identity.

## Verify the installation

Start the app and emit a local test event:

```sh
open "$HOME/Applications/Agent Watch.app"
agent-watch emit-demo claude
```

The menu bar should show one Claude session in `Needs input`. Clicking the row should focus the matching iTerm2 session.

On the first click, macOS may request permission for Agent Watch to control iTerm2. If navigation does not work, enable it under:

```text
System Settings → Privacy & Security → Automation → Agent Watch → iTerm2
```

The demo event is local test data. Remove it from `~/.agent-watch/events.ndjson` when finished.

## CLI reference

```text
agent-watch install-hooks       Back up and merge Codex and Claude Code hooks
agent-watch emit-demo claude    Emit a local Claude test event
agent-watch emit-demo codex     Emit a local Codex test event
agent-watch claude-hook         Receive Claude hook JSON on standard input
agent-watch codex-hook <json>   Receive a Codex notification payload
```

The hook commands are normally invoked by Codex and Claude Code, not manually.

## Manual configuration

Automatic configuration is recommended. Use the following only if you manage dotfiles declaratively or need custom hook composition.

### Codex

Add this top-level setting to `~/.codex/config.toml`:

```toml
notify = ["/Users/YOU/.local/bin/agent-watch", "codex-hook"]
```

Codex invokes the helper with a JSON argument when an agent turn completes. The payload includes the thread ID, working directory, input messages, and final assistant message. If `notify` already exists, use `agent-watch install-hooks` so the existing notifier is preserved and chained correctly.

### Claude Code

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

## How it works

The CLI helper appends hook payloads as normalized events to `~/.agent-watch/events.ndjson`. The menu bar process reads that append-only log and reduces it to the latest event for every session. Terminal identity comes from inherited iTerm2 and tmux environment variables, so no shell wrapper is required.

Clicking a row closes the Agent Watch popover, focuses the matching iTerm2 session, and leaves keyboard focus in that terminal so you can type immediately. Clicking a completed session also acknowledges it, removing it from the list and badge until that session emits a new event.

The menu bar badge counts sessions in `Needs input`, `Completed`, or `Failed`. It does not count `Running` or `Closed` sessions.

## Troubleshooting

### The app is running but the list is empty

Confirm that the event log exists and receives new lines:

```sh
tail -f "$HOME/.agent-watch/events.ndjson"
```

Restart agent sessions created before `install-hooks` was run. You can also run `agent-watch emit-demo claude` to test the app independently of provider hooks.

### Clicking a session does not focus iTerm2

Grant Automation permission under `System Settings → Privacy & Security → Automation`. Precise navigation currently requires iTerm2 and the session must still be open.

### Codex Computer Use or another notifier is already configured

Run `agent-watch install-hooks`. The installer turns Agent Watch into a dispatcher and forwards the unchanged Codex payload to the existing notifier after recording it.

### Restore the previous configuration

The installer creates:

```text
~/.codex/config.toml.agent-watch-backup
~/.claude/settings.json.agent-watch-backup
```

Review and restore those files manually if needed. A dedicated `uninstall-hooks` command is planned.

## Development

```sh
swift build
swift test
swift run agent-watch
```

The project intentionally has no third-party runtime dependencies.

## Roadmap

- `setup`, `doctor`, `status`, and `uninstall-hooks` CLI workflows
- Native Settings and diagnostics UI backed by the same configuration engine
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
