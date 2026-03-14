import Foundation

/// Represents a Docker image returned by `GET .../images/json`.
struct DockerImage: Decodable, Identifiable, Hashable, Sendable {

    let id: String
    let parentId: String
    let repoTags: [String]
    let repoDigests: [String]
    let created: Int         // Unix timestamp
    let size: Int64
    let virtualSize: Int64
    let sharedSize: Int64
    let labels: [String: String]
    let containers: Int

    enum CodingKeys: String, CodingKey {
        case id           = "Id"
        case parentId     = "ParentId"
        case repoTags     = "RepoTags"
        case repoDigests  = "RepoDigests"
        case created      = "Created"
        case size         = "Size"
        case virtualSize  = "VirtualSize"
        case sharedSize   = "SharedSize"
        case labels       = "Labels"
        case containers   = "Containers"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,           forKey: .id)
        parentId    = try c.decodeIfPresent(String.self,  forKey: .parentId)     ?? ""
        repoTags    = try c.decodeIfPresent([String].self, forKey: .repoTags)    ?? []
        repoDigests = try c.decodeIfPresent([String].self, forKey: .repoDigests) ?? []
        created     = try c.decodeIfPresent(Int.self,     forKey: .created)      ?? 0
        size        = try c.decodeIfPresent(Int64.self,   forKey: .size)         ?? 0
        virtualSize = try c.decodeIfPresent(Int64.self,   forKey: .virtualSize)  ?? 0
        sharedSize  = try c.decodeIfPresent(Int64.self,   forKey: .sharedSize)   ?? 0
        labels      = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        containers  = try c.decodeIfPresent(Int.self,     forKey: .containers)   ?? 0
    }

    // MARK: - Computed helpers

    /// The primary display name: first repo tag, or the short image ID if untagged.
    var displayName: String {
        repoTags.first ?? shortId
    }

    /// The short (12-char) image ID with the `sha256:` prefix stripped.
    var shortId: String {
        let stripped = id.hasPrefix("sha256:") ? String(id.dropFirst(7)) : id
        return String(stripped.prefix(12))
    }

    /// Creation date as a `Date`.
    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(created)) }

    /// `true` when no repo tags are assigned (a "dangling" image).
    var isDangling: Bool { repoTags.isEmpty }

    /// Human-readable size string using binary byte count formatting.
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Image prune response

/// Response from `POST .../images/prune`.
struct ImagePruneResponse: Decodable, Sendable {
    let spaceReclaimed: Int64

    enum CodingKeys: String, CodingKey {
        case spaceReclaimed = "SpaceReclaimed"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spaceReclaimed = try c.decodeIfPresent(Int64.self, forKey: .spaceReclaimed) ?? 0
    }

    var formattedSpaceReclaimed: String {
        ByteCountFormatter.string(fromByteCount: spaceReclaimed, countStyle: .file)
    }
}
