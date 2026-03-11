import Foundation
import SwiftData

/// A Portainer server bookmark persisted via SwiftData.
///
/// Only non-sensitive metadata is stored here.
/// Credentials (username + password) live exclusively in the Keychain,
/// keyed by `serverURL`.
@Model
final class SavedServer {

    // MARK: - Stored Properties

    var id: UUID
    var name: String
    var host: String
    var port: Int
    var usesHTTPS: Bool
    var username: String
    var trustSelfSignedCertificates: Bool
    var dateAdded: Date
    var lastConnected: Date?

    // MARK: - Init

    init(
        name: String,
        host: String,
        port: Int,
        usesHTTPS: Bool,
        username: String,
        trustSelfSignedCertificates: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.usesHTTPS = usesHTTPS
        self.username = username
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
        self.dateAdded = Date()
        self.lastConnected = nil
    }

    // MARK: - Computed

    /// The full server URL string used as the Keychain key.
    var serverURL: String {
        "\(usesHTTPS ? "https" : "http")://\(host):\(port)"
    }
}
