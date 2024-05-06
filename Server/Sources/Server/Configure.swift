import Vapor
import Fluent
import FluentSQLiteDriver
import JWTKit
import Common
import NIOSSL

// configures your application
public func configure(_ app: Application) async throws {
    let dataDir = URL(filePath: "Data")
    try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

    app.http.server.configuration.address = .hostname("127.0.0.1", port: 8001)

    try await configureTLS(app)

    app.passwords.use(.bcrypt)

    let jwtSecretFile = URL(filePath: "Data/jwt-secret")
    let jwtSecret: Data
    if let existing = try? Data(contentsOf: jwtSecretFile) {
        jwtSecret = existing
    } else {
        let secret = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        jwtSecret = secret
        try secret.write(to: jwtSecretFile)
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))

    app.databases.use(.sqlite(.file("Data/db.sqlite")), as: .sqlite)
    configureMigrations(app)

    try await app.autoMigrate()

    app.middleware.use(FileMiddleware(publicDirectory: "Data/public"))
    app.middleware.use(SecretMiddleware())
    try addRoutes(app)
}

func configureTLS(_ app: Application) async throws {
    guard FileManager.default.fileExists(atPath: "Data/privkey.pem") else {
        app.logger.log(level: .warning, "Could not find Data/privkey.pem. Running without TLS.")
        return
    }
    guard FileManager.default.fileExists(atPath: "Data/fullchain.pem") else {
        app.logger.log(level: .warning, "Could not find Data/fullchain.pem. Running without TLS.")
        return
    }
    let privKey = try NIOSSLPrivateKey(file: "Data/privkey.pem", format: .pem)
    let certs = try NIOSSLCertificate.fromPEMFile("Data/fullchain.pem")
    app.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
        certificateChain: certs.map { .certificate($0) },
        privateKey: .privateKey(privKey)
    )
}

private struct SecretMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard request.headers.first(name: APIKey.header) == APIKey.value else {
            throw Abort(.unauthorized)
        }
        return try await next.respond(to: request)
    }
}
