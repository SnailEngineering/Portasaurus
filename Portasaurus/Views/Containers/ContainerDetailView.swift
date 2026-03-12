import SwiftUI

/// Displays full inspection data for a single container.
///
/// Sections: Status, Configuration, Environment, Ports, Mounts, Networks, Labels, Resources.
struct ContainerDetailView: View {

    let client: PortainerClient
    let container: DockerContainer
    let endpointId: Int

    @State private var viewModel = ContainerDetailViewModel()

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
        .task { await viewModel.load(client: client, containerId: container.id, endpointId: endpointId) }
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
        .listStyle(.insetGrouped)
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
                    LabeledContent(parts[0]) {
                        Text(parts[1])
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                    .font(.callout.monospaced())
                } else {
                    Text(entry)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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
            ForEach(mounts, id: \.destination) { mount in
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
                            .foregroundStyle(mount.rw ? .primary : .orange)
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
