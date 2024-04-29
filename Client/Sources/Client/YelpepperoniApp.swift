import SwiftUI

@main
struct YelpepperoniApp: App {
    var body: some Scene {
        WindowGroup {
            if AuthManager.shared.isLoggedIn {
                LoggedInView()
            } else {
                LoginView()
            }
        }
    }
}
