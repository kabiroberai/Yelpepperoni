import Vapor
import Fluent
import FluentSQLiteDriver
import JWTKit

// configures your application
public func configure(_ app: Application) async throws {
    app.http.server.configuration.port = 8001

    app.passwords.use(.bcrypt)

    // NB: this should really be injected
    app.jwt.signers.use(.hs256(key: "0F6180B8-C5F6-4D64-94E8-ABEAD9BF62BE"))

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    configureMigrations(app)

    try await app.autoMigrate()

    try routes(app)
}
