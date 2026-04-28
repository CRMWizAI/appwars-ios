import SwiftUI

struct PortfolioManageView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                Text("Your Portfolio")
                    .font(.title2.weight(.bold))
                Text("Showcase your tournament builds")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Portfolio")
        }
    }
}
