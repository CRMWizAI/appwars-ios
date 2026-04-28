import SwiftUI
import Kingfisher

/// Temporary simple bracket list while Canvas bracket is being fixed.
/// Shows rounds with matchup cards — functional, just not the fancy bracket tree.
struct SimpleBracketList: View {
    let matchups: [Matchup]
    let tournament: Tournament

    var rounds: [(key: Int, value: [Matchup])] {
        Dictionary(grouping: matchups, by: \.round)
            .sorted { $0.key < $1.key }
    }

    // Find champion
    var champion: (name: String, avatarUrl: String?)? {
        guard let finals = matchups.first(where: { $0.round == (tournament.totalRounds ?? 3) }),
              let winnerName = finals.winnerUsername else { return nil }
        let avatarUrl = finals.winnerId == finals.participantAId
            ? finals.participantAScreenshotUrl
            : finals.participantBScreenshotUrl
        return (winnerName, avatarUrl)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Champion banner
                if let champ = champion {
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.6), radius: 8)

                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 70, height: 70)

                            if let url = champ.avatarUrl, let imageURL = URL(string: url) {
                                KFImage(imageURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 2.5))
                            } else {
                                Circle()
                                    .fill(Color.yellow.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Text(String(champ.name.prefix(2)).uppercased())
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundStyle(.yellow)
                                    )
                                    .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 2.5))
                            }
                        }

                        Text(champ.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text("CHAMPION")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.yellow.opacity(0.5))
                    }
                    .padding(.vertical, 12)
                }

                // Rounds
                ForEach(rounds, id: \.key) { round, roundMatchups in
                    VStack(alignment: .leading, spacing: 8) {
                        let isFinal = round == (tournament.totalRounds ?? rounds.count)
                        Text(isFinal ? "⚔️ FINALS" : "ROUND \(round)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(isFinal ? .yellow : .secondary)

                        ForEach(roundMatchups.sorted(by: { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) })) { matchup in
                            BracketMatchCard(matchup: matchup)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Bracket Match Card
struct BracketMatchCard: View {
    let matchup: Matchup
    @State private var showDetail = false

    var totalVotes: Int { matchup.votesA + matchup.votesB }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                PlayerRow2(
                    name: matchup.participantAUsername ?? "TBD",
                    screenshotUrl: matchup.participantAScreenshotUrl,
                    votes: matchup.votesA,
                    totalVotes: totalVotes,
                    isWinner: matchup.winnerId == matchup.participantAId
                )

                HStack(spacing: 8) {
                    Rectangle().fill(Color.yellow.opacity(0.15)).frame(height: 0.5)
                    Text("VS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Rectangle().fill(Color.yellow.opacity(0.15)).frame(height: 0.5)
                }
                .padding(.horizontal, 12)

                PlayerRow2(
                    name: matchup.participantBUsername ?? "TBD",
                    screenshotUrl: matchup.participantBScreenshotUrl,
                    votes: matchup.votesB,
                    totalVotes: totalVotes,
                    isWinner: matchup.winnerId == matchup.participantBId
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupDetailSheet(matchup: matchup)
        }
    }
}

struct PlayerRow2: View {
    let name: String
    let screenshotUrl: String?
    let votes: Int
    let totalVotes: Int
    let isWinner: Bool

    var pct: CGFloat { totalVotes > 0 ? CGFloat(votes) / CGFloat(totalVotes) : 0 }

    func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        return colors[abs(name.hashValue) % colors.count]
    }

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(colorForName(name).opacity(0.25))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(name.prefix(2)).uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(colorForName(name))
                    )
            }

            Text(name)
                .font(.system(size: 13, weight: isWinner ? .bold : .medium))
                .foregroundColor(isWinner ? .white : .gray)
                .lineLimit(1)

            Spacer(minLength: 4)

            if totalVotes > 0 {
                Text("\(votes)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isWinner ? .yellow : .gray)

                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            GeometryReader { geo in
                if totalVotes > 0 && isWinner {
                    Rectangle()
                        .fill(Color.yellow.opacity(0.05))
                        .frame(width: geo.size.width * pct)
                }
            }
        )
    }
}
