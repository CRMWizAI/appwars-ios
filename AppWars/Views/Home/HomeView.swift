import SwiftUI
import Kingfisher

struct HomeView: View {
    @EnvironmentObject var auth: AuthService
    @State private var tournaments: [Tournament] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if loading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .shimmer()
                        }
                    } else {
                        // Active tournaments
                        let active = tournaments.filter { $0.isActive || $0.isRegistration }
                        if !active.isEmpty {
                            SectionHeader(title: "Active Tournaments")
                            ForEach(active) { tournament in
                                NavigationLink(destination: TournamentDetailView(tournament: tournament)) {
                                    TournamentCard(tournament: tournament)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Completed
                        let completed = tournaments.filter { $0.isCompleted }
                        if !completed.isEmpty {
                            SectionHeader(title: "Past Tournaments")
                            ForEach(completed) { tournament in
                                NavigationLink(destination: TournamentDetailView(tournament: tournament)) {
                                    TournamentCard(tournament: tournament)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if tournaments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "trophy")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.gray)
                                Text("No tournaments yet")
                                    .font(.title3)
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("AppWars")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellView()
                }
            }
            .refreshable { await loadTournaments() }
            .task { await loadTournaments() }
        }
    }

    func loadTournaments() async {
        do {
            let response: [Tournament] = try await supabase.from("tournaments")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            tournaments = response
        } catch {
            print("Failed to load tournaments: \(error)")
        }
        loading = false
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct TournamentCard: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner image
            if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                }
                .frame(height: 160)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tournament.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(status: tournament.status)
                }

                if let desc = tournament.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("Round \(tournament.currentRound)", systemImage: "flag.fill")
                    if let count = tournament.playerCount {
                        Label("\(count) players", systemImage: "person.2.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "registration": return .blue
        case "active": return .green
        case "completed": return .gray
        default: return .gray
        }
    }

    var label: String {
        switch status {
        case "registration": return "Open"
        case "active": return "Live"
        case "completed": return "Done"
        default: return status.capitalized
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
