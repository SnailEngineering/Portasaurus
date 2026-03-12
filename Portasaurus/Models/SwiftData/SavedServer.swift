import Foundation
import SwiftData

/// A Portainer server bookmark persisted via SwiftData.
///
/// Only non-sensitive metadata is stored here.
/// Credentials (username + password) live exclusively in the Keychain,
/// keyed by `serverURL`.
@Model
final class SavedServer {

    #Unique<SavedServer>([\.name])

    // MARK: - Stored Properties

    var id: UUID
    var name: String
    var serverURL: String
    var username: String
    var trustSelfSignedCertificates: Bool
    var dateAdded: Date
    var lastConnected: Date?

    // MARK: - Init

    init(
        name: String,
        serverURL: String,
        username: String,
        trustSelfSignedCertificates: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.serverURL = serverURL
        self.username = username
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
        self.dateAdded = Date()
        self.lastConnected = nil
    }
}
