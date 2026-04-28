import SwiftUI
import Kingfisher

/// Vote Now tab — shows all current round matchups with voting UI.
struct VoteNowTab: View {
    let tournament: Tournament
    let matchups: [Matchup]
    @EnvironmentObject var auth: AuthService

    var currentRoundMatchups: [Matchup] {
        matchups.filter { $0.round == tournament.currentRound && $0.status == "voting" }
            .sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
    }

    var tiebreakerMatchups: [Matchup] {
        matchups.filter {
            $0.status == "voting" && $0.votesA == $0.votesB && $0.votesA > 0
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !tiebreakerMatchups.isEmpty {
                    TiebreakerBannerView(count: tiebreakerMatchups.count)
                }

                if currentRoundMatchups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(.green.opacity(0.5))
                        Text("No active votes right now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if tournament.isCompleted {
                            Text("Tournament complete!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(currentRoundMatchups) { matchup in
                        VoteMatchupCard(matchup: matchup, tournament: tournament)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Vote Matchup Card
struct VoteMatchupCard: View {
    let matchup: Matchup
    let tournament: Tournament
    @EnvironmentObject var auth: AuthService
    @State private var showDetail = false
    @State private var hasVoted = false
    @State private var votedFor: UUID?

    var totalVotes: Int { matchup.votesA + matchup.votesB }
    var pctA: Double { totalVotes > 0 ? Double(matchup.votesA) / Double(totalVotes) : 0.5 }
    var pctB: Double { totalVotes > 0 ? Double(matchup.votesB) / Double(totalVotes) : 0.5 }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                // Category header
                if let cat = matchup.category {
                    Text(cat)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }

                HStack(spacing: 0) {
                    // Side A
                    EntrantSide(
                        name: matchup.participantAUsername ?? "TBD",
                        screenshotUrl: matchup.participantAScreenshotUrl,
                        votes: matchup.votesA,
                        pct: pctA,
                        isWinner: matchup.winnerId == matchup.participantAId,
                        voted: votedFor == matchup.participantAId
                    )

                    // VS
                    VStack {
                        Text("VS")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .frame(width: 36)

                    // Side B
                    EntrantSide(
                        name: matchup.participantBUsername ?? "TBD",
                        screenshotUrl: matchup.participantBScreenshotUrl,
                        votes: matchup.votesB,
                        pct: pctB,
                        isWinner: matchup.winnerId == matchup.participantBId,
                        voted: votedFor == matchup.participantBId
                    )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)

                // Vote bar
                if totalVotes > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geo.size.width * pctA)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geo.size.width * pctB)
                        }
                    }
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupVotingSheet(matchup: matchup, tournament: tournament)
        }
        .task { await checkVoted() }
    }

    func checkVoted() async {
        guard let email = auth.profile?.email else { return }
        do {
            let votes: [VoteRecord] = try await supabase.from("votes")
                .select()
                .eq("matchup_id", value: matchup.id.uuidString)
                .eq("voter_fingerprint", value: email)
                .execute()
                .value
            if let vote = votes.first {
                hasVoted = true
                votedFor = vote.votedForId
            }
        } catch {}
    }
}

struct VoteRecord: Codable {
    let id: UUID
    let votedForId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case votedForId = "voted_for_id"
    }
}

// MARK: - Entrant Side
struct EntrantSide: View {
    let name: String
    let screenshotUrl: String?
    let votes: Int
    let pct: Double
    let isWinner: Bool
    let voted: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Screenshot
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 80)
                    .overlay(
                        Text("No submission")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    )
            }

            Text(name)
                .font(.system(size: 12, weight: isWinner ? .bold : .medium))
                .lineLimit(1)

            HStack(spacing: 4) {
                Text("\(votes)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("(\(Int(pct * 100))%)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if voted {
                Text("Your vote ✓")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tiebreaker Banner
struct TiebreakerBannerView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) tiebreaker\(count > 1 ? "s" : "") needed!")
                    .font(.system(size: 13, weight: .bold))
                Text("Your vote decides the winner")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
    }
}
