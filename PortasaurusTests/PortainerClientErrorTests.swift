import Foundation
import Testing
@testable import Portasaurus

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
