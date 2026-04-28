import SwiftUI
import Kingfisher

/// True visual tournament bracket — golden bracket arms with circular
/// avatar nodes, split top/bottom with champion centered.
/// Matches the original web canvas-based bracket.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    // Layout constants matching original
    let avatarSize: CGFloat = 44
    let lineColor = Color(red: 0.83, green: 0.66, blue: 0.04) // #d4a80b gold

    var body: some View {
        let rounds = Dictionary(grouping: matchups, by: \.round)
            .sorted { $0.key < $1.key }
        let totalRounds = rounds.count

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
            GeometryReader { geo in
                let width = max(geo.size.width, CGFloat(totalRounds + 1) * 120)
                let height = max(geo.size.height, 500)

                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // Draw bracket lines
                        BracketLines(rounds: rounds, width: width, height: height, avatarSize: avatarSize, lineColor: lineColor)

                        // Place avatar nodes
                        ForEach(rounds, id: \.key) { round, roundMatchups in
                            let sorted = roundMatchups.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
                            let roundIndex = round - (rounds.first?.key ?? 1)
                            let x = xForRound(roundIndex, totalRounds: totalRounds, width: width)

                            ForEach(Array(sorted.enumerated()), id: \.element.id) { matchIndex, matchup in
                                let positions = avatarPositions(
                                    round: roundIndex, matchIndex: matchIndex,
                                    matchCount: sorted.count, totalRounds: totalRounds,
                                    width: width, height: height
                                )

                                // Player A
                                AvatarNode(
                                    name: matchup.participantAUsername ?? "?",
                                    avatarUrl: matchup.participantAScreenshotUrl,
                                    isWinner: matchup.winnerId == matchup.participantAId,
                                    isEliminated: matchup.winnerId != nil && matchup.winnerId != matchup.participantAId,
                                    size: avatarSize
                                )
                                .position(positions.a)

                                // Player B
                                AvatarNode(
                                    name: matchup.participantBUsername ?? "?",
                                    avatarUrl: matchup.participantBScreenshotUrl,
                                    isWinner: matchup.winnerId == matchup.participantBId,
                                    isEliminated: matchup.winnerId != nil && matchup.winnerId != matchup.participantBId,
                                    size: avatarSize
                                )
                                .position(positions.b)
                            }
                        }

                        // Champion in center
                        if let finalMatch = rounds.last?.value.first,
                           let winnerName = finalMatch.winnerUsername {
                            let cx = xForRound(totalRounds, totalRounds: totalRounds, width: width)
                            let cy = height / 2

                            VStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.yellow)
                                    .shadow(color: .yellow.opacity(0.6), radius: 8)

                                ZStack {
                                    // Glow
                                    Circle()
                                        .fill(RadialGradient(
                                            colors: [.yellow.opacity(0.3), .clear],
                                            center: .center, startRadius: 20, endRadius: 50
                                        ))
                                        .frame(width: 80, height: 80)

                                    Circle()
                                        .fill(Color.yellow.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Text(String(winnerName.prefix(2)).uppercased())
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundStyle(.yellow)
                                        )
                                        .overlay(
                                            Circle().strokeBorder(Color.yellow, lineWidth: 2.5)
                                        )
                                }

                                Text(winnerName)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.yellow)

                                Text("CHAMPION")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .tracking(2)
                                    .foregroundStyle(.yellow.opacity(0.6))
                            }
                            .position(x: cx, y: cy)
                        }
                    }
                    .frame(width: width, height: height)
                }
            }
        }
    }

    func xForRound(_ roundIndex: Int, totalRounds: Int, width: CGFloat) -> CGFloat {
        let padding: CGFloat = 50
        let usable = width - padding * 2
        let step = usable / CGFloat(totalRounds)
        return padding + CGFloat(roundIndex) * step + step / 2
    }

    struct AvatarPositions {
        let a: CGPoint
        let b: CGPoint
    }

    func avatarPositions(round: Int, matchIndex: Int, matchCount: Int, totalRounds: Int, width: CGFloat, height: CGFloat) -> AvatarPositions {
        let x = xForRound(round, totalRounds: totalRounds, width: width)
        let padding: CGFloat = 60
        let usableHeight = height - padding * 2
        let gap: CGFloat = 50 // gap between the two players in a matchup

        // Spacing grows exponentially per round
        let blockHeight = usableHeight / CGFloat(matchCount)
        let centerY = padding + blockHeight * CGFloat(matchIndex) + blockHeight / 2

        let aY = centerY - gap / 2
        let bY = centerY + gap / 2

        return AvatarPositions(a: CGPoint(x: x, y: aY), b: CGPoint(x: x, y: bY))
    }
}

