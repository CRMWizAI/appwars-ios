import SwiftUI
import Kingfisher

/// Vertical split bracket — top half grows downward, bottom half grows
/// upward, champion centered. Matches the original web bracket exactly.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    let avatarSize: CGFloat = 46
    let goldColor = Color(red: 0.83, green: 0.66, blue: 0.04)

    var body: some View {
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
            let rounds = Dictionary(grouping: matchups, by: \.round)
                .sorted { $0.key < $1.key }
            let r1 = rounds.first?.value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } ?? []

            // Split R1 matchups: top half and bottom half
            let topR1 = Array(r1.prefix(r1.count / 2))
            let bottomR1 = Array(r1.suffix(r1.count / 2))

            // R2 (semis)
            let r2 = rounds.count > 1 ? rounds[1].value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } : []
            let topR2 = r2.isEmpty ? nil : r2.first
            let bottomR2 = r2.count > 1 ? r2.last : nil

            // Finals
            let finals = rounds.count > 2 ? rounds[2].value.first : (rounds.count == 2 ? rounds[1].value.first : nil)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── TOP HALF (grows downward) ──
                    TopBracketHalf(
                        r1Matchups: topR1,
                        r2Matchup: topR2,
                        avatarSize: avatarSize,
                        goldColor: goldColor
                    )

                    // ── CHAMPION CENTER ──
                    ChampionCenter(
                        finals: finals,
                        avatarSize: avatarSize,
                        goldColor: goldColor
                    )
                    .padding(.vertical, 10)

                    // ── BOTTOM HALF (grows upward, so reversed) ──
                    BottomBracketHalf(
                        r1Matchups: bottomR1,
                        r2Matchup: bottomR2,
                        avatarSize: avatarSize,
                        goldColor: goldColor
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Top Bracket Half
struct TopBracketHalf: View {
    let r1Matchups: [Matchup]
    let r2Matchup: Matchup?
    let avatarSize: CGFloat
    let goldColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // R1 matchups side by side
            HStack(alignment: .top, spacing: 20) {
                ForEach(r1Matchups) { matchup in
                    BracketPair(matchup: matchup, avatarSize: avatarSize, goldColor: goldColor)
                }
            }

            // Bracket arms merging down
            BracketMergeDown(count: r1Matchups.count, goldColor: goldColor)
                .frame(height: 40)

            // R2 (semifinal) — winner avatars
            if let semi = r2Matchup {
                BracketPair(matchup: semi, avatarSize: avatarSize, goldColor: goldColor)

                // Line down to champion
                Rectangle()
                    .fill(goldColor.opacity(0.5))
                    .frame(width: 2, height: 30)
            }
        }
    }
}

// MARK: - Bottom Bracket Half (mirrored)
struct BottomBracketHalf: View {
    let r1Matchups: [Matchup]
    let r2Matchup: Matchup?
    let avatarSize: CGFloat
    let goldColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // Line up from champion
            if let semi = r2Matchup {
                Rectangle()
                    .fill(goldColor.opacity(0.5))
                    .frame(width: 2, height: 30)

                BracketPair(matchup: semi, avatarSize: avatarSize, goldColor: goldColor)
            }

            // Bracket arms merging up
            BracketMergeUp(count: r1Matchups.count, goldColor: goldColor)
                .frame(height: 40)

            // R1 matchups side by side
            HStack(alignment: .bottom, spacing: 20) {
                ForEach(r1Matchups) { matchup in
                    BracketPair(matchup: matchup, avatarSize: avatarSize, goldColor: goldColor)
                }
            }
        }
    }
}

// MARK: - Bracket Pair (two players in a matchup)
struct BracketPair: View {
    let matchup: Matchup
    let avatarSize: CGFloat
    let goldColor: Color

    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                // Player A
                PlayerAvatar(
                    name: matchup.participantAUsername ?? "?",
                    avatarUrl: matchup.participantAScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantAId,
                    isEliminated: matchup.winnerId != nil && matchup.winnerId != matchup.participantAId,
                    size: avatarSize
                )

                // Vertical bracket line connecting pair
                Rectangle()
                    .fill(goldColor.opacity(0.5))
                    .frame(width: 2, height: 20)

                // Horizontal crossbar
                Rectangle()
                    .fill(goldColor.opacity(0.5))
                    .frame(width: avatarSize + 40, height: 2)

                // Vertical bracket line
                Rectangle()
                    .fill(goldColor.opacity(0.5))
                    .frame(width: 2, height: 20)

                // Player B
                PlayerAvatar(
                    name: matchup.participantBUsername ?? "?",
                    avatarUrl: matchup.participantBScreenshotUrl,
                    isWinner: matchup.winnerId == matchup.participantBId,
                    isEliminated: matchup.winnerId != nil && matchup.winnerId != matchup.participantBId,
                    size: avatarSize
                )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MatchupDetailSheet(matchup: matchup)
        }
    }
}

