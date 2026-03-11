import Foundation
import Testing
@testable import Portasaurus

struct KeychainServiceTests {

    // Each test gets its own unique URL to avoid cross-test interference
    // when Swift Testing runs tests in parallel.
    private static func uniqueURL() -> String {
        "https://keychain-test-\(UUID().uuidString).local:9443"
    }

    @Test func saveAndLoad() throws {
        let url = Self.uniqueURL()
        defer { try? KeychainService.delete(serverURL: url) }

        try KeychainService.save(username: "admin", password: "secret", serverURL: url)
        let credentials = KeychainService.load(serverURL: url)

        #expect(credentials?.username == "admin")
        #expect(credentials?.password == "secret")
    }

    @Test func loadReturnsNilWhenMissing() {
        let url = Self.uniqueURL()
        let credentials = KeychainService.load(serverURL: url)
        #expect(credentials == nil)
    }

    @Test func saveOverwritesPreviousEntry() throws {
        let url = Self.uniqueURL()
        defer { try? KeychainService.delete(serverURL: url) }

        try KeychainService.save(username: "admin", password: "old", serverURL: url)
        try KeychainService.save(username: "admin", password: "new", serverURL: url)

        let credentials = KeychainService.load(serverURL: url)
        #expect(credentials?.password == "new")
    }

    @Test func deleteRemovesEntry() throws {
        let url = Self.uniqueURL()

        try KeychainService.save(username: "admin", password: "secret", serverURL: url)
        try KeychainService.delete(serverURL: url)

        #expect(KeychainService.load(serverURL: url) == nil)
    }

    @Test func deleteOnMissingEntrySucceeds() throws {
        let url = Self.uniqueURL()
        // Should not throw when the item doesn't exist.
        try KeychainService.delete(serverURL: url)
    }
}
