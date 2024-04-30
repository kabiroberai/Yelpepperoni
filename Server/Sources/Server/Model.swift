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

    @Field(key: "isPro")
    var isPro: Date?

    init() {}

    init(id: UUID? = nil, username: String, password: Data, isPro: Date? = nil) {
        self.id = id
        self.username = username
        self.password = password
        self.isPro = isPro
    }
}

struct SessionToken: Content, Authenticatable, JWTPayload {
    static let expirationTime: TimeInterval = 86400 * 30

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

struct AddPro: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("isPro", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {}
}

func configureMigrations(_ app: Application) {
    app.migrations.add(CreateUser())
    app.migrations.add(AddPro())
}
