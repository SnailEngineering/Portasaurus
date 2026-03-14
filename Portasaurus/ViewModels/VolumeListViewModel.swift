import Foundation
import OSLog

@Observable
final class VolumeListViewModel {

    // MARK: - State

    private(set) var volumes: [DockerVolume] = []
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?
    var searchText = ""
    var usageFilter: UsageFilter = .all

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads volumes without a network call.
    init(previewVolumes: [DockerVolume]) {
        volumes = previewVolumes
    }

    // MARK: - Filtering

    enum UsageFilter: String, CaseIterable, Identifiable {
        case all    = "All"
        case inUse  = "In Use"
        case unused = "Unused"

        var id: String { rawValue }
    }

    var filtered: [DockerVolume] {
        volumes
            .filter { volume in
                switch usageFilter {
                case .all:    return true
                case .inUse:  return volume.isInUse
                case .unused: return !volume.isInUse
                }
            }
            .filter { volume in
                guard !searchText.isEmpty else { return true }
                let needle = searchText
                return volume.name.localizedCaseInsensitiveContains(needle)
                    || volume.driver.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Loading

    func load(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Loading volumes for endpoint \(endpointId)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let response = try await client.volumes(endpointId: endpointId)
            volumes = response.volumes
            AppLogger.viewModel.info("Loaded \(self.volumes.count) volume(s)")
        } catch {
            AppLogger.viewModel.error("Failed to load volumes: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func removeVolume(_ volume: DockerVolume, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Removing volume \(volume.name, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeVolume(name: volume.name, endpointId: endpointId)
            AppLogger.viewModel.info("Removed volume \(volume.name, privacy: .public)")
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Remove volume failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
