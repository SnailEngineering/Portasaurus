import Foundation
import OSLog

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

    // MARK: - Init

    init() {}

    /// Preview-only initializer that pre-loads environments without a network call.
    init(previewEnvironments: [PortainerEndpoint]) {
        environments = previewEnvironments
    }

    // MARK: - Actions

    func load(from client: PortainerClient) async {
        AppLogger.viewModel.info("Loading environments")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            environments = try await client.endpoints()
            AppLogger.viewModel.info("Loaded \(self.environments.count) environment(s)")
        } catch {
            AppLogger.viewModel.error("Failed to load environments: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }
}
