import Foundation
import Testing
@testable import Portasaurus

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
