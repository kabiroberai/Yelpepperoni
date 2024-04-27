public struct CreateRequest: Codable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct LoginRequest: Codable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct ClientTokenResponse: Codable, Sendable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}

public enum APIKey {
    public static let header = "X-YPR-KEY"

    // NB: in reality one would use a database to store many keys.
    public static let value = "D5F48B79-7BFC-4222-9E4B-8639FA2943A5"
}
