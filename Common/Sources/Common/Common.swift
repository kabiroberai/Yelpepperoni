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

public struct ChallengeResponse: Codable, Sendable {
    public let id: String
    public let data: String // base64

    public init(id: String, data: String) {
        self.id = id
        self.data = data
    }
}

public struct AttestKeyRequest: Codable, Sendable {
    public let challengeID: String
    public let keyID: String // base64
    public let attestation: String // base64

    public init(challengeID: String, keyID: String, attestation: String) {
        self.challengeID = challengeID
        self.keyID = keyID
        self.attestation = attestation
    }
}

public struct Pizzeria: Codable, Sendable, Identifiable {
    public struct Photo: Codable, Sendable, Hashable {
        public var filename: String
        public var description: String
        public var url: String

        public init(filename: String, description: String, url: String) {
            self.filename = filename
            self.description = description
            self.url = url
        }
    }

    public var id: String
    public var name: String
    public var address: String
    public var rating: Double // out of 5
    public var photos: [Photo]

    public init(id: String, name: String, address: String, rating: Double, photos: [Photo]) {
        self.id = id
        self.name = name
        self.address = address
        self.rating = rating
        self.photos = photos
    }
}

public enum APIKey {
    public static let header = "X-YPR-KEY"

    // NB: in reality one would use a database to store many keys.
    public static let value = "D5F48B79-7BFC-4222-9E4B-8639FA2943A5"
}
