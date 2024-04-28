import Vapor
import Fluent
import Common
import PizzaDetection

extension ClientTokenResponse: Content {}
extension Pizzeria: Content {}

func addRoutes(_ routes: any RoutesBuilder) throws {
    routes.put("create") { req async throws in
        let body = try req.content.decode(CreateRequest.self)
        let hash = try await req.password.async.hash(Data(body.password.utf8))
        let user = try await req.db.transaction { db in
            let existing = try await User.query(on: db)
                .filter(\.$username, .equal, body.username)
                .count()
            if existing != 0 { throw Abort(.conflict) }
            let user = User(username: body.username, password: Data(hash))
            try await user.create(on: db)
            return user
        }
        let jwt = try req.jwt.sign(SessionToken(user: user))
        return ClientTokenResponse(token: jwt)
    }

    routes.post("login") { req async throws -> ClientTokenResponse in
        let body = try req.content.decode(LoginRequest.self)
        let user = try await User.query(on: req.db).filter(\.$username, .equal, body.username).first()
        guard let user else { throw Abort(.unauthorized) }
        let isValid = try await req.password.async.verify(Data(body.password.utf8), created: user.password)
        guard isValid else { throw Abort(.unauthorized) }
        let jwt = try req.jwt.sign(SessionToken(user: user))
        return ClientTokenResponse(token: jwt)
    }

    try routes.group(SessionToken.authenticator(), SessionToken.guardMiddleware()) {
        try addAuthedRoutes($0)
    }
}

func addAuthedRoutes(_ routes: any RoutesBuilder) throws {
    try addAttestationRoutes(routes)

    routes.get { req async throws in
        let user = try await req.user()
        return "Hello, \(user.username)"
    }

    routes.get("pizzerias") { req async throws in
        req.fileio.streamFile(at: "pizzerias.json")
    }

    routes.on(.POST, "detectPizza", body: .collect(maxSize: "5mb")) { req async throws in
        guard req.isAttested else {
            throw Abort(.unauthorized, reason: "Attestation failed")
        }
        guard let imageBuffer = req.body.data else {
            throw Abort(.badRequest, reason: "Missing image")
        }
        let bytes = imageBuffer.withUnsafeReadableBytes { Data($0) }
        return try await GPTPizzaDetector.shared.detectPizza(image: bytes)
    }
}

extension Request {
    var userID: UUID? {
        auth.get(SessionToken.self)?.userID
    }

    func user() async throws -> User {
        guard let userID, let user = try await User.find(userID, on: db) else {
            throw Abort(.unauthorized)
        }
        return user
    }
}
