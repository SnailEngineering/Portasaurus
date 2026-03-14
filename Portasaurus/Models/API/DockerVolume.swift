import Foundation

/// Represents a Docker volume returned by `GET .../volumes`.
struct DockerVolume: Decodable, Identifiable, Hashable, Sendable {

    let name: String
    let driver: String
    let mountpoint: String
    let scope: String
    let labels: [String: String]
    let options: [String: String]
    let createdAt: String
    let usageData: UsageData?

    /// Docker volumes use `Name` as the stable identifier.
    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name       = "Name"
        case driver     = "Driver"
        case mountpoint = "Mountpoint"
        case scope      = "Scope"
        case labels     = "Labels"
        case options    = "Options"
        case createdAt  = "CreatedAt"
        case usageData  = "UsageData"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name        = try c.decode(String.self, forKey: .name)
        driver      = try c.decodeIfPresent(String.self, forKey: .driver)      ?? "local"
        mountpoint  = try c.decodeIfPresent(String.self, forKey: .mountpoint)  ?? ""
        scope       = try c.decodeIfPresent(String.self, forKey: .scope)       ?? "local"
        labels      = try c.decodeIfPresent([String: String].self, forKey: .labels)  ?? [:]
        options     = try c.decodeIfPresent([String: String].self, forKey: .options) ?? [:]
        createdAt   = try c.decodeIfPresent(String.self, forKey: .createdAt)   ?? ""
        usageData   = try c.decodeIfPresent(UsageData.self, forKey: .usageData)
    }

    // MARK: - Nested types

    /// Usage data returned when volume detail is fetched (requires `GET .../volumes/{name}`)
    struct UsageData: Decodable, Hashable, Sendable {
        /// Number of containers referencing this volume. -1 means unavailable.
        let refCount: Int
        /// Disk space used in bytes. -1 means unavailable.
        let size: Int64

        enum CodingKeys: String, CodingKey {
            case refCount = "RefCount"
            case size     = "Size"
        }

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            refCount = try c.decodeIfPresent(Int.self,   forKey: .refCount) ?? -1
            size     = try c.decodeIfPresent(Int64.self, forKey: .size)     ?? -1
        }
    }

    // MARK: - Computed helpers

    /// `true` when the volume has at least one container referencing it.
    var isInUse: Bool {
        guard let usage = usageData, usage.refCount > 0 else { return false }
        return true
    }

    /// Human-readable size string. Returns `nil` when size is unavailable (-1).
    var formattedSize: String? {
        guard let usage = usageData, usage.size >= 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: usage.size, countStyle: .file)
    }

    /// The creation date parsed from the ISO 8601 `CreatedAt` string.
    var createdDate: Date? {
        guard !createdAt.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }
}

// MARK: - Volume list response

/// Response from `GET .../volumes`.
struct DockerVolumeListResponse: Decodable, Sendable {
    let volumes: [DockerVolume]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case volumes  = "Volumes"
        case warnings = "Warnings"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volumes  = try c.decodeIfPresent([DockerVolume].self, forKey: .volumes)  ?? []
        warnings = try c.decodeIfPresent([String].self,       forKey: .warnings) ?? []
    }
}
