import Foundation
import SwiftData

@Observable
final class ServerListViewModel {

    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case failed(String)

        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.connecting, .connecting): true
            case (.failed(let a), .failed(let b)):           a == b
            default:                                          false
            }
        }
    }

    // MARK: - Properties

    /// Per-server connection state, keyed by server ID.
    private(set) var connectionStates: [UUID: ConnectionState] = [:]

    // MARK: - Public API

    func connectionState(for server: SavedServer) -> ConnectionState {
        connectionStates[server.id] ?? .idle
    }

    /// Deletes a server from SwiftData and removes its Keychain credentials.
    func delete(_ server: SavedServer, in modelContext: ModelContext) {
        try? KeychainService.delete(serverURL: server.serverURL)
        modelContext.delete(server)
    }

    /// Authenticates with `server` and returns a connected `PortainerClient`.
    ///
    /// Updates `connectionState` as the request progresses.
    /// Returns `nil` and sets `.failed` state if authentication fails or credentials are missing.
    @discardableResult
    func connect(to server: SavedServer) async -> PortainerClient? {
        connectionStates[server.id] = .connecting

        guard let credentials = KeychainService.load(serverURL: server.serverURL) else {
            connectionStates[server.id] = .failed("No saved credentials found.")
            return nil
        }

        guard let client = PortainerClient(
            scheme: server.usesHTTPS ? "https" : "http",
            host: server.host,
            port: server.port,
            trustSelfSigned: server.trustSelfSignedCertificates
        ) else {
            connectionStates[server.id] = .failed("Invalid server URL.")
            return nil
        }

        do {
            try await client.authenticate(username: credentials.username, password: credentials.password)
            try await client.systemStatus()
            connectionStates[server.id] = .idle
            return client
        } catch {
            connectionStates[server.id] = .failed(error.localizedDescription)
            return nil
        }
    }

    func clearError(for server: SavedServer) {
        if case .failed = connectionStates[server.id] {
            connectionStates[server.id] = .idle
        }
    }
}
