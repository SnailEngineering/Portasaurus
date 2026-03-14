import Foundation

/// A Portainer-managed container registry.
///
/// Registries are global Portainer resources — not scoped to a specific environment.
/// Sensitive credential fields (password, access tokens) are intentionally omitted
/// from this model and are never displayed in the UI.
struct PortainerRegistry: Decodable, Identifiable, Hashable, Sendable {

    // MARK: - Registry type

    enum RegistryType: Int, Decodable, Sendable {
        case quay      = 1
        case azure     = 2
        case custom    = 3
        case gitlab    = 4
        case proget    = 5
        case dockerHub = 6
        case ecr       = 7
        case github    = 8
        case unknown   = 0
    }

    // MARK: - Nested types

    struct GitlabData: Decodable, Hashable, Sendable {
        let projectId: Int
        let instanceURL: String
        let projectPath: String

        private enum CodingKeys: String, CodingKey {
            case projectId   = "ProjectId"
            case instanceURL = "InstanceURL"
            case projectPath = "ProjectPath"
        }

        nonisolated init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            projectId   = (try? c.decodeIfPresent(Int.self,    forKey: .projectId))   ?? 0
            instanceURL = (try? c.decodeIfPresent(String.self, forKey: .instanceURL)) ?? ""
            projectPath = (try? c.decodeIfPresent(String.self, forKey: .projectPath)) ?? ""
        }
    }

    struct EcrData: Decodable, Hashable, Sendable {
        let region: String

        private enum CodingKeys: String, CodingKey {
            case region = "Region"
        }

        nonisolated init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            region = (try? c.decodeIfPresent(String.self, forKey: .region)) ?? ""
        }
    }

    // MARK: - Properties

    let id: Int
    let name: String
    let type: RegistryType
    let url: String
    let baseURL: String
    let authentication: Bool
    let username: String
    let gitlab: GitlabData
    let ecr: EcrData

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id             = "Id"
        case name           = "Name"
        case type           = "Type"
        case url            = "URL"
        case baseURL        = "BaseURL"
        case authentication = "Authentication"
        case username       = "Username"
        case gitlab         = "Gitlab"
        case ecr            = "Ecr"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = (try? c.decodeIfPresent(Int.self,          forKey: .id))             ?? 0
        name           = (try? c.decodeIfPresent(String.self,       forKey: .name))           ?? ""
        type           = (try? c.decodeIfPresent(RegistryType.self, forKey: .type))           ?? .unknown
        url            = (try? c.decodeIfPresent(String.self,       forKey: .url))            ?? ""
        baseURL        = (try? c.decodeIfPresent(String.self,       forKey: .baseURL))        ?? ""
        authentication = (try? c.decodeIfPresent(Bool.self,         forKey: .authentication)) ?? false
        username       = (try? c.decodeIfPresent(String.self,       forKey: .username))       ?? ""
        gitlab         = (try? c.decodeIfPresent(GitlabData.self,   forKey: .gitlab))         ?? GitlabData(projectId: 0, instanceURL: "", projectPath: "")
        ecr            = (try? c.decodeIfPresent(EcrData.self,      forKey: .ecr))            ?? EcrData(region: "")
    }

    // MARK: - Computed helpers

    /// Human-readable registry type label.
    var typeName: String {
        switch type {
        case .quay:      return "Quay.io"
        case .azure:     return "Azure Container Registry"
        case .custom:    return "Custom Registry"
        case .gitlab:    return "GitLab Registry"
        case .proget:    return "ProGet"
        case .dockerHub: return "Docker Hub"
        case .ecr:       return "AWS ECR"
        case .github:    return "GitHub Container Registry"
        case .unknown:   return "Registry"
        }
    }

    /// SF Symbol name for the registry type.
    var typeIcon: String {
        switch type {
        case .dockerHub: return "cube.box.fill"
        case .ecr:       return "cloud.fill"
        case .azure:     return "cloud.fill"
        case .gitlab:    return "chevron.left.forwardslash.chevron.right"
        case .github:    return "chevron.left.forwardslash.chevron.right"
        case .quay:      return "externaldrive.connected.to.line.below.fill"
        case .proget:    return "externaldrive.connected.to.line.below.fill"
        case .custom,
             .unknown:   return "externaldrive.connected.to.line.below.fill"
        }
    }

    /// URL with protocol prefix stripped for compact display.
    var displayURL: String {
        var result = url
        for prefix in ["https://", "http://"] {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        return result
    }
}

// MARK: - Memberwise inits (used in decoder defaults)

private extension PortainerRegistry.GitlabData {
    nonisolated init(projectId: Int, instanceURL: String, projectPath: String) {
        self.projectId   = projectId
        self.instanceURL = instanceURL
        self.projectPath = projectPath
    }
}

private extension PortainerRegistry.EcrData {
    nonisolated init(region: String) {
        self.region = region
    }
}
