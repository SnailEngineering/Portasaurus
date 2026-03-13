import Foundation
import OSLog

@Observable
final class StackDetailViewModel {

    // MARK: - State

    private(set) var stack: PortainerStack?
    private(set) var composeFile: String?
    private(set) var isLoading = false
    private(set) var isLoadingFile = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Init

    init() {}

    /// Preview-only initializer with pre-loaded data.
    init(previewStack: PortainerStack, composeFile: String? = nil) {
        self.stack = previewStack
        self.composeFile = composeFile
        self.isLoading = false
    }

    // MARK: - Loading

    func load(client: PortainerClient, stackId: Int) async {
        AppLogger.viewModel.info("Loading stack detail for \(stackId, privacy: .public)")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            stack = try await client.stack(id: stackId)
        } catch {
            AppLogger.viewModel.error("Failed to load stack \(stackId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    func loadComposeFile(client: PortainerClient, stackId: Int) async {
        AppLogger.viewModel.info("Loading compose file for stack \(stackId, privacy: .public)")
        isLoadingFile = true
        defer { isLoadingFile = false }
        do {
            let response = try await client.stackFile(id: stackId)
            composeFile = response.stackFileContent
        } catch {
            AppLogger.viewModel.error("Failed to load compose file for stack \(stackId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            // Non-fatal — compose file section shows an error inline.
            composeFile = nil
        }
    }

    // MARK: - Actions

    enum Action: Sendable { case start, stop }

    func perform(_ action: Action, client: PortainerClient, stackId: Int, endpointId: Int) async {
        AppLogger.viewModel.info("Performing \(String(describing: action), privacy: .public) on stack \(stackId, privacy: .public)")
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            switch action {
            case .start: try await client.startStack(id: stackId, endpointId: endpointId)
            case .stop:  try await client.stopStack(id: stackId, endpointId: endpointId)
            }
            await load(client: client, stackId: stackId)
        } catch {
            AppLogger.viewModel.error("Stack action failed: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}
