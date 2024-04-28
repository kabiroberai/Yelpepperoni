import Vapor
import Common
import AppAttest

private var appID: AppAttest.AppID {
    .init(
        teamID: "25MTNC334J",
        bundleID: "com.kabiroberai.Yelpepperoni"
    )
}

extension ChallengeResponse: Content {}

actor ChallengeManager {
    private var challenges: [String: Data] = [:]

    static let shared = ChallengeManager()
    private init() {}

    func generateChallenge() -> ChallengeResponse {
        let id = UUID().uuidString
        let nonce = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        challenges[id] = nonce
        return ChallengeResponse(id: id, data: nonce.base64EncodedString())
    }

    func retrieveChallenge(id: String) -> Data? {
        challenges.removeValue(forKey: id)
    }
}

func addAttestationRoutes(_ routes: any RoutesBuilder) throws {
    routes.get("challenge") { req async throws in
        await ChallengeManager.shared.generateChallenge()
    }

    routes.put("attestKey") { req async throws in
        let request = try req.content.decode(AttestKeyRequest.self)

        guard let challenge = await ChallengeManager.shared.retrieveChallenge(id: request.challengeID) else {
            throw Abort(.badRequest, reason: "Invalid challenge ID")
        }

        guard let attestation = Data(base64Encoded: request.attestation) else {
            throw Abort(.badRequest, reason: "Invalid attestation")
        }

        guard let keyID = Data(base64Encoded: request.keyID) else {
            throw Abort(.badRequest, reason: "Invalid keyID")
        }

        let attestRequest = AppAttest.AttestationRequest(attestation: attestation, keyID: keyID)
        let result = try AppAttest.verifyAttestation(
            challenge: challenge,
            request: attestRequest,
            appID: appID
        )

        let key = AttestationKey(
            keyID: request.keyID,
            publicKey: result.publicKey.derRepresentation
        )
        try await key.create(on: req.db)

        return Response(status: .noContent)
    }
}

struct AttestationMiddleware: AsyncMiddleware {
    private func validate(_ req: Request, assertion rawAssertion: String) async throws {
        guard let assertion = Data(base64Encoded: rawAssertion) else {
            throw Abort(.badRequest, reason: "Bad assertion")
        }

        guard let keyID = req.headers.first(name: "X-YPR-ATTEST-KEY") else {
            throw Abort(.badRequest, reason: "Missing X-YPR-ATTEST-KEY")
        }
        let key = try await AttestationKey.query(on: req.db)
            .filter(\.$keyID, .equal, keyID)
            .first()
        guard let key else {
            throw Abort(.badRequest, reason: "Invalid keyID")
        }
        let publicKey = try P256.Signing.PublicKey(derRepresentation: key.publicKey)
        // NB: a better implementation would store the userID associated with the key
        // and verify that it matches the current user.

        guard let challengeID = req.headers.first(name: "X-YPR-ATTEST-CHAL") else {
            throw Abort(.badRequest, reason: "Missing X-YPR-ATTEST-CHAL")
        }
        guard let challenge = await ChallengeManager.shared.retrieveChallenge(id: challengeID) else {
            throw Abort(.badRequest, reason: "Invalid challengeID")
        }

        let assertionRequest = AppAttest.AssertionRequest(
            assertion: assertion,
            // NB: a better implementation would mix in the headers/body here
            clientData: challenge,
            challenge: challenge
        )
        _ = try AppAttest.verifyAssertion(
            challenge: challenge,
            request: assertionRequest,
            previousResult: nil,
            publicKey: publicKey,
            appID: appID
        )
    }

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let assertion = request.headers.first(name: "X-YPR-ASSERTION") {
            try await validate(request, assertion: assertion)
            request.isAttested = true
        }
        return try await next.respond(to: request)
    }
}

extension Request {
    fileprivate(set) var isAttested: Bool {
        get { storage[IsAttestedKey.self] != nil }
        set { storage[IsAttestedKey.self] = newValue ? () : nil }
    }
}

private enum IsAttestedKey: StorageKey {
    typealias Value = Void
}
