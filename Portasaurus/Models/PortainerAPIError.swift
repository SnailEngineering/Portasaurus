import Foundation

/// Error response body returned by Portainer API.
struct PortainerAPIError: Decodable, Sendable {
    let message: String
    let details: String?
}
