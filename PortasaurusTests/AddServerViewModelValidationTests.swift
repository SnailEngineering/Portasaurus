import Foundation
import Testing
@testable import Portasaurus

struct AddServerViewModelValidationTests {

    // MARK: parsedURL

    @Test func parsedURLValidHTTPS() {
        let vm = AddServerViewModel()
        vm.serverURL = "https://portainer.example.com"
        #expect(vm.parsedURL != nil)
        #expect(vm.parsedURL?.scheme == "https")
        #expect(vm.parsedURL?.host == "portainer.example.com")
    }

    @Test func parsedURLValidHTTP() {
        let vm = AddServerViewModel()
        vm.serverURL = "http://192.168.1.1:9000"
        #expect(vm.parsedURL != nil)
        #expect(vm.parsedURL?.scheme == "http")
        #expect(vm.parsedURL?.port == 9000)
    }

    @Test func parsedURLValidWithCustomPort() {
        let vm = AddServerViewModel()
        vm.serverURL = "https://192.168.1.1:9443"
        #expect(vm.parsedURL != nil)
        #expect(vm.parsedURL?.port == 9443)
    }

    @Test func parsedURLPrependsHTTPSWhenNoScheme() {
        let vm = AddServerViewModel()
        vm.serverURL = "portainer.example.com"
        #expect(vm.parsedURL != nil)
        #expect(vm.parsedURL?.scheme == "https")
        #expect(vm.parsedURL?.host == "portainer.example.com")
    }

    @Test func parsedURLNilForEmptyString() {
        let vm = AddServerViewModel()
        vm.serverURL = ""
        #expect(vm.parsedURL == nil)
    }

    @Test func parsedURLNilForInvalidScheme() {
        let vm = AddServerViewModel()
        vm.serverURL = "ftp://portainer.example.com"
        #expect(vm.parsedURL == nil)
    }

    @Test func parsedURLNilForWhitespaceOnly() {
        let vm = AddServerViewModel()
        vm.serverURL = "   "
        #expect(vm.parsedURL == nil)
    }

    // MARK: isValid

    @Test func isValidRequiresAllFields() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.serverURL = "https://portainer.example.com"
        vm.username = "admin"
        vm.password = "pass"
        #expect(vm.isValid)
    }

    @Test func isValidFalseWhenNameBlank() {
        let vm = AddServerViewModel()
        vm.name = "   "
        vm.serverURL = "https://portainer.example.com"
        vm.username = "admin"
        vm.password = "pass"
        #expect(!vm.isValid)
    }

    @Test func isValidFalseWhenURLInvalid() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.serverURL = ""
        vm.username = "admin"
        vm.password = "pass"
        #expect(!vm.isValid)
    }

    @Test func isValidFalseWhenPasswordBlank() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.serverURL = "https://portainer.example.com"
        vm.username = "admin"
        vm.password = ""
        #expect(!vm.isValid)
    }

    // MARK: validationMessage

    @Test func validationMessageNameFirst() {
        let vm = AddServerViewModel()
        #expect(vm.validationMessage?.contains("name") == true)
    }

    @Test func validationMessageURLAfterName() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        #expect(vm.validationMessage?.contains("URL") == true)
    }

    @Test func validationMessageUsernameAfterURL() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.serverURL = "https://portainer.example.com"
        #expect(vm.validationMessage?.contains("Username") == true)
    }

    @Test func validationMessageNilWhenValid() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.serverURL = "https://portainer.example.com"
        vm.username = "admin"
        vm.password = "pass"
        #expect(vm.validationMessage == nil)
    }
}
