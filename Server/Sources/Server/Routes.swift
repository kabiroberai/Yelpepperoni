import Vapor
import Fluent
import Common

extension ClientTokenResponse: Content {}

func routes(_ app: Application) throws {
    app.put("create") { req async throws in
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

    app.post("login") { req async throws -> ClientTokenResponse in
        let body = try req.content.decode(LoginRequest.self)
        let user = try await User.query(on: req.db).filter(\.$username, .equal, body.username).first()
        guard let user else { throw Abort(.unauthorized) }
        let isValid = try await req.password.async.verify(Data(body.password.utf8), created: user.password)
        guard isValid else { throw Abort(.unauthorized) }
        let jwt = try req.jwt.sign(SessionToken(user: user))
        return ClientTokenResponse(token: jwt)
    }

    let group = app.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
    try authedRoutes(group)
}

func authedRoutes(_ app: some RoutesBuilder) throws {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
}
