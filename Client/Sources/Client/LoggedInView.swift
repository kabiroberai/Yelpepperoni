import SwiftUI

@MainActor struct HomeView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        VStack {
            Text("Token: \(authManager.token ?? "<none>")")
                .task {
                }

            Button("Log Out") {
                authManager.logOut()
            }
        }
    }
}

@MainActor struct LoggedInView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            NotPizzaView()
                .tabItem {
                    Label("Not Pizza", systemImage: "camera.viewfinder")
                }
        }
    }
}

#Preview {
    LoggedInView()
}
