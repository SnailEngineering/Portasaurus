import Foundation
import SwiftData

@Observable
final class AddServerViewModel {

    // MARK: - Form Fields

    var name: String = ""
    var host: String = ""
    var port: String = "9443"
    var usesHTTPS: Bool = true
    var username: String = ""
    var password: String = ""
    var trustSelfSigned: Bool = false

    // MARK: - State

    enum TestResult {
        case success(version: String)
        case failure(String)
    }

    var testResult: TestResult?
    var isTesting: Bool = false
    var isSaving: Bool = false

    // MARK: - Validation

    var portValue: Int? {
        guard let n = Int(port), (1...65535).contains(n) else { return nil }
        return n
    }

    var isValid: Bool {
        !name.isBlank && !host.isBlank && portValue != nil &&
        !username.isBlank && !password.isBlank
    }

    var validationMessage: String? {
        if name.isBlank       { return "Display name is required." }
        if host.isBlank       { return "Host or IP address is required." }
        if portValue == nil   { return "Port must be between 1 and 65535." }
        if username.isBlank   { return "Username is required." }
        if password.isBlank   { return "Password is required." }
        return nil
    }

    // MARK: - Actions

    /// Attempts authentication + system status check without saving anything.
    func testConnection() async {
        guard let client = makeClient() else {
            testResult = .failure("Invalid server URL.")
            return
        }

        isTesting = true
        testResult = nil
        defer { isTesting = false }

        do {
            try await client.authenticate(username: username, password: password)
            let status = try await client.systemStatus()
            testResult = .success(version: status.version)
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }

    /// Saves the server to SwiftData + Keychain, authenticates, and returns the connected client and server ID.
    @discardableResult
    func saveAndConnect(modelContext: ModelContext) async throws -> (client: PortainerClient, serverID: UUID) {
        guard let client = makeClient() else {
            throw AddServerError.invalidURL
        }

        isSaving = true
        defer { isSaving = false }

        // Reject duplicate display names before touching the network.
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let namePredicate = #Predicate<SavedServer> { $0.name == trimmedName }
        let existing = try modelContext.fetch(FetchDescriptor(predicate: namePredicate))
        if !existing.isEmpty {
            throw AddServerError.duplicateName(trimmedName)
        }

        // Authenticate first — fail fast before persisting anything.
        try await client.authenticate(username: username, password: password)
        try await client.systemStatus()

        // Persist metadata.
        guard let port = portValue else { throw AddServerError.invalidURL }
        let server = SavedServer(
            name: trimmedName,
            host: host.trimmingCharacters(in: .whitespaces),
            port: port,
            usesHTTPS: usesHTTPS,
            username: username.trimmingCharacters(in: .whitespaces),
            trustSelfSignedCertificates: trustSelfSigned
        )
        modelContext.insert(server)

        // Persist credentials.
        try KeychainService.save(
            username: server.username,
            password: password,
            serverURL: server.serverURL
        )

        return (client, server.id)
    }

    // MARK: - Helpers

    private func makeClient() -> PortainerClient? {
        guard let port = portValue else { return nil }
        return PortainerClient(
            scheme: usesHTTPS ? "https" : "http",
            host: host.trimmingCharacters(in: .whitespaces),
            port: port,
            trustSelfSigned: trustSelfSigned
        )
    }
}

// MARK: - Supporting Types

enum AddServerError: LocalizedError {
    case invalidURL
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not construct a valid server URL from the provided host and port."
        case .duplicateName(let name):
            "A server named \"\(name)\" already exists. Please choose a different name."
        }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty }
}
