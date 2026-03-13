import Foundation

/// Errors that can occur during Portainer API operations.
enum PortainerClientError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case apiError(statusCode: Int, apiError: PortainerAPIError)
    case httpError(statusCode: Int)
    case decodingError(DecodingError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL."
        case .unauthorized:
            "Authentication required. Please log in again."
        case .forbidden:
            "Permission denied. This action requires Administrator access in Portainer."
        case .apiError(let statusCode, let apiError):
            "Server error (\(statusCode)): \(apiError.message)"
        case .httpError(let statusCode):
            "Unexpected HTTP response (\(statusCode))."
        case .decodingError(let error):
            "Failed to decode response: \(error.detailedDescription)"
        }
    }
}

private extension DecodingError {
    /// Returns a human-readable description that includes the key path where decoding failed.
    var detailedDescription: String {
        switch self {
        case .keyNotFound(let key, let ctx):
            "Key '\(key.stringValue)' not found at \(ctx.codingPathString). \(ctx.debugDescription)"
        case .typeMismatch(let type, let ctx):
            "Type mismatch for \(type) at \(ctx.codingPathString). \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            "Value of type \(type) not found at \(ctx.codingPathString). \(ctx.debugDescription)"
        case .dataCorrupted(let ctx):
            "Data corrupted at \(ctx.codingPathString). \(ctx.debugDescription)"
        @unknown default:
            localizedDescription
        }
    }
}

private extension DecodingError.Context {
    var codingPathString: String {
        codingPath.isEmpty ? "root" : codingPath.map(\.stringValue).joined(separator: ".")
    }
}
