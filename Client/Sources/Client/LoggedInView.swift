import SwiftUI

@MainActor struct LoggedInView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            DiscountsView()
                .tabItem {
                    Label("Discounts", systemImage: "tag.fill")
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
