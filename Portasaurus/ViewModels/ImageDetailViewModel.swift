import Foundation
import OSLog

@Observable
final class ImageDetailViewModel {

    // MARK: - State

    private(set) var detail: DockerImageDetail?
    private(set) var isLoading = false
    var loadError: String?
    var actionError: String?
    private(set) var isActing = false

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads detail without a network call.
    init(previewDetail: DockerImageDetail) {
        self.detail = previewDetail
    }

    // MARK: - Loading

    func load(client: PortainerClient, imageId: String, endpointId: Int) async {
        AppLogger.viewModel.info("Loading image detail for \(imageId, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            detail = try await client.imageDetail(id: imageId, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Failed to load image detail: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func removeImage(id: String, client: PortainerClient, endpointId: Int) async -> Bool {
        AppLogger.viewModel.info("Removing image \(id, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeImage(id: id, endpointId: endpointId)
            AppLogger.viewModel.info("Removed image \(id, privacy: .public)")
            return true
        } catch {
            AppLogger.viewModel.error("Remove image failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
            return false
        }
    }
}
