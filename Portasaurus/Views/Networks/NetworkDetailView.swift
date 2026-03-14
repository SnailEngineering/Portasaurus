import SwiftUI

/// Displays full inspection data for a single Docker network.
///
/// Sections: Overview, IPAM, Connected Containers, Labels, Options.
struct NetworkDetailView: View {

    let client: PortainerClient
    /// The network passed from the list — used as initial data and as the navigation title source.
    let network: DockerNetwork
    let endpointId: Int

    @State private var viewModel: NetworkDetailViewModel
    @State private var isPreview = false
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(client: PortainerClient, network: DockerNetwork, endpointId: Int) {
        self.client = client
        self.network = network
        self.endpointId = endpointId
        self._viewModel = State(initialValue: NetworkDetailViewModel())
    }

    init(client: PortainerClient, network: DockerNetwork, endpointId: Int, previewViewModel: NetworkDetailViewModel) {
        self.client = client
        self.network = network
        self.endpointId = endpointId
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let detail = viewModel.detail {
                detailContent(detail)
            } else if let error = viewModel.loadError {
                errorView(message: error)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(network.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .refreshable { await viewModel.load(client: client, networkId: network.id, endpointId: endpointId) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, networkId: network.id, endpointId: endpointId)
        }
        .confirmationDialog(
            "Remove Network?",
            isPresented: $pendingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    let removed = await viewModel.removeNetwork(id: network.id, client: client, endpointId: endpointId)
                    if removed { dismiss() }
                }
            }
        } message: {
            Text("Permanently remove \"\(network.name)\"? This cannot be undone.")
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: DockerNetwork) -> some View {
        List {
            overviewSection(detail)
            if !detail.ipam.config.isEmpty {
                ipamSection(detail.ipam)
            }
            if !detail.containers.isEmpty {
                containersSection(detail.containers)
            }
            if !detail.labels.isEmpty {
                labelsSection(detail.labels)
            }
            if !detail.options.isEmpty {
                optionsSection(detail.options)
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

    // MARK: - Overview Section

    private func overviewSection(_ detail: DockerNetwork) -> some View {
        Section("Overview") {
            LabeledContent("ID") {
                Text(detail.id)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Driver", value: detail.driver)
            LabeledContent("Scope", value: detail.scope.capitalized)
            LabeledContent("Internal") {
                HStack(spacing: 4) {
                    Image(systemName: detail.isInternal ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(detail.isInternal ? .orange : .secondary)
                    Text(detail.isInternal ? "Yes" : "No")
                        .foregroundStyle(detail.isInternal ? .orange : .secondary)
                }
            }
            LabeledContent("Attachable") {
                Text(detail.isAttachable ? "Yes" : "No")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("IPv6 Enabled") {
                Text(detail.enableIPv6 ? "Yes" : "No")
                    .foregroundStyle(.secondary)
            }
            if let date = detail.createdDate {
                LabeledContent("Created") {
                    Text(date, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - IPAM Section

    private func ipamSection(_ ipam: DockerNetwork.IPAM) -> some View {
        Section("IPAM") {
            LabeledContent("Driver", value: ipam.driver)
            ForEach(Array(ipam.config.enumerated()), id: \.offset) { _, config in
                if !config.subnet.isEmpty {
                    LabeledContent("Subnet") {
                        Text(config.subnet)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if !config.gateway.isEmpty {
                    LabeledContent("Gateway") {
                        Text(config.gateway)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Containers Section

    private func containersSection(_ containers: [String: DockerNetwork.ContainerEndpoint]) -> some View {
        Section("Connected Containers (\(containers.count))") {
            ForEach(containers.sorted(by: { $0.value.name < $1.value.name }), id: \.key) { _, endpoint in
                VStack(alignment: .leading, spacing: 4) {
                    Text(endpoint.name.isEmpty ? "(unnamed)" : endpoint.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if !endpoint.ipv4Address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(endpoint.ipv4Address)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    if !endpoint.macAddress.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "personalhotspot")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(endpoint.macAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Labels Section

    private func labelsSection(_ labels: [String: String]) -> some View {
        Section("Labels (\(labels.count))") {
            ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                LabeledContent(key) {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    // MARK: - Options Section

    private func optionsSection(_ options: [String: String]) -> some View {
        Section("Options (\(options.count))") {
            ForEach(options.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                LabeledContent(key) {
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            if !network.isBuiltIn {
                Button(role: .destructive) {
                    pendingDelete = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(viewModel.isActing)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(client: client, networkId: network.id, endpointId: endpointId) }
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

#Preview("Network Detail — With Containers") {
    NavigationStack {
        NetworkDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            network: DockerNetwork.mockNetworks[3],
            endpointId: 1,
            previewViewModel: NetworkDetailViewModel(previewDetail: DockerNetwork.mockNetworks[3])
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Network Detail — Bridge (Built-in)") {
    NavigationStack {
        NetworkDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            network: DockerNetwork.mockNetworks[0],
            endpointId: 1,
            previewViewModel: NetworkDetailViewModel(previewDetail: DockerNetwork.mockNetworks[0])
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Network Detail — Internal") {
    NavigationStack {
        NetworkDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            network: DockerNetwork.mockNetworks[4],
            endpointId: 1,
            previewViewModel: NetworkDetailViewModel(previewDetail: DockerNetwork.mockNetworks[4])
        )
    }
}
