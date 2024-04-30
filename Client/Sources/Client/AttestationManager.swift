import Foundation
import DeviceCheck
import KeychainAccess
import CryptoKit

struct RequestAssertion {
    let keyID: String
    let challengeID: String
    let assertion: Data

    func apply(to request: inout URLRequest) {
        request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-YPR-ASSERTION")
        request.setValue(keyID, forHTTPHeaderField: "X-YPR-ATTEST-KEY")
        request.setValue(challengeID, forHTTPHeaderField: "X-YPR-ATTEST-CHAL")
    }
}

@MainActor final class AttestationManager {
    static let shared = AttestationManager()

    private init() {}

    private let keychain = Keychain(service: "com.kabiroberai.Yelpepperoni.attest")
    private let api = APIClient.shared

    private var keyIDTask: Task<String, Error>?

    func generateAssertion() async throws -> RequestAssertion {
        let id = try await keyID()
        let challenge = try await api.getChallenge()
        let hash = Data(SHA256.hash(data: challenge.data))
        let assertion = try await DCAppAttestService.shared.generateAssertion(id, clientDataHash: hash)
        return RequestAssertion(keyID: id, challengeID: challenge.id, assertion: assertion)
    }

    func keyID() async throws -> String {
        let task: Task<String, Error>
        if let keyIDTask {
            task = keyIDTask
        } else {
            task = Task { try await _keyID() }
            keyIDTask = task
        }
        return try await task.value
    }

    private func _keyID() async throws -> String {
        if let keyID = keychain["keyID"] { return keyID }
        let keyID = try await DCAppAttestService.shared.generateKey()
        let challenge = try await api.getChallenge()
        let hash = Data(SHA256.hash(data: challenge.data))
        let attestation = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: hash)
        try await api.attestKey(challengeID: challenge.id, keyID: keyID, attestation: attestation)
        keychain["keyID"] = keyID
        return keyID
    }
}
