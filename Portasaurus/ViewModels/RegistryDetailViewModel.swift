import Foundation

/// View model for the registry detail screen.
///
/// Fetches a single registry by ID and provides a delete action.
@Observable
final class RegistryDetailViewModel {

    // MARK: - State

    private(set) var detail: PortainerRegistry?
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?

    // MARK: - Init

    init() {}

    init(previewRegistry: PortainerRegistry) {
        self.detail = previewRegistry
    }

    // MARK: - Actions

    /// Loads detailed information for the given registry ID.
    func load(id: Int, client: PortainerClient) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            detail = try await client.registry(id: id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Deletes the registry from Portainer. Returns `true` on success so the
    /// caller can dismiss the view.
    func removeRegistry(client: PortainerClient) async -> Bool {
        guard let detail else { return false }
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeRegistry(id: detail.id)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
