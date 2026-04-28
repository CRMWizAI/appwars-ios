import SwiftUI
import Kingfisher

/// Full tournament bracket — horizontal scroll through rounds,
/// connected matchup cards with lines showing advancement path.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    var body: some View {
        let rounds = Dictionary(grouping: matchups, by: \.round)
            .sorted { $0.key < $1.key }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(rounds, id: \.key) { round, roundMatchups in
                    VStack(spacing: 0) {
                        // Round header
                        RoundHeader(
                            round: round,
                            totalRounds: tournament.totalRounds ?? rounds.count,
                            category: round == rounds.last?.key ? tournament.currentCategory : nil,
                            isFinal: round == (tournament.totalRounds ?? rounds.count)
                        )

                        // Matchup cards with spacing that grows per round
                        let spacing = spacingForRound(round, in: rounds.count)
                        VStack(spacing: spacing) {
                            ForEach(roundMatchups.sorted(by: { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) })) { matchup in
                                BracketMatchupCard(matchup: matchup)
                            }
                        }
                        .padding(.top, topPaddingForRound(round, in: rounds.count))
                    }
                    .frame(width: 280)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    func spacingForRound(_ round: Int, in totalRounds: Int) -> CGFloat {
        switch round {
        case 1: return 16
        case 2: return 80
        case 3: return 160
        default: return CGFloat(round - 1) * 80
        }
    }

    func topPaddingForRound(_ round: Int, in totalRounds: Int) -> CGFloat {
        switch round {
        case 1: return 0
        case 2: return 48
        case 3: return 112
        default: return CGFloat(round - 1) * 56
        }
    }
}

// MARK: - Round Header
struct RoundHeader: View {
    let round: Int
    let totalRounds: Int
    let category: String?
    let isFinal: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(isFinal ? "FINALS" : "ROUND \(round)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(isFinal ? .yellow : .secondary)

            if let category = category {
                Text(category)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Bracket Matchup Card
struct BracketMatchupCard: View {
    let matchup: Matchup
    @State private var showDetail = false

    var totalVotes: Int { matchup.votesA + matchup.votesB }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                // Player A
                PlayerRow(
                    name: matchup.participantAUsername ?? "TBD",
                    votes: matchup.votesA,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantAScreenshotUrl,
                    isWinner: matchup.winnerId != nil && matchup.winnerId == matchup.participantAId,
                    isLoser: matchup.winnerId != nil && matchup.winnerId != matchup.participantAId,
                    isTop: true
                )

                // VS divider
                HStack(spacing: 8) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    Text("VS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                }
                .padding(.horizontal, 12)

                // Player B
                PlayerRow(
                    name: matchup.participantBUsername ?? "TBD",
                    votes: matchup.votesB,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantBScreenshotUrl,
                    isWinner: matchup.winnerId != nil && matchup.winnerId == matchup.participantBId,
                    isLoser: matchup.winnerId != nil && matchup.winnerId != matchup.participantBId,
                    isTop: false
                )
            }
            .background(Color(.secondarySystemBackground).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        matchup.status == "voting" ? Color.yellow.opacity(0.4) : Color.white.opacity(0.06),
                        lineWidth: matchup.status == "voting" ? 1.5 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupDetailSheet(matchup: matchup)
        }
    }
}

// MARK: - Player Row
struct PlayerRow: View {
    let name: String
    let votes: Int
    let totalVotes: Int
    let screenshotUrl: String?
    let isWinner: Bool
    let isLoser: Bool
    let isTop: Bool

    var votePct: Double {
        totalVotes > 0 ? Double(votes) / Double(totalVotes) : 0
    }

    var body: some View {
        HStack(spacing: 10) {
            // Avatar or screenshot thumbnail
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                    )
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: isWinner ? .bold : .medium))
                    .foregroundStyle(isLoser ? .secondary : .primary)
                    .lineLimit(1)

                if totalVotes > 0 {
                    // Vote bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            Capsule()
                                .fill(isWinner ? Color.yellow : Color.white.opacity(0.3))
                                .frame(width: geo.size.width * votePct, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }

            Spacer(minLength: 4)

            // Vote count
            if totalVotes > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(votes)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(isWinner ? .yellow : .secondary)
                    Text("\(Int(votePct * 100))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Winner indicator
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Matchup Detail Sheet
struct MatchupDetailSheet: View {
    let matchup: Matchup
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let category = matchup.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Player A
                    SubmissionCard(
                        name: matchup.participantAUsername ?? "TBD",
                        screenshotUrl: matchup.participantAScreenshotUrl,
                        submissionUrl: matchup.participantASubmissionUrl,
                        description: matchup.participantADescription,
                        votes: matchup.votesA,
                        isWinner: matchup.winnerId == matchup.participantAId
                    )

                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)

                    // Player B
                    SubmissionCard(
                        name: matchup.participantBUsername ?? "TBD",
                        screenshotUrl: matchup.participantBScreenshotUrl,
                        submissionUrl: matchup.participantBSubmissionUrl,
                        description: matchup.participantBDescription,
                        votes: matchup.votesB,
                        isWinner: matchup.winnerId == matchup.participantBId
                    )
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Round \(matchup.round)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct SubmissionCard: View {
    let name: String
    let screenshotUrl: String?
    let submissionUrl: String?
    let description: String?
    let votes: Int
    let isWinner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Screenshot
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.headline)
                        if isWinner {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                    Text("\(votes) votes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = submissionUrl, let link = URL(string: url) {
                    Link(destination: link) {
                        Text("View App")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
            }

            if let desc = description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isWinner ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}
