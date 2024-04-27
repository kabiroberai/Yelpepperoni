import Foundation

// crude SSL pinning impl

final class TrustManager: NSObject, URLSessionTaskDelegate {
    private let anchor: SecCertificate
    private let policy: SecPolicy

    init(hostname: String, certificate: Data) {
        policy = SecPolicyCreateSSL(true, hostname as CFString)
        anchor = SecCertificateCreateWithData(nil, certificate as CFData)!
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let trust = challenge.protectionSpace.serverTrust, await validate(trust) {
            return (.useCredential, URLCredential(trust: trust))
        } else {
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    private func validate(_ trust: SecTrust) async -> Bool {
        SecTrustSetPolicies(trust, [policy] as CFArray)
        SecTrustSetAnchorCertificates(trust, [anchor] as CFArray)
        return SecTrustEvaluateWithError(trust, nil)
    }
}
