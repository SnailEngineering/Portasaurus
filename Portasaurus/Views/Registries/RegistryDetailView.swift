import SwiftUI

/// Shows detailed information for a single Portainer registry.
///
/// Sections: Overview, Credentials, type-specific details (GitLab, ECR),
/// plus a toolbar delete button. Password/tokens are intentionally not shown.
struct RegistryDetailView: View {

    let client: PortainerClient
    let registry: PortainerRegistry

    @State private var viewModel: RegistryDetailViewModel
    @State private var isPreview = false
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(client: PortainerClient, registry: PortainerRegistry) {
        self.client = client
        self.registry = registry
        self._viewModel = State(initialValue: RegistryDetailViewModel())
    }

    init(client: PortainerClient, registry: PortainerRegistry, previewViewModel: RegistryDetailViewModel) {
        self.client = client
        self.registry = registry
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading registry…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.detail == nil {
                errorView(message: error)
            } else {
                let reg = viewModel.detail ?? registry
                detailContent(reg)
            }
        }
        .navigationTitle(registry.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar { toolbarContent }
        .task {
            guard !isPreview else { return }
            await viewModel.load(id: registry.id, client: client)
        }
        .confirmationDialog(
            "Remove Registry?",
            isPresented: $pendingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    if await viewModel.removeRegistry(client: client) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Permanently remove \"\(registry.name)\"? This cannot be undone.")
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ reg: PortainerRegistry) -> some View {
        List {
            overviewSection(reg)
            if reg.authentication {
                credentialsSection(reg)
            }
            if reg.type == .gitlab {
                gitlabSection(reg)
            }
            if reg.type == .ecr {
                ecrSection(reg)
            }
        }
        .overlay {
            if viewModel.isActing {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Sections

    private func overviewSection(_ reg: PortainerRegistry) -> some View {
        Section("Overview") {
            detailRow(label: "Name", value: reg.name)
            detailRow(label: "Type", value: reg.typeName)
            if !reg.url.isEmpty {
                detailRow(label: "URL", value: reg.url, monospaced: true)
            }
            if !reg.baseURL.isEmpty {
                detailRow(label: "Base URL", value: reg.baseURL, monospaced: true)
            }
            HStack {
                Text("Authentication")
                    .foregroundStyle(.secondary)
                Spacer()
                Label(
                    reg.authentication ? "Enabled" : "Disabled",
                    systemImage: reg.authentication ? "lock.fill" : "lock.open"
                )
                .font(.subheadline)
                .foregroundStyle(reg.authentication ? .primary : .secondary)
            }
        }
    }

    private func credentialsSection(_ reg: PortainerRegistry) -> some View {
        Section("Credentials") {
            if !reg.username.isEmpty {
                detailRow(label: "Username", value: reg.username, monospaced: true)
            }
            HStack {
                Text("Password")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("••••••••")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func gitlabSection(_ reg: PortainerRegistry) -> some View {
        Section("GitLab") {
            if !reg.gitlab.instanceURL.isEmpty {
                detailRow(label: "Instance URL", value: reg.gitlab.instanceURL, monospaced: true)
            }
            if !reg.gitlab.projectPath.isEmpty {
                detailRow(label: "Project Path", value: reg.gitlab.projectPath, monospaced: true)
            }
            if reg.gitlab.projectId != 0 {
                detailRow(label: "Project ID", value: "\(reg.gitlab.projectId)")
            }
        }
    }

    private func ecrSection(_ reg: PortainerRegistry) -> some View {
        Section("AWS ECR") {
            if !reg.ecr.region.isEmpty {
                detailRow(label: "Region", value: reg.ecr.region, monospaced: true)
            }
        }
    }

    // MARK: - Row helper

    private func detailRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            Button(role: .destructive) {
                pendingDelete = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .disabled(viewModel.isActing)
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
                Task { await viewModel.load(id: registry.id, client: client) }
            }
            .buttonStyle(.borderedProminent)
        }
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

#Preview("Registry Detail — Light") {
    NavigationStack {
        RegistryDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            registry: PortainerRegistry.mockRegistries[1],
            previewViewModel: RegistryDetailViewModel(previewRegistry: PortainerRegistry.mockRegistries[1])
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Registry Detail — Dark") {
    NavigationStack {
        RegistryDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            registry: PortainerRegistry.mockRegistries[4],
            previewViewModel: RegistryDetailViewModel(previewRegistry: PortainerRegistry.mockRegistries[4])
        )
    }
    .preferredColorScheme(.dark)
}
