import Foundation
import OSLog

// MARK: - Re-authentication

/// Provides credentials for re-authentication when a 401 is received.
protocol PortainerClientAuthDelegate: AnyObject, Sendable {
    /// Called when the client receives a 401 and needs fresh credentials.
    /// Return new credentials to retry, or `nil` to propagate the 401 as an error.
    func portainerClientNeedsReauthentication(
        _ client: PortainerClient
    ) async -> (username: String, password: String)?
}

// MARK: - PortainerClient

/// Core networking layer for the Portainer CE API.
@Observable
final class PortainerClient: Sendable {

    // MARK: - Properties

    let baseURL: URL
    private let session: URLSession

    private let _token = MutableSendableValue<String?>(nil)
    private let _authDelegate = MutableSendableValue<WeakDelegate?>(nil)
    // Retained so the URLSession delegate is not deallocated.
    private let _sslTrustHandler: MutableSendableValue<SSLTrustHandler?>

    /// The current JWT token, if authenticated.
    var token: String? {
        get { _token.value }
        set { _token.value = newValue }
    }

    /// Delegate that provides credentials for re-authentication on 401.
    weak var authDelegate: PortainerClientAuthDelegate? {
        get { _authDelegate.value?.delegate }
        set { _authDelegate.value = newValue.map { WeakDelegate($0) } }
    }

    // MARK: - Initialization

