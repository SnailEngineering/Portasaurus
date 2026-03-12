import Foundation

/// Full container inspection response from `GET .../containers/{id}/json`.
struct DockerContainerDetail: Decodable, Identifiable, Sendable {

    let id: String
    let name: String
    let created: String
    let state: ContainerDetailState
    let config: Config
    let hostConfig: HostConfig
    let mounts: [Mount]
    let networkSettings: NetworkSettings

    enum CodingKeys: String, CodingKey {
        case id             = "Id"
        case name           = "Name"
        case created        = "Created"
        case state          = "State"
        case config         = "Config"
        case hostConfig     = "HostConfig"
        case mounts         = "Mounts"
        case networkSettings = "NetworkSettings"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self,              forKey: .id)
        name            = try c.decode(String.self,             forKey: .name)
        created         = try c.decode(String.self,             forKey: .created)
        state           = try c.decode(ContainerDetailState.self, forKey: .state)
        config          = try c.decode(Config.self,             forKey: .config)
        hostConfig      = try c.decode(HostConfig.self,         forKey: .hostConfig)
        mounts          = try c.decodeIfPresent([Mount].self,   forKey: .mounts) ?? []
        networkSettings = try c.decode(NetworkSettings.self,    forKey: .networkSettings)
    }

    /// Display name without the leading slash Docker adds.
    var displayName: String {
        name.hasPrefix("/") ? String(name.dropFirst()) : name
    }

    // MARK: - State

    struct ContainerDetailState: Decodable, Sendable {
        let containerState: ContainerState
        let running: Bool
        let paused: Bool
        let restarting: Bool
        let oomKilled: Bool
        let dead: Bool
        let pid: Int
        let exitCode: Int
        let error: String
        let startedAt: String
        let finishedAt: String

        enum CodingKeys: String, CodingKey {
            case containerState = "Status"
            case running     = "Running"
            case paused      = "Paused"
            case restarting  = "Restarting"
            case oomKilled   = "OOMKilled"
            case dead        = "Dead"
            case pid         = "Pid"
            case exitCode    = "ExitCode"
            case error       = "Error"
            case startedAt   = "StartedAt"
            case finishedAt  = "FinishedAt"
        }
    }

    // MARK: - Config

    struct Config: Decodable, Sendable {
        let image: String
        let cmd: [String]?
        let entrypoint: [String]?
        let workingDir: String
        let user: String
        let env: [String]?
        let labels: [String: String]?

        enum CodingKeys: String, CodingKey {
            case image      = "Image"
            case cmd        = "Cmd"
            case entrypoint = "Entrypoint"
            case workingDir = "WorkingDir"
            case user       = "User"
            case env        = "Env"
            case labels     = "Labels"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            image      = try c.decode(String.self,              forKey: .image)
            cmd        = try c.decodeIfPresent([String].self,   forKey: .cmd)
            workingDir = try c.decodeIfPresent(String.self,     forKey: .workingDir) ?? ""
            user       = try c.decodeIfPresent(String.self,     forKey: .user) ?? ""
            env        = try c.decodeIfPresent([String].self,   forKey: .env)
            labels     = try c.decodeIfPresent([String: String].self, forKey: .labels)

            // Entrypoint can arrive as null, a string array, or occasionally a single string.
            if let arr = try? c.decodeIfPresent([String].self, forKey: .entrypoint) {
                entrypoint = arr
            } else if let single = try? c.decodeIfPresent(String.self, forKey: .entrypoint) {
                entrypoint = [single]
            } else {
                entrypoint = nil
            }
        }
    }

    // MARK: - HostConfig

    struct HostConfig: Decodable, Sendable {
        /// Memory limit in bytes; 0 means unlimited.
        let memory: Int64
        let nanoCpus: Int64
        let restartPolicy: RestartPolicy

        enum CodingKeys: String, CodingKey {
            case memory       = "Memory"
            case nanoCpus     = "NanoCpus"
            case restartPolicy = "RestartPolicy"
        }

        struct RestartPolicy: Decodable, Sendable {
            let name: String
            let maximumRetryCount: Int

            enum CodingKeys: String, CodingKey {
                case name              = "Name"
                case maximumRetryCount = "MaximumRetryCount"
            }
        }

        var cpuCount: Double { Double(nanoCpus) / 1_000_000_000 }
        var memoryMB: Int64? { memory > 0 ? memory / (1024 * 1024) : nil }
    }

    // MARK: - Mount

    struct Mount: Decodable, Hashable, Sendable {
        let type: String
        let source: String
        let destination: String
        let mode: String
        let rw: Bool

        enum CodingKeys: String, CodingKey {
            case type        = "Type"
            case source      = "Source"
            case destination = "Destination"
            case mode        = "Mode"
            case rw          = "RW"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type        = try c.decodeIfPresent(String.self, forKey: .type) ?? "bind"
            source      = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
            destination = try c.decode(String.self,          forKey: .destination)
            mode        = try c.decodeIfPresent(String.self, forKey: .mode) ?? ""
            rw          = try c.decodeIfPresent(Bool.self,   forKey: .rw) ?? true
        }
    }

    // MARK: - NetworkSettings

    struct NetworkSettings: Decodable, Sendable {
        /// Exposed port bindings keyed by "port/proto", e.g. "80/tcp".
        let ports: [String: [PortBinding]?]
        let networks: [String: NetworkInfo]

        enum CodingKeys: String, CodingKey {
            case ports    = "Ports"
            case networks = "Networks"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            ports    = try c.decodeIfPresent([String: [PortBinding]?].self, forKey: .ports) ?? [:]
            networks = try c.decodeIfPresent([String: NetworkInfo].self, forKey: .networks) ?? [:]
        }

        struct PortBinding: Decodable, Sendable {
            let hostIP: String
            let hostPort: String

            enum CodingKeys: String, CodingKey {
                case hostIP   = "HostIp"
                case hostPort = "HostPort"
            }
        }

        struct NetworkInfo: Decodable, Sendable {
            let ipAddress: String
            let gateway: String
            let macAddress: String

            enum CodingKeys: String, CodingKey {
                case ipAddress  = "IPAddress"
                case gateway    = "Gateway"
                case macAddress = "MacAddress"
            }

            nonisolated init(from decoder: any Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                ipAddress  = try c.decodeIfPresent(String.self, forKey: .ipAddress) ?? ""
                gateway    = try c.decodeIfPresent(String.self, forKey: .gateway) ?? ""
                macAddress = try c.decodeIfPresent(String.self, forKey: .macAddress) ?? ""
            }
        }
    }
}
