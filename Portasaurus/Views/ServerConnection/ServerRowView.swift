import SwiftUI
import SwiftData

/// A card representing a single saved Portainer server.
///
/// Shows the server name, URL, last-connected time, connection state,
/// and an auto-reconnect toggle. Tapping the card triggers a connection attempt.
struct ServerCardView: View {

    let server: SavedServer
    let state: ServerListViewModel.ConnectionState
    let onTap: () -> Void
    let onDelete: () -> Void
    let onToggleAutoReconnect: () -> Void

    var body: some View {
        Button(action: { guard state != .connecting else { return }; onTap() }) {
            cardFace
        }
        .buttonStyle(.plain)
        .contextMenu {
            Toggle(isOn: Binding(
                get: { server.autoReconnect },
                set: { _ in onToggleAutoReconnect() }
            )) {
                Label("Auto-Reconnect", systemImage: "arrow.clockwise")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Server", systemImage: "trash")
            }
        }
    }

    // MARK: - Card face

    private var cardFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + name + status indicator
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "server.rack")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(server.serverURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                statusIndicator
            }

            // Divider
            Divider()
                .padding(.vertical, 10)

            // Footer: last connected + auto-reconnect badge
            HStack(spacing: 6) {
                if let lastConnected = server.lastConnected {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(lastConnected.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Never connected")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                if server.autoReconnect {
                    Label("Auto", systemImage: "arrow.clockwise")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                }
            }

            // Error message (if any)
            if case .failed(let message) = state {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 6)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    // MARK: - Derived appearance

    private var accentColor: Color {
        switch state {
        case .idle:        return .blue
        case .connecting:  return .orange
        case .failed:      return .red
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:       return .clear
        case .connecting: return .orange.opacity(0.4)
        case .failed:     return .red.opacity(0.3)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch state {
        case .idle:
            EmptyView()
        case .connecting:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

// MARK: - Previews

#Preview("Idle + Auto-Reconnect — Light") {
    previewGrid(scheme: .light)
}

#Preview("Idle + Auto-Reconnect — Dark") {
    previewGrid(scheme: .dark)
}

private func previewGrid(scheme: ColorScheme) -> some View {
    let idle    = SavedServer(name: "Home Lab",    serverURL: "https://portainer.local:9443",       username: "admin",  autoReconnect: true)
    let prod    = SavedServer(name: "Production",  serverURL: "https://portainer.example.com",      username: "deploy", autoReconnect: false)
    let failed  = SavedServer(name: "Staging",     serverURL: "https://staging.example.com:9000",   username: "admin",  autoReconnect: false)
    idle.lastConnected   = Date(timeIntervalSinceNow: -3600)
    prod.lastConnected   = Date(timeIntervalSinceNow: -86400)

    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    return ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            ServerCardView(server: idle,   state: .idle,                         onTap: {}, onDelete: {}, onToggleAutoReconnect: {})
            ServerCardView(server: prod,   state: .connecting,                   onTap: {}, onDelete: {}, onToggleAutoReconnect: {})
            ServerCardView(server: failed, state: .failed("Connection refused"), onTap: {}, onDelete: {}, onToggleAutoReconnect: {})
        }
        .padding()
    }
    .frame(minWidth: 600, minHeight: 400)
    .preferredColorScheme(scheme)
}
