import Vapor
import Fluent
import JWT
import FluentSQL

final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password")
    var password: Data // bcrypt hash

    init() {}

    init(id: UUID? = nil, username: String, password: Data) {
        self.id = id
        self.username = username
        self.password = password
    }
}

final class AttestationKey: Model, @unchecked Sendable {
    static let schema = "attestation_keys"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "keyid")
    var keyID: String

    @Field(key: "pubkey")
    var publicKey: Data

    init() {}

    init(id: UUID? = nil, keyID: String, publicKey: Data) {
        self.id = id
        self.keyID = keyID
        self.publicKey = publicKey
    }
}

struct SessionToken: Content, Authenticatable, JWTPayload {
    static let expirationTime: TimeInterval = 60 * 15

    var expiration: ExpirationClaim
    var userID: UUID

    init(userID: UUID) {
        self.userID = userID
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(Self.expirationTime))
    }

    init(user: User) throws {
        let userID = try user.requireID()
        self.init(userID: userID)
    }

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string)
            .unique(on: "username")
            .field("password", .data)
            .create()
    }

    func revert(on database: Database) async throws {}
}

struct CreateAttestationKey: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("attestation_keys")
            .id()
            .field("keyid", .string)
            .unique(on: "keyid")
            .field("pubkey", .data)
            .create()
    }

    func revert(on database: any Database) async throws {}
}

func configureMigrations(_ app: Application) {
    app.migrations.add(CreateUser())
    app.migrations.add(CreateAttestationKey())
}
