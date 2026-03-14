import SwiftUI

/// Lists all Docker networks for a Portainer environment.
///
/// Supports search by name/driver, filter by scope, and delete individual
/// networks with a guard against removing the built-in bridge/host/none networks.
struct NetworkListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint
    /// Written with the total network count once networks are loaded.
    /// Allows the caller (e.g. environment card) to display a live count.
    var networkCount: Binding<Int>?

    @State private var viewModel: NetworkListViewModel
    @State private var isPreview = false
    @State private var pendingDeleteNetwork: DockerNetwork?

    // MARK: - Init

    init(client: PortainerClient, environment: PortainerEndpoint, networkCount: Binding<Int>? = nil) {
        self.client = client
        self.environment = environment
        self.networkCount = networkCount
        self._viewModel = State(initialValue: NetworkListViewModel())
    }

    init(client: PortainerClient, environment: PortainerEndpoint, previewViewModel: NetworkListViewModel) {
        self.client = client
        self.environment = environment
        self.networkCount = nil
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.networks.isEmpty {
                ProgressView("Loading networks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.networks.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("Networks")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search networks")
        .refreshable {
            await viewModel.load(client: client, endpointId: environment.id)
            networkCount?.wrappedValue = viewModel.networks.count
        }
        .navigationDestination(for: DockerNetwork.self) { network in
            NetworkDetailView(client: client, network: network, endpointId: environment.id)
        }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, endpointId: environment.id)
            networkCount?.wrappedValue = viewModel.networks.count
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $pendingDeleteNetwork.isPresented,
            titleVisibility: .visible
        ) {
            if let network = pendingDeleteNetwork {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeNetwork(network, client: client, endpointId: environment.id) }
                }
            }
        } message: {
            if let network = pendingDeleteNetwork {
                Text("Permanently remove \"\(network.name)\"? This cannot be undone.")
            }
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    private var deleteDialogTitle: String {
        "Remove Network?"
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { network in
            NavigationLink(value: network) {
                networkRow(network)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !network.isBuiltIn {
                    Button(role: .destructive) {
                        pendingDeleteNetwork = network
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .contextMenu {
                if !network.isBuiltIn {
                    Button(role: .destructive) {
                        pendingDeleteNetwork = network
                    } label: {
                        Label("Remove Network", systemImage: "trash")
                    }
                }
            }
            .disabled(viewModel.isActing)
        }
        .overlay {
            if viewModel.isActing {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Network Row

    private func networkRow(_ network: DockerNetwork) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor(for: network).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "network")
                    .font(.callout)
                    .foregroundStyle(iconColor(for: network))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(network.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if network.isBuiltIn {
                        Text("built-in")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(network.driver)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(network.scope.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if network.containerCount > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(network.containerCount) container\(network.containerCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }

                    if let subnet = network.subnet {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(subnet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func iconColor(for network: DockerNetwork) -> Color {
        if network.isBuiltIn { return .secondary }
        if network.containerCount > 0 { return .teal }
        return .blue
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("Filter", selection: $viewModel.scopeFilter) {
                ForEach(NetworkListViewModel.ScopeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView {
                    Label("No Networks", systemImage: "network")
                } description: {
                    switch viewModel.scopeFilter {
                    case .all:   Text("No Docker networks found in this environment.")
                    case .local: Text("No local-scope networks found.")
                    case .swarm: Text("No swarm-scope networks found.")
                    }
                }
            }
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(client: client, endpointId: environment.id) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Optional<Identifiable> binding helper

private extension Optional where Wrapped: Identifiable {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

// MARK: - Optional<String> binding helper

private extension Optional where Wrapped == String {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

// MARK: - Previews

#Preview("Networks — Light") {
    NavigationStack {
        NetworkListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: NetworkListViewModel(previewNetworks: DockerNetwork.mockNetworks)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Networks — Dark") {
    NavigationStack {
        NetworkListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: NetworkListViewModel(previewNetworks: DockerNetwork.mockNetworks)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    NavigationStack {
        NetworkListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: NetworkListViewModel(previewNetworks: [])
        )
    }
}

// MARK: - Preview Mock Data

private extension PortainerEndpoint {
    static let previewMock: PortainerEndpoint = {
        let json = """
        {"Id":1,"Name":"production","Type":1,"Status":1,"URL":"tcp://localhost:2375","PublicURL":"","Snapshots":[]}
        """
        return try! JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
    }()
}

extension DockerNetwork {
    static let mockNetworks: [DockerNetwork] = {
        struct MockNet {
            var id: String; var name: String; var driver: String; var scope: String
            var internal_: Bool; var subnet: String; var gateway: String
            var containers: [(id: String, name: String, ip: String)]
        }
        let items: [MockNet] = [
            MockNet(id: "abc1", name: "bridge",     driver: "bridge",  scope: "local",  internal_: false, subnet: "172.17.0.0/16",  gateway: "172.17.0.1", containers: []),
            MockNet(id: "abc2", name: "host",       driver: "host",    scope: "local",  internal_: false, subnet: "",               gateway: "",           containers: []),
            MockNet(id: "abc3", name: "none",       driver: "null",    scope: "local",  internal_: false, subnet: "",               gateway: "",           containers: []),
            MockNet(id: "abc4", name: "app_net",    driver: "bridge",  scope: "local",  internal_: false, subnet: "172.20.0.0/16",  gateway: "172.20.0.1", containers: [("c1","web","172.20.0.2/16"), ("c2","db","172.20.0.3/16")]),
            MockNet(id: "abc5", name: "monitoring", driver: "bridge",  scope: "local",  internal_: true,  subnet: "172.21.0.0/16",  gateway: "172.21.0.1", containers: [("c3","prometheus","172.21.0.2/16")]),
            MockNet(id: "abc6", name: "overlay_net",driver: "overlay", scope: "swarm",  internal_: false, subnet: "10.0.1.0/24",    gateway: "10.0.1.1",   containers: []),
        ]
        return items.map { item in
            let containerJSON = item.containers.map { c in
                """
                "\(c.id)": {"Name":"\(c.name)","EndpointID":"ep\(c.id)","MacAddress":"02:42:ac:14:00:02","IPv4Address":"\(c.ip)","IPv6Address":""}
                """
            }.joined(separator: ",")
            let ipamConfig = item.subnet.isEmpty ? "[]" : """
            [{"Subnet":"\(item.subnet)","Gateway":"\(item.gateway)"}]
            """
            let json = """
            {
              "Id": "\(item.id)",
              "Name": "\(item.name)",
              "Driver": "\(item.driver)",
              "Scope": "\(item.scope)",
              "Internal": \(item.internal_),
              "Attachable": false,
              "EnableIPv6": false,
              "Created": "2024-01-15T10:00:00Z",
              "Labels": {},
              "Options": {},
              "Containers": {\(containerJSON)},
              "IPAM": {"Driver": "default", "Config": \(ipamConfig)}
            }
            """
            return try! JSONDecoder().decode(DockerNetwork.self, from: Data(json.utf8))
        }
    }()
}
