import Foundation
import OSLog

@Observable
final class ContainerDetailViewModel {

    // MARK: - State

    private(set) var detail: DockerContainerDetail?
    private(set) var isLoading = true
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Init

    init() {}

    /// Preview-only initializer with pre-loaded detail data.
    init(previewDetail: DockerContainerDetail) {
        detail = previewDetail
    }

    // MARK: - Loading

    func load(client: PortainerClient, containerId: String, endpointId: Int) async {
        AppLogger.viewModel.info("Loading detail for container \(containerId, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            detail = try await client.containerDetail(id: containerId, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Failed to load container detail: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    enum Action: Sendable { case start, stop, restart }

    func perform(_ action: Action, client: PortainerClient, containerId: String, endpointId: Int) async {
        AppLogger.viewModel.info("Performing \(String(describing: action), privacy: .public) on \(containerId, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            switch action {
            case .start:   try await client.startContainer(id: containerId, endpointId: endpointId)
            case .stop:    try await client.stopContainer(id: containerId, endpointId: endpointId)
            case .restart: try await client.restartContainer(id: containerId, endpointId: endpointId)
            }
            await load(client: client, containerId: containerId, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Action failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
