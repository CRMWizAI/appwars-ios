import SwiftUI
import Kingfisher

struct HomeView: View {
    @EnvironmentObject var auth: AuthService
    @State private var tournaments: [Tournament] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if loading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 220)
                                .shimmer()
                        }
                    } else {
                        // Active / Registration
                        let live = tournaments.filter { $0.isActive || $0.isRegistration }
                        if !live.isEmpty {
                            ForEach(live) { tournament in
                                NavigationLink(destination: TournamentDetailView(tournament: tournament)) {
                                    LiveTournamentCard(tournament: tournament)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Completed
                        let completed = tournaments.filter { $0.isCompleted }
                        if !completed.isEmpty {
                            HStack {
                                Text("PAST SEASONS")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }

                            ForEach(completed) { tournament in
                                NavigationLink(destination: TournamentDetailView(tournament: tournament)) {
                                    CompletedTournamentCard(tournament: tournament)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if tournaments.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "trophy")
                                    .font(.system(size: 52))
                                    .foregroundStyle(.gray.opacity(0.3))
                                Text("No tournaments yet")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Check back soon for the next battle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
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

// MARK: - Live Tournament Card (hero style)
struct LiveTournamentCard: View {
    let tournament: Tournament

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.yellow.opacity(0.4), .orange.opacity(0.3), .black],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(height: 240)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    if tournament.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    } else {
                        StatusBadge(status: tournament.status)
                    }
                }

                Spacer()

                Text(tournament.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let desc = tournament.description {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                        Text("Round \(tournament.currentRound)")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(tournament.playerCount ?? 0) builders")
                    }
                    if let hours = tournament.roundDurationHours {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text("\(hours)h rounds")
                        }
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }
}

// MARK: - Completed Tournament Card
struct CompletedTournamentCard: View {
    let tournament: Tournament

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow.opacity(0.5))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    StatusBadge(status: tournament.status)
                    Text("\(tournament.playerCount ?? 0) builders")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if let prizes = tournament.prizes, let first = prizes.first {
                    Text("🏆 \(first.name)")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Status Badge (upgraded)
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
        case "completed": return "Completed"
        default: return status.capitalized
        }
    }

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
