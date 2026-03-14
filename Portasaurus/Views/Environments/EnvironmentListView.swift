import SwiftUI
import SwiftData

/// Lists all Portainer environments for a connected server as large scrollable cards.
///
/// Each card embeds tappable resource tiles that navigate directly into the relevant
/// resource list, removing the intermediate dashboard screen.
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
        Group {
            if viewModel.isLoading && viewModel.environments.isEmpty {
                ProgressView("Loading environments…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.environments.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                scrollContent
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
        .navigationDestination(for: EnvironmentSection.self) { destination in
            destination.view(client: client)
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filtered) { env in
                    EnvironmentCard(client: client, env: env)
                }
            }
            .padding()
        }
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

// MARK: - Environment Section

/// Typed navigation value that pairs an environment with a resource category,
/// so that `navigationDestination` can resolve the correct destination view.
struct EnvironmentSection: Hashable {
    enum Category: Hashable {
        case containers
        case stacks
        case images
        case volumes
        case networks
        case registries
    }

    let environment: PortainerEndpoint
    let category: Category

    @ViewBuilder
    func view(client: PortainerClient) -> some View {
        switch category {
        case .containers:
            ContainerListView(client: client, environment: environment)
        case .stacks:
            StackListView(client: client, environment: environment)
        case .images:
            ImageListView(client: client, environment: environment)
        case .volumes:
            VolumeListView(client: client, environment: environment)
        case .networks:
            NetworkListView(client: client, environment: environment)
        case .registries:
            ComingSoonView(title: "Registries", systemImage: "externaldrive.connected.to.line.below.fill")
        }
    }
}

// MARK: - Environment Card

/// A large card for one Portainer environment, showing tappable resource tiles.
private struct EnvironmentCard: View {

    let client: PortainerClient
    let env: PortainerEndpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if let snap = env.snapshot {
                Divider()
                resourceGrid(snap)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: env.type.systemImage)
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(env.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(env.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let snap = env.snapshot, let version = snap.dockerVersion {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(version)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let date = env.snapshot?.date {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                        Text(date, format: .dateTime.year().month().day().hour().minute().second())
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: env.status)
                if let snap = env.snapshot {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text("\(snap.totalCPU) CPU")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                            Text(snap.formattedMemory)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Resource tiles

    private func resourceGrid(_ snap: PortainerEndpoint.DockerSnapshot) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            resourceTile(
                section: .init(environment: env, category: .stacks),
                systemImage: "square.stack.3d.up.fill",
                title: "Stacks",
                value: "\(snap.stackCount)"
            )
            resourceTile(
                section: .init(environment: env, category: .containers),
                systemImage: "shippingbox.fill",
                title: "Containers",
                value: "\(snap.totalContainerCount)",
                badge: { containerBadge(snap) }
            )
            resourceTile(
                section: .init(environment: env, category: .images),
                systemImage: "photo.stack.fill",
                title: "Images",
                value: "\(snap.imageCount)"
            )
            resourceTile(
                section: .init(environment: env, category: .volumes),
                systemImage: "cylinder.fill",
                title: "Volumes",
                value: "\(snap.volumeCount)"
            )
            resourceTile(
                section: .init(environment: env, category: .networks),
                systemImage: "network",
                title: "Networks",
                value: "—"
            )
            resourceTile(
                section: .init(environment: env, category: .registries),
                systemImage: "externaldrive.connected.to.line.below.fill",
                title: "Registries",
                value: "—"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resourceTile(
        section: EnvironmentSection,
        systemImage: String,
        title: String,
        value: String,
        @ViewBuilder badge: () -> some View = { EmptyView() }
    ) -> some View {
        NavigationLink(value: section) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(.blue)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                badge()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func containerBadge(_ snap: PortainerEndpoint.DockerSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "power")
                .foregroundStyle(.green)
            Text("\(snap.runningContainerCount)")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    private var borderColor: Color {
        switch env.status {
        case .up:   return .clear
        case .down: return .red.opacity(0.25)
        }
    }
}

// MARK: - Coming Soon placeholder

private struct ComingSoonView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text("Coming soon.")
        }
        .navigationTitle(title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }
}

// MARK: - Previews

#Preview("Environments — Light") {
    NavigationStack {
        EnvironmentListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            serverName: "My Portainer",
            previewViewModel: EnvironmentListViewModel(previewEnvironments: PortainerEndpoint.mockEnvironments)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Environments — Dark") {
    NavigationStack {
        EnvironmentListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            serverName: "My Portainer",
            previewViewModel: EnvironmentListViewModel(previewEnvironments: PortainerEndpoint.mockEnvironments)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Single Environment") {
    NavigationStack {
        EnvironmentListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            serverName: "Home Lab",
            previewViewModel: EnvironmentListViewModel(previewEnvironments: [PortainerEndpoint.mockEnvironments[0]])
        )
    }
}

// MARK: - Preview Mock Data

private extension PortainerEndpoint {
    static let mockEnvironments: [PortainerEndpoint] = {
        struct MockEnv {
            var id: Int; var name: String; var type: Int; var status: Int
            var running: Int; var stopped: Int; var unhealthy: Int
            var volumes: Int; var images: Int; var stacks: Int
            var cpu: Int; var memoryGB: Double
        }
        let items: [MockEnv] = [
            MockEnv(id: 1, name: "production",  type: 1, status: 1, running: 12, stopped: 2, unhealthy: 1, volumes: 23, images: 39, stacks: 8,  cpu: 12, memoryGB: 23.6),
            MockEnv(id: 2, name: "staging",     type: 1, status: 1, running:  5, stopped: 3, unhealthy: 0, volumes:  8, images: 15, stacks: 3,  cpu:  4, memoryGB:  7.8),
            MockEnv(id: 3, name: "dev-cluster", type: 2, status: 1, running:  8, stopped: 1, unhealthy: 0, volumes:  5, images: 12, stacks: 2,  cpu:  8, memoryGB: 16.0),
            MockEnv(id: 4, name: "edge-node-1", type: 4, status: 2, running:  0, stopped: 0, unhealthy: 0, volumes:  0, images:  0, stacks: 0,  cpu:  2, memoryGB:  2.0),
        ]
        let memBytes = { (gb: Double) in Int64(gb * 1_073_741_824) }
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
                "VolumeCount": \(item.volumes),
                "ImageCount": \(item.images),
                "StackCount": \(item.stacks),
                "TotalCPU": \(item.cpu),
                "TotalMemory": \(memBytes(item.memoryGB)),
                "DockerVersion": "24.0.7",
                "Time": \(Int(Date().timeIntervalSince1970))
              }]
            }
            """
            return try! JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
        }
    }()
}
