import Foundation

/// Response from `POST /api/auth`.
struct AuthResponse: Decodable, Sendable {
    let jwt: String
}
