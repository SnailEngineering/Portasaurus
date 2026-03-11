import Foundation
import Testing
@testable import Portasaurus

struct AddServerViewModelValidationTests {

    // MARK: portValue

    @Test func portValueValidForInRange() {
        let vm = AddServerViewModel()
        vm.port = "9443"
        #expect(vm.portValue == 9443)
    }

    @Test func portValueNilForZero() {
        let vm = AddServerViewModel()
        vm.port = "0"
        #expect(vm.portValue == nil)
    }

    @Test func portValueNilForAboveMax() {
        let vm = AddServerViewModel()
        vm.port = "65536"
        #expect(vm.portValue == nil)
    }

    @Test func portValueNilForNonNumeric() {
        let vm = AddServerViewModel()
        vm.port = "abc"
        #expect(vm.portValue == nil)
    }

    @Test func portValueAcceptsBoundaries() {
        let vm = AddServerViewModel()
        vm.port = "1"
        #expect(vm.portValue == 1)
        vm.port = "65535"
        #expect(vm.portValue == 65535)
    }

    // MARK: isValid

    @Test func isValidRequiresAllFields() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = "192.168.1.1"
        vm.port = "9443"
        vm.username = "admin"
        vm.password = "pass"
        #expect(vm.isValid)
    }

    @Test func isValidFalseWhenNameBlank() {
        let vm = AddServerViewModel()
        vm.name = "   "
        vm.host = "192.168.1.1"
        vm.port = "9443"
        vm.username = "admin"
        vm.password = "pass"
        #expect(!vm.isValid)
    }

    @Test func isValidFalseWhenHostBlank() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = ""
        vm.port = "9443"
        vm.username = "admin"
        vm.password = "pass"
        #expect(!vm.isValid)
    }

    @Test func isValidFalseWhenPortInvalid() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = "192.168.1.1"
        vm.port = "0"
        vm.username = "admin"
        vm.password = "pass"
        #expect(!vm.isValid)
    }

    @Test func isValidFalseWhenPasswordBlank() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = "192.168.1.1"
        vm.port = "9443"
        vm.username = "admin"
        vm.password = ""
        #expect(!vm.isValid)
    }

    // MARK: validationMessage

    @Test func validationMessageNameFirst() {
        let vm = AddServerViewModel()
        // All blank — name is checked first.
        #expect(vm.validationMessage?.contains("name") == true)
    }

    @Test func validationMessageHostAfterName() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        #expect(vm.validationMessage?.contains("Host") == true)
    }

    @Test func validationMessagePortAfterHost() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = "192.168.1.1"
        vm.port = "bad"
        #expect(vm.validationMessage?.contains("Port") == true)
    }

    @Test func validationMessageNilWhenValid() {
        let vm = AddServerViewModel()
        vm.name = "Home"
        vm.host = "192.168.1.1"
        vm.port = "9443"
        vm.username = "admin"
        vm.password = "pass"
        #expect(vm.validationMessage == nil)
    }
}
