import Foundation

/// A container entry from `GET .../containers/json?all=true`.
struct DockerContainer: Decodable, Identifiable, Hashable, Sendable {

    let id: String
    let names: [String]
    let image: String
    let imageID: String
    let command: String
    let created: Int
    let state: ContainerState
    /// Human-readable status string, e.g. "Up 2 hours" or "Exited (0) 3 days ago".
    let statusText: String
    let ports: [Port]
    let labels: [String: String]

    enum CodingKeys: String, CodingKey {
        case id       = "Id"
        case names    = "Names"
        case image    = "Image"
        case imageID  = "ImageID"
        case command  = "Command"
        case created  = "Created"
        case state    = "State"
        case statusText = "Status"
        case ports    = "Ports"
        case labels   = "Labels"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self,              forKey: .id)
        names      = try c.decode([String].self,            forKey: .names)
        image      = try c.decode(String.self,              forKey: .image)
        imageID    = try c.decode(String.self,              forKey: .imageID)
        command    = try c.decode(String.self,              forKey: .command)
        created    = try c.decode(Int.self,                 forKey: .created)
        state      = try c.decode(ContainerState.self,      forKey: .state)
        statusText = try c.decode(String.self,              forKey: .statusText)
        ports      = try c.decodeIfPresent([Port].self,     forKey: .ports) ?? []
        labels     = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }

    /// The primary display name — first name without the leading slash, or short ID.
    var displayName: String {
        names.first.map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 } ?? shortID
    }

    /// First 12 characters of the container ID, matching Docker CLI convention.
    var shortID: String { String(id.prefix(12)) }

    // MARK: - Port

    struct Port: Decodable, Hashable, Sendable {
        let ip: String?
        let privatePort: Int
        let publicPort: Int?
        let type: String

        enum CodingKeys: String, CodingKey {
            case ip          = "IP"
            case privatePort = "PrivatePort"
            case publicPort  = "PublicPort"
            case type        = "Type"
        }
    }
}
