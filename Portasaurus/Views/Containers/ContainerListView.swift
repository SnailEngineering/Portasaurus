import SwiftUI

/// Lists all containers for a Portainer environment.
///
/// Auto-refreshes every 10 seconds while visible. Supports filtering by state,
/// search by name/image, and quick actions via swipe and context menu.
struct ContainerListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint

    @State private var viewModel = ContainerListViewModel()

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
        .navigationTitle(environment.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search containers")
        .refreshable { await viewModel.load(client: client, endpointId: environment.id) }
        .task { await viewModel.loadAndAutoRefresh(client: client, endpointId: environment.id) }
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
            return "Forcefully terminate "\(action.container.displayName)"? The container will remain and can be restarted."
        case .remove:
            return "Permanently remove "\(action.container.displayName)" and its associated volumes? This cannot be undone."
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

// MARK: - Preview

#Preview {
    NavigationStack {
        ContainerListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .preview
        )
    }
}

private extension PortainerEndpoint {
    static let preview = PortainerEndpoint.makeMock()

    static func makeMock() -> PortainerEndpoint {
        // Decode a minimal JSON stub so we don't need a custom init.
        let json = """
        {"Id":1,"Name":"local","Type":1,"Status":1,"URL":"tcp://localhost:2375",
         "PublicURL":"","Snapshots":[]}
        """
        return try! JSONDecoder().decode(PortainerEndpoint.self, from: Data(json.utf8))
    }
}
