import Foundation
import Common

struct ClientToken {
    let value: String
}

@MainActor final class APIClient {
    enum AuthLevel {
        case none
        case authenticated
        case asserted
    }

    private let base: URL
    private let urlSession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let authManager = AuthManager.shared
    private let trustManager: TrustManager

    static let shared = APIClient()

    private init() {
        urlSession = URLSession(configuration: .ephemeral)
        let customEndpoint = UserDefaults.standard.string(forKey: "YPRStagingEndpoint")
        let endpoint = customEndpoint ?? "https://ypr.ober.ai:8080"
        base = URL(string: endpoint)!
        trustManager = TrustManager(
            hostname: "ypr.ober.ai",
            certificate: Data(base64Encoded: letsEncryptRoot.replacing("\n", with: ""))!
        )
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
        if level == .asserted {
            if let assertion = try? await AttestationManager.shared.generateAssertion() {
                assertion.apply(to: &request)
            }
        }
        try configure(&request)
        let (data, response) = try await urlSession.data(for: request, delegate: trustManager)
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

    func getChallenge() async throws -> (id: String, data: Data) {
        let (data, _) = try await makeRequest(to: "challenge") {
            $0.httpMethod = "GET"
        }
        let decoded = try decoder.decode(ChallengeResponse.self, from: data)
        guard let data = Data(base64Encoded: decoded.data) else {
            throw StringError("Invalid challenge base64")
        }
        return (decoded.id, data)
    }

    func attestKey(
        challengeID: String,
        keyID: String,
        attestation: Data
    ) async throws {
        let body = AttestKeyRequest(
            challengeID: challengeID,
            keyID: keyID,
            attestation: attestation.base64EncodedString()
        )
        _ = try await makeRequest(to: "attestKey") {
            $0.httpMethod = "PUT"
            $0.setValue("application/json", forHTTPHeaderField: "content-type")
            $0.httpBody = try encoder.encode(body)
        }
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

extension APIClient: PizzaDetector {
    func detectPizza(image: Data) async throws -> Bool {
        let (data, _) = try await makeRequest(to: "detectPizza", level: .asserted) {
            $0.httpMethod = "POST"
            $0.httpBody = image
        }
        return try decoder.decode(Bool.self, from: data)
    }
}

private struct ErrorResponse: Codable {
    var error: Bool
    var reason: String
}

private let letsEncryptRoot = """
MIIFFjCCAv6gAwIBAgIRAJErCErPDBinU/bWLiWnX1owDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMjAwOTA0MDAwMDAw
WhcNMjUwOTE1MTYwMDAwWjAyMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNTGV0J3Mg
RW5jcnlwdDELMAkGA1UEAxMCUjMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQC7AhUozPaglNMPEuyNVZLD+ILxmaZ6QoinXSaqtSu5xUyxr45r+XXIo9cP
R5QUVTVXjJ6oojkZ9YI8QqlObvU7wy7bjcCwXPNZOOftz2nwWgsbvsCUJCWH+jdx
sxPnHKzhm+/b5DtFUkWWqcFTzjTIUu61ru2P3mBw4qVUq7ZtDpelQDRrK9O8Zutm
NHz6a4uPVymZ+DAXXbpyb/uBxa3Shlg9F8fnCbvxK/eG3MHacV3URuPMrSXBiLxg
Z3Vms/EY96Jc5lP/Ooi2R6X/ExjqmAl3P51T+c8B5fWmcBcUr2Ok/5mzk53cU6cG
/kiFHaFpriV1uxPMUgP17VGhi9sVAgMBAAGjggEIMIIBBDAOBgNVHQ8BAf8EBAMC
AYYwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMBMBIGA1UdEwEB/wQIMAYB
Af8CAQAwHQYDVR0OBBYEFBQusxe3WFbLrlAJQOYfr52LFMLGMB8GA1UdIwQYMBaA
FHm0WeZ7tuXkAXOACIjIGlj26ZtuMDIGCCsGAQUFBwEBBCYwJDAiBggrBgEFBQcw
AoYWaHR0cDovL3gxLmkubGVuY3Iub3JnLzAnBgNVHR8EIDAeMBygGqAYhhZodHRw
Oi8veDEuYy5sZW5jci5vcmcvMCIGA1UdIAQbMBkwCAYGZ4EMAQIBMA0GCysGAQQB
gt8TAQEBMA0GCSqGSIb3DQEBCwUAA4ICAQCFyk5HPqP3hUSFvNVneLKYY611TR6W
PTNlclQtgaDqw+34IL9fzLdwALduO/ZelN7kIJ+m74uyA+eitRY8kc607TkC53wl
ikfmZW4/RvTZ8M6UK+5UzhK8jCdLuMGYL6KvzXGRSgi3yLgjewQtCPkIVz6D2QQz
CkcheAmCJ8MqyJu5zlzyZMjAvnnAT45tRAxekrsu94sQ4egdRCnbWSDtY7kh+BIm
lJNXoB1lBMEKIq4QDUOXoRgffuDghje1WrG9ML+Hbisq/yFOGwXD9RiX8F6sw6W4
avAuvDszue5L3sz85K+EC4Y/wFVDNvZo4TYXao6Z0f+lQKc0t8DQYzk1OXVu8rp2
yJMC6alLbBfODALZvYH7n7do1AZls4I9d1P4jnkDrQoxB3UqQ9hVl3LEKQ73xF1O
yK5GhDDX8oVfGKF5u+decIsH4YaTw7mP3GFxJSqv3+0lUFJoi5Lc5da149p90Ids
hCExroL1+7mryIkXPeFM5TgO9r0rvZaBFOvV2z0gp35Z0+L4WPlbuEjN/lxPFin+
HlUjr8gRsI3qfJOQFy/9rKIJR0Y/8Omwt/8oTWgy1mdeHmmjk7j1nYsvC9JSQ6Zv
MldlTTKB3zhThV1+XWYp6rjd5JW1zbVWEkLNxE7GJThEUG3szgBVGP7pSWTUTsqX
nLRbwHOoq7hHwg==
"""
