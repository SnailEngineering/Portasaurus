import Foundation

/// A Portainer-managed Docker Compose or Swarm stack.
///
/// Returned by `GET /api/stacks` and `GET /api/stacks/{id}`.
struct PortainerStack: Decodable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    let id: Int
    let name: String
    let type: StackType
    let endpointId: Int
    let status: StackStatus
    /// Environment variables injected into the stack at deploy time.
    let env: [EnvPair]
    /// Additional compose files (multi-file deployments).
    let additionalFiles: [String]

    enum CodingKeys: String, CodingKey {
        case id             = "Id"
        case name           = "Name"
        case type           = "Type"
        case endpointId     = "EndpointId"
        case status         = "Status"
        case env            = "Env"
        case additionalFiles = "AdditionalFiles"
    }

    // MARK: - Nested Types

    /// Stack technology type reported by Portainer.
    enum StackType: Int, Decodable, Sendable {
        case dockerSwarm   = 1
        case dockerCompose = 2
        case kubernetes    = 3

        /// Falls back to `dockerCompose` for unrecognised values.
        nonisolated init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(Int.self)
            self = StackType(rawValue: raw) ?? .dockerCompose
        }

        var displayName: String {
            switch self {
            case .dockerSwarm:   "Swarm"
            case .dockerCompose: "Compose"
            case .kubernetes:    "Kubernetes"
            }
        }

        var systemImage: String {
            switch self {
            case .dockerSwarm:   "square.stack.3d.up.fill"
            case .dockerCompose: "square.stack.3d.up"
            case .kubernetes:    "helm"
            }
        }
    }

    /// Stack activity status reported by Portainer.
    enum StackStatus: Int, Decodable, Sendable {
        case active   = 1
        case inactive = 2

        /// Falls back to `inactive` for unrecognised values.
        nonisolated init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(Int.self)
            self = StackStatus(rawValue: raw) ?? .inactive
        }

        var displayName: String {
            switch self {
            case .active:   "Active"
            case .inactive: "Inactive"
            }
        }

        var isActive: Bool { self == .active }
    }

    /// A name=value environment variable pair in the stack's configuration.
    struct EnvPair: Decodable, Hashable, Sendable {
        let name: String
        let value: String

        enum CodingKeys: String, CodingKey {
            case name  = "name"
            case value = "value"
        }
    }

    // MARK: - Custom Decoder

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self,        forKey: .id)
        name            = try c.decode(String.self,     forKey: .name)
        type            = try c.decode(StackType.self,  forKey: .type)
        endpointId      = try c.decode(Int.self,        forKey: .endpointId)
        status          = try c.decode(StackStatus.self, forKey: .status)
        env             = try c.decodeIfPresent([EnvPair].self,  forKey: .env) ?? []
        additionalFiles = try c.decodeIfPresent([String].self,   forKey: .additionalFiles) ?? []
    }
}

// MARK: - Stack File Response

/// Response from `GET /api/stacks/{id}/file`.
struct PortainerStackFile: Decodable, Sendable {
    let stackFileContent: String

    enum CodingKeys: String, CodingKey {
        case stackFileContent = "StackFileContent"
    }
}
