import Foundation

/// Full image inspection response from `GET .../images/{id}/json`.
struct DockerImageDetail: Decodable, Sendable {

    let id: String
    let repoTags: [String]
    let repoDigests: [String]
    let parent: String
    let created: String          // ISO-8601 string
    let size: Int64
    let virtualSize: Int64
    let os: String
    let architecture: String
    let author: String
    let config: ImageConfig
    let rootFS: RootFS

    enum CodingKeys: String, CodingKey {
        case id           = "Id"
        case repoTags     = "RepoTags"
        case repoDigests  = "RepoDigests"
        case parent       = "Parent"
        case created      = "Created"
        case size         = "Size"
        case virtualSize  = "VirtualSize"
        case os           = "Os"
        case architecture = "Architecture"
        case author       = "Author"
        case config       = "Config"
        case rootFS       = "RootFS"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self,      forKey: .id)
        repoTags     = try c.decodeIfPresent([String].self, forKey: .repoTags)    ?? []
        repoDigests  = try c.decodeIfPresent([String].self, forKey: .repoDigests) ?? []
        parent       = try c.decodeIfPresent(String.self,   forKey: .parent)      ?? ""
        created      = try c.decodeIfPresent(String.self,   forKey: .created)     ?? ""
        size         = try c.decodeIfPresent(Int64.self,    forKey: .size)        ?? 0
        virtualSize  = try c.decodeIfPresent(Int64.self,    forKey: .virtualSize) ?? 0
        os           = try c.decodeIfPresent(String.self,   forKey: .os)          ?? ""
        architecture = try c.decodeIfPresent(String.self,   forKey: .architecture) ?? ""
        author       = try c.decodeIfPresent(String.self,   forKey: .author)      ?? ""
        config       = try c.decodeIfPresent(ImageConfig.self, forKey: .config)   ?? ImageConfig()
        rootFS       = try c.decodeIfPresent(RootFS.self,   forKey: .rootFS)      ?? RootFS()
    }

    // MARK: - Computed helpers

    /// The short (12-char) image ID with the `sha256:` prefix stripped.
    var shortId: String {
        let stripped = id.hasPrefix("sha256:") ? String(id.dropFirst(7)) : id
        return String(stripped.prefix(12))
    }

    /// Human-readable total size.
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Human-readable virtual size.
    var formattedVirtualSize: String {
        ByteCountFormatter.string(fromByteCount: virtualSize, countStyle: .file)
    }

    /// The creation date parsed from the ISO-8601 string.
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: created)
    }

    // MARK: - Config

    struct ImageConfig: Decodable, Sendable {
        let cmd: [String]
        let entrypoint: [String]
        let env: [String]
        let exposedPorts: [String: [String: String]]
        let labels: [String: String]
        let workingDir: String
        let user: String

        enum CodingKeys: String, CodingKey {
            case cmd          = "Cmd"
            case entrypoint   = "Entrypoint"
            case env          = "Env"
            case exposedPorts = "ExposedPorts"
            case labels       = "Labels"
            case workingDir   = "WorkingDir"
            case user         = "User"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cmd          = try c.decodeIfPresent([String].self,                    forKey: .cmd)          ?? []
            entrypoint   = try c.decodeIfPresent([String].self,                    forKey: .entrypoint)   ?? []
            env          = try c.decodeIfPresent([String].self,                    forKey: .env)          ?? []
            exposedPorts = try c.decodeIfPresent([String: [String: String]].self,  forKey: .exposedPorts) ?? [:]
            labels       = try c.decodeIfPresent([String: String].self,            forKey: .labels)       ?? [:]
            workingDir   = try c.decodeIfPresent(String.self,                      forKey: .workingDir)   ?? ""
            user         = try c.decodeIfPresent(String.self,                      forKey: .user)         ?? ""
        }

        nonisolated init() {
            cmd = []; entrypoint = []; env = []
            exposedPorts = [:]; labels = [:]; workingDir = ""; user = ""
        }
    }

    // MARK: - RootFS

    struct RootFS: Decodable, Sendable {
        let type: String
        let layers: [String]

        enum CodingKeys: String, CodingKey {
            case type   = "Type"
            case layers = "Layers"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type   = try c.decodeIfPresent(String.self,   forKey: .type)   ?? ""
            layers = try c.decodeIfPresent([String].self, forKey: .layers) ?? []
        }

        nonisolated init() { type = ""; layers = [] }
    }
}
