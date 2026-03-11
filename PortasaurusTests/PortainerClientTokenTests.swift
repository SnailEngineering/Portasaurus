import Foundation
import Testing
@testable import Portasaurus

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
