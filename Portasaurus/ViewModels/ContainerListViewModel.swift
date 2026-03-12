import Foundation
import OSLog

@Observable
final class ContainerListViewModel {

    // MARK: - State

    private(set) var containers: [DockerContainer] = []
    private(set) var isLoading = false
    private(set) var actionInProgress: String? // container ID currently being acted on
    var loadError: String?
    var searchText = ""
    var stateFilter: StateFilter = .all

    // Confirmation dialog state
    var pendingDestructiveAction: DestructiveAction? = nil

    // MARK: - Filter

    enum StateFilter: String, CaseIterable, Identifiable {
        case all      = "All"
        case running  = "Running"
        case stopped  = "Stopped"
        case paused   = "Paused"

        var id: String { rawValue }
    }

    var filtered: [DockerContainer] {
        containers.filter { container in
            let matchesState: Bool = {
                switch stateFilter {
                case .all:     return true
                case .running: return container.state == .running
                case .stopped: return container.state == .exited || container.state == .dead || container.state == .created
                case .paused:  return container.state == .paused
                }
            }()

            let matchesSearch = searchText.isEmpty
                || container.displayName.localizedCaseInsensitiveContains(searchText)
                || container.image.localizedCaseInsensitiveContains(searchText)

            return matchesState && matchesSearch
        }
    }

    // MARK: - Loading

    func load(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Loading containers for endpoint \(endpointId)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            containers = try await client.containers(endpointId: endpointId)
            AppLogger.viewModel.info("Loaded \(self.containers.count) container(s)")
        } catch {
            AppLogger.viewModel.error("Failed to load containers: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    /// Loads once then polls every 10 seconds until the task is cancelled.
    func loadAndAutoRefresh(client: PortainerClient, endpointId: Int) async {
        await load(client: client, endpointId: endpointId)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { break }
            await load(client: client, endpointId: endpointId)
        }
    }

    // MARK: - Container Actions

    enum ContainerAction: Sendable {
        case start, stop, restart
    }

    struct DestructiveAction: Identifiable, Sendable {
        enum Kind: Sendable { case kill, remove }
        let id = UUID()
        let kind: Kind
        let container: DockerContainer
    }

    func perform(_ action: ContainerAction, on container: DockerContainer, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Performing \(String(describing: action), privacy: .public) on \(container.displayName, privacy: .public)")
        actionInProgress = container.id
        defer { actionInProgress = nil }
        do {
            switch action {
            case .start:   try await client.startContainer(id: container.id, endpointId: endpointId)
            case .stop:    try await client.stopContainer(id: container.id, endpointId: endpointId)
            case .restart: try await client.restartContainer(id: container.id, endpointId: endpointId)
            }
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Action failed: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    func confirmDestructive(_ action: DestructiveAction, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Performing \(String(describing: action.kind), privacy: .public) on \(action.container.displayName, privacy: .public)")
        actionInProgress = action.container.id
        defer { actionInProgress = nil }
        do {
            switch action.kind {
            case .kill:   try await client.killContainer(id: action.container.id, endpointId: endpointId)
            case .remove: try await client.removeContainer(id: action.container.id, endpointId: endpointId)
            }
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Destructive action failed: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }
}
