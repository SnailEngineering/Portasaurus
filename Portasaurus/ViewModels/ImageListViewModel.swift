import Foundation
import OSLog

@Observable
final class ImageListViewModel {

    // MARK: - State

    private(set) var images: [DockerImage] = []
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?
    var searchText = ""
    var tagFilter: TagFilter = .all
    var lastPruneResult: ImagePruneResponse?

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads images without a network call.
    init(previewImages: [DockerImage]) {
        images = previewImages
    }

    // MARK: - Filtering

    enum TagFilter: String, CaseIterable, Identifiable {
        case all       = "All"
        case tagged    = "Tagged"
        case untagged  = "Untagged"

        var id: String { rawValue }
    }

    var filtered: [DockerImage] {
        images
            .filter { image in
                switch tagFilter {
                case .all:      return true
                case .tagged:   return !image.isDangling
                case .untagged: return image.isDangling
                }
            }
            .filter { image in
                guard !searchText.isEmpty else { return true }
                let needle = searchText
                return image.repoTags.contains { $0.localizedCaseInsensitiveContains(needle) }
                    || image.shortId.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Loading

    func load(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Loading images for endpoint \(endpointId)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            images = try await client.images(endpointId: endpointId)
            AppLogger.viewModel.info("Loaded \(self.images.count) image(s)")
        } catch {
            AppLogger.viewModel.error("Failed to load images: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func removeImage(_ image: DockerImage, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Removing image \(image.shortId, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeImage(id: image.id, endpointId: endpointId)
            AppLogger.viewModel.info("Removed image \(image.shortId, privacy: .public)")
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Remove image failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }

    func pruneImages(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Pruning images for endpoint \(endpointId)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            lastPruneResult = try await client.pruneImages(endpointId: endpointId)
            AppLogger.viewModel.info("Pruned images, reclaimed \(self.lastPruneResult?.formattedSpaceReclaimed ?? "0", privacy: .public)")
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Prune images failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
