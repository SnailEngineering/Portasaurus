import SwiftUI

/// Displays full details for a single Portainer stack.
///
/// Sections: Overview, Containers, Environment Variables, Compose File.
/// Toolbar: start/stop actions.
struct StackDetailView: View {

    let client: PortainerClient
    let stack: PortainerStack
    let environment: PortainerEndpoint

    @State private var viewModel: StackDetailViewModel
    @State private var isPreview = false
    @State private var showEnvVars = false

    /// Convenience accessor so the rest of the view can use `endpointId` directly.
    private var endpointId: Int { environment.id }

    // MARK: - Init

    init(client: PortainerClient, stack: PortainerStack, environment: PortainerEndpoint) {
        self.client = client
        self.stack = stack
        self.environment = environment
        self._viewModel = State(initialValue: StackDetailViewModel())
    }

    init(client: PortainerClient, stack: PortainerStack, environment: PortainerEndpoint, previewViewModel: StackDetailViewModel) {
        self.client = client
        self.stack = stack
        self.environment = environment
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stack == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.stack == nil {
                errorView(message: error)
            } else if let detail = viewModel.stack {
                detailContent(detail)
            } else {
                // Fallback — show the list-row data we already have
                detailContent(stack)
            }
        }
        .navigationTitle(stack.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .refreshable {
            await viewModel.load(client: client, stackId: stack.id)
            await viewModel.loadComposeFile(client: client, stackId: stack.id)
        }
        .task {
            guard !isPreview else { return }
            async let detail: () = viewModel.load(client: client, stackId: stack.id)
            async let file: () = viewModel.loadComposeFile(client: client, stackId: stack.id)
            _ = await (detail, file)
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: PortainerStack) -> some View {
        List {
            overviewSection(detail)
            containersSection(detail)
            if !detail.env.isEmpty {
                envSection(detail.env)
            }
            composeFileSection
        }
        .listStyle(.inset)
    }

    // MARK: - Overview Section

    private func overviewSection(_ detail: PortainerStack) -> some View {
        Section("Overview") {
            LabeledContent("Status") {
                statusBadge(detail.status)
            }
            LabeledContent("Type") {
                HStack(spacing: 6) {
                    Image(systemName: detail.type.systemImage)
                        .foregroundStyle(.secondary)
                    Text(detail.type.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Environment ID") {
                Text("\(detail.endpointId)")
                    .foregroundStyle(.secondary)
            }
            if !detail.additionalFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compose Files")
                        .foregroundStyle(.primary)
                    ForEach(detail.additionalFiles, id: \.self) { file in
                        Text(file)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Containers Section

    private func containersSection(_ detail: PortainerStack) -> some View {
        Section {
            NavigationLink {
                ContainerListView(
                    client: client,
                    environment: environment,
                    stackName: detail.name
                )
            } label: {
                Label("Containers", systemImage: "shippingbox")
            }
        }
    }

    // MARK: - Env Section

    private func envSection(_ env: [PortainerStack.EnvPair]) -> some View {
        Section {
            // Always-visible toggle row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEnvVars.toggle()
                }
            } label: {
                HStack {
                    Label(
                        showEnvVars ? "Hide Environment Variables" : "Show Environment Variables",
                        systemImage: showEnvVars ? "eye.slash" : "eye"
                    )
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showEnvVars ? 90 : 0))
                }
            }

            if showEnvVars {
                ForEach(env, id: \.name) { pair in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.name)
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(pair.value.isEmpty ? "(empty)" : pair.value)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Environment Variables (\(env.count))")
        }
    }

    // MARK: - Compose File Section

    private var composeFileSection: some View {
        Section("Compose File") {
            if viewModel.isLoadingFile {
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }
            } else if let content = viewModel.composeFile {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(content)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Copy button
                Button {
                    copyToClipboard(content)
                } label: {
                    Label("Copy File", systemImage: "doc.on.doc")
                        .font(.callout)
                }
            } else {
                Text("Compose file unavailable.")
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.loadComposeFile(client: client, stackId: stack.id) }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if viewModel.isActing {
                ProgressView()
            }

            let currentStack = viewModel.stack ?? stack
            if currentStack.status.isActive {
                Button {
                    Task { await viewModel.perform(.stop, client: client, stackId: stack.id, endpointId: endpointId) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(viewModel.isActing)
            } else {
                Button {
                    Task { await viewModel.perform(.start, client: client, stackId: stack.id, endpointId: endpointId) }
                } label: {
                    Label("Start", systemImage: "play.fill")
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
                Task { await viewModel.load(client: client, stackId: stack.id) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: PortainerStack.StackStatus) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15),
                        in: Capsule())
            .foregroundStyle(status.isActive ? Color.green : Color.secondary)
    }

    private func copyToClipboard(_ text: String) {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#else
        UIPasteboard.general.string = text
#endif
    }
}

// MARK: - Optional binding helper

private extension Optional where Wrapped == String {
    var isPresented: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

// MARK: - Previews

#Preview("Active Stack — Light") {
    NavigationStack {
        StackDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            stack: .previewActive,
            environment: .previewMock,
            previewViewModel: StackDetailViewModel(
                previewStack: .previewActive,
                composeFile: .previewComposeFile
            )
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Active Stack — Dark") {
    NavigationStack {
        StackDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            stack: .previewActive,
            environment: .previewMock,
            previewViewModel: StackDetailViewModel(
                previewStack: .previewActive,
                composeFile: .previewComposeFile
            )
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Inactive Stack") {
    NavigationStack {
        StackDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            stack: .previewInactive,
            environment: .previewMock,
            previewViewModel: StackDetailViewModel(
                previewStack: .previewInactive,
                composeFile: nil
            )
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

private extension PortainerStack {
    static let previewActive: PortainerStack = {
        let json = """
        {
          "Id": 1,
          "Name": "nginx-proxy",
          "Type": 2,
          "EndpointId": 1,
          "Status": 1,
          "Env": [
            {"name": "NGINX_HOST", "value": "example.com"},
            {"name": "NGINX_PORT", "value": "80"},
            {"name": "SSL_CERT_PATH", "value": "/etc/ssl/certs/nginx.crt"}
          ],
          "AdditionalFiles": []
        }
        """
        return try! JSONDecoder().decode(PortainerStack.self, from: Data(json.utf8))
    }()

    static let previewInactive: PortainerStack = {
        let json = """
        {
          "Id": 3,
          "Name": "database-stack",
          "Type": 2,
          "EndpointId": 1,
          "Status": 2,
          "Env": [
            {"name": "POSTGRES_USER", "value": "admin"},
            {"name": "POSTGRES_PASSWORD", "value": "secret"},
            {"name": "POSTGRES_DB", "value": "myapp"},
            {"name": "PGDATA", "value": "/var/lib/postgresql/data"},
            {"name": "POSTGRES_HOST_AUTH_METHOD", "value": "md5"},
            {"name": "BACKUP_SCHEDULE", "value": "0 2 * * *"},
            {"name": "BACKUP_RETENTION_DAYS", "value": "14"},
            {"name": "REPLICATION_MODE", "value": "async"}
          ],
          "AdditionalFiles": ["docker-compose.override.yml"]
        }
        """
        return try! JSONDecoder().decode(PortainerStack.self, from: Data(json.utf8))
    }()
}

private extension String {
    static let previewComposeFile = """
    version: "3.8"

    services:
      nginx:
        image: nginx:alpine
        restart: unless-stopped
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - ./nginx.conf:/etc/nginx/nginx.conf:ro
          - ./certs:/etc/ssl/certs:ro
          - nginx-logs:/var/log/nginx
        environment:
          - NGINX_HOST=${NGINX_HOST}
          - NGINX_PORT=${NGINX_PORT}
        networks:
          - proxy

    volumes:
      nginx-logs:

    networks:
      proxy:
        external: true
    """
}
