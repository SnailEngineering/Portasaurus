import Foundation

/// `URLSessionDelegate` that unconditionally accepts server certificates.
///
/// Only use this when the user has explicitly opted in to trusting
/// self-signed certificates for a given server. Never apply globally.
final class SSLTrustHandler: NSObject, URLSessionDelegate, @unchecked Sendable {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