    /// Creates a client for the given server URL.
    /// - Parameters:
    ///   - serverURL: The base URL of the Portainer server (e.g. `https://portainer.example.com:9443`).
    ///   - trustSelfSigned: When `true`, accepts self-signed / untrusted certificates.
    ///     Only enable this when the user has explicitly opted in for a given server.
    init(serverURL: URL, trustSelfSigned: Bool = false) {
        self.baseURL = serverURL

        // Use ephemeral configuration so URLSession never persists cookies.
        // Portainer sets a `portainer_api_key` cookie on successful auth; if that
        // cookie is stored and replayed, Portainer's CSRF middleware activates and
        // rejects subsequent requests with 403. The app uses JWT bearer tokens
        // exclusively, so cookies serve no purpose here.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        if trustSelfSigned {
            let handler = SSLTrustHandler()
            self._sslTrustHandler = MutableSendableValue(handler)
            self.session = URLSession(configuration: config, delegate: handler, delegateQueue: nil)
        } else {
            self._sslTrustHandler = MutableSendableValue(nil)
            self.session = URLSession(configuration: config)
        }
    }

    /// Convenience initializer from URL components.
    /// - Parameters:
    ///   - scheme: `http` or `https`.
    ///   - host: Server hostname or IP.
    ///   - port: Port number (e.g. 9443).
    ///   - trustSelfSigned: When `true`, accepts self-signed / untrusted certificates.
    convenience init?(scheme: String, host: String, port: Int, trustSelfSigned: Bool = false) {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        guard let url = components.url else { return nil }
        self.init(serverURL: url, trustSelfSigned: trustSelfSigned)
    }

    // MARK: - Authentication

    /// Authenticates with the Portainer server and stores the JWT token.
    /// - Parameters:
    ///   - username: Portainer username.
    ///   - password: Portainer password.
    /// - Returns: The JWT token string.
    @discardableResult
    func authenticate(username: String, password: String) async throws -> String {
        struct AuthRequest: Encodable {
            let username: String
            let password: String
        }

        AppLogger.auth.info("Authenticating user '\(username, privacy: .public)' at \(self.baseURL, privacy: .public)")

        do {
            let response: AuthResponse = try await request(
                method: .post,
                path: "/api/auth",
                body: AuthRequest(username: username, password: password),
                authenticated: false,
                allowRetry: false
            )
            token = response.jwt
            AppLogger.auth.info("Authentication succeeded for '\(username, privacy: .public)'")
            return response.jwt
        } catch {
            AppLogger.auth.error("Authentication failed for '\(username, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - System

    /// Fetches the Portainer system status. Useful for validating connectivity after login.
    @discardableResult
    func systemStatus() async throws -> PortainerSystemStatus {
        try await request(path: "/api/system/status")
    }

    // MARK: - Environments

    /// Returns all environments (endpoints) visible to the authenticated user.
    func endpoints() async throws -> [PortainerEndpoint] {
        try await request(path: "/api/endpoints")
    }

    // MARK: - Containers

    /// Base Docker proxy path for a given endpoint.
    private func dockerBase(endpointId: Int) -> String {
        "/api/endpoints/\(endpointId)/docker"
    }

    /// Lists all containers (running + stopped) for an environment.
    func containers(endpointId: Int) async throws -> [DockerContainer] {
        try await request(path: "\(dockerBase(endpointId: endpointId))/containers/json?all=true")
    }

    /// Returns full inspection data for a single container.
    func containerDetail(id: String, endpointId: Int) async throws -> DockerContainerDetail {
        try await request(path: "\(dockerBase(endpointId: endpointId))/containers/\(id)/json")
    }

    func startContainer(id: String, endpointId: Int) async throws {
        try await requestVoid(method: .post, path: "\(dockerBase(endpointId: endpointId))/containers/\(id)/start")
    }

    func stopContainer(id: String, endpointId: Int) async throws {
        try await requestVoid(method: .post, path: "\(dockerBase(endpointId: endpointId))/containers/\(id)/stop")
    }

    func restartContainer(id: String, endpointId: Int) async throws {
        try await requestVoid(method: .post, path: "\(dockerBase(endpointId: endpointId))/containers/\(id)/restart")
    }

    func killContainer(id: String, endpointId: Int) async throws {
        try await requestVoid(method: .post, path: "\(dockerBase(endpointId: endpointId))/containers/\(id)/kill")
    }

    func removeContainer(id: String, endpointId: Int) async throws {
        try await requestVoid(method: .delete, path: "\(dockerBase(endpointId: endpointId))/containers/\(id)?force=true&v=true")
    }

    // MARK: - Generic Request

    /// Performs an API request and decodes the JSON response.
    /// - Parameters:
    ///   - method: HTTP method.
    ///   - path: API path (e.g. `/api/endpoints`).
    ///   - body: Optional request body (must be `Encodable`).
    ///   - authenticated: Whether to attach the Bearer token. Defaults to `true`.
    ///   - allowRetry: Whether to attempt re-authentication on 401. Defaults to `true`.
    /// - Returns: Decoded response of type `T`.
    func request<T: Decodable>(
        method: HTTPMethod = .get,
        path: String,
        body: (any Encodable & Sendable)? = nil,
        authenticated: Bool = true,
        allowRetry: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            AppLogger.network.error("Invalid URL for path '\(path, privacy: .public)'")
            throw PortainerClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        // Some Portainer deployments (behind a reverse proxy with CSRF checks) reject
        // requests that lack a Referer header. Supply the server's base URL.
        urlRequest.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")

        // Attach Bearer token
        if authenticated, let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        AppLogger.network.debug("\(method.rawValue, privacy: .public) \(url, privacy: .public)")
        #if DEBUG
        AppLogger.network.debug("\(urlRequest.curlDescription, privacy: .public)")
        #endif

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.network.error("\(method.rawValue, privacy: .public) \(url, privacy: .public) → non-HTTP response")
            throw PortainerClientError.httpError(statusCode: -1)
        }

        let statusCode = httpResponse.statusCode
        AppLogger.network.info("\(method.rawValue, privacy: .public) \(url, privacy: .public) → \(statusCode, privacy: .public)")

        // 401 — attempt re-authentication once
        if statusCode == 401, authenticated, allowRetry,
           let delegate = authDelegate,
           let credentials = await delegate.portainerClientNeedsReauthentication(self) {
            AppLogger.auth.info("Received 401 on \(path, privacy: .public) — retrying after re-authentication")
            try await authenticate(username: credentials.username, password: credentials.password)
            return try await request(
                method: method,
                path: path,
                body: body,
                authenticated: true,
                allowRetry: false
            )
        }

        if statusCode == 401 {
            AppLogger.auth.warning("Unauthorized (401) on \(path, privacy: .public) — clearing token")
            token = nil
            throw PortainerClientError.unauthorized
        }

        // Other error responses
        if statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(PortainerAPIError.self, from: data) {
                AppLogger.network.error("API error \(statusCode, privacy: .public) on \(path, privacy: .public): \(apiError.message, privacy: .public)")
                throw PortainerClientError.apiError(statusCode: statusCode, apiError: apiError)
            }
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            AppLogger.network.error("HTTP \(statusCode, privacy: .public) on \(path, privacy: .public): \(body, privacy: .public)")
            throw PortainerClientError.httpError(statusCode: statusCode)
        }

        // Decode success response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            AppLogger.network.error("Decoding failed for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw PortainerClientError.decodingError(error)
        }
    }

    /// Performs an API request that returns no body (e.g. DELETE, 204 responses).
    func requestVoid(
        method: HTTPMethod = .get,
        path: String,
        body: (any Encodable & Sendable)? = nil,
        authenticated: Bool = true,
        allowRetry: Bool = true
    ) async throws {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            AppLogger.network.error("Invalid URL for path '\(path, privacy: .public)'")
            throw PortainerClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")

        if authenticated, let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        AppLogger.network.debug("\(method.rawValue, privacy: .public) \(url, privacy: .public)")
        #if DEBUG
        AppLogger.network.debug("\(urlRequest.curlDescription, privacy: .public)")
        #endif

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.network.error("\(method.rawValue, privacy: .public) \(url, privacy: .public) → non-HTTP response")
            throw PortainerClientError.httpError(statusCode: -1)
        }

        let statusCode = httpResponse.statusCode
        AppLogger.network.info("\(method.rawValue, privacy: .public) \(url, privacy: .public) → \(statusCode, privacy: .public)")

        // 401 — attempt re-authentication once
        if statusCode == 401, authenticated, allowRetry,
           let delegate = authDelegate,
           let credentials = await delegate.portainerClientNeedsReauthentication(self) {
            AppLogger.auth.info("Received 401 on \(path, privacy: .public) — retrying after re-authentication")
            try await authenticate(username: credentials.username, password: credentials.password)
            try await requestVoid(method: method, path: path, body: body, authenticated: true, allowRetry: false)
            return
        }

        if statusCode == 401 {
            AppLogger.auth.warning("Unauthorized (401) on \(path, privacy: .public) — clearing token")
            token = nil
            throw PortainerClientError.unauthorized
        }

        if statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(PortainerAPIError.self, from: data) {
                AppLogger.network.error("API error \(statusCode, privacy: .public) on \(path, privacy: .public): \(apiError.message, privacy: .public)")
                throw PortainerClientError.apiError(statusCode: statusCode, apiError: apiError)
            }
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            AppLogger.network.error("HTTP \(statusCode, privacy: .public) on \(path, privacy: .public): \(body, privacy: .public)")
            throw PortainerClientError.httpError(statusCode: statusCode)
        }
    }
}

