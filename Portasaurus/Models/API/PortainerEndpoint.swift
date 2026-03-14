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
        let volumeCount:             Int
        let imageCount:              Int
        let stackCount:              Int
        let totalCPU:                Int
        let totalMemory:             Int64
        let dockerVersion:           String?
        let time:                    Int64?
        /// Network count derived from the raw snapshot Networks array.
        /// The top-level snapshot summary has no dedicated NetworkCount field.
        let networkCount:            Int

        enum CodingKeys: String, CodingKey {
            case runningContainerCount   = "RunningContainerCount"
            case stoppedContainerCount   = "StoppedContainerCount"
            case healthyContainerCount   = "HealthyContainerCount"
            case unhealthyContainerCount = "UnhealthyContainerCount"
            case volumeCount             = "VolumeCount"
            case imageCount              = "ImageCount"
            case stackCount              = "StackCount"
            case totalCPU                = "TotalCPU"
            case totalMemory             = "TotalMemory"
            case dockerVersion           = "DockerVersion"
            case time                    = "Time"
            case rawSnapshot             = "DockerSnapshotRaw"
        }

        /// Minimal decode of the raw snapshot block — only the Networks count is needed.
        private struct RawSnapshot: Decodable, Sendable {
            let networkCount: Int
            private enum RawKeys: String, CodingKey { case networks = "Networks" }
            // Each network object can have arbitrary fields; we only need the array length.
            private struct AnyNetwork: Decodable, Sendable {}
            nonisolated init(from decoder: any Decoder) throws {
                let c = try decoder.container(keyedBy: RawKeys.self)
                let networks = try c.decodeIfPresent([AnyNetwork].self, forKey: .networks) ?? []
                networkCount = networks.count
            }
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            runningContainerCount   = try c.decodeIfPresent(Int.self,    forKey: .runningContainerCount)   ?? 0
            stoppedContainerCount   = try c.decodeIfPresent(Int.self,    forKey: .stoppedContainerCount)   ?? 0
            healthyContainerCount   = try c.decodeIfPresent(Int.self,    forKey: .healthyContainerCount)   ?? 0
            unhealthyContainerCount = try c.decodeIfPresent(Int.self,    forKey: .unhealthyContainerCount) ?? 0
            volumeCount             = try c.decodeIfPresent(Int.self,    forKey: .volumeCount)             ?? 0
            imageCount              = try c.decodeIfPresent(Int.self,    forKey: .imageCount)              ?? 0
            stackCount              = try c.decodeIfPresent(Int.self,    forKey: .stackCount)              ?? 0
            totalCPU                = try c.decodeIfPresent(Int.self,    forKey: .totalCPU)                ?? 0
            totalMemory             = try c.decodeIfPresent(Int64.self,  forKey: .totalMemory)             ?? 0
            dockerVersion           = try c.decodeIfPresent(String.self, forKey: .dockerVersion)
            time                    = try c.decodeIfPresent(Int64.self,  forKey: .time)
            let raw                 = try c.decodeIfPresent(RawSnapshot.self, forKey: .rawSnapshot)
            networkCount            = raw?.networkCount ?? 0
        }

        /// The snapshot timestamp as a `Date`, or `nil` if absent.
        var date: Date? {
            guard let time else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(time))
        }

        var totalContainerCount: Int { runningContainerCount + stoppedContainerCount }

        /// Formats `totalMemory` (bytes) as a compact human-readable string, e.g. "23.6 GB".
        var formattedMemory: String {
            let bytes = Double(totalMemory)
            let gb = bytes / 1_073_741_824
            if gb >= 1 {
                return String(format: "%.1f GB", gb)
            }
            let mb = bytes / 1_048_576
            return String(format: "%.0f MB", mb)
        }
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
