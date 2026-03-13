import SwiftUI

/// Lists all Docker images for a Portainer environment.
///
/// Supports search by name/tag, filter by tagged/untagged, delete individual
/// images, and prune all dangling (unused, untagged) images.
struct ImageListView: View {

    let client: PortainerClient
    let environment: PortainerEndpoint

    @State private var viewModel: ImageListViewModel
    @State private var isPreview = false
    @State private var pendingDeleteImage: DockerImage?

    // MARK: - Init

    init(client: PortainerClient, environment: PortainerEndpoint) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: ImageListViewModel())
    }

    init(client: PortainerClient, environment: PortainerEndpoint, previewViewModel: ImageListViewModel) {
        self.client = client
        self.environment = environment
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView("Loading images…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.images.isEmpty {
                errorView(message: error)
            } else if viewModel.filtered.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("Images")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "Search images")
        .refreshable { await viewModel.load(client: client, endpointId: environment.id) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, endpointId: environment.id)
        }
        .confirmationDialog(
            "Remove Image?",
            isPresented: $pendingDeleteImage.isPresented,
            titleVisibility: .visible
        ) {
            if let image = pendingDeleteImage {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeImage(image, client: client, endpointId: environment.id) }
                }
            }
        } message: {
            if let image = pendingDeleteImage {
                Text("Permanently remove \"\(image.displayName)\"? This cannot be undone.")
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
        List(viewModel.filtered) { image in
            imageRow(image)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeleteImage = image
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDeleteImage = image
                    } label: {
                        Label("Remove Image", systemImage: "trash")
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

    // MARK: - Image Row

    private func imageRow(_ image: DockerImage) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(image.isDangling
                          ? Color.secondary.opacity(0.12)
                          : Color.indigo.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "photo.stack.fill")
                    .font(.callout)
                    .foregroundStyle(image.isDangling ? Color.secondary : Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(image.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(image.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if image.repoTags.count > 1 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(image.repoTags.count) tags")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if image.isDangling {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("dangling")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
            Picker("Filter", selection: $viewModel.tagFilter) {
                ForEach(ImageListViewModel.TagFilter.allCases) { filter in
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
                    Label("No Images", systemImage: "photo.stack.fill")
                } description: {
                    switch viewModel.tagFilter {
                    case .all:      Text("No Docker images found in this environment.")
                    case .tagged:   Text("No tagged images found.")
                    case .untagged: Text("No dangling images — nothing to prune.")
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

#Preview("Images — Light") {
    NavigationStack {
        ImageListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ImageListViewModel(previewImages: DockerImage.mockImages)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Images — Dark") {
    NavigationStack {
        ImageListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ImageListViewModel(previewImages: DockerImage.mockImages)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Untagged Filter") {
    NavigationStack {
        ImageListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: {
                let vm = ImageListViewModel(previewImages: DockerImage.mockImages)
                vm.tagFilter = .untagged
                return vm
            }()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        ImageListView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            environment: .previewMock,
            previewViewModel: ImageListViewModel(previewImages: [])
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

private struct _MockImage {
    var id: String; var tags: [String]; var size: Int64; var containers: Int
}

private extension DockerImage {
    static let mockImages: [DockerImage] = {
        let items: [_MockImage] = [
            _MockImage(id: "sha256:aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222", tags: ["nginx:latest", "nginx:1.25"],    size: 142_349_312, containers: 2),
            _MockImage(id: "sha256:bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222cccc3333", tags: ["postgres:16"],                  size: 431_390_720, containers: 1),
            _MockImage(id: "sha256:cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222cccc3333dddd4444", tags: ["redis:7-alpine"],               size:  40_337_408, containers: 0),
            _MockImage(id: "sha256:dddd4444eeee5555ffff6666aaaa1111bbbb2222cccc3333dddd4444eeee5555", tags: ["node:20-alpine"],              size: 172_023_808, containers: 3),
            _MockImage(id: "sha256:eeee5555ffff6666aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666", tags: [],                             size:  63_881_216, containers: 0),
            _MockImage(id: "sha256:ffff6666aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111", tags: ["grafana/grafana:10.2.0"],      size: 396_500_992, containers: 1),
        ]
        let ts = Int(Date().timeIntervalSince1970)
        return items.map { item in
            let tagsJSON = item.tags.map { "\"\($0)\"" }.joined(separator: ",")
            let json = """
            {
              "Id": "\(item.id)",
              "ParentId": "",
              "RepoTags": [\(tagsJSON)],
              "RepoDigests": [],
              "Created": \(ts - Int.random(in: 3600...2592000)),
              "Size": \(item.size),
              "VirtualSize": \(item.size),
              "SharedSize": 0,
              "Labels": null,
              "Containers": \(item.containers)
            }
            """
            return try! JSONDecoder().decode(DockerImage.self, from: Data(json.utf8))
        }
    }()
}
