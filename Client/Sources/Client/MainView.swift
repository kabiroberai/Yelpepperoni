import SwiftUI

@MainActor struct MainView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        if authManager.isLoggedIn {
            LoggedInView()
        } else {
            LoginView()
        }
    }
}
