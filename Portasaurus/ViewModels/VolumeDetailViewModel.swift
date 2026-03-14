import Foundation
import OSLog

@Observable
final class VolumeDetailViewModel {

    // MARK: - State

    /// The enriched volume returned by the detail endpoint (includes UsageData).
    private(set) var detail: DockerVolume?
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads detail without a network call.
    init(previewDetail: DockerVolume) {
        self.detail = previewDetail
    }

    // MARK: - Loading

    func load(client: PortainerClient, volumeName: String, endpointId: Int) async {
        AppLogger.viewModel.info("Loading volume detail for \(volumeName, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            detail = try await client.volumeDetail(name: volumeName, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Failed to load volume detail: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    /// Removes the volume and returns `true` on success so the caller can dismiss.
    func removeVolume(name: String, client: PortainerClient, endpointId: Int) async -> Bool {
        AppLogger.viewModel.info("Removing volume \(name, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeVolume(name: name, endpointId: endpointId)
            AppLogger.viewModel.info("Removed volume \(name, privacy: .public)")
            return true
        } catch {
            AppLogger.viewModel.error("Remove volume failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
            return false
        }
    }
}
