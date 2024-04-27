import Foundation
import Common

struct ClientToken {
    let value: String
}

@MainActor final class APIClient {
    private let base: URL
    private let urlSession = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let authManager = AuthManager.shared

    static let shared = APIClient()

    private init() {
        base = URL(string: "https://ypr.ober.ai:8080")!
    }

    private func makeRequest(
        to endpoint: String,
        authenticated: Bool = true,
        configure: (inout URLRequest) throws -> Void
    ) async throws -> (Data, URLResponse) {
        let url = base.appending(path: endpoint)
        var request = URLRequest(url: url)
        request.setValue(APIKey.value, forHTTPHeaderField: APIKey.header)
        if authenticated {
            guard let token = authManager.token else {
                throw StringError("Not logged in")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        }
        try configure(&request)
        return try await urlSession.data(for: request)
    }

    func createAccount(
        username: String,
        password: String
    ) async throws -> ClientToken {
        let body = CreateRequest(username: username, password: password)
        let (data, _) = try await makeRequest(to: "create", authenticated: false) {
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
        let (data, _) = try await makeRequest(to: "login", authenticated: false) {
            $0.httpMethod = "POST"
            $0.setValue("application/json", forHTTPHeaderField: "content-type")
            $0.httpBody = try encoder.encode(body)
        }
        let decoded = try decoder.decode(ClientTokenResponse.self, from: data)
        return ClientToken(value: decoded.token)
    }
}
