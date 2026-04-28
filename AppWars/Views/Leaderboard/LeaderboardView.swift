import SwiftUI
import Kingfisher

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
    var wins: Int = 0
    var losses: Int = 0
    var totalVotes: Int = 0
    var tournamentsEntered: Int = 0
}

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    VStack(spacing: 8) {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.12))
                                .frame(height: 64)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal)
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray.opacity(0.3))
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 80)
                } else {
                    // Top 3 podium
                    if entries.count >= 3 {
                        PodiumView(entries: Array(entries.prefix(3)))
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    // Full list
                    VStack(spacing: 6) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRowView(rank: index + 1, entry: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Leaderboard")
            .refreshable { await loadLeaderboard() }
            .task { await loadLeaderboard() }
        }
    }

    func loadLeaderboard() async {
        do {
            // Get all completed matchups and compute W/L from them
            let matchups: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("status", value: "completed")
                .execute()
                .value

            let participants: [Participant] = try await supabase.from("participants")
                .select()
                .execute()
                .value

            // Build leaderboard from matchup results
            var board: [String: LeaderboardEntry] = [:]

            for p in participants {
                board[p.id.uuidString] = LeaderboardEntry(
                    id: p.id.uuidString,
                    username: p.discordUsername,
                    avatarUrl: p.avatarUrl,
                    tournamentsEntered: 1
                )
            }

            for m in matchups {
                guard let winnerId = m.winnerId else { continue }

                // Winner
                let wKey = winnerId.uuidString
                board[wKey]?.wins += 1
                board[wKey]?.totalVotes += (winnerId == m.participantAId ? m.votesA : m.votesB)

                // Loser
                let loserId = (winnerId == m.participantAId ? m.participantBId : m.participantAId)
                if let lKey = loserId?.uuidString {
                    board[lKey]?.losses += 1
                    board[lKey]?.totalVotes += (loserId == m.participantAId ? m.votesA : m.votesB)
                }
            }

            entries = Array(board.values)
                .sorted { ($0.wins, $0.totalVotes) > ($1.wins, $1.totalVotes) }

        } catch {
            print("Failed to load leaderboard: \(error)")
        }
        loading = false
    }
}

// MARK: - Podium
struct PodiumView: View {
    let entries: [LeaderboardEntry]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count >= 2 { PodiumSlot(entry: entries[1], place: 2, height: 90) }
            if entries.count >= 1 { PodiumSlot(entry: entries[0], place: 1, height: 110) }
            if entries.count >= 3 { PodiumSlot(entry: entries[2], place: 3, height: 75) }
        }
        .padding(.bottom, 16)
    }
}

struct PodiumSlot: View {
    let entry: LeaderboardEntry
    let place: Int
    let height: CGFloat

    var podiumColor: Color {
        switch place {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(podiumColor.opacity(0.15))
                    .frame(width: place == 1 ? 56 : 44, height: place == 1 ? 56 : 44)

                if let url = entry.avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: place == 1 ? 48 : 38, height: place == 1 ? 48 : 38)
                        .clipShape(Circle())
                } else {
                    Text(String(entry.username.prefix(1)).uppercased())
                        .font(.system(size: place == 1 ? 20 : 16, weight: .bold, design: .rounded))
                        .foregroundStyle(podiumColor)
                }
            }
            .overlay(alignment: .top) {
                if place == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                        .offset(y: -14)
                }
            }

            Text(entry.username)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            // Podium block
            VStack(spacing: 2) {
                Text("\(place)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(podiumColor)
                Text("\(entry.wins)W \(entry.losses)L")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(podiumColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(podiumColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row
struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                .frame(width: 28)

            // Avatar
            if let url = entry.avatarUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.yellow.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String(entry.username.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                    )
            }

            // Name + stats
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(entry.wins)W").foregroundStyle(.green).font(.system(size: 11, weight: .semibold))
                    Text("\(entry.losses)L").foregroundStyle(.red).font(.system(size: 11, weight: .semibold))
                    Text("\(entry.totalVotes) votes").foregroundStyle(.secondary).font(.system(size: 11))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(rank <= 3 ? 0.8 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
