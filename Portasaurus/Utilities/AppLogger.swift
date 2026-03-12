import OSLog

/// Centralised logging using OSLog structured logging.
///
/// Usage:
/// ```swift
/// AppLogger.network.info("GET /api/endpoints → 200")
/// AppLogger.auth.error("Authentication failed: \(error.localizedDescription)")
/// ```
///
/// Logs are visible in Console.app filtered by subsystem `com.snailengineering.swift.Portasaurus`.
enum AppLogger {
    private static let subsystem = "com.snailengineering.swift.Portasaurus"

    /// HTTP requests, responses, retries.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Authentication, token lifecycle.
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// Keychain read/write/delete operations.
    static let keychain = Logger(subsystem: subsystem, category: "keychain")

    /// SwiftData persistence operations.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// ViewModel state changes and user-initiated actions.
    static let viewModel = Logger(subsystem: subsystem, category: "viewModel")
}
