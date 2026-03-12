import SwiftUI
import SwiftData

/// A single row in the server list showing connection state, metadata, and actions.
struct ServerRowView: View {

    let server: SavedServer
    let state: ServerListViewModel.ConnectionState
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                stateIcon(for: state)

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.body)

                    Text(server.serverURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastConnected = server.lastConnected {
                        Text("Last connected \(lastConnected.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if state == .connecting {
                    ProgressView().controlSize(.small)
                }
            }

            if case .failed(let message) = state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 36)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard state != .connecting else { return }
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func stateIcon(for state: ServerListViewModel.ConnectionState) -> some View {
        switch state {
        case .idle:
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 24)
        case .connecting:
            Image(systemName: "server.rack")
                .foregroundStyle(.orange)
                .frame(width: 24)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .frame(width: 24)
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
    let server = SavedServer(name: "Home Lab", serverURL: "https://portainer.local:9443", username: "admin")
    List {
        ServerRowView(server: server, state: .idle, onTap: {}, onDelete: {})
    }
}

#Preview("Connecting") {
    let server = SavedServer(name: "Home Lab", serverURL: "https://portainer.local:9443", username: "admin")
    List {
        ServerRowView(server: server, state: .connecting, onTap: {}, onDelete: {})
    }
}

#Preview("Failed") {
    let server = SavedServer(name: "Home Lab", serverURL: "https://portainer.local:9443", username: "admin")
    List {
        ServerRowView(server: server, state: .failed("Connection refused"), onTap: {}, onDelete: {})
    }
}

#Preview("With Last Connected") {
    let server = SavedServer(name: "Production", serverURL: "https://portainer.example.com", username: "admin")
    server.lastConnected = Date(timeIntervalSinceNow: -3600)
    return List {
        ServerRowView(server: server, state: .idle, onTap: {}, onDelete: {})
    }
}
