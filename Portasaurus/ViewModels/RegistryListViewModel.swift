import Foundation

/// View model for the registry list screen.
///
/// Handles fetching all Portainer registries, filtering by search text,
/// and deleting individual registries.
@Observable
final class RegistryListViewModel {

    // MARK: - State

    private(set) var registries: [PortainerRegistry] = []
    private(set) var isLoading = false
    private(set) var isActing = false
    var loadError: String?
    var actionError: String?
    var searchText = ""

    // MARK: - Filtered view

    /// Registries filtered by the current search text, sorted alphabetically by name.
    var filtered: [PortainerRegistry] {
        let base = searchText.isEmpty
            ? registries
            : registries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        return base.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Init

    init() {}

    init(previewRegistries: [PortainerRegistry]) {
        self.registries = previewRegistries
    }

    // MARK: - Actions

    /// Fetches the full registry list from Portainer.
    func load(client: PortainerClient) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            registries = try await client.registries()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Deletes a registry from Portainer and refreshes the list on success.
    func removeRegistry(_ registry: PortainerRegistry, client: PortainerClient) async {
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await client.removeRegistry(id: registry.id)
            await load(client: client)
        } catch {
            actionError = error.localizedDescription
        }
    }
}
