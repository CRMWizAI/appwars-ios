import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0

    var isAdmin: Bool { auth.profile?.role == "admin" }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            LeaderboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Leaderboard")
                }
                .tag(1)

            TeamWarsListView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Wars")
                }
                .tag(2)

            PortfolioManageView()
                .tabItem {
                    Image(systemName: "briefcase.fill")
                    Text("Portfolio")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)

            if isAdmin {
                AdminView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Admin")
                    }
                    .tag(5)
            }
        }
        .tint(.yellow)
        .preferredColorScheme(.dark)
    }
}
