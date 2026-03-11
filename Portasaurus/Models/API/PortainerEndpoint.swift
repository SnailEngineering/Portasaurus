import Foundation

/// A Portainer environment (endpoint) — the Docker host to manage.
struct PortainerEndpoint: Decodable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    let id: Int
    let name: String
    let type: EndpointType
    let status: EndpointStatus
    let url: String
    let publicURL: String
    let snapshots: [DockerSnapshot]

    enum CodingKeys: String, CodingKey {
        case id        = "Id"
        case name      = "Name"
        case type      = "Type"
        case status    = "Status"
        case url       = "URL"
        case publicURL = "PublicURL"
        case snapshots = "Snapshots"
    }

    // MARK: - Nested Types

    /// Docker environment type reported by Portainer.
    enum EndpointType: Int, Decodable, Sendable {
        case dockerStandalone = 1
        case dockerAgent      = 2
        case azure            = 3
        case edgeAgent        = 4
        case kubernetes       = 5
        case kubeConfig       = 6

        /// Falls back to `dockerStandalone` for unrecognised values.
        nonisolated init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(Int.self)
            self = EndpointType(rawValue: raw) ?? .dockerStandalone
        }

        var displayName: String {
            switch self {
            case .dockerStandalone: "Docker"
            case .dockerAgent:      "Docker Agent"
            case .azure:            "Azure ACI"
            case .edgeAgent:        "Edge Agent"
            case .kubernetes:       "Kubernetes"
            case .kubeConfig:       "KubeConfig"
            }
        }

        var systemImage: String {
            switch self {
            case .dockerStandalone, .dockerAgent, .edgeAgent: "shippingbox"
            case .kubernetes, .kubeConfig:                    "helm"
            case .azure:                                      "cloud"
            }
        }
    }

    /// Connectivity status reported by Portainer.
    enum EndpointStatus: Int, Decodable, Sendable {
        case up   = 1
        case down = 2

        nonisolated init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(Int.self)
            self = EndpointStatus(rawValue: raw) ?? .down
        }
    }

    /// Container/health summary captured in Portainer's environment snapshot.
    struct DockerSnapshot: Decodable, Hashable, Sendable {
        let runningContainerCount:   Int
        let stoppedContainerCount:   Int
        let healthyContainerCount:   Int
        let unhealthyContainerCount: Int
        let dockerVersion:           String?

        enum CodingKeys: String, CodingKey {
            case runningContainerCount   = "RunningContainerCount"
            case stoppedContainerCount   = "StoppedContainerCount"
            case healthyContainerCount   = "HealthyContainerCount"
            case unhealthyContainerCount = "UnhealthyContainerCount"
            case dockerVersion           = "DockerVersion"
        }

        var totalContainerCount: Int { runningContainerCount + stoppedContainerCount }
    }

    // MARK: - Convenience

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(Int.self,          forKey: .id)
        name      = try c.decode(String.self,       forKey: .name)
        type      = try c.decode(EndpointType.self, forKey: .type)
        status    = try c.decode(EndpointStatus.self, forKey: .status)
        url       = try c.decode(String.self,       forKey: .url)
        publicURL = try c.decodeIfPresent(String.self, forKey: .publicURL) ?? ""
        snapshots = try c.decodeIfPresent([DockerSnapshot].self, forKey: .snapshots) ?? []
    }

    /// Most-recent snapshot summary, or `nil` if Portainer hasn't snapshotted yet.
    var snapshot: DockerSnapshot? { snapshots.first }
}
