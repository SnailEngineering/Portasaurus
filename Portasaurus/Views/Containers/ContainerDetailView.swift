import SwiftUI

/// Displays full inspection data for a single container.
///
/// Sections: Status, Configuration, Environment, Ports, Mounts, Networks, Labels, Resources.
struct ContainerDetailView: View {

    let client: PortainerClient
    let container: DockerContainer
    let endpointId: Int

    @State private var viewModel: ContainerDetailViewModel
    @State private var isPreview = false

    init(client: PortainerClient, container: DockerContainer, endpointId: Int) {
        self.client = client
        self.container = container
        self.endpointId = endpointId
        self._viewModel = State(initialValue: ContainerDetailViewModel())
    }

    init(client: PortainerClient, container: DockerContainer, endpointId: Int, previewViewModel: ContainerDetailViewModel) {
        self.client = client
        self.container = container
        self.endpointId = endpointId
        self._viewModel = State(initialValue: previewViewModel)
        self._isPreview = State(initialValue: true)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.detail == nil {
                errorView(message: error)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            }
        }
        .navigationTitle(container.displayName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .refreshable { await viewModel.load(client: client, containerId: container.id, endpointId: endpointId) }
        .task {
            guard !isPreview else { return }
            await viewModel.load(client: client, containerId: container.id, endpointId: endpointId)
        }
        .alert("Action Failed", isPresented: $viewModel.actionError.isPresented) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            if let error = viewModel.actionError { Text(error) }
        }
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: DockerContainerDetail) -> some View {
        List {
            statusSection(detail.state)
            configSection(detail.config)
            if let env = detail.config.env, !env.isEmpty {
                envSection(env)
            }
            portsSection(detail.networkSettings.ports)
            if !detail.mounts.isEmpty {
                mountsSection(detail.mounts)
            }
            if !detail.networkSettings.networks.isEmpty {
                networksSection(detail.networkSettings.networks)
            }
            if let labels = detail.config.labels, !labels.isEmpty {
                labelsSection(labels)
            }
            resourcesSection(detail.hostConfig)
        }
        .listStyle(.inset)
    }

    // MARK: - Status Section

    private func statusSection(_ state: DockerContainerDetail.ContainerDetailState) -> some View {
        Section("Status") {
            LabeledContent("State") {
                StatusBadge(containerState: state.containerState)
            }
            if state.running || state.restarting {
                infoRow("PID", value: "\(state.pid)")
            }
            if !state.startedAt.isEmpty && state.startedAt != "0001-01-01T00:00:00Z" {
                infoRow("Started", value: formattedDate(state.startedAt))
            }
            if !state.running,
               !state.finishedAt.isEmpty,
               state.finishedAt != "0001-01-01T00:00:00Z" {
                infoRow("Finished", value: formattedDate(state.finishedAt))
                infoRow("Exit Code", value: "\(state.exitCode)")
            }
            if state.oomKilled {
                infoRow("OOM Killed", value: "Yes")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Config Section

    private func configSection(_ config: DockerContainerDetail.Config) -> some View {
        Section("Configuration") {
            infoRow("Image", value: config.image)
            if let cmd = config.cmd, !cmd.isEmpty {
                infoRow("Command", value: cmd.joined(separator: " "))
            }
            if let ep = config.entrypoint, !ep.isEmpty {
                infoRow("Entrypoint", value: ep.joined(separator: " "))
            }
            if !config.workingDir.isEmpty {
                infoRow("Working Dir", value: config.workingDir)
            }
            if !config.user.isEmpty {
                infoRow("User", value: config.user)
            }
        }
    }

    // MARK: - Environment Section

    private func envSection(_ env: [String]) -> some View {
        Section("Environment Variables") {
            ForEach(env, id: \.self) { entry in
                let parts = entry.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(parts[0])
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(parts[1])
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                    .padding(.vertical, 2)
                } else {
                    Text(entry)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Ports Section

    private func portsSection(_ ports: [String: [DockerContainerDetail.NetworkSettings.PortBinding]?]) -> some View {
        Section("Ports") {
            let bindings = ports.compactMap { key, value -> (String, [DockerContainerDetail.NetworkSettings.PortBinding])? in
                guard let binds = value, !binds.isEmpty else { return nil }
                return (key, binds)
            }.sorted { $0.0 < $1.0 }

            if bindings.isEmpty {
                Text("No port bindings")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bindings, id: \.0) { containerPort, hostBindings in
                    ForEach(hostBindings, id: \.hostPort) { binding in
                        LabeledContent(containerPort) {
                            Text("\(binding.hostIP.isEmpty ? "0.0.0.0" : binding.hostIP):\(binding.hostPort)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout.monospaced())
                    }
                }
            }
        }
    }

    // MARK: - Mounts Section

    private func mountsSection(_ mounts: [DockerContainerDetail.Mount]) -> some View {
        Section("Mounts") {
            ForEach(Array(mounts.enumerated()), id: \.offset) { _, mount in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mount.destination)
                            .font(.callout.monospaced())
                        Spacer()
                        Text(mount.type.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.tertiary, in: Capsule())
                        Text(mount.rw ? "rw" : "ro")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(mount.rw ? AnyShapeStyle(.primary) : AnyShapeStyle(.orange))
                    }
                    if !mount.source.isEmpty {
                        Text(mount.source)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Networks Section

    private func networksSection(_ networks: [String: DockerContainerDetail.NetworkSettings.NetworkInfo]) -> some View {
        Section("Networks") {
            ForEach(networks.sorted(by: { $0.key < $1.key }), id: \.key) { name, info in
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.body)
                    if !info.ipAddress.isEmpty {
                        Label(info.ipAddress, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !info.gateway.isEmpty {
                        Label(info.gateway, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !info.macAddress.isEmpty {
                        Label(info.macAddress, systemImage: "cpu")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Labels Section

    private func labelsSection(_ labels: [String: String]) -> some View {
        Section("Labels") {
            ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                LabeledContent(key) {
                    Text(value)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                .font(.callout.monospaced())
            }
        }
    }

    // MARK: - Resources Section

    private func resourcesSection(_ hostConfig: DockerContainerDetail.HostConfig) -> some View {
        Section("Resource Limits") {
            if let mb = hostConfig.memoryMB {
                infoRow("Memory", value: "\(mb) MB")
            } else {
                infoRow("Memory", value: "Unlimited")
            }

            let cpu = hostConfig.cpuCount
            if cpu > 0 {
                infoRow("CPU", value: String(format: "%.2f cores", cpu))
            } else {
                infoRow("CPU", value: "Unlimited")
            }

            let policy = hostConfig.restartPolicy.name
            if !policy.isEmpty && policy != "no" {
                let retries = hostConfig.restartPolicy.maximumRetryCount
                let label = retries > 0 ? "\(policy) (max \(retries))" : policy
                infoRow("Restart Policy", value: label)
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

            if let detail = viewModel.detail {
                let state = detail.state.containerState
                if state.canStart {
                    Button {
                        Task { await viewModel.perform(.start, client: client, containerId: container.id, endpointId: endpointId) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .disabled(viewModel.isActing)
                }
                if state.canStop {
                    Button {
                        Task { await viewModel.perform(.stop, client: client, containerId: container.id, endpointId: endpointId) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .disabled(viewModel.isActing)
                }
                if state.canRestart {
                    Button {
                        Task { await viewModel.perform(.restart, client: client, containerId: container.id, endpointId: endpointId) }
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isActing)
                }
            }
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
                Task { await viewModel.load(client: client, containerId: container.id, endpointId: endpointId) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func formattedDate(_ iso8601: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso8601) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso8601) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return iso8601
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

#Preview("Running Container") {
    NavigationStack {
        ContainerDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            container: .previewMock,
            endpointId: 1,
            previewViewModel: ContainerDetailViewModel(previewDetail: .previewRunning)
        )
    }
}

#Preview("Exited Container") {
    NavigationStack {
        ContainerDetailView(
            client: PortainerClient(serverURL: URL(string: "http://localhost:9000")!),
            container: .previewMockExited,
            endpointId: 1,
            previewViewModel: ContainerDetailViewModel(previewDetail: .previewExited)
        )
    }
}

// MARK: - Preview Mock Data

private extension DockerContainer {
    static let previewMock: DockerContainer = {
        let json = """
        {"Id":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4","Names":["/nginx-proxy"],"Image":"nginx:alpine",
         "ImageID":"sha256:abc","Command":"nginx -g 'daemon off;'","Created":1700000000,
         "State":"running","Status":"Up 3 days","Ports":[],"Labels":{}}
        """
        return try! JSONDecoder().decode(DockerContainer.self, from: Data(json.utf8))
    }()

    static let previewMockExited: DockerContainer = {
        let json = """
        {"Id":"b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5","Names":["/api-server"],"Image":"myapp/api:v2.1.0",
         "ImageID":"sha256:def","Command":"/entrypoint.sh","Created":1700000000,
         "State":"exited","Status":"Exited (0) 2 hours ago","Ports":[],"Labels":{}}
        """
        return try! JSONDecoder().decode(DockerContainer.self, from: Data(json.utf8))
    }()
}

private extension DockerContainerDetail {
    static let previewRunning: DockerContainerDetail = {
        let json = """
        {
          "Id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
          "Name": "/nginx-proxy",
          "Created": "2024-01-15T10:30:00Z",
          "State": {
            "Status": "running", "Running": true, "Paused": false, "Restarting": false,
            "OOMKilled": false, "Dead": false, "Pid": 1234, "ExitCode": 0, "Error": "",
            "StartedAt": "2024-01-15T10:30:00Z", "FinishedAt": "0001-01-01T00:00:00Z"
          },
          "Config": {
            "Image": "nginx:alpine",
            "Cmd": ["nginx", "-g", "daemon off;"],
            "Entrypoint": null,
            "WorkingDir": "",
            "User": "",
            "Env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "NGINX_VERSION=1.25.3"],
            "Labels": {"maintainer": "NGINX Docker Maintainers", "com.example.version": "1.0"}
          },
          "HostConfig": {
            "Memory": 268435456,
            "NanoCpus": 500000000,
            "RestartPolicy": {"Name": "unless-stopped", "MaximumRetryCount": 0}
          },
          "Mounts": [
            {"Type": "bind", "Source": "/etc/nginx/conf.d", "Destination": "/etc/nginx/conf.d", "Mode": "ro", "RW": false},
            {"Type": "volume", "Source": "nginx-logs", "Destination": "/var/log/nginx", "Mode": "", "RW": true}
          ],
          "NetworkSettings": {
            "Ports": {"80/tcp": [{"HostIp": "0.0.0.0", "HostPort": "8080"}], "443/tcp": [{"HostIp": "0.0.0.0", "HostPort": "8443"}]},
            "Networks": {
              "bridge": {"IPAddress": "172.17.0.2", "Gateway": "172.17.0.1", "MacAddress": "02:42:ac:11:00:02"}
            }
          }
        }
        """
        return try! JSONDecoder().decode(DockerContainerDetail.self, from: Data(json.utf8))
    }()

    static let previewExited: DockerContainerDetail = {
        let json = """
        {
          "Id": "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5",
          "Name": "/api-server",
          "Created": "2024-01-10T08:00:00Z",
          "State": {
            "Status": "exited", "Running": false, "Paused": false, "Restarting": false,
            "OOMKilled": false, "Dead": false, "Pid": 0, "ExitCode": 0, "Error": "",
            "StartedAt": "2024-01-15T08:00:00Z", "FinishedAt": "2024-01-15T09:45:00Z"
          },
          "Config": {
            "Image": "myapp/api:v2.1.0",
            "Cmd": ["/entrypoint.sh"],
            "Entrypoint": null,
            "WorkingDir": "/app",
            "User": "node",
            "Env": ["NODE_ENV=production", "PORT=3000", "DATABASE_URL=postgres://db:5432/myapp"],
            "Labels": {}
          },
          "HostConfig": {
            "Memory": 536870912,
            "NanoCpus": 1000000000,
            "RestartPolicy": {"Name": "on-failure", "MaximumRetryCount": 3}
          },
          "Mounts": [],
          "NetworkSettings": {
            "Ports": {"3000/tcp": [{"HostIp": "127.0.0.1", "HostPort": "3000"}]},
            "Networks": {
              "app-network": {"IPAddress": "10.0.0.5", "Gateway": "10.0.0.1", "MacAddress": "02:42:0a:00:00:05"}
            }
          }
        }
        """
        return try! JSONDecoder().decode(DockerContainerDetail.self, from: Data(json.utf8))
    }()
}
