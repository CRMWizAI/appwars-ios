import SwiftUI
import Kingfisher

struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    static let COL = Color(red: 212/255, green: 168/255, blue: 11/255)
    static let LW: CGFloat = 2.5
    static let SLOT_W: CGFloat = 80
    static let U_HEIGHT: CGFloat = 42
    static let STEM: CGFloat = 36
    static let PAD: CGFloat = 44
    static let CENTER_GAP: CGFloat = 70
    static let AVATAR_SIZE: CGFloat = 38

    // Pre-computed on init — NOT in body
    @State private var avatarPositions: [AvatarPos] = []
    @State private var didCompute = false

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

                    // Avatar overlay — uses stable pre-computed IDs
                    ForEach(avatarPositions) { pos in
                        AvatarDot(
                            username: pos.username,
                            avatarUrl: pos.avatarUrl,
                            size: Self.AVATAR_SIZE,
                            matchup: findMatchup(pos.matchupId)
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
            .onAppear {
                if !didCompute {
                    avatarPositions = buildAvatarPositions()
                    didCompute = true
                }
            }
        }
    }

    func findMatchup(_ id: UUID?) -> Matchup? {
        guard let id = id else { return nil }
        return matchups.first { $0.id == id }
    }

    var finalsMatchup: Matchup? {
        let br = Dictionary(grouping: matchups, by: \.round)
        return br[totalRounds]?.first
    }

    func matchCx(_ r: Int, _ i: Int) -> CGFloat {
        (CGFloat(i) + 0.5) * pow(2, CGFloat(r + 1)) * Self.SLOT_W
    }

    func armOff(_ r: Int) -> CGFloat {
        pow(2, CGFloat(r)) * Self.SLOT_W / 2
    }

    // MARK: - Stable avatar position struct
    struct AvatarPos: Identifiable {
        let id: String // stable string ID, NOT random UUID
        let x: CGFloat
        let y: CGFloat
        let username: String?
        let avatarUrl: String?
        let matchupId: UUID?
    }

    // MARK: - Build positions ONCE (not in body)
    func buildAvatarPositions() -> [AvatarPos] {
        var positions: [AvatarPos] = []
        let br = Dictionary(grouping: matchups, by: \.round)
            .mapValues { $0.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } }

        var topHalf: [[Matchup]] = []
        var bottomHalf: [[Matchup]] = []
        for r in 1...totalRounds {
            let roundMatchups = br[r] ?? []
            let expected = Int(pow(2, Double(totalRounds - r)))
            let topCount = Int(ceil(Double(expected) / 2.0))
            topHalf.append(Array(roundMatchups.prefix(topCount)))
            bottomHalf.append(Array(roundMatchups.dropFirst(topCount).prefix(expected - topCount)))
        }

        let finals = br[totalRounds]?.first

        func computeHalf(_ halfData: [[Matchup]], dir: CGFloat, prefix: String) {
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
                        if !aIsWinner {
                            positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_a", x: lx, y: armY, username: matchup?.participantAUsername, avatarUrl: matchup?.participantAScreenshotUrl, matchupId: matchup?.id))
                        }
                        if matchup?.isBye != true && !bIsWinner {
                            positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_b", x: rx, y: armY, username: matchup?.participantBUsername, avatarUrl: matchup?.participantBScreenshotUrl, matchupId: matchup?.id))
                        }
                    } else {
                        let nudgedArmY = armY - dir * (Self.AVATAR_SIZE / 2 + 2)
                        if isCompleted {
                            let loserIsA = !aIsWinner
                            positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_loser", x: loserIsA ? lx : rx, y: nudgedArmY,
                                username: loserIsA ? matchup?.participantAUsername : matchup?.participantBUsername,
                                avatarUrl: loserIsA ? matchup?.participantAScreenshotUrl : matchup?.participantBScreenshotUrl,
                                matchupId: matchup?.id))
                        } else {
                            if matchup?.participantAId != nil {
                                positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_pa", x: lx, y: nudgedArmY, username: matchup?.participantAUsername, avatarUrl: matchup?.participantAScreenshotUrl, matchupId: matchup?.id))
                            }
                            if matchup?.participantBId != nil {
                                positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_pb", x: rx, y: nudgedArmY, username: matchup?.participantBUsername, avatarUrl: matchup?.participantBScreenshotUrl, matchupId: matchup?.id))
                            }
                        }
                    }

                    if let winnerId = matchup?.winnerId {
                        var advancedFurther = false
                        if r + 1 < halfData.count {
                            let nextMatchIdx = i / 2
                            if nextMatchIdx < halfData[r + 1].count {
                                let next = halfData[r + 1][nextMatchIdx]
                                advancedFurther = next.participantAId == winnerId || next.participantBId == winnerId
                            }
                        } else if r == halfRounds - 1, let f = finals {
                            advancedFurther = f.participantAId == winnerId || f.participantBId == winnerId
                        }

                        if !advancedFurther {
                            let nudgedY = stemEnd - dir * (Self.AVATAR_SIZE / 2 + 2)
                            let isA = winnerId == matchup?.participantAId
                            positions.append(AvatarPos(id: "\(prefix)_r\(r)_m\(i)_winner", x: cx, y: nudgedY,
                                username: isA ? matchup?.participantAUsername : matchup?.participantBUsername,
                                avatarUrl: isA ? matchup?.participantAScreenshotUrl : matchup?.participantBScreenshotUrl,
                                matchupId: matchup?.id))
                        }
                    }
                }
                armY = stemEnd
            }
        }

        computeHalf(topHalf, dir: 1, prefix: "top")
        computeHalf(bottomHalf, dir: -1, prefix: "bot")

        // Finals avatars
        if let f = finals {
            let cx = totalW / 2
            let topY = halfH
            let botY = totalH - halfH
            let championId = f.winnerId

            if f.participantAId != nil && f.participantAId != championId {
                positions.append(AvatarPos(id: "finals_a", x: cx, y: topY - (Self.AVATAR_SIZE / 2 + 2), username: f.participantAUsername, avatarUrl: f.participantAScreenshotUrl, matchupId: f.id))
            }
            if f.participantBId != nil && f.participantBId != championId {
                positions.append(AvatarPos(id: "finals_b", x: cx, y: botY + (Self.AVATAR_SIZE / 2 + 2), username: f.participantBUsername, avatarUrl: f.participantBScreenshotUrl, matchupId: f.id))
            }
        }

        return positions
    }

    // MARK: - Draw bracket lines
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

                    var p1 = Path(); p1.move(to: .init(x: lx, y: armStart)); p1.addLine(to: .init(x: lx, y: barY))
                    ctx.stroke(p1, with: .color(Self.COL), lineWidth: Self.LW)
                    var p2 = Path(); p2.move(to: .init(x: rx, y: armStart)); p2.addLine(to: .init(x: rx, y: barY))
                    ctx.stroke(p2, with: .color(Self.COL), lineWidth: Self.LW)
                    var p3 = Path(); p3.move(to: .init(x: lx, y: barY)); p3.addLine(to: .init(x: rx, y: barY))
                    ctx.stroke(p3, with: .color(Self.COL), lineWidth: Self.LW)
                    var p4 = Path(); p4.move(to: .init(x: cx, y: barY)); p4.addLine(to: .init(x: cx, y: stemEnd))
                    ctx.stroke(p4, with: .color(Self.COL), lineWidth: Self.LW)
                }
                armY = stemEnd
            }
        }

        drawHalf(yStart: Self.PAD, dir: 1)
        drawHalf(yStart: totalH - Self.PAD, dir: -1)

        let cx = totalW / 2
        var center = Path()
        center.move(to: .init(x: cx, y: halfH))
        center.addLine(to: .init(x: cx, y: totalH - halfH))
        ctx.stroke(center, with: .color(Self.COL), lineWidth: Self.LW)
    }
}

// MARK: - Avatar Dot
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
                        .overlay(Text("?").font(.system(size: size * 0.35)).foregroundColor(.gray))
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showMatchup) {
            if let m = matchup { MatchupDetailSheet(matchup: m) }
        }
    }

    func colorForName(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        return colors[abs(name.hashValue) % colors.count]
    }
}

// MARK: - Champion Node
struct ChampionNode: View {
    let username: String
    let avatarUrl: String?
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(BracketView.COL)
                .shadow(color: BracketView.COL.opacity(0.8), radius: 6)
                .offset(y: 6)

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
        return colors[abs(name.hashValue) % colors.count]
    }
}
