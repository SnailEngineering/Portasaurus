import Foundation

/// Represents a Docker network returned by `GET .../networks`.
struct DockerNetwork: Decodable, Identifiable, Hashable, Sendable {

    let id: String
    let name: String
    let driver: String
    let scope: String
    let isInternal: Bool
    let isAttachable: Bool
    let enableIPv6: Bool
    let created: String
    let labels: [String: String]
    let options: [String: String]
    /// Map of container ID → endpoint info for containers attached to this network.
    let containers: [String: ContainerEndpoint]
    /// IPAM configuration (subnets, gateways).
    let ipam: IPAM

    enum CodingKeys: String, CodingKey {
        case id          = "Id"
        case name        = "Name"
        case driver      = "Driver"
        case scope       = "Scope"
        case isInternal  = "Internal"
        case isAttachable = "Attachable"
        case enableIPv6  = "EnableIPv6"
        case created     = "Created"
        case labels      = "Labels"
        case options     = "Options"
        case containers  = "Containers"
        case ipam        = "IPAM"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        name         = try c.decodeIfPresent(String.self, forKey: .name)        ?? ""
        driver       = try c.decodeIfPresent(String.self, forKey: .driver)      ?? "bridge"
        scope        = try c.decodeIfPresent(String.self, forKey: .scope)       ?? "local"
        isInternal   = try c.decodeIfPresent(Bool.self,   forKey: .isInternal)  ?? false
        isAttachable = try c.decodeIfPresent(Bool.self,   forKey: .isAttachable) ?? false
        enableIPv6   = try c.decodeIfPresent(Bool.self,   forKey: .enableIPv6)  ?? false
        created      = try c.decodeIfPresent(String.self, forKey: .created)     ?? ""
        labels       = try c.decodeIfPresent([String: String].self, forKey: .labels)   ?? [:]
        options      = try c.decodeIfPresent([String: String].self, forKey: .options)  ?? [:]
        containers   = try c.decodeIfPresent([String: ContainerEndpoint].self, forKey: .containers) ?? [:]
        ipam         = try c.decodeIfPresent(IPAM.self, forKey: .ipam) ?? IPAM()
    }

    // MARK: - Nested types

    /// Per-container endpoint information within a network.
    struct ContainerEndpoint: Decodable, Hashable, Sendable {
        let name: String
        let endpointID: String
        let macAddress: String
        let ipv4Address: String
        let ipv6Address: String

        enum CodingKeys: String, CodingKey {
            case name         = "Name"
            case endpointID   = "EndpointID"
            case macAddress   = "MacAddress"
            case ipv4Address  = "IPv4Address"
            case ipv6Address  = "IPv6Address"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name        = try c.decodeIfPresent(String.self, forKey: .name)        ?? ""
            endpointID  = try c.decodeIfPresent(String.self, forKey: .endpointID)  ?? ""
            macAddress  = try c.decodeIfPresent(String.self, forKey: .macAddress)  ?? ""
            ipv4Address = try c.decodeIfPresent(String.self, forKey: .ipv4Address) ?? ""
            ipv6Address = try c.decodeIfPresent(String.self, forKey: .ipv6Address) ?? ""
        }
    }

    /// IPAM (IP Address Management) configuration block.
    struct IPAM: Decodable, Hashable, Sendable {
        let driver: String
        let config: [IPAMConfig]

        enum CodingKeys: String, CodingKey {
            case driver = "Driver"
            case config = "Config"
        }

        init() {
            driver = "default"
            config = []
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            driver = try c.decodeIfPresent(String.self,      forKey: .driver) ?? "default"
            config = try c.decodeIfPresent([IPAMConfig].self, forKey: .config) ?? []
        }
    }

    /// A single IPAM subnet/gateway block.
    struct IPAMConfig: Decodable, Hashable, Sendable {
        let subnet: String
        let gateway: String

        enum CodingKeys: String, CodingKey {
            case subnet  = "Subnet"
            case gateway = "Gateway"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            subnet  = try c.decodeIfPresent(String.self, forKey: .subnet)  ?? ""
            gateway = try c.decodeIfPresent(String.self, forKey: .gateway) ?? ""
        }
    }

    // MARK: - Computed helpers

    /// `true` for the three built-in Docker networks that should never be deleted.
    var isBuiltIn: Bool {
        name == "bridge" || name == "host" || name == "none"
    }

    /// Number of containers connected to this network.
    var containerCount: Int { containers.count }

    /// The first subnet string from IPAM config, or nil.
    var subnet: String? {
        guard let s = ipam.config.first?.subnet, !s.isEmpty else { return nil }
        return s
    }

    /// The first gateway string from IPAM config, or nil.
    var gateway: String? {
        guard let g = ipam.config.first?.gateway, !g.isEmpty else { return nil }
        return g
    }

    /// The creation date parsed from the ISO 8601 `Created` string.
    var createdDate: Date? {
        guard !created.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: created) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: created)
    }
}
