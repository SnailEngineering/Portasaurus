import Foundation

/// Errors that can occur during Portainer API operations.
enum PortainerClientError: LocalizedError {
    case invalidURL
    case unauthorized
    case apiError(statusCode: Int, apiError: PortainerAPIError)
    case httpError(statusCode: Int)
    case decodingError(DecodingError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL."
        case .unauthorized:
            "Authentication required. Please log in again."
        case .apiError(let statusCode, let apiError):
            "Server error (\(statusCode)): \(apiError.message)"
        case .httpError(let statusCode):
            "Unexpected HTTP response (\(statusCode))."
        case .decodingError(let error):
            "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
