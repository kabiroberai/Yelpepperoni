import Foundation
import Common

struct ClientToken {
    let value: String
}

@MainActor final class APIClient {
    enum AuthLevel {
        case none
        case authenticated
    }

    private let base: URL
    private let urlSession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let authManager = AuthManager.shared

    static let shared = APIClient()

    private init() {
        urlSession = URLSession(configuration: .ephemeral)
        #if DEBUG
        let defaultEndpoint = "https://ypr.ober.ai:8080"
        let customEndpoint = try? String(contentsOf: URL.libraryDirectory.appending(component: "Endpoint.txt"))
        let endpoint = customEndpoint ?? defaultEndpoint
        #else
        let endpoint = defaultEndpoint
        #endif
        base = URL(string: endpoint)!
    }

    private func makeRequest(
        to endpoint: String,
        level: AuthLevel = .authenticated,
        configure: (inout URLRequest) throws -> Void
    ) async throws -> (Data, URLResponse) {
        let url = base.appending(path: endpoint)
        var request = URLRequest(url: url)
        request.setValue(APIKey.value, forHTTPHeaderField: APIKey.header)
        if level != .none {
            guard let token = authManager.token else {
                throw StringError("Not logged in")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        }
        try configure(&request)
        let (data, response) = try await urlSession.data(for: request)
        if let error = try? decoder.decode(ErrorResponse.self, from: data), error.error {
            throw StringError(error.reason)
        }
        return (data, response)
    }

    func createAccount(
        username: String,
        password: String
    ) async throws -> ClientToken {
        let body = CreateRequest(username: username, password: password)
        let (data, _) = try await makeRequest(to: "create", level: .none) {
            $0.httpMethod = "PUT"
            $0.setValue("application/json", forHTTPHeaderField: "content-type")
            $0.httpBody = try encoder.encode(body)
        }
        let decoded = try decoder.decode(ClientTokenResponse.self, from: data)
        return ClientToken(value: decoded.token)
    }

    func login(
        username: String,
        password: String
    ) async throws -> ClientToken {
        let body = LoginRequest(username: username, password: password)
        let (data, _) = try await makeRequest(to: "login", level: .none) {
            $0.httpMethod = "POST"
            $0.setValue("application/json", forHTTPHeaderField: "content-type")
            $0.httpBody = try encoder.encode(body)
        }
        let decoded = try decoder.decode(ClientTokenResponse.self, from: data)
        return ClientToken(value: decoded.token)
    }

    func getPizzerias() async throws -> [Pizzeria] {
        let (data, _) = try await makeRequest(to: "pizzerias") {
            $0.httpMethod = "GET"
        }
        return try decoder.decode([Pizzeria].self, from: data)
    }

    func downloadPizzeriaPhoto(_ photo: Pizzeria.Photo, to destination: URL) async throws {
        let url = base.appending(components: "images", photo.id)
        let (downloaded, _) = try await urlSession.download(from: url)

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: downloaded, to: destination)
    }

    func getDiscounts() async throws -> [Discount] {
        let (data, _) = try await makeRequest(to: "discounts") {
            $0.httpMethod = "GET"
        }
        return try decoder.decode([Discount].self, from: data)
    }
}

private struct ErrorResponse: Codable {
    var error: Bool
    var reason: String
}
