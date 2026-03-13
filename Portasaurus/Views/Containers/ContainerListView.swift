import SwiftUI

/// Lists all containers for a Portainer environment.
///
/// Auto-refreshes while visible. Supports filtering by state,
/// search by name/image, and quick actions via swipe and context menu.
///
/// When `stackName` is provided the list is pre-filtered to containers
/// belonging to that Compose project (via the `com.docker.compose.project` label),
/// and the navigation title is suppressed so the parent view can own it.
struct ContainerListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint
    /// When set, only containers whose `com.docker.compose.project` label
    /// matches this value are shown. The navigation title is also hidden
    /// so the embedding view controls the title bar.
    let stackName: String?

    @State private var viewModel: ContainerListViewModel
    @State private var isPreview = false

    init(client: PortainerClient, environment: PortainerEndpoint, stackName: String? = nil) {
        self.client = client
        self.environment = environment
        self.stackName = stackName
        self._viewModel = State(initialValue: ContainerListViewModel(stackName: stackName))
    }

    init(client: PortainerClient, environment: PortainerEndpoint, stackName: String? = nil, previewViewModel: ContainerListViewModel) {
        self.client = client
        self.environment = environment
        self.stackName = stackName
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.containers.isEmpty {
                ProgressView("Loading containers…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.containers.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        // When embedded inside another view (e.g. StackDetailView), suppress
        // the navigation title so the parent owns the title bar.
        .navigationTitle(stackName == nil ? environment.name : "")
#if os(iOS)
        .navigationBarTitleDisplayMode(stackName == nil ? .large : .inline)
#endif
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search containers")
        .refreshable { await viewModel.load(client: client, endpointId: environment.id) }
        .navigationDestination(for: DockerContainer.self) { container in
            ContainerDetailView(client: client, container: container, endpointId: environment.id)
        }
        .task {
            guard !isPreview else { return }
            await viewModel.loadAndListenForEvents(client: client, endpointId: environment.id)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: $viewModel.pendingDestructiveAction.isPresented,
            titleVisibility: .visible
        ) {
            if let action = viewModel.pendingDestructiveAction {
                Button(confirmationButtonLabel(for: action.kind), role: .destructive) {
                    Task { await viewModel.confirmDestructive(action, client: client, endpointId: environment.id) }
                }
            }
        } message: {
            if let action = viewModel.pendingDestructiveAction {
                Text(confirmationMessage(for: action))
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { container in
            NavigationLink(value: container) {
                containerRow(container)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions(for: container)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                leadingSwipeActions(for: container)
            }
            .contextMenu { contextMenuItems(for: container) }
            .disabled(viewModel.actionInProgress == container.id)
        }
    }

    // MARK: - Container Row

    @ViewBuilder
    private func containerRow(_ container: DockerContainer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(containerState: container.state)
                if viewModel.actionInProgress == container.id {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func trailingSwipeActions(for container: DockerContainer) -> some View {
        if container.state.canStop {
            Button {
                Task { await viewModel.perform(.stop, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .tint(.red)
        }

        Button(role: .destructive) {
            viewModel.pendingDestructiveAction = .init(kind: .remove, container: container)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func leadingSwipeActions(for container: DockerContainer) -> some View {
        if container.state.canStart {
            Button {
                Task { await viewModel.perform(.start, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .tint(.green)
        }

        if container.state.canRestart {
            Button {
                Task { await viewModel.perform(.restart, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
            }
            .tint(.orange)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for container: DockerContainer) -> some View {
        if container.state.canStart {
            Button {
                Task { await viewModel.perform(.start, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Start", systemImage: "play.fill")
            }
        }
        if container.state.canStop {
            Button {
                Task { await viewModel.perform(.stop, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        }
        if container.state.canRestart {
            Button {
                Task { await viewModel.perform(.restart, on: container, client: client, endpointId: environment.id) }
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            viewModel.pendingDestructiveAction = .init(kind: .kill, container: container)
        } label: {
            Label("Kill", systemImage: "bolt.fill")
        }

        Button(role: .destructive) {
            viewModel.pendingDestructiveAction = .init(kind: .remove, container: container)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("Filter", selection: $viewModel.stateFilter) {
                ForEach(ContainerListViewModel.StateFilter.allCases) { filter in
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
                    Label("No Containers", systemImage: "shippingbox")
                } description: {
                    Text("No containers match the current filter.")
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

    // MARK: - Confirmation Helpers

    private var confirmationTitle: String {
        guard let action = viewModel.pendingDestructiveAction else { return "" }
        return action.kind == .kill ? "Kill Container?" : "Remove Container?"
    }

    private func confirmationButtonLabel(for kind: ContainerListViewModel.DestructiveAction.Kind) -> String {
        kind == .kill ? "Kill" : "Remove"
    }

    private func confirmationMessage(for action: ContainerListViewModel.DestructiveAction) -> String {
        switch action.kind {
        case .kill:
            return "Forcefully terminate \"\(action.container.displayName)\"? The container will remain and can be restarted."
        case .remove:
            return "Permanently remove \"\(action.container.displayName)\" and its associated volumes? This cannot be undone."
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

// MARK: - Previews

#Preview("Container List — Light") {
    NavigationStack {
        ContainerListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ContainerListViewModel(previewContainers: DockerContainer.mockContainers)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Container List — Dark") {
    NavigationStack {
        ContainerListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ContainerListViewModel(previewContainers: DockerContainer.mockContainers)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty — No Containers") {
    NavigationStack {
        ContainerListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ContainerListViewModel(previewContainers: [])
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

private extension DockerContainer {
    static func make(
        id: String,
        name: String,
        image: String,
        state: String,
        status: String
    ) -> DockerContainer {
        let json = """
        {
          "Id": "\(id)",
          "Names": ["/\(name)"],
          "Image": "\(image)",
          "ImageID": "sha256:abc123",
          "Command": "/entrypoint.sh",
          "Created": 1700000000,
          "State": "\(state)",
          "Status": "\(status)",
          "Ports": [],
          "Labels": {}
        }
        """
        return try! JSONDecoder().decode(DockerContainer.self, from: Data(json.utf8))
    }

    static let mockContainers: [DockerContainer] = [
        .make(id: "a1b2c3d4e5f6", name: "nginx-proxy",    image: "nginx:alpine",          state: "running",  status: "Up 3 days"),
        .make(id: "b2c3d4e5f6a1", name: "postgres-db",    image: "postgres:16",            state: "running",  status: "Up 2 hours"),
        .make(id: "c3d4e5f6a1b2", name: "redis-cache",    image: "redis:7-alpine",         state: "running",  status: "Up 5 days"),
        .make(id: "d4e5f6a1b2c3", name: "api-server",     image: "myapp/api:latest",       state: "exited",   status: "Exited (0) 1 hour ago"),
        .make(id: "e5f6a1b2c3d4", name: "worker-queue",   image: "myapp/worker:v2.1.0",    state: "exited",   status: "Exited (1) 30 minutes ago"),
        .make(id: "f6a1b2c3d4e5", name: "grafana",        image: "grafana/grafana:latest", state: "running",  status: "Up 12 days"),
        .make(id: "a1b2c3d4e5f7", name: "prometheus",     image: "prom/prometheus:v2.48",  state: "paused",   status: "Paused"),
    ]
}


