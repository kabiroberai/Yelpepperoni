import Vapor
import Fluent
import Common
import PizzaDetection
import NIOCore

extension ClientTokenResponse: Content {}
extension Pizzeria: Content {}
extension Discount: Content {}

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
    let store = try PizzeriaStore()

    try addAttestationRoutes(routes)

    routes.get { req async throws in
        let user = try await req.user()
        return "Hello, \(user.username)"
    }

    routes.get("pizzerias") { req async throws in
        await store.pizzerias
    }

    routes.put("pizzerias") { req async throws in
        var pizzeria = try req.content.decode(Pizzeria.self)
        let id = UUID().uuidString
        pizzeria.id = id
        // ensure that photo IDs are valid UUID strings
        guard pizzeria.photos.allSatisfy({ UUID($0.id) != nil }) else {
            throw Abort(.badRequest)
        }
        try await store.add(pizzeria: pizzeria)
        return id
    }

    routes.on(.PUT, "images", body: .stream) { req async throws in
        let id = UUID().uuidString
        let fd = try NIOFileHandle(path: "Data/public/images/\(id)", mode: .write, flags: .allowFileCreation())
        defer { try? fd.close() }
        let io = NonBlockingFileIO(threadPool: req.application.threadPool)
        for try await chunk in req.body {
            try await io.write(fileHandle: fd, buffer: chunk)
        }
        return id
    }

    routes.on(.POST, "detectPizza", body: .collect(maxSize: "15mb")) { req async throws in
        guard req.isAttested else {
            throw Abort(.unauthorized, reason: "Attestation failed")
        }
        guard let imageBuffer = req.body.data else {
            throw Abort(.badRequest, reason: "Missing image")
        }
        let bytes = imageBuffer.withUnsafeReadableBytes { Data($0) }
        return try await GPTPizzaDetector.shared.detectPizza(image: bytes)
    }

    routes.post("unlockPro") { req async throws in
        guard let buffer = req.body.data else {
            throw Abort(.badRequest, reason: "Missing receipt")
        }
        let jws = buffer.withUnsafeReadableBytes { String(decoding: $0, as: UTF8.self) }
        do {
            try await ReceiptValidator.validateReceipt(jws)
        } catch {
            throw Abort(.badRequest, reason: "Invalid receipt")
        }
        let user = try await req.user()
        user.isPro = Date()
        try await user.update(on: req.db)
        return Response(status: .accepted)
    }

    routes.get("discounts") { req async throws in
        guard try await req.user().isPro != nil else {
            throw Abort(.unauthorized)
        }
        return Discount.all
    }
}

extension Discount {
    static let all: [Discount] = [
        Discount(id: "1", title: "50% off ALL pizzas!", code: "50-OFF"),
        Discount(id: "2", title: "20% off pineapples", code: "20-OFF"),
    ]
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

actor PizzeriaStore {
    private let url: URL
    private let encoder = JSONEncoder()
    var pizzerias: [Pizzeria]

    init() throws {
        url = URL(filePath: "Data/pizzerias.json")
        let data = try Data(contentsOf: url)
        pizzerias = try JSONDecoder().decode([Pizzeria].self, from: data)
    }

    func add(pizzeria: Pizzeria) throws {
        pizzerias.append(pizzeria)
        let data = try encoder.encode(pizzerias)
        try data.write(to: url)
    }
}
