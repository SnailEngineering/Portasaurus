import Foundation

@Observable
final class EnvironmentListViewModel {

    // MARK: - Properties

    private(set) var environments: [PortainerEndpoint] = []
    private(set) var isLoading = false
    var loadError: String?
    var searchText = ""

    // MARK: - Derived

    var filtered: [PortainerEndpoint] {
        guard !searchText.isEmpty else { return environments }
        return environments.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Actions

    func load(from client: PortainerClient) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            environments = try await client.endpoints()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
