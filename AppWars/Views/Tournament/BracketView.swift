import SwiftUI
import Kingfisher

/// Bracket view using native SwiftUI layout (no Canvas, no absolute positioning).
/// Renders the split bracket visually using VStacks/HStacks with connecting lines.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    private let gold = Color(red: 212/255, green: 168/255, blue: 11/255)
    private let avatarSize: CGFloat = 40

    var rounds: [(key: Int, value: [Matchup])] {
        Dictionary(grouping: matchups, by: \.round)
            .sorted { $0.key < $1.key }
    }

    var champion: (name: String, avatarUrl: String?)? {
        guard let finals = rounds.last?.value.first,
              let winnerName = finals.winnerUsername else { return nil }
        let avatarUrl = finals.winnerId == finals.participantAId
            ? finals.participantAScreenshotUrl : finals.participantBScreenshotUrl
        return (winnerName, avatarUrl)
    }

    var body: some View {
        if matchups.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "trophy").font(.system(size: 44)).foregroundStyle(.gray.opacity(0.3))
                Text("No matchups yet").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Top half — first half of R1 matchups feeding down
                    let r1 = rounds.first?.value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } ?? []
                    let topR1 = Array(r1.prefix(r1.count / 2))
                    let botR1 = Array(r1.suffix(from: r1.count / 2))

                    let r2 = rounds.count > 1 ? rounds[1].value.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } : []
                    let topR2 = r2.isEmpty ? nil : r2.first
                    let botR2 = r2.count > 1 ? r2.last : nil

                    let finals = rounds.count > 2 ? rounds[2].value.first : nil

                    // ── TOP BRACKET ──
                    VStack(spacing: 0) {
                        // R1 top matchups
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(topR1) { m in
                                matchupPair(m)
                            }
                        }

                        // Merge line down
                        if topR1.count > 1 {
                            Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 16)
                        }

                        // R2 top (semifinal)
                        if let semi = topR2 {
                            matchupPair(semi)
                        }

                        // Line to center
                        Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 20)
                    }

                    // ── CHAMPION / FINALS ──
                    if let champ = champion {
                        VStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(gold)
                                .shadow(color: gold.opacity(0.6), radius: 8)

                            ZStack {
                                Circle().fill(gold.opacity(0.12)).frame(width: 72, height: 72)
                                avatarCircle(name: champ.name, url: champ.avatarUrl, size: 58)
                                    .overlay(Circle().strokeBorder(gold, lineWidth: 2.5))
                            }

                            Text(champ.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(gold)
                            Text("CHAMPION")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(gold.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                    } else if let f = finals {
                        VStack(spacing: 4) {
                            Text("⚔️ FINALS")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(gold)
                            matchupPair(f)
                        }
                        .padding(.vertical, 8)
                    }

                    // ── BOTTOM BRACKET ──
                    VStack(spacing: 0) {
                        // Line from center
                        Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 20)

                        // R2 bottom (semifinal)
                        if let semi = botR2 {
                            matchupPair(semi)
                        }

                        // Merge line
                        if botR1.count > 1 {
                            Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 16)
                        }

                        // R1 bottom matchups
                        HStack(alignment: .bottom, spacing: 16) {
                            ForEach(botR1) { m in
                                matchupPair(m)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Matchup pair (two avatars + connecting bracket line)
    @ViewBuilder
    func matchupPair(_ matchup: Matchup) -> some View {
        let aWin = matchup.winnerId == matchup.participantAId
        let bWin = matchup.winnerId == matchup.participantBId
        let hasWinner = matchup.winnerId != nil

        VStack(spacing: 0) {
            // Player A
            avatarWithName(
                name: matchup.participantAUsername ?? "TBD",
                url: matchup.participantAScreenshotUrl,
                isWinner: aWin,
                isEliminated: hasWinner && !aWin
            )

            // Bracket arm down
            Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 10)

            // Horizontal bar
            Rectangle().fill(gold.opacity(0.4)).frame(width: avatarSize + 30, height: 2)

            // Bracket arm down
            Rectangle().fill(gold.opacity(0.4)).frame(width: 2, height: 10)

            // Player B
            avatarWithName(
                name: matchup.participantBUsername ?? "TBD",
                url: matchup.participantBScreenshotUrl,
                isWinner: bWin,
                isEliminated: hasWinner && !bWin
            )

            // Score
            if matchup.votesA + matchup.votesB > 0 {
                Text("\(matchup.votesA) - \(matchup.votesB)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Avatar with name label
    @ViewBuilder
    func avatarWithName(name: String, url: String?, isWinner: Bool, isEliminated: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                if isWinner {
                    Circle().fill(gold.opacity(0.12)).frame(width: avatarSize + 8, height: avatarSize + 8)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                        .offset(y: -(avatarSize / 2 + 8))
                }

                avatarCircle(name: name, url: url, size: avatarSize)
                    .overlay(
                        Circle().strokeBorder(
                            isWinner ? gold : isEliminated ? Color.gray.opacity(0.3) : Color.white.opacity(0.2),
                            lineWidth: isWinner ? 2.5 : 1.5
                        )
                    )
                    .opacity(isEliminated ? 0.4 : 1)
            }

            Text(name.count > 8 ? String(name.prefix(7)) + "…" : name)
                .font(.system(size: 9, weight: isWinner ? .bold : .medium))
                .foregroundColor(isEliminated ? .gray : .white)
                .lineLimit(1)
        }
    }

    // MARK: - Avatar circle
    @ViewBuilder
    func avatarCircle(name: String, url: String?, size: CGFloat) -> some View {
        if let urlStr = url, let imageURL = URL(string: urlStr) {
            KFImage(imageURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
            Circle()
                .fill(colors[abs(name.hashValue) % colors.count])
                .frame(width: size, height: size)
                .overlay(
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }
}