// MARK: - Avatar Node
struct AvatarNode: View {
    let name: String
    let avatarUrl: String?
    let isWinner: Bool
    let isEliminated: Bool
    let size: CGFloat

    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Ring
                Circle()
                    .strokeBorder(
                        isWinner ? Color.yellow : isEliminated ? Color.gray.opacity(0.3) : Color.white.opacity(0.3),
                        lineWidth: isWinner ? 2.5 : 1.5
                    )
                    .frame(width: size, height: size)

                if let url = avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                        .opacity(isEliminated ? 0.4 : 1)
                } else {
                    Circle()
                        .fill(isWinner ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.15))
                        .frame(width: size - 4, height: size - 4)
                        .overlay(
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                                .foregroundStyle(isWinner ? .yellow : .white.opacity(isEliminated ? 0.3 : 0.7))
                        )
                }

                // Winner crown
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                        .offset(y: -(size / 2 + 6))
                }
            }

            Text(name.count > 8 ? String(name.prefix(7)) + "…" : name)
                .font(.system(size: 9, weight: isWinner ? .bold : .medium))
                .foregroundColor(isEliminated ? .gray : .white)
                .lineLimit(1)
        }
    }
}

// MARK: - Bracket Lines (Canvas)
struct BracketLines: View {
    let rounds: [(key: Int, value: [Matchup])]
    let width: CGFloat
    let height: CGFloat
    let avatarSize: CGFloat
    let lineColor: Color

    var body: some View {
        Canvas { context, size in
            let totalRounds = rounds.count
            let padding: CGFloat = 50
            let usableWidth = width - padding * 2
            let step = usableWidth / CGFloat(totalRounds)
            let usableHeight = height - 120

            for (roundIdx, roundData) in rounds.enumerated() {
                let sorted = roundData.value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
                let matchCount = sorted.count
                let x = padding + CGFloat(roundIdx) * step + step / 2

                let blockHeight = usableHeight / CGFloat(matchCount)
                let gap: CGFloat = 50

                for matchIndex in 0..<matchCount {
                    let centerY = 60 + blockHeight * CGFloat(matchIndex) + blockHeight / 2
                    let aY = centerY - gap / 2
                    let bY = centerY + gap / 2

                    // Vertical line connecting the pair
                    var pairLine = Path()
                    pairLine.move(to: CGPoint(x: x, y: aY + avatarSize / 2 + 2))
                    pairLine.addLine(to: CGPoint(x: x, y: bY - avatarSize / 2 - 2))
                    context.stroke(pairLine, with: .color(lineColor.opacity(0.4)), lineWidth: 1.5)

                    // Horizontal + merge line to next round
                    if roundIdx < totalRounds - 1 {
                        let nextX = padding + CGFloat(roundIdx + 1) * step + step / 2
                        let nextSorted = rounds[roundIdx + 1].value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
                        let nextMatchCount = nextSorted.count
                        let nextBlockHeight = usableHeight / CGFloat(nextMatchCount)
                        let nextMatchIndex = matchIndex / 2
                        let nextCenterY = 60 + nextBlockHeight * CGFloat(nextMatchIndex) + nextBlockHeight / 2

                        // Determine which side of next match this connects to
                        let isTopOfPair = matchIndex % 2 == 0
                        let nextGap: CGFloat = 50
                        let nextTargetY = isTopOfPair ? nextCenterY - nextGap / 2 : nextCenterY + nextGap / 2

                        // Draw horizontal line from pair center to next round
                        let midX = (x + nextX) / 2
                        var connector = Path()
                        connector.move(to: CGPoint(x: x + avatarSize / 2 + 4, y: centerY))
                        connector.addLine(to: CGPoint(x: midX, y: centerY))
                        connector.addLine(to: CGPoint(x: midX, y: nextTargetY))
                        connector.addLine(to: CGPoint(x: nextX - avatarSize / 2 - 4, y: nextTargetY))
                        context.stroke(connector, with: .color(lineColor.opacity(0.3)), lineWidth: 1.5)
                    }

                    // Line from finals to champion
                    if roundIdx == totalRounds - 1 {
                        let champX = padding + CGFloat(totalRounds) * step + step / 2
                        var champLine = Path()
                        champLine.move(to: CGPoint(x: x + avatarSize / 2 + 4, y: centerY))
                        champLine.addLine(to: CGPoint(x: champX - 40, y: height / 2))
                        context.stroke(champLine, with: .color(lineColor.opacity(0.3)), lineWidth: 1.5)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}
