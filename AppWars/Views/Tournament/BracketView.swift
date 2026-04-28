import SwiftUI
import Kingfisher

/// Split tournament bracket — top half grows down, bottom half grows up,
/// finals and champion displayed in the center. Matches the original
/// canvas-based web bracket layout.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    var body: some View {
        let rounds = Dictionary(grouping: matchups, by: \.round)
            .sorted { $0.key < $1.key }

        if matchups.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(.gray.opacity(0.3))
                Text("Bracket not available yet")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(rounds, id: \.key) { round, roundMatchups in
                            let sorted = roundMatchups.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
                            let isFinal = round == rounds.last?.key
                            let isFirst = round == rounds.first?.key

                            VStack(spacing: 0) {
                                // Round label
                                Text(isFinal ? "FINALS" : "ROUND \(round)")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(isFinal ? .yellow : .secondary)
                                    .padding(.bottom, 12)

                                if isFinal && sorted.count == 1 {
                                    // Finals: show as a centered special card
                                    FinalMatchCard(matchup: sorted[0])
                                } else {
                                    // Regular rounds
                                    VStack(spacing: roundSpacing(round, totalRounds: rounds.count)) {
                                        ForEach(sorted) { matchup in
                                            BracketMatchNode(matchup: matchup)
                                        }
                                    }
                                }
                            }
                            .frame(width: 260)

                            // Connector lines between rounds
                            if !isFinal {
                                ConnectorLines(
                                    matchCount: sorted.count,
                                    spacing: roundSpacing(round, totalRounds: rounds.count)
                                )
                                .frame(width: 28)
                            }
                        }

                        // Champion display
                        if let finalMatch = matchups.first(where: { $0.round == (rounds.last?.key ?? 0) }),
                           let winnerName = finalMatch.winnerUsername {
                            ChampionBadge(
                                name: winnerName,
                                winnerId: finalMatch.winnerId,
                                matchups: matchups
                            )
                            .frame(width: 140)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    func roundSpacing(_ round: Int, totalRounds: Int) -> CGFloat {
        let base: CGFloat = 12
        return base + CGFloat(round - 1) * 60
    }
}

// MARK: - Bracket Match Node
struct BracketMatchNode: View {
    let matchup: Matchup
    @State private var showDetail = false

    var totalVotes: Int { matchup.votesA + matchup.votesB }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                PlayerSlot(
                    name: matchup.participantAUsername ?? "TBD",
                    votes: matchup.votesA,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantAScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantAId,
                    isTop: true
                )

                Divider().background(Color.yellow.opacity(0.15))

                PlayerSlot(
                    name: matchup.participantBUsername ?? "TBD",
                    votes: matchup.votesB,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantBScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantBId,
                    isTop: false
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        matchup.status == "voting"
                            ? Color.yellow.opacity(0.5)
                            : Color.white.opacity(0.08),
                        lineWidth: matchup.status == "voting" ? 1.5 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupDetailSheet(matchup: matchup)
        }
    }
}

// MARK: - Player Slot (single row in bracket)
struct PlayerSlot: View {
    let name: String
    let votes: Int
    let totalVotes: Int
    let screenshotUrl: String?
    let isWinner: Bool
    let isTop: Bool

    var votePct: CGFloat {
        totalVotes > 0 ? CGFloat(votes) / CGFloat(totalVotes) : 0
    }

    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.yellow.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                    )
            }

            // Name
            Text(name)
                .font(.system(size: 12, weight: isWinner ? .bold : .medium))
                .foregroundStyle(isWinner ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 2)

            // Votes
            if totalVotes > 0 {
                Text("\(votes)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isWinner ? .yellow : .secondary)
                    .frame(minWidth: 24)
            }

            // Winner crown
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                if totalVotes > 0 {
                    Rectangle()
                        .fill(isWinner ? Color.yellow.opacity(0.06) : Color.clear)
                        .frame(width: geo.size.width * votePct)
                }
            }
        )
    }
}

// MARK: - Finals Match Card
struct FinalMatchCard: View {
    let matchup: Matchup
    @State private var showDetail = false

    var totalVotes: Int { matchup.votesA + matchup.votesB }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                // "CHAMPIONSHIP" banner
                Text("⚔️ CHAMPIONSHIP")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.yellow)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.08))

                PlayerSlot(
                    name: matchup.participantAUsername ?? "TBD",
                    votes: matchup.votesA,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantAScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantAId,
                    isTop: true
                )

                HStack(spacing: 6) {
                    Rectangle().fill(Color.yellow.opacity(0.2)).frame(height: 0.5)
                    Text("VS").font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.yellow.opacity(0.5))
                    Rectangle().fill(Color.yellow.opacity(0.2)).frame(height: 0.5)
                }
                .padding(.horizontal, 10)

                PlayerSlot(
                    name: matchup.participantBUsername ?? "TBD",
                    votes: matchup.votesB,
                    totalVotes: totalVotes,
                    screenshotUrl: matchup.participantBScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantBId,
                    isTop: false
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .yellow.opacity(0.15), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupDetailSheet(matchup: matchup)
        }
    }
}

// MARK: - Connector Lines
struct ConnectorLines: View {
    let matchCount: Int
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let slotHeight: CGFloat = 76
            let totalHeight = CGFloat(matchCount) * slotHeight + CGFloat(matchCount - 1) * spacing
            let startY = (size.height - totalHeight) / 2

            let color = Color.yellow.opacity(0.25)

            for i in stride(from: 0, to: matchCount, by: 2) {
                let topMidY = startY + CGFloat(i) * (slotHeight + spacing) + slotHeight / 2
                let bottomMidY = startY + CGFloat(i + 1) * (slotHeight + spacing) + slotHeight / 2
                let mergeY = (topMidY + bottomMidY) / 2

                var path = Path()
                // Top arm
                path.move(to: CGPoint(x: 0, y: topMidY))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: topMidY))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: mergeY))
                // Bottom arm
                path.move(to: CGPoint(x: 0, y: bottomMidY))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: bottomMidY))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: mergeY))
                // Output
                path.move(to: CGPoint(x: size.width * 0.5, y: mergeY))
                path.addLine(to: CGPoint(x: size.width, y: mergeY))

                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Champion Badge
struct ChampionBadge: View {
    let name: String
    let winnerId: UUID?
    let matchups: [Matchup]

    var body: some View {
        VStack(spacing: 8) {
            // Crown
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.5), radius: 8)

            // Avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 2)
                    )
            }

            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)

            Text("CHAMPION")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.yellow.opacity(0.6))
        }
    }
}
