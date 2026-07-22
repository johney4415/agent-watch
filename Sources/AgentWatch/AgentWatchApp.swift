import AppKit
import SwiftUI

@main
struct AgentWatchApp: App {
    @StateObject private var model = SessionViewModel()

    init() {
        if CommandLine.arguments.count > 1 {
            do {
                try HookCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
                Foundation.exit(EXIT_SUCCESS)
            } catch {
                FileHandle.standardError.write(Data("agent-watch: \(error.localizedDescription)\n".utf8))
                Foundation.exit(EXIT_FAILURE)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            SessionMenu(model: model)
        } label: {
            Image(systemName: model.attentionCount > 0 ? "bubble.left.and.exclamationmark.bubble.right.fill" : "bubble.left.and.bubble.right")
            if model.attentionCount > 0 {
                Text("\(model.attentionCount)")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SessionMenu: View {
    @ObservedObject var model: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Agent Watch").font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refresh(forceTerminalRefresh: true)
                }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
            }

            if model.activeSessions.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "terminal", description: Text("Install the Codex and Claude hooks to begin."))
                    .frame(width: 330, height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.activeSessions) { session in
                            SessionRow(session: session) { model.select(session) }
                        }
                    }
                }
                .frame(width: 360, height: min(CGFloat(model.activeSessions.count * 64), 420))
            }

            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()
            HStack {
                Button("Open event log") {
                    NSWorkspace.shared.open(EventStore.shared.eventsURL)
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(12)
    }
}

private struct SessionRow: View {
    let session: AgentSession
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: session.status.symbol)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.provider.displayName).fontWeight(.semibold)
                        Text("·")
                        Text(session.projectName).lineLimit(1)
                        Spacer()
                        Text(session.status.label).foregroundStyle(color)
                    }
                    Text(session.summary.isEmpty ? session.cwd : session.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(session.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var color: Color {
        switch session.status {
        case .running: .blue
        case .needsInput: .orange
        case .completed: .green
        case .failed: .red
        case .closed: .gray
        }
    }
}
