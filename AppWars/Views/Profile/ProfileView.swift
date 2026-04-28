import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(auth.profile?.displayName?.prefix(1) ?? "?").uppercased())
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.yellow)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.profile?.displayName ?? "User")
                                .font(.headline)
                            Text(auth.profile?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let discord = auth.profile?.discordUsername {
                                Text("@\(discord)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Account") {
                    NavigationLink {
                        Text("Edit Profile")
                    } label: {
                        Label("Edit Profile", systemImage: "person.circle")
                    }
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                Section("Support") {
                    Link(destination: URL(string: "https://appwars.io/support")!) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "https://appwars.io/privacy-policy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://appwars.io/terms-and-conditions")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
