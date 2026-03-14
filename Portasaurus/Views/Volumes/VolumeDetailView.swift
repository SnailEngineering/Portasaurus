import SwiftUI

/// Displays full inspection data for a single Docker volume.
///
/// Sections: Overview, Usage, Labels, Options.
/// The view calls the detail endpoint on load to get enriched UsageData.
struct VolumeDetailView: View {

    let client: PortainerClient
    /// The volume passed from the list — used as initial data and as the navigation title source.
    let volume: DockerVolume
    let endpointId: Int

    @State private var viewModel: VolumeDetailViewModel
    @State private var isPreview = false
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(client: PortainerClient, volume: DockerVolume, endpointId: Int) {
        self.client = client
        self.volume = volume
        self.endpointId = endpointId
        self._viewModel = State(initialValue: VolumeDetailViewModel())
    }

    init(client: PortainerClient, volume: DockerVolume, endpointId: Int, previewViewModel: VolumeDetailViewModel) {
        self.client = client
        self.volume = volume
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
        .navigationTitle(volume.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .refreshable { await viewModel.load(client: client, volumeName: volume.name, endpointId: endpointId) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, volumeName: volume.name, endpointId: endpointId)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $pendingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    let removed = await viewModel.removeVolume(name: volume.name, client: client, endpointId: endpointId)
                    if removed { dismiss() }
                }
            }
        } message: {
            if volume.isInUse {
                Text("Volume \"\(volume.name)\" is currently in use by one or more containers. Removing it may cause data loss and container failures.")
            } else {
                Text("Permanently remove \"\(volume.name)\"? This cannot be undone.")
            }
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    private var deleteDialogTitle: String {
        volume.isInUse ? "Volume In Use" : "Remove Volume?"
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: DockerVolume) -> some View {
        List {
            overviewSection(detail)
            if let usage = detail.usageData {
                usageSection(usage)
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

    private func overviewSection(_ detail: DockerVolume) -> some View {
        Section("Overview") {
            LabeledContent("Name") {
                Text(detail.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Driver", value: detail.driver)
            LabeledContent("Scope", value: detail.scope.capitalized)
            if let date = detail.createdDate {
                LabeledContent("Created") {
                    Text(date, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Mountpoint") {
                Text(detail.mountpoint)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Usage Section

    private func usageSection(_ usage: DockerVolume.UsageData) -> some View {
        Section("Usage") {
            LabeledContent("Containers") {
                if usage.refCount < 0 {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                } else if usage.refCount == 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                        Text("Not in use")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.teal)
                        Text("\(usage.refCount) container\(usage.refCount == 1 ? "" : "s")")
                            .foregroundStyle(.teal)
                    }
                }
            }
            LabeledContent("Size") {
                if usage.size < 0 {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                } else {
                    Text(ByteCountFormatter.string(fromByteCount: usage.size, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
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
            Button(role: .destructive) {
                pendingDelete = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .disabled(viewModel.isActing)
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
                Task { await viewModel.load(client: client, volumeName: volume.name, endpointId: endpointId) }
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

#Preview("Volume Detail — In Use") {
    NavigationStack {
        VolumeDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            volume: DockerVolume.mockVolumes[0],
            endpointId: 1,
            previewViewModel: VolumeDetailViewModel(previewDetail: DockerVolume.mockVolumes[0])
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Volume Detail — Unused") {
    NavigationStack {
        VolumeDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            volume: DockerVolume.mockVolumes[2],
            endpointId: 1,
            previewViewModel: VolumeDetailViewModel(previewDetail: DockerVolume.mockVolumes[2])
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Volume Detail — NFS") {
    NavigationStack {
        VolumeDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            volume: DockerVolume.mockVolumes[5],
            endpointId: 1,
            previewViewModel: VolumeDetailViewModel(previewDetail: DockerVolume.mockVolumes[5])
        )
    }
}
