import Foundation
import KeychainAccess

protocol AuthStore {
    func getToken() -> String?
    func setToken(_ token: String?)
}

struct DefaultsAuthStore: AuthStore {
    private static let key = "YPRAuthToken"

    func getToken() -> String? {
        UserDefaults.standard.string(forKey: Self.key)
    }

    func setToken(_ token: String?) {
        UserDefaults.standard.setValue(token, forKey: Self.key)
    }
}

struct KeychainAuthStore: AuthStore {
    private static let key = "YPRAuthToken"
    private static let keychain = Keychain(service: "com.kabiroberai.Yelpepperoni")

    func getToken() -> String? {
        Self.keychain[Self.key]
    }

    func setToken(_ token: String?) {
        Self.keychain[Self.key] = token
    }
}

@MainActor @Observable final class AuthManager {
    static let shared = AuthManager(store: KeychainAuthStore())

    private let store: any AuthStore

    var token: String? {
        didSet {
            store.setToken(token)
        }
    }

    var isLoggedIn: Bool { token != nil }

    func logOut() {
        token = nil
    }

    private init(store: some AuthStore) {
        self.store = store
        self.token = store.getToken()
    }
}
