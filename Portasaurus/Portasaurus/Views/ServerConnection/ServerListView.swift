import SwiftUI
import SwiftData

/// Landing view — lists saved Portainer servers and handles connect/delete.
struct ServerListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedServer.dateAdded) private var servers: [SavedServer]

    @State private var viewModel = ServerListViewModel()
    @State private var showingAddServer = false
    @State private var activeClient: PortainerClient?
    @State private var activeServerName = ""

    var body: some View {
        NavigationSplitView {
            List {
                if servers.isEmpty {
                    emptyState
                } else {
                    ForEach(servers) { server in
                        serverRow(for: server)
                    }
                    .onDelete(perform: deleteServers)
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddServer = true } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
#endif
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerView { client, name in
                    activeClient = client
                    activeServerName = name
                    showingAddServer = false
                }
            }
        } detail: {
            if let client = activeClient {
                EnvironmentListView(client: client, serverName: activeServerName)
            } else {
                ContentUnavailableView {
                    Label("No Server Selected", systemImage: "server.rack")
                } description: {
                    Text("Select a server from the list to connect.")
                }
            }
        }
    }

    // MARK: - Server Row

    @ViewBuilder
    private func serverRow(for server: SavedServer) -> some View {
        let state = viewModel.connectionState(for: server)

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
            viewModel.clearError(for: server)
            Task {
                if let client = await viewModel.connect(to: server) {
                    activeClient = client
                    activeServerName = server.name
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(server, in: modelContext)
            } label: {
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

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Servers", systemImage: "server.rack")
        } description: {
            Text("Add a Portainer server to get started.")
        } actions: {
            Button("Add Server") { showingAddServer = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Delete

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]
            if activeServerName == server.name { activeClient = nil; activeServerName = "" }
            viewModel.delete(server, in: modelContext)
        }
    }
}

#Preview {
    ServerListView()
        .modelContainer(for: SavedServer.self, inMemory: true)
}
