import SwiftUI

@main
struct AppWarsApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            if auth.isLoading {
                LaunchScreen()
            } else if auth.isAuthenticated {
                MainTabView()
                    .environmentObject(auth)
            } else {
                LoginView()
                    .environmentObject(auth)
            }
        }
    }
}
