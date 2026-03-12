import Foundation
import OSLog
import SwiftData

@Observable
final class AddServerViewModel {

    // MARK: - Form Fields

    var name: String = ""
    var serverURL: String = ""
    var username: String = ""
    var password: String = ""
    var trustSelfSigned: Bool = false

    // MARK: - State

    enum TestResult: Equatable {
        case success(version: String)
        case failure(String)
    }

    var testResult: TestResult?
    var isTesting: Bool = false
    var isSaving: Bool = false

    // MARK: - Validation

    /// Parses `serverURL` into a `URL` with a valid http/https scheme and non-empty host.
    var parsedURL: URL? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        // If the input already has a scheme, use it as-is; otherwise prepend https://.
        // Inputs with a non-http/https scheme (e.g. ftp://) are rejected below.
        let hasScheme = lower.contains("://")
        let candidate = hasScheme ? trimmed : "https://\(trimmed)"

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme, (scheme == "http" || scheme == "https"),
              let host = components.host, !host.isEmpty,
              let url = components.url else { return nil }

        return url
    }

    var isValid: Bool {
        !name.isBlank && parsedURL != nil && !username.isBlank && !password.isBlank
    }

    var validationMessage: String? {
        if name.isBlank     { return "Display name is required." }
        if parsedURL == nil { return "Enter a valid server URL (e.g. https://portainer.example.com)." }
        if username.isBlank { return "Username is required." }
        if password.isBlank { return "Password is required." }
        return nil
    }

    // MARK: - Actions

    /// Attempts authentication + system status check without saving anything.
    func testConnection() async {
        guard let url = parsedURL else {
            AppLogger.viewModel.warning("testConnection called with invalid URL: '\(self.serverURL, privacy: .public)'")
            testResult = .failure("Invalid server URL.")
            return
        }

        AppLogger.viewModel.info("Testing connection to \(url, privacy: .public)")
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        let client = PortainerClient(serverURL: url, trustSelfSigned: trustSelfSigned)
        do {
            try await client.authenticate(username: username, password: password)
            let status = try await client.systemStatus()
            AppLogger.viewModel.info("Connection test succeeded — Portainer \(status.version, privacy: .public)")
            testResult = .success(version: status.version)
        } catch {
            AppLogger.viewModel.error("Connection test failed: \(error.localizedDescription, privacy: .public)")
            testResult = .failure(error.localizedDescription)
        }
    }

    /// Saves the server to SwiftData + Keychain, authenticates, and returns the connected client and server ID.
    @discardableResult
    func saveAndConnect(modelContext: ModelContext) async throws -> (client: PortainerClient, serverID: UUID) {
        guard let url = parsedURL else {
            AppLogger.viewModel.error("saveAndConnect called with invalid URL: '\(self.serverURL, privacy: .public)'")
            throw AddServerError.invalidURL
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        AppLogger.viewModel.info("Saving server '\(trimmedName, privacy: .public)' at \(url, privacy: .public)")

        let namePredicate = #Predicate<SavedServer> { $0.name == trimmedName }
        let existing = try modelContext.fetch(FetchDescriptor(predicate: namePredicate))
        if !existing.isEmpty {
            AppLogger.viewModel.warning("Duplicate server name '\(trimmedName, privacy: .public)'")
            throw AddServerError.duplicateName(trimmedName)
        }

        let client = PortainerClient(serverURL: url, trustSelfSigned: trustSelfSigned)

        // Authenticate first — fail fast before persisting anything.
        try await client.authenticate(username: username, password: password)
        try await client.systemStatus()

        let urlString = url.absoluteString
        let server = SavedServer(
            name: trimmedName,
            serverURL: urlString,
            username: username.trimmingCharacters(in: .whitespaces),
            trustSelfSignedCertificates: trustSelfSigned
        )
        modelContext.insert(server)
        AppLogger.persistence.info("Inserted server '\(trimmedName, privacy: .public)' (id: \(server.id, privacy: .public))")

        try KeychainService.save(
            username: server.username,
            password: password,
            serverURL: urlString
        )

        AppLogger.viewModel.info("Server '\(trimmedName, privacy: .public)' saved and connected (id: \(server.id, privacy: .public))")
        return (client, server.id)
    }
}

// MARK: - Supporting Types

enum AddServerError: LocalizedError {
    case invalidURL
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not construct a valid server URL from the provided input."
        case .duplicateName(let name):
            "A server named \"\(name)\" already exists. Please choose a different name."
        }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty }
}
