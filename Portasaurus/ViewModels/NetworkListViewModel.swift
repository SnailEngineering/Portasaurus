import Foundation
import OSLog

@Observable
final class NetworkListViewModel {

    // MARK: - State

    private(set) var networks: [DockerNetwork] = []
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?
    var searchText = ""
    var scopeFilter: ScopeFilter = .all

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads networks without a network call.
    init(previewNetworks: [DockerNetwork]) {
        networks = previewNetworks
    }

    // MARK: - Filtering

    enum ScopeFilter: String, CaseIterable, Identifiable {
        case all    = "All"
        case local  = "Local"
        case swarm  = "Swarm"

        var id: String { rawValue }
    }

    var filtered: [DockerNetwork] {
        networks
            .filter { network in
                switch scopeFilter {
                case .all:   return true
                case .local: return network.scope == "local"
                case .swarm: return network.scope == "swarm"
                }
            }
            .filter { network in
                guard !searchText.isEmpty else { return true }
                let needle = searchText
                return network.name.localizedCaseInsensitiveContains(needle)
                    || network.driver.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Loading

    func load(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Loading networks for endpoint \(endpointId)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            networks = try await client.networks(endpointId: endpointId)
            AppLogger.viewModel.info("Loaded \(self.networks.count) network(s)")
        } catch {
            AppLogger.viewModel.error("Failed to load networks: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func removeNetwork(_ network: DockerNetwork, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Removing network \(network.name, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeNetwork(id: network.id, endpointId: endpointId)
            AppLogger.viewModel.info("Removed network \(network.name, privacy: .public)")
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Remove network failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
