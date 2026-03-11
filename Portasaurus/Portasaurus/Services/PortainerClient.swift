import Foundation
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
    /// - Parameter serverURL: The base URL of the Portainer server (e.g. `https://portainer.example.com:9443`).
    init(serverURL: URL) {
        self.baseURL = serverURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// Convenience initializer from URL components.
    /// - Parameters:
    ///   - scheme: `http` or `https`.
    ///   - host: Server hostname or IP.
    ///   - port: Port number (e.g. 9443).
    convenience init?(scheme: String, host: String, port: Int) {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        guard let url = components.url else { return nil }
        self.init(serverURL: url)
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

        let response: AuthResponse = try await request(
            method: .post,
            path: "/api/auth",
            body: AuthRequest(username: username, password: password),
            authenticated: false,
            allowRetry: false
        )

        token = response.jwt
        return response.jwt
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
        let url = baseURL.appendingPathComponent(path)
        guard url.scheme != nil else { throw PortainerClientError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Attach Bearer token
        if authenticated, let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PortainerClientError.httpError(statusCode: -1)
        }

        let statusCode = httpResponse.statusCode

        // 401 — attempt re-authentication once
        if statusCode == 401, authenticated, allowRetry,
           let delegate = authDelegate,
           let credentials = await delegate.portainerClientNeedsReauthentication(self) {
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
            token = nil
            throw PortainerClientError.unauthorized
        }

        // Other error responses
        if statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(PortainerAPIError.self, from: data) {
                throw PortainerClientError.apiError(statusCode: statusCode, apiError: apiError)
            }
            throw PortainerClientError.httpError(statusCode: statusCode)
        }

        // Decode success response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
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
        let _: EmptyResponse = try await request(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated,
            allowRetry: allowRetry
        )
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

/// Used for decoding responses that may have an empty body.
private struct EmptyResponse: Decodable {}
