import Vapor
import Fluent
import Common

extension ClientTokenResponse: Content {}

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
    routes.get { req async throws in
        return "It works!"
    }

    routes.get("hello") { req async throws in
        let user = try await req.user()
        return "Hello, \(user.username)"
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
