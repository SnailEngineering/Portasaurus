import SwiftUI
import SwiftData

/// Lists all Portainer environments (endpoints) for the connected server.
///
/// Displayed in the detail column of `ServerListView`'s `NavigationSplitView`
/// after a successful connection.
struct EnvironmentListView: View {

    let client: PortainerClient
    let serverName: String

    @State private var viewModel: EnvironmentListViewModel
    @State private var isPreview = false

    init(client: PortainerClient, serverName: String) {
        self.client = client
        self.serverName = serverName
        self._viewModel = State(initialValue: EnvironmentListViewModel())
    }

    init(client: PortainerClient, serverName: String, previewViewModel: EnvironmentListViewModel) {
        self.client = client
        self.serverName = serverName
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.environments.isEmpty {
                    ProgressView("Loading environments…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.loadError, viewModel.environments.isEmpty {
                    errorView(message: error)
                } else if viewModel.filtered.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    list
                }
            }
            .navigationTitle(serverName)
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .searchable(text: $viewModel.searchText, prompt: "Search environments")
            .refreshable { await viewModel.load(from: client) }
            .task {
                guard !isPreview else { return }
                await viewModel.load(from: client)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { env in
            NavigationLink(value: env) {
                environmentRow(env)
            }
        }
        .navigationDestination(for: PortainerEndpoint.self) { env in
            ContainerListView(client: client, environment: env)
                .navigationDestination(for: DockerContainer.self) { container in
                    ContainerDetailView(client: client, container: container, endpointId: env.id)
                }
        }
    }

    // MARK: - Environment Row

    @ViewBuilder
    private func environmentRow(_ env: PortainerEndpoint) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: env.type.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(env.name)
                        .font(.body)
                    Spacer()
                    StatusBadge(status: env.status)
                }

                HStack(spacing: 8) {
                    Text(env.type.displayName)
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    if let snap = env.snapshot {
                        snapshotSummary(snap)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func snapshotSummary(_ snap: PortainerEndpoint.DockerSnapshot) -> some View {
        HStack(spacing: 6) {
            Text("·")
                .foregroundStyle(.tertiary)
            HStack(spacing: 3) {
                Image(systemName: "play.fill").foregroundStyle(.green)
                Text("\(snap.runningContainerCount)").foregroundStyle(.primary)
            }
            HStack(spacing: 3) {
                Image(systemName: "stop.fill").foregroundStyle(.secondary)
                Text("\(snap.stoppedContainerCount)").foregroundStyle(.secondary)
            }
            if snap.unhealthyContainerCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("\(snap.unhealthyContainerCount)").foregroundStyle(.orange)
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(from: client) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
// MARK: - Previews

#Preview("Environment List") {
    EnvironmentListView(
        client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
        serverName: "My Portainer",
        previewViewModel: EnvironmentListViewModel(previewEnvironments: PortainerEndpoint.mockEnvironments)
    )
}

#Preview("No Server Selected") {
    ContentUnavailableView {
        Label("No Server Selected", systemImage: "server.rack")
    } description: {
        Text("Select a server from the list to connect.")
    }
}

// MARK: - Preview Mock Data

private extension PortainerEndpoint {
    static let mockEnvironments: [PortainerEndpoint] = {
        let items: [(id: Int, name: String, type: Int, status: Int, running: Int, stopped: Int, unhealthy: Int)] = [
            (1, "production",  1, 1, 12, 2, 1),
            (2, "staging",     1, 1,  5, 3, 0),
            (3, "dev-cluster", 2, 1,  8, 1, 0),
            (4, "edge-node-1", 4, 2,  0, 0, 0),
        ]
        return items.map { item in
            let json = """
            {
              "Id": \(item.id),
              "Name": "\(item.name)",
              "Type": \(item.type),
              "Status": \(item.status),
              "URL": "tcp://localhost:2375",
              "PublicURL": "",
              "Snapshots": [{
                "RunningContainerCount": \(item.running),
                "StoppedContainerCount": \(item.stopped),
                "HealthyContainerCount": \(item.running),
                "UnhealthyContainerCount": \(item.unhealthy),
                "DockerVersion": "24.0.7"
              }]
            }
            """
            return try! JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
        }
    }()
}

