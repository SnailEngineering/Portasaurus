import SwiftUI

/// Lists all Docker volumes for a Portainer environment.
///
/// Supports search by name/driver, filter by usage status, and delete individual
/// volumes with an in-use warning.
struct VolumeListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint

    @State private var viewModel: VolumeListViewModel
    @State private var isPreview = false
    @State private var pendingDeleteVolume: DockerVolume?

    // MARK: - Init

    init(client: PortainerClient, environment: PortainerEndpoint) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: VolumeListViewModel())
    }

    init(client: PortainerClient, environment: PortainerEndpoint, previewViewModel: VolumeListViewModel) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.volumes.isEmpty {
                ProgressView("Loading volumes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.volumes.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("Volumes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search volumes")
        .refreshable { await viewModel.load(client: client, endpointId: environment.id) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, endpointId: environment.id)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $pendingDeleteVolume.isPresented,
            titleVisibility: .visible
        ) {
            if let volume = pendingDeleteVolume {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeVolume(volume, client: client, endpointId: environment.id) }
                }
            }
        } message: {
            if let volume = pendingDeleteVolume {
                if volume.isInUse {
                    Text("Volume \"\(volume.name)\" is currently in use by one or more containers. Removing it may cause data loss and container failures.")
                } else {
                    Text("Permanently remove \"\(volume.name)\"? This cannot be undone.")
                }
            }
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    private var deleteDialogTitle: String {
        if let volume = pendingDeleteVolume, volume.isInUse {
            return "Volume In Use"
        }
        return "Remove Volume?"
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.filtered) { volume in
            volumeRow(volume)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeleteVolume = volume
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDeleteVolume = volume
                    } label: {
                        Label("Remove Volume", systemImage: "trash")
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

    // MARK: - Volume Row

    private func volumeRow(_ volume: DockerVolume) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(volume.isInUse
                          ? Color.teal.opacity(0.12)
                          : Color.secondary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "cylinder.fill")
                    .font(.callout)
                    .foregroundStyle(volume.isInUse ? Color.teal : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(volume.driver)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let size = volume.formattedSize {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if volume.isInUse {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("in use")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("Filter", selection: $viewModel.usageFilter) {
                ForEach(VolumeListViewModel.UsageFilter.allCases) { filter in
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
                    Label("No Volumes", systemImage: "cylinder.fill")
                } description: {
                    switch viewModel.usageFilter {
                    case .all:    Text("No Docker volumes found in this environment.")
                    case .inUse:  Text("No volumes are currently in use.")
                    case .unused: Text("No unused volumes — nothing to remove.")
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

#Preview("Volumes — Light") {
    NavigationStack {
        VolumeListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: VolumeListViewModel(previewVolumes: DockerVolume.mockVolumes)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Volumes — Dark") {
    NavigationStack {
        VolumeListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: VolumeListViewModel(previewVolumes: DockerVolume.mockVolumes)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("In Use Filter") {
    NavigationStack {
        VolumeListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: {
                let vm = VolumeListViewModel(previewVolumes: DockerVolume.mockVolumes)
                vm.usageFilter = .inUse
                return vm
            }()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        VolumeListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: VolumeListViewModel(previewVolumes: [])
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

private struct _MockVolume {
    var name: String
    var driver: String
    var refCount: Int
    var sizeBytes: Int64
}

extension DockerVolume {
    static let mockVolumes: [DockerVolume] = {
        let items: [_MockVolume] = [
            _MockVolume(name: "postgres_data",   driver: "local", refCount: 1,  sizeBytes: 524_288_000),
            _MockVolume(name: "redis_data",      driver: "local", refCount: 1,  sizeBytes:  10_485_760),
            _MockVolume(name: "grafana_storage", driver: "local", refCount: 0,  sizeBytes: 104_857_600),
            _MockVolume(name: "nginx_logs",      driver: "local", refCount: 2,  sizeBytes:   5_242_880),
            _MockVolume(name: "old_backup_vol",  driver: "local", refCount: 0,  sizeBytes: -1),
            _MockVolume(name: "nfs_share",       driver: "nfs",   refCount: 3,  sizeBytes: -1),
        ]
        return items.map { item in
            let usageData = item.sizeBytes >= 0
                ? "{\"RefCount\":\(item.refCount),\"Size\":\(item.sizeBytes)}"
                : "{\"RefCount\":\(item.refCount),\"Size\":-1}"
            let json = """
            {
              "Name": "\(item.name)",
              "Driver": "\(item.driver)",
              "Mountpoint": "/var/lib/docker/volumes/\(item.name)/_data",
              "Scope": "local",
              "Labels": null,
              "Options": null,
              "CreatedAt": "2024-01-15T10:00:00Z",
              "UsageData": \(usageData)
            }
            """
            return try! JSONDecoder().decode(DockerVolume.self, from: Data(json.utf8))
        }
    }()
}
