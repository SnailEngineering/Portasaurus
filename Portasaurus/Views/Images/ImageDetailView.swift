import SwiftUI

/// Displays full inspection data for a single Docker image.
///
/// Sections: Overview, Tags, Config (cmd/entrypoint/ports/workdir/user),
/// Environment, Labels, Layers, Digests.
struct ImageDetailView: View {

    let client: PortainerClient
    let image: DockerImage
    let endpointId: Int

    @State private var viewModel: ImageDetailViewModel
    @State private var isPreview = false
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(client: PortainerClient, image: DockerImage, endpointId: Int) {
        self.client = client
        self.image = image
        self.endpointId = endpointId
        self._viewModel = State(initialValue: ImageDetailViewModel())
    }

    init(client: PortainerClient, image: DockerImage, endpointId: Int, previewViewModel: ImageDetailViewModel) {
        self.client = client
        self.image = image
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
        .navigationTitle(image.displayName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .refreshable { await viewModel.load(client: client, imageId: image.id, endpointId: endpointId) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, imageId: image.id, endpointId: endpointId)
        }
        .confirmationDialog(
            "Remove Image?",
            isPresented: $pendingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    let removed = await viewModel.removeImage(id: image.id, client: client, endpointId: endpointId)
                    if removed { dismiss() }
                }
            }
        } message: {
            Text("Permanently remove \"\(image.displayName)\"? This cannot be undone.")
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: DockerImageDetail) -> some View {
        List {
            overviewSection(detail)
            if !detail.repoTags.isEmpty {
                tagsSection(detail.repoTags)
            }
            configSection(detail.config)
            if !detail.config.env.isEmpty {
                envSection(detail.config.env)
            }
            if !detail.config.labels.isEmpty {
                labelsSection(detail.config.labels)
            }
            if !detail.rootFS.layers.isEmpty {
                layersSection(detail.rootFS)
            }
            if !detail.repoDigests.isEmpty {
                digestsSection(detail.repoDigests)
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

    private func overviewSection(_ detail: DockerImageDetail) -> some View {
        Section("Overview") {
            LabeledContent("ID") {
                Text(detail.shortId)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let date = detail.createdDate {
                LabeledContent("Created") {
                    Text(date, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Size", value: detail.formattedSize)
            if detail.virtualSize != detail.size {
                LabeledContent("Virtual Size", value: detail.formattedVirtualSize)
            }
            if !detail.os.isEmpty {
                LabeledContent("OS", value: detail.os.capitalized)
            }
            if !detail.architecture.isEmpty {
                LabeledContent("Architecture", value: detail.architecture)
            }
            if !detail.author.isEmpty {
                LabeledContent("Author", value: detail.author)
            }
        }
    }

    // MARK: - Tags Section

    private func tagsSection(_ tags: [String]) -> some View {
        Section("Tags (\(tags.count))") {
            ForEach(tags.sorted(), id: \.self) { tag in
                Text(tag)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Config Section

    private func configSection(_ config: DockerImageDetail.ImageConfig) -> some View {
        Section("Configuration") {
            if !config.workingDir.isEmpty {
                LabeledContent("Working Dir") {
                    Text(config.workingDir)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            if !config.user.isEmpty {
                LabeledContent("User", value: config.user)
            }
            if !config.entrypoint.isEmpty {
                LabeledContent("Entrypoint") {
                    Text(config.entrypoint.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            if !config.cmd.isEmpty {
                LabeledContent("Command") {
                    Text(config.cmd.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            if !config.exposedPorts.isEmpty {
                let ports = config.exposedPorts.keys.sorted()
                LabeledContent("Exposed Ports") {
                    Text(ports.joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Environment Section

    private func envSection(_ env: [String]) -> some View {
        Section("Environment (\(env.count))") {
            ForEach(env, id: \.self) { entry in
                let parts = entry.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    LabeledContent(String(parts[0])) {
                        Text(String(parts[1]))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Text(entry)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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

    // MARK: - Layers Section

    private func layersSection(_ rootFS: DockerImageDetail.RootFS) -> some View {
        Section("Layers (\(rootFS.layers.count))") {
            ForEach(Array(rootFS.layers.enumerated()), id: \.offset) { index, layer in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, alignment: .trailing)
                    Text(layer.hasPrefix("sha256:") ? String(layer.dropFirst(7).prefix(24)) : String(layer.prefix(24)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Digests Section

    private func digestsSection(_ digests: [String]) -> some View {
        Section("Digests") {
            ForEach(digests, id: \.self) { digest in
                Text(digest)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
                Task { await viewModel.load(client: client, imageId: image.id, endpointId: endpointId) }
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

#Preview("Image Detail — Light") {
    NavigationStack {
        ImageDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            image: .previewMock,
            endpointId: 1,
            previewViewModel: ImageDetailViewModel(previewDetail: .previewMock)
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Image Detail — Dark") {
    NavigationStack {
        ImageDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            image: .previewMock,
            endpointId: 1,
            previewViewModel: ImageDetailViewModel(previewDetail: .previewMock)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dangling Image") {
    NavigationStack {
        ImageDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            image: .previewDanglingMock,
            endpointId: 1,
            previewViewModel: ImageDetailViewModel(previewDetail: .previewDanglingMock)
        )
    }
}

// MARK: - Preview Mock Data

private extension DockerImage {
    static let previewMock: DockerImage = {
        let json = """
        {
          "Id": "sha256:aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222",
          "ParentId": "",
          "RepoTags": ["nginx:latest", "nginx:1.25"],
          "RepoDigests": ["nginx@sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"],
          "Created": 1700000000,
          "Size": 142349312,
          "VirtualSize": 142349312,
          "SharedSize": 0,
          "Labels": null,
          "Containers": 2
        }
        """
        return try! JSONDecoder().decode(DockerImage.self, from: Data(json.utf8))
    }()

    static let previewDanglingMock: DockerImage = {
        let json = """
        {
          "Id": "sha256:eeee5555ffff6666aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666",
          "ParentId": "",
          "RepoTags": [],
          "RepoDigests": [],
          "Created": 1699000000,
          "Size": 63881216,
          "VirtualSize": 63881216,
          "SharedSize": 0,
          "Labels": null,
          "Containers": 0
        }
        """
        return try! JSONDecoder().decode(DockerImage.self, from: Data(json.utf8))
    }()
}

private extension DockerImageDetail {
    static let previewMock: DockerImageDetail = {
        let json = """
        {
          "Id": "sha256:aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222",
          "RepoTags": ["nginx:latest", "nginx:1.25"],
          "RepoDigests": ["nginx@sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"],
          "Parent": "",
          "Created": "2023-11-14T22:13:20.123456789Z",
          "Size": 142349312,
          "VirtualSize": 187109376,
          "Os": "linux",
          "Architecture": "amd64",
          "Author": "",
          "Config": {
            "Cmd": ["nginx", "-g", "daemon off;"],
            "Entrypoint": ["/docker-entrypoint.sh"],
            "Env": [
              "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
              "NGINX_VERSION=1.25.3",
              "NJS_VERSION=0.8.2",
              "PKG_RELEASE=1~bookworm"
            ],
            "ExposedPorts": {"80/tcp": {}},
            "Labels": {
              "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>"
            },
            "WorkingDir": "",
            "User": ""
          },
          "RootFS": {
            "Type": "layers",
            "Layers": [
              "sha256:a1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:b1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:c1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:d1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:e1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:f1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
            ]
          }
        }
        """
        return try! JSONDecoder().decode(DockerImageDetail.self, from: Data(json.utf8))
    }()

    static let previewDanglingMock: DockerImageDetail = {
        let json = """
        {
          "Id": "sha256:eeee5555ffff6666aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666",
          "RepoTags": [],
          "RepoDigests": [],
          "Parent": "sha256:aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222",
          "Created": "2023-11-03T10:22:11.000000000Z",
          "Size": 63881216,
          "VirtualSize": 63881216,
          "Os": "linux",
          "Architecture": "arm64",
          "Author": "",
          "Config": {
            "Cmd": ["node", "server.js"],
            "Entrypoint": null,
            "Env": ["NODE_ENV=production", "PORT=3000"],
            "ExposedPorts": {"3000/tcp": {}},
            "Labels": {},
            "WorkingDir": "/app",
            "User": "node"
          },
          "RootFS": {
            "Type": "layers",
            "Layers": [
              "sha256:a1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "sha256:b1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
            ]
          }
        }
        """
        return try! JSONDecoder().decode(DockerImageDetail.self, from: Data(json.utf8))
    }()
}
