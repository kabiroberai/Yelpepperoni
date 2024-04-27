import SwiftUI

@MainActor struct LoggedInView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        VStack {
            Text("Token: \(authManager.token ?? "<none>")")

            Button("Log Out") {
                authManager.logOut()
            }
        }
        .task {
        }
    }
}
