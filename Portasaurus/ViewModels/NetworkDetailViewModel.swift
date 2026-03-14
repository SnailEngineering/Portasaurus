import Foundation
import OSLog

@Observable
final class NetworkDetailViewModel {

    // MARK: - State

    /// The enriched network returned by the detail endpoint (includes full Containers map).
    private(set) var detail: DockerNetwork?
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads detail without a network call.
    init(previewDetail: DockerNetwork) {
        self.detail = previewDetail
    }

    // MARK: - Loading

    func load(client: PortainerClient, networkId: String, endpointId: Int) async {
        AppLogger.viewModel.info("Loading network detail for \(networkId, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            detail = try await client.networkDetail(id: networkId, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Failed to load network detail: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    /// Removes the network and returns `true` on success so the caller can dismiss.
    func removeNetwork(id: String, client: PortainerClient, endpointId: Int) async -> Bool {
        AppLogger.viewModel.info("Removing network \(id, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeNetwork(id: id, endpointId: endpointId)
            AppLogger.viewModel.info("Removed network \(id, privacy: .public)")
            return true
        } catch {
            AppLogger.viewModel.error("Remove network failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
            return false
        }
    }
}
