import Foundation
import OSLog

@Observable
final class StackListViewModel {

    // MARK: - State

    private(set) var stacks: [PortainerStack] = []
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Filters

    var searchText: String = ""
    var statusFilter: StatusFilter = .all

    // MARK: - Computed

    var filtered: [PortainerStack] {
        stacks
            .filter { stack in
                switch statusFilter {
                case .all:      return true
                case .active:   return stack.status.isActive
                case .inactive: return !stack.status.isActive
                }
            }
            .filter { stack in
                searchText.isEmpty || stack.name.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - Nested Types

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all      = "All"
        case active   = "Active"
        case inactive = "Inactive"

        var id: String { rawValue }
    }

    // MARK: - Init

    init() {}

    /// Preview-only initializer with pre-loaded stacks.
    init(previewStacks: [PortainerStack]) {
        self.stacks = previewStacks
    }

    // MARK: - Loading

    func load(client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Loading stacks for endpoint \(endpointId, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            stacks = try await client.stacks(endpointId: endpointId)
            AppLogger.viewModel.info("Loaded \(self.stacks.count, privacy: .public) stacks")
        } catch {
            AppLogger.viewModel.error("Failed to load stacks: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    // MARK: - Actions

    enum Action: Sendable { case start, stop }

    func perform(_ action: Action, stack: PortainerStack, client: PortainerClient, endpointId: Int) async {
        AppLogger.viewModel.info("Performing \(String(describing: action), privacy: .public) on stack \(stack.name, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            switch action {
            case .start: try await client.startStack(id: stack.id, endpointId: endpointId)
            case .stop:  try await client.stopStack(id: stack.id, endpointId: endpointId)
            }
            // Reload to reflect updated status.
            await load(client: client, endpointId: endpointId)
        } catch {
            AppLogger.viewModel.error("Stack action failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
