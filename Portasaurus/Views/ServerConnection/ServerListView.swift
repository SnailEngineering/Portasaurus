import SwiftUI
import SwiftData

/// Root landing view — shows saved Portainer servers as visual cards.
///
/// On launch, if any server has `autoReconnect` enabled, the app authenticates
/// automatically and pushes straight into that server's environment list.
struct ServerListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedServer.dateAdded) private var servers: [SavedServer]

    @State private var viewModel = ServerListViewModel()
    @State private var showingAddServer = false

    /// Navigation path for the root NavigationStack.
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            scrollContent
                .navigationTitle("Servers")
#if os(iOS)
                .navigationBarTitleDisplayMode(.large)
#endif
                .toolbar { addButton }
                .sheet(isPresented: $showingAddServer) {
                    AddServerView { client, _, name in
                        showingAddServer = false
                        navigationPath.append(ConnectedServer(client: client, name: name))
                    }
                }
                .navigationDestination(for: ConnectedServer.self) { connected in
                    EnvironmentListView(client: connected.client, serverName: connected.name)
                }
                .task { await attemptAutoReconnect() }
        }
    }

    // MARK: - Scroll content

    @ViewBuilder
    private var scrollContent: some View {
        if servers.isEmpty {
            emptyState
        } else {
            ScrollView {
                serverGrid
                    .padding()
            }
        }
    }

    // MARK: - Server grid

    private var serverGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(servers) { server in
                ServerCardView(
                    server: server,
                    state: viewModel.connectionState(for: server),
                    onTap: { connect(to: server) },
                    onDelete: { delete(server) },
                    onToggleAutoReconnect: { server.autoReconnect.toggle() }
                )
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingAddServer = true } label: {
                Label("Add Server", systemImage: "plus")
            }
        }
    }

    // MARK: - Empty state

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

    // MARK: - Actions

    private func connect(to server: SavedServer) {
        viewModel.clearError(for: server)
        Task {
            if let client = await viewModel.connect(to: server) {
                navigationPath.append(ConnectedServer(client: client, name: server.name))
            }
        }
    }

    private func delete(_ server: SavedServer) {
        viewModel.delete(server, in: modelContext)
    }

    /// On launch, find the first server flagged for auto-reconnect and connect silently.
    private func attemptAutoReconnect() async {
        // Only attempt if there is exactly one path entry (i.e. we haven't already navigated).
        guard navigationPath.isEmpty else { return }
        guard let server = servers.first(where: { $0.autoReconnect }) else { return }
        if let client = await viewModel.connect(to: server) {
            navigationPath.append(ConnectedServer(client: client, name: server.name))
        }
    }
}

// MARK: - Navigation value

/// Wraps an authenticated client so it can be pushed onto a NavigationPath.
private struct ConnectedServer: Hashable {
    let client: PortainerClient
    let name: String

    static func == (lhs: ConnectedServer, rhs: ConnectedServer) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

// MARK: - Previews

#Preview("Servers — Light") {
    ServerListView()
        .modelContainer(makePreviewContainer())
        .preferredColorScheme(.light)
        .frame(minWidth: 600, minHeight: 500)
}

#Preview("Servers — Dark") {
    ServerListView()
        .modelContainer(makePreviewContainer())
        .preferredColorScheme(.dark)
        .frame(minWidth: 600, minHeight: 500)
}

#Preview("No Servers") {
    ServerListView()
        .modelContainer(for: SavedServer.self, inMemory: true)
        .frame(minWidth: 600, minHeight: 400)
}

// MARK: - Preview container

@MainActor
private func makePreviewContainer() -> ModelContainer {
    let container = try! ModelContainer(for: SavedServer.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext
    let s1 = SavedServer(name: "Home Lab", serverURL: "https://portainer.local:9443", username: "admin", autoReconnect: false)
    s1.lastConnected = Date(timeIntervalSinceNow: -3600)
    let s2 = SavedServer(name: "Production", serverURL: "https://portainer.example.com", username: "deploy")
    let s3 = SavedServer(name: "Staging", serverURL: "https://staging.example.com:9000", username: "admin")
    s3.lastConnected = Date(timeIntervalSinceNow: -86400)
    ctx.insert(s1); ctx.insert(s2); ctx.insert(s3)
    return container
}
