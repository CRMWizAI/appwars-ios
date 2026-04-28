import SwiftUI
import Kingfisher

/// Exact port of the web BracketView — canvas-drawn golden bracket arms
/// with circular avatars positioned at computed coordinates.
/// Top half grows downward, bottom half grows upward, champion centered.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    // Layout constants — matching the web original exactly
    static let COL = Color(red: 212/255, green: 168/255, blue: 11/255)
    static let LW: CGFloat = 2.5
    static let SLOT_W: CGFloat = 80
    static let U_HEIGHT: CGFloat = 42
    static let STEM: CGFloat = 36
    static let PAD: CGFloat = 44
    static let CENTER_GAP: CGFloat = 70
    static let AVATAR_SIZE: CGFloat = 38

    var totalRounds: Int {
        tournament.totalRounds ?? max(1, Int(ceil(log2(Double(max(matchups.count * 2, 2))))))
    }
    var playerCount: Int { Int(pow(2, Double(totalRounds))) }
    var halfPlayers: Int { playerCount / 2 }
    var halfRounds: Int { Int(log2(Double(max(halfPlayers, 2)))) }
    var totalW: CGFloat { CGFloat(halfPlayers) * Self.SLOT_W }
    var roundH: CGFloat { Self.U_HEIGHT + Self.STEM }
    var halfH: CGFloat { CGFloat(halfRounds) * roundH + Self.PAD }
    var totalH: CGFloat { halfH * 2 + Self.CENTER_GAP }

    var byRound: [Int: [Matchup]] {
        var br: [Int: [Matchup]] = [:]
        for m in matchups {
            br[m.round, default: []].append(m)
        }
        for key in br.keys {
            br[key]?.sort { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
        }
        return br
    }

    var topHalf: [[Matchup]] {
        var top: [[Matchup]] = []
        for r in 1...totalRounds {
            let roundMatchups = byRound[r] ?? []
            let expected = Int(pow(2, Double(totalRounds - r)))
            let topCount = Int(ceil(Double(expected) / 2.0))
            top.append(Array(roundMatchups.prefix(topCount)))
        }
        return top
    }

    var bottomHalf: [[Matchup]] {
        var bot: [[Matchup]] = []
        for r in 1...totalRounds {
            let roundMatchups = byRound[r] ?? []
            let expected = Int(pow(2, Double(totalRounds - r)))
            let topCount = Int(ceil(Double(expected) / 2.0))
            bot.append(Array(roundMatchups.dropFirst(topCount).prefix(expected - topCount)))
        }
        return bot
    }

    var finalsMatchup: Matchup? {
        byRound[totalRounds]?.first
    }

    func matchCx(_ r: Int, _ i: Int) -> CGFloat {
        (CGFloat(i) + 0.5) * pow(2, CGFloat(r + 1)) * Self.SLOT_W
    }

    func armOff(_ r: Int) -> CGFloat {
        pow(2, CGFloat(r)) * Self.SLOT_W / 2
    }

    var body: some View {
        if matchups.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "trophy")
                    .font(.system(size: 44))
                    .foregroundStyle(.gray.opacity(0.3))
                Text("No matchups yet")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let screenWidth = UIScreen.main.bounds.width
            let scale = min(1, screenWidth / totalW)

            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                        // Canvas: golden bracket lines
                        Canvas { ctx, size in
                            drawBracket(ctx: ctx)
                        }
                        .frame(width: totalW, height: totalH)

                        // Avatar overlay
                        ForEach(computeAvatarPositions(), id: \.id) { pos in
                            AvatarDot(
                                username: pos.username,
                                avatarUrl: pos.avatarUrl,
                                size: Self.AVATAR_SIZE,
                                matchup: pos.matchup
                            )
                            .position(x: pos.x, y: pos.y)
                        }

                        // Champion
                        if let finals = finalsMatchup, let winnerName = finals.winnerUsername {
                            let cx = totalW / 2
                            let cy = halfH + Self.CENTER_GAP / 2
                            let winnerAvatar = finals.winnerId == finals.participantAId
                                ? finals.participantAScreenshotUrl
                                : finals.participantBScreenshotUrl

                            ChampionNode(
                                username: winnerName,
                                avatarUrl: winnerAvatar,
                                size: Self.AVATAR_SIZE + 14
                            )
                            .position(x: cx, y: cy)
                        }
                    }
                .frame(width: totalW, height: totalH)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: totalW * scale, height: totalH * scale)
            }
        }
    }

    // MARK: - Draw bracket lines on Canvas
    func drawBracket(ctx: GraphicsContext) {
        func drawHalf(yStart: CGFloat, dir: CGFloat) {
            var armY = yStart
            for r in 0..<halfRounds {
                let numMatches = halfPlayers / Int(pow(2, Double(r + 1)))
                let off = armOff(r)
                let barY = armY + dir * Self.U_HEIGHT
                let stemEnd = barY + dir * Self.STEM

                for i in 0..<numMatches {
                    let cx = matchCx(r, i)
                    let lx = cx - off
                    let rx = cx + off
                    let armStart = r == 0 ? armY + dir * 8 : armY

                    // Left arm
                    var p1 = Path(); p1.move(to: .init(x: lx, y: armStart)); p1.addLine(to: .init(x: lx, y: barY))
                    ctx.stroke(p1, with: .color(Self.COL), lineWidth: Self.LW)
                    // Right arm
                    var p2 = Path(); p2.move(to: .init(x: rx, y: armStart)); p2.addLine(to: .init(x: rx, y: barY))
                    ctx.stroke(p2, with: .color(Self.COL), lineWidth: Self.LW)
                    // Horizontal bar
                    var p3 = Path(); p3.move(to: .init(x: lx, y: barY)); p3.addLine(to: .init(x: rx, y: barY))
                    ctx.stroke(p3, with: .color(Self.COL), lineWidth: Self.LW)
                    // Stem
                    var p4 = Path(); p4.move(to: .init(x: cx, y: barY)); p4.addLine(to: .init(x: cx, y: stemEnd))
                    ctx.stroke(p4, with: .color(Self.COL), lineWidth: Self.LW)
                }
                armY = stemEnd
            }
        }

        drawHalf(yStart: Self.PAD, dir: 1)
        drawHalf(yStart: totalH - Self.PAD, dir: -1)

        // Center line connecting the two halves
        let cx = totalW / 2
        var center = Path()
        center.move(to: .init(x: cx, y: halfH))
        center.addLine(to: .init(x: cx, y: totalH - halfH))
        ctx.stroke(center, with: .color(Self.COL), lineWidth: Self.LW)
    }

    // MARK: - Compute avatar positions
    struct AvatarPos: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let username: String?
        let avatarUrl: String?
        let matchup: Matchup?
    }

    func computeAvatarPositions() -> [AvatarPos] {
        var positions: [AvatarPos] = []

        func computeHalf(_ halfData: [[Matchup]], dir: CGFloat) {
            var armY = dir == 1 ? Self.PAD : totalH - Self.PAD

            for r in 0..<halfRounds {
                let numMatches = halfPlayers / Int(pow(2, Double(r + 1)))
                let off = armOff(r)
                let barY = armY + dir * Self.U_HEIGHT
                let stemEnd = barY + dir * Self.STEM
                let roundData = r < halfData.count ? halfData[r] : []

                for i in 0..<numMatches {
                    let cx = matchCx(r, i)
                    let lx = cx - off
                    let rx = cx + off
                    let matchup = i < roundData.count ? roundData[i] : nil

                    let isCompleted = matchup?.status == "completed" && matchup?.winnerId != nil
                    let aIsWinner = isCompleted && matchup?.winnerId == matchup?.participantAId
                    let bIsWinner = isCompleted && matchup?.winnerId == matchup?.participantBId

                    if r == 0 {
                        // R1: show non-winners at arm tips
                        if !aIsWinner {
                            positions.append(AvatarPos(
                                x: lx, y: armY,
                                username: matchup?.participantAUsername,
                                avatarUrl: matchup?.participantAScreenshotUrl,
                                matchup: matchup
                            ))
                        }
                        if matchup?.isBye != true && !bIsWinner {
                            positions.append(AvatarPos(
                                x: rx, y: armY,
                                username: matchup?.participantBUsername,
                                avatarUrl: matchup?.participantBScreenshotUrl,
                                matchup: matchup
                            ))
                        }
                    } else {
                        let nudgedArmY = armY - dir * (Self.AVATAR_SIZE / 2 + 2)
                        if isCompleted {
                            let loserIsA = !aIsWinner
                            positions.append(AvatarPos(
                                x: loserIsA ? lx : rx, y: nudgedArmY,
                                username: loserIsA ? matchup?.participantAUsername : matchup?.participantBUsername,
                                avatarUrl: loserIsA ? matchup?.participantAScreenshotUrl : matchup?.participantBScreenshotUrl,
                                matchup: matchup
                            ))
                        } else {
                            if matchup?.participantAId != nil {
                                positions.append(AvatarPos(x: lx, y: nudgedArmY, username: matchup?.participantAUsername, avatarUrl: matchup?.participantAScreenshotUrl, matchup: matchup))
                            }
                            if matchup?.participantBId != nil {
                                positions.append(AvatarPos(x: rx, y: nudgedArmY, username: matchup?.participantBUsername, avatarUrl: matchup?.participantBScreenshotUrl, matchup: matchup))
                            }
                        }
                    }

                    // Winner at stem end (if not advanced further)
                    if let winnerId = matchup?.winnerId {
                        var advancedFurther = false
                        if r + 1 < halfData.count {
                            let nextMatchIdx = i / 2
                            if nextMatchIdx < halfData[r + 1].count {
                                let next = halfData[r + 1][nextMatchIdx]
                                advancedFurther = next.participantAId == winnerId || next.participantBId == winnerId
                            }
                        } else if r == halfRounds - 1, let finals = finalsMatchup {
                            advancedFurther = finals.participantAId == winnerId || finals.participantBId == winnerId
                        }

                        if !advancedFurther {
                            let nudgedY = stemEnd - dir * (Self.AVATAR_SIZE / 2 + 2)
                            let isA = winnerId == matchup?.participantAId
                            positions.append(AvatarPos(
                                x: cx, y: nudgedY,
                                username: isA ? matchup?.participantAUsername : matchup?.participantBUsername,
                                avatarUrl: isA ? matchup?.participantAScreenshotUrl : matchup?.participantBScreenshotUrl,
                                matchup: matchup
                            ))
                        }
                    }
                }
                armY = stemEnd
            }
        }

        computeHalf(topHalf, dir: 1)
        computeHalf(bottomHalf, dir: -1)

        // Finals avatars (non-champion)
        if let finals = finalsMatchup {
            let cx = totalW / 2
            let topY = halfH
            let botY = totalH - halfH
            let championId = finals.winnerId

            if finals.participantAId != nil && finals.participantAId != championId {
                positions.append(AvatarPos(
                    x: cx, y: topY - (Self.AVATAR_SIZE / 2 + 2),
                    username: finals.participantAUsername,
                    avatarUrl: finals.participantAScreenshotUrl,
                    matchup: finals
                ))
            }
            if finals.participantBId != nil && finals.participantBId != championId {
                positions.append(AvatarPos(
                    x: cx, y: botY + (Self.AVATAR_SIZE / 2 + 2),
                    username: finals.participantBUsername,
                    avatarUrl: finals.participantBScreenshotUrl,
                    matchup: finals
                ))
            }
        }

        return positions
    }
}

