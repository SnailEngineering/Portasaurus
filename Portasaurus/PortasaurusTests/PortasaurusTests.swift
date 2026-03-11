import Foundation
import Testing
@testable import Portasaurus

// MARK: - PortainerClient Initialization Tests

struct PortainerClientInitTests {

    @Test func initWithServerURL() {
        let url = URL(string: "https://portainer.example.com:9443")!
        let client = PortainerClient(serverURL: url)

        #expect(client.baseURL == url)
        #expect(client.token == nil)
    }

    @Test func initWithComponents() {
        let client = PortainerClient(scheme: "https", host: "10.0.0.5", port: 9443)

        #expect(client != nil)
        #expect(client?.baseURL.scheme == "https")
        #expect(client?.baseURL.host == "10.0.0.5")
        #expect(client?.baseURL.port == 9443)
    }

    @Test func initWithInvalidComponents() {
        // Empty host should still produce a valid URL per URLComponents behavior,
        // but we verify it doesn't crash.
        let client = PortainerClient(scheme: "https", host: "", port: 9443)
        #expect(client != nil)
    }
}

// MARK: - PortainerClient Token Tests

struct PortainerClientTokenTests {

    @Test func tokenStartsNil() {
        let client = PortainerClient(serverURL: URL(string: "https://localhost:9443")!)
        #expect(client.token == nil)
    }

    @Test func tokenCanBeSet() {
        let client = PortainerClient(serverURL: URL(string: "https://localhost:9443")!)
        client.token = "test-jwt-token"
        #expect(client.token == "test-jwt-token")
    }

    @Test func tokenCanBeCleared() {
        let client = PortainerClient(serverURL: URL(string: "https://localhost:9443")!)
        client.token = "test-jwt-token"
        client.token = nil
        #expect(client.token == nil)
    }
}

// MARK: - PortainerClientError Tests

struct PortainerClientErrorTests {

    @Test func errorDescriptions() {
        let invalidURL = PortainerClientError.invalidURL
        #expect(invalidURL.localizedDescription.contains("Invalid"))

        let unauthorized = PortainerClientError.unauthorized
        #expect(unauthorized.localizedDescription.contains("Authentication"))

        let apiError = PortainerClientError.apiError(
            statusCode: 422,
            apiError: PortainerAPIError(message: "Invalid credentials", details: nil)
        )
        #expect(apiError.localizedDescription.contains("422"))
        #expect(apiError.localizedDescription.contains("Invalid credentials"))

        let httpError = PortainerClientError.httpError(statusCode: 500)
        #expect(httpError.localizedDescription.contains("500"))
    }
}

// MARK: - URL Construction Tests

struct PortainerClientURLTests {

    @Test func baseURLPreservesTrailingPath() {
        let url = URL(string: "https://example.com:9443/portainer")!
        let client = PortainerClient(serverURL: url)
        #expect(client.baseURL.absoluteString == "https://example.com:9443/portainer")
    }

    @Test func httpSchemeSupported() {
        let client = PortainerClient(scheme: "http", host: "192.168.1.100", port: 9000)
        #expect(client != nil)
        #expect(client?.baseURL.scheme == "http")
        #expect(client?.baseURL.port == 9000)
    }
}
