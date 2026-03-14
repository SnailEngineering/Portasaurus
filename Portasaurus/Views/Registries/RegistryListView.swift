import SwiftUI

/// Lists all registries configured in Portainer.
///
/// Registries are global resources — not scoped to a specific environment —
/// so this view takes only a `PortainerClient`, not an environment.
/// Supports search by name or URL and swipe-to-delete.
struct RegistryListView: View {

    let client: PortainerClient

    @State private var viewModel: RegistryListViewModel
    @State private var isPreview = false
    @State private var pendingDeleteRegistry: PortainerRegistry?

    // MARK: - Init

    init(client: PortainerClient) {
        self.client = client
        self._viewModel = State(initialValue: RegistryListViewModel())
    }

    init(client: PortainerClient, previewViewModel: RegistryListViewModel) {
        self.client = client
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.registries.isEmpty {
                ProgressView("Loading registries…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.registries.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("Registries")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .searchable(text: $viewModel.searchText, prompt: "Search registries")
        .refreshable {
            await viewModel.load(client: client)
        }
        .navigationDestination(for: PortainerRegistry.self) { registry in
            RegistryDetailView(client: client, registry: registry)
        }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client)
        }
        .confirmationDialog(
            "Remove Registry?",
            isPresented: $pendingDeleteRegistry.isPresented,
            titleVisibility: .visible
        ) {
            if let registry = pendingDeleteRegistry {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeRegistry(registry, client: client) }
                }
            }
        } message: {
            if let registry = pendingDeleteRegistry {
                Text("Permanently remove \"\(registry.name)\"? This cannot be undone.")
            }
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { registry in
            NavigationLink(value: registry) {
                registryRow(registry)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDeleteRegistry = registry
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    pendingDeleteRegistry = registry
                } label: {
                    Label("Remove Registry", systemImage: "trash")
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

    // MARK: - Registry Row

    private func registryRow(_ registry: PortainerRegistry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: registry.typeIcon)
                    .font(.callout)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(registry.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(registry.typeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !registry.displayURL.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(registry.displayURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if registry.authentication {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(registry.username.isEmpty ? "Authenticated" : registry.username)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView {
                    Label("No Registries", systemImage: "externaldrive.connected.to.line.below.fill")
                } description: {
                    Text("No container registries are configured in Portainer.")
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
                Task { await viewModel.load(client: client) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Optional binding helpers

private extension Optional where Wrapped: Identifiable {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

private extension Optional where Wrapped == String {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

// MARK: - Previews

#Preview("Registries — Light") {
    NavigationStack {
        RegistryListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            previewViewModel: RegistryListViewModel(previewRegistries: PortainerRegistry.mockRegistries)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Registries — Dark") {
    NavigationStack {
        RegistryListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            previewViewModel: RegistryListViewModel(previewRegistries: PortainerRegistry.mockRegistries)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    NavigationStack {
        RegistryListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            previewViewModel: RegistryListViewModel(previewRegistries: [])
        )
    }
}

// MARK: - Preview Mock Data

extension PortainerRegistry {
    static let mockRegistries: [PortainerRegistry] = {
        let items: [(id: Int, name: String, type: Int, url: String, auth: Bool, username: String)] = [
            (1, "Docker Hub",        6, "https://index.docker.io",                                    true,  "myuser"),
            (2, "Registry (custom)", 3, "https://registry.internal.example.com:5000",                 true,  "admin"),
            (3, "Quay.io",           1, "https://quay.io",                                             false, ""),
            (4, "AWS ECR",           7, "https://123456789.dkr.ecr.us-east-1.amazonaws.com",           true,  "AWS"),
            (5, "GitLab Registry",   4, "https://registry.gitlab.com",                                 true,  "gitlab-ci-token"),
        ]
        return items.map { item in
            let json = """
            {
              "Id": \(item.id),
              "Name": "\(item.name)",
              "Type": \(item.type),
              "URL": "\(item.url)",
              "BaseURL": "",
              "Authentication": \(item.auth),
              "Username": "\(item.username)",
              "Gitlab": {"ProjectId": 0, "InstanceURL": "", "ProjectPath": ""},
              "Ecr": {"Region": ""}
            }
            """
            return try! JSONDecoder().decode(PortainerRegistry.self, from: Data(json.utf8))
        }
    }()
}