// MARK: - Helpers

/// A Sendable wrapper for mutable values used from `@Observable` + `Sendable` context.
private final class MutableSendableValue<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

/// Weak reference wrapper for the auth delegate.
private struct WeakDelegate: Sendable {
    weak var delegate: PortainerClientAuthDelegate?
    init(_ delegate: PortainerClientAuthDelegate) {
        self.delegate = delegate
    }
}

#if DEBUG
// MARK: - cURL debug helper

private extension URLRequest {
    /// Returns a cURL command string reproducing this request.
    ///
    /// Logged at `.debug` level in debug builds so requests can be replayed
    /// directly in a terminal for troubleshooting.
    var curlDescription: String {
        guard let url else { return "curl <missing URL>" }

        var parts = ["curl -v"]
        parts.append("-X \(httpMethod ?? "GET")")

        for (field, value) in (allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            // Redact the Bearer token so the log is safe to share.
            let safeValue = field.lowercased() == "authorization" ? "<redacted>" : value
            parts.append("-H \"\(field): \(safeValue)\"")
        }

        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8) {
            // Escape single quotes inside the body so the shell command stays valid.
            let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("--data '\(escaped)'")
        }

        parts.append("\"\(url.absoluteString)\"")
        return parts.joined(separator: " \\\n  ")
    }
}
#endif


