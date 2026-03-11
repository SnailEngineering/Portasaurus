import Foundation

/// Response from `GET /api/system/status`.
struct PortainerSystemStatus: Decodable, Sendable {
    let instanceID: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case instanceID = "InstanceID"
        case version    = "Version"
    }
}
