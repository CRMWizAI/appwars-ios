import SwiftUI

struct LeaderboardView: View {
    @State private var participants: [Participant] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ForEach(0..<10, id: \.self) { _ in
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 10)
                            }
                        }
                    }
                } else {
                    ForEach(Array(participants.enumerated()), id: \.element.id) { index, p in
                        HStack(spacing: 12) {
                            // Rank
                            ZStack {
                                if index < 3 {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(index == 0 ? .yellow : index == 1 ? .gray : .orange)
                                }
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(index < 3 ? .clear : .secondary)
                            }
                            .frame(width: 32)

                            // Avatar placeholder
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(p.discordUsername.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.yellow)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.discordUsername)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 8) {
                                    Text("\(p.matchesWon)W")
                                        .foregroundStyle(.green)
                                    Text("\(p.matchesLost)L")
                                        .foregroundStyle(.red)
                                    Text("\(p.totalVotesReceived) votes")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption2)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .refreshable { await loadLeaderboard() }
            .task { await loadLeaderboard() }
        }
    }

    func loadLeaderboard() async {
        do {
            let response: [Participant] = try await supabase.from("participants")
                .select()
                .order("matches_won", ascending: false)
                .limit(50)
                .execute()
                .value
            participants = response
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
        loading = false
    }
}
