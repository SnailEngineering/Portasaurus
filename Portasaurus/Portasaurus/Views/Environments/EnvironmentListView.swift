import SwiftUI

/// Lists all Portainer environments (endpoints) for the connected server.
///
/// Displayed in the detail column of `ServerListView`'s `NavigationSplitView`
/// after a successful connection.
struct EnvironmentListView: View {

    let client: PortainerClient
    let serverName: String

    @State private var viewModel = EnvironmentListViewModel()

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
            .task { await viewModel.load(from: client) }
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
            // Phase 3 will replace this placeholder.
            ContentUnavailableView {
                Label(env.name, systemImage: env.type.systemImage)
            } description: {
                Text("Container management coming in Phase 3.")
            }
            .navigationTitle(env.name)
        }
    }

    // MARK: - Environment Row

    @ViewBuilder
    private func environmentRow(_ env: PortainerEndpoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(env.name, systemImage: env.type.systemImage)
                    .font(.body)
                Spacer()
                StatusBadge(status: env.status)
            }

            HStack(spacing: 12) {
                Label(env.type.displayName, systemImage: "tag")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                if let snap = env.snapshot {
                    Divider().frame(height: 12)
                    snapshotSummary(snap)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func snapshotSummary(_ snap: PortainerEndpoint.DockerSnapshot) -> some View {
        HStack(spacing: 8) {
            Label("\(snap.runningContainerCount)", systemImage: "play.fill")
                .foregroundStyle(.green)
            Label("\(snap.stoppedContainerCount)", systemImage: "stop.fill")
                .foregroundStyle(.secondary)
            if snap.unhealthyContainerCount > 0 {
                Label("\(snap.unhealthyContainerCount)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
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
