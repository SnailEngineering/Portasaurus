import SwiftUI
import SwiftData

/// Landing view — lists saved Portainer servers and handles connect/delete.
struct ServerListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedServer.dateAdded) private var servers: [SavedServer]

    @State private var viewModel = ServerListViewModel()
    @State private var showingAddServer = false
    @State private var activeClient: PortainerClient?
    @State private var activeServerID: UUID?
    @State private var activeServerName = ""

    var body: some View {
        NavigationSplitView {
            List {
                if servers.isEmpty {
                    emptyState
                } else {
                    ForEach(servers) { server in
                        ServerRowView(
                            server: server,
                            state: viewModel.connectionState(for: server),
                            onTap: {
                                viewModel.clearError(for: server)
                                Task {
                                    if let client = await viewModel.connect(to: server) {
                                        activeClient = client
                                        activeServerID = server.id
                                        activeServerName = server.name
                                    }
                                }
                            },
                            onDelete: {
                                if activeServerID == server.id { activeClient = nil; activeServerID = nil; activeServerName = "" }
                                viewModel.delete(server, in: modelContext)
                            }
                        )
                    }
                    .onDelete(perform: deleteServers)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
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
                AddServerView { client, serverID, name in
                    activeClient = client
                    activeServerID = serverID
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
            if activeServerID == server.id { activeClient = nil; activeServerID = nil; activeServerName = "" }
            viewModel.delete(server, in: modelContext)
        }
    }
}

#Preview {
    ServerListView()
        .modelContainer(for: SavedServer.self, inMemory: true)
}