// MARK: - Player Avatar
struct PlayerAvatar: View {
    let name: String
    let avatarUrl: String?
    let isWinner: Bool
    let isEliminated: Bool
    let size: CGFloat

    var ringColor: Color {
        isWinner ? Color(red: 0.83, green: 0.66, blue: 0.04) : isEliminated ? .gray.opacity(0.3) : .white.opacity(0.3)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Glow for winner
                if isWinner {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: size + 12, height: size + 12)
                }

                Circle()
                    .strokeBorder(ringColor, lineWidth: isWinner ? 3 : 1.5)
                    .frame(width: size, height: size)

                if let url = avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                        .opacity(isEliminated ? 0.35 : 1)
                } else {
                    Circle()
                        .fill(randomColor(for: name).opacity(isEliminated ? 0.15 : 0.3))
                        .frame(width: size - 4, height: size - 4)
                        .overlay(
                            Text(initials(name))
                                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                                .foregroundColor(isEliminated ? .gray : randomColor(for: name))
                        )
                }

                // Crown for winner
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 4)
                        .offset(y: -(size / 2 + 8))
                }
            }

            Text(name.count > 10 ? String(name.prefix(9)) + "…" : name)
                .font(.system(size: 10, weight: isWinner ? .bold : .medium))
                .foregroundColor(isEliminated ? .gray.opacity(0.5) : .white)
                .lineLimit(1)
        }
    }

    func initials(_ name: String) -> String {
        String(name.prefix(2)).uppercased()
    }

    func randomColor(for name: String) -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Champion Center
struct ChampionCenter: View {
    let finals: Matchup?
    let avatarSize: CGFloat
    let goldColor: Color

    var body: some View {
        if let finals = finals, let winnerName = finals.winnerUsername {
            VStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 12)

                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.yellow.opacity(0.25), .clear],
                            center: .center, startRadius: 25, endRadius: 60
                        ))
                        .frame(width: 100, height: 100)

                    Circle()
                        .strokeBorder(goldColor, lineWidth: 3)
                        .frame(width: 68, height: 68)

                    // Try to find winner's avatar from the matchup
                    let winnerAvatar = finals.winnerId == finals.participantAId
                        ? finals.participantAScreenshotUrl
                        : finals.participantBScreenshotUrl

                    if let url = winnerAvatar, let imageURL = URL(string: url) {
                        KFImage(imageURL)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 62, height: 62)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 62, height: 62)
                            .overlay(
                                Text(String(winnerName.prefix(2)).uppercased())
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.yellow)
                            )
                    }
                }

                Text(winnerName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)

                Text("CHAMPION")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.yellow.opacity(0.5))
            }
        } else if let finals = finals {
            // Finals not decided yet
            VStack(spacing: 8) {
                Text("⚔️")
                    .font(.system(size: 32))
                Text("FINALS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(goldColor)
            }
        }
    }
}

// MARK: - Bracket Merge Lines (going down)
struct BracketMergeDown: View {
    let count: Int
    let goldColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let segmentWidth = w / CGFloat(max(count, 1))

            Canvas { context, size in
                for i in 0..<count {
                    let centerX = segmentWidth * CGFloat(i) + segmentWidth / 2

                    // Line from each matchup down
                    var path = Path()
                    path.move(to: CGPoint(x: centerX, y: 0))
                    path.addLine(to: CGPoint(x: centerX, y: h * 0.5))
                    // Merge to center
                    path.addLine(to: CGPoint(x: w / 2, y: h * 0.5))
                    context.stroke(path, with: .color(goldColor.opacity(0.5)), lineWidth: 2)
                }
                // Center line down
                var center = Path()
                center.move(to: CGPoint(x: w / 2, y: h * 0.5))
                center.addLine(to: CGPoint(x: w / 2, y: h))
                context.stroke(center, with: .color(goldColor.opacity(0.5)), lineWidth: 2)
            }
        }
    }
}

// MARK: - Bracket Merge Lines (going up)
struct BracketMergeUp: View {
    let count: Int
    let goldColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let segmentWidth = w / CGFloat(max(count, 1))

            Canvas { context, size in
                // Center line from top
                var center = Path()
                center.move(to: CGPoint(x: w / 2, y: 0))
                center.addLine(to: CGPoint(x: w / 2, y: h * 0.5))
                context.stroke(center, with: .color(goldColor.opacity(0.5)), lineWidth: 2)

                for i in 0..<count {
                    let centerX = segmentWidth * CGFloat(i) + segmentWidth / 2

                    var path = Path()
                    // From center merge point
                    path.move(to: CGPoint(x: w / 2, y: h * 0.5))
                    path.addLine(to: CGPoint(x: centerX, y: h * 0.5))
                    // Down to matchup
                    path.addLine(to: CGPoint(x: centerX, y: h))
                    context.stroke(path, with: .color(goldColor.opacity(0.5)), lineWidth: 2)
                }
            }
        }
    }
}
