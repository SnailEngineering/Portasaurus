import Foundation
import Testing
@testable import Portasaurus

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