// MARK: - Avatar Dot (matches web PlayerDot)
struct AvatarDot: View {
    let username: String?
    let avatarUrl: String?
    let size: CGFloat
    let matchup: Matchup?

    @State private var showMatchup = false

    var body: some View {
        Button { if matchup != nil { showMatchup = true } } label: {
            ZStack {
                if let url = avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
                } else if let name = username {
                    Circle()
                        .fill(colorForName(name))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(String(name.prefix(2)).uppercased())
                                .font(.system(size: size * 0.32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: size, height: size)
                        .overlay(
                            Text("?")
                                .font(.system(size: size * 0.35))
                                .foregroundColor(.gray)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showMatchup) {
            if let m = matchup {
                MatchupDetailSheet(matchup: m)
            }
        }
    }

    func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Champion Node (matches web ChampionCenter)
struct ChampionNode: View {
    let username: String
    let avatarUrl: String?
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Crown above
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(BracketView.COL)
                .shadow(color: BracketView.COL.opacity(0.8), radius: 6)
                .offset(y: 6)

            // Avatar with golden ring and glow
            ZStack {
                Circle()
                    .fill(BracketView.COL.opacity(0.15))
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: BracketView.COL.opacity(0.6), radius: 20)

                if let url = avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(BracketView.COL, lineWidth: 2.5))
                } else {
                    Circle()
                        .fill(colorForName(username))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(String(username.prefix(2)).uppercased())
                                .font(.system(size: size * 0.34, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().strokeBorder(BracketView.COL, lineWidth: 2.5))
                }
            }
        }
    }

    func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
