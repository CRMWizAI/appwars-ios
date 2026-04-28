import SwiftUI
import Kingfisher

/// Pre-computes all bracket data ONCE, then renders a static image + positioned avatars.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    @State private var bracketData: BracketData?

    var body: some View {
        if let data = bracketData {
            BracketRenderer(data: data, matchups: matchups)
        } else if matchups.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "trophy")
                    .font(.system(size: 44))
                    .foregroundStyle(.gray.opacity(0.3))
                Text("No matchups yet")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView().tint(.yellow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { bracketData = BracketData.compute(matchups: matchups, tournament: tournament) }
        }
    }
}

// MARK: - All bracket math computed once, stored as a plain struct
struct BracketData {
    static let SLOT_W: CGFloat = 80
    static let U_HEIGHT: CGFloat = 42
    static let STEM: CGFloat = 36
    static let PAD: CGFloat = 44
    static let CENTER_GAP: CGFloat = 70
    static let AVATAR_SIZE: CGFloat = 38

    let totalW: CGFloat
    let totalH: CGFloat
    let halfH: CGFloat
    let halfRounds: Int
    let halfPlayers: Int
    let totalRounds: Int
    let scale: CGFloat
    let avatars: [AvatarPos]
    let champion: ChampionInfo?
    let lines: [BracketLine]

    struct AvatarPos: Identifiable {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let username: String?
        let avatarUrl: String?
        let matchupId: UUID?
    }

    struct ChampionInfo {
        let x: CGFloat
        let y: CGFloat
        let username: String
        let avatarUrl: String?
    }

    struct BracketLine {
        let from: CGPoint
        let to: CGPoint
    }

    static func compute(matchups: [Matchup], tournament: Tournament) -> BracketData {
        let totalRounds = tournament.totalRounds ?? max(1, Int(ceil(log2(Double(max(matchups.count * 2, 2))))))
        let playerCount = Int(pow(2, Double(totalRounds)))
        let halfPlayers = playerCount / 2
        let halfRounds = Int(log2(Double(max(halfPlayers, 2))))
        let totalW = CGFloat(halfPlayers) * SLOT_W
        let roundH = U_HEIGHT + STEM
        let halfH = CGFloat(halfRounds) * roundH + PAD
        let totalH = halfH * 2 + CENTER_GAP
        let screenWidth = UIScreen.main.bounds.width
        let scale = min(1, screenWidth / totalW)

        let br = Dictionary(grouping: matchups, by: \.round)
            .mapValues { $0.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } }

        // Build halves
        var topHalf: [[Matchup]] = []
        var bottomHalf: [[Matchup]] = []
        for r in 1...totalRounds {
            let rm = br[r] ?? []
            let expected = Int(pow(2, Double(totalRounds - r)))
            let topCount = Int(ceil(Double(expected) / 2.0))
            topHalf.append(Array(rm.prefix(topCount)))
            bottomHalf.append(Array(rm.dropFirst(topCount).prefix(expected - topCount)))
        }

        let finals = br[totalRounds]?.first

        // Compute lines
        var lines: [BracketLine] = []
        func addLine(_ fx: CGFloat, _ fy: CGFloat, _ tx: CGFloat, _ ty: CGFloat) {
            lines.append(BracketLine(from: CGPoint(x: fx, y: fy), to: CGPoint(x: tx, y: ty)))
        }

        func matchCx(_ r: Int, _ i: Int) -> CGFloat {
            (CGFloat(i) + 0.5) * pow(2, CGFloat(r + 1)) * SLOT_W
        }
        func armOff(_ r: Int) -> CGFloat {
            pow(2, CGFloat(r)) * SLOT_W / 2
        }

        func drawHalfLines(yStart: CGFloat, dir: CGFloat) {
            var armY = yStart
            for r in 0..<halfRounds {
                let numMatches = halfPlayers / Int(pow(2, Double(r + 1)))
                let off = armOff(r)
                let barY = armY + dir * U_HEIGHT
                let stemEnd = barY + dir * STEM
                for i in 0..<numMatches {
                    let cx = matchCx(r, i)
                    let lx = cx - off
                    let rx = cx + off
                    let armStart = r == 0 ? armY + dir * 8 : armY
                    addLine(lx, armStart, lx, barY)
                    addLine(rx, armStart, rx, barY)
                    addLine(lx, barY, rx, barY)
                    addLine(cx, barY, cx, stemEnd)
                }
                armY = stemEnd
            }
        }
        drawHalfLines(yStart: PAD, dir: 1)
        drawHalfLines(yStart: totalH - PAD, dir: -1)
        addLine(totalW / 2, halfH, totalW / 2, totalH - halfH)

        // Compute avatar positions
        var avatars: [AvatarPos] = []

        func computeHalfAvatars(_ halfData: [[Matchup]], dir: CGFloat, prefix: String) {
            var armY = dir == 1 ? PAD : totalH - PAD
            for r in 0..<halfRounds {
                let numMatches = halfPlayers / Int(pow(2, Double(r + 1)))
                let off = armOff(r)
                let barY = armY + dir * U_HEIGHT
                let stemEnd = barY + dir * STEM
                let roundData = r < halfData.count ? halfData[r] : []

                for i in 0..<numMatches {
                    let cx = matchCx(r, i)
                    let lx = cx - off
                    let rx = cx + off
                    let m = i < roundData.count ? roundData[i] : nil
                    let done = m?.status == "completed" && m?.winnerId != nil
                    let aWin = done && m?.winnerId == m?.participantAId
                    let bWin = done && m?.winnerId == m?.participantBId

                    if r == 0 {
                        if !aWin {
                            avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_a", x: lx, y: armY, username: m?.participantAUsername, avatarUrl: m?.participantAScreenshotUrl, matchupId: m?.id))
                        }
                        if m?.isBye != true && !bWin {
                            avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_b", x: rx, y: armY, username: m?.participantBUsername, avatarUrl: m?.participantBScreenshotUrl, matchupId: m?.id))
                        }
                    } else {
                        let ny = armY - dir * (AVATAR_SIZE / 2 + 2)
                        if done {
                            let la = !aWin
                            avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_l", x: la ? lx : rx, y: ny,
                                username: la ? m?.participantAUsername : m?.participantBUsername,
                                avatarUrl: la ? m?.participantAScreenshotUrl : m?.participantBScreenshotUrl, matchupId: m?.id))
                        } else {
                            if m?.participantAId != nil {
                                avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_a", x: lx, y: ny, username: m?.participantAUsername, avatarUrl: m?.participantAScreenshotUrl, matchupId: m?.id))
                            }
                            if m?.participantBId != nil {
                                avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_b", x: rx, y: ny, username: m?.participantBUsername, avatarUrl: m?.participantBScreenshotUrl, matchupId: m?.id))
                            }
                        }
                    }

                    if let wid = m?.winnerId {
                        var adv = false
                        if r + 1 < halfData.count, i / 2 < halfData[r + 1].count {
                            let n = halfData[r + 1][i / 2]
                            adv = n.participantAId == wid || n.participantBId == wid
                        } else if r == halfRounds - 1, let f = finals {
                            adv = f.participantAId == wid || f.participantBId == wid
                        }
                        if !adv {
                            let ny = stemEnd - dir * (AVATAR_SIZE / 2 + 2)
                            let isA = wid == m?.participantAId
                            avatars.append(.init(id: "\(prefix)_r\(r)_m\(i)_w", x: cx, y: ny,
                                username: isA ? m?.participantAUsername : m?.participantBUsername,
                                avatarUrl: isA ? m?.participantAScreenshotUrl : m?.participantBScreenshotUrl, matchupId: m?.id))
                        }
                    }
                }
                armY = stemEnd
            }
        }

        computeHalfAvatars(topHalf, dir: 1, prefix: "t")
        computeHalfAvatars(bottomHalf, dir: -1, prefix: "b")

        if let f = finals {
            let cx = totalW / 2
            let cid = f.winnerId
            if f.participantAId != nil && f.participantAId != cid {
                avatars.append(.init(id: "f_a", x: cx, y: halfH - (AVATAR_SIZE / 2 + 2), username: f.participantAUsername, avatarUrl: f.participantAScreenshotUrl, matchupId: f.id))
            }
            if f.participantBId != nil && f.participantBId != cid {
                avatars.append(.init(id: "f_b", x: cx, y: totalH - halfH + (AVATAR_SIZE / 2 + 2), username: f.participantBUsername, avatarUrl: f.participantBScreenshotUrl, matchupId: f.id))
            }
        }

        // Champion
        var champ: ChampionInfo? = nil
        if let f = finals, let wn = f.winnerUsername {
            let wa = f.winnerId == f.participantAId ? f.participantAScreenshotUrl : f.participantBScreenshotUrl
            champ = ChampionInfo(x: totalW / 2, y: halfH + CENTER_GAP / 2, username: wn, avatarUrl: wa)
        }

        return BracketData(totalW: totalW, totalH: totalH, halfH: halfH, halfRounds: halfRounds,
                           halfPlayers: halfPlayers, totalRounds: totalRounds, scale: scale,
                           avatars: avatars, champion: champ, lines: lines)
    }
}

// MARK: - Pure renderer — no computation in body
struct BracketRenderer: View {
    let data: BracketData
    let matchups: [Matchup]

    private static let gold = Color(red: 212/255, green: 168/255, blue: 11/255)

    var body: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Pre-computed lines drawn as shapes (no Canvas closure capturing self)
                ForEach(Array(data.lines.enumerated()), id: \.offset) { _, line in
                    Path { p in
                        p.move(to: line.from)
                        p.addLine(to: line.to)
                    }
                    .stroke(Self.gold, lineWidth: 2.5)
                }

                // Avatars
                ForEach(data.avatars) { pos in
                    StaticAvatarDot(
                        username: pos.username,
                        avatarUrl: pos.avatarUrl,
                        size: BracketData.AVATAR_SIZE,
                        matchupId: pos.matchupId,
                        matchups: matchups
                    )
                    .position(x: pos.x, y: pos.y)
                }

                // Champion
                if let c = data.champion {
                    ChampionNode(username: c.username, avatarUrl: c.avatarUrl, size: BracketData.AVATAR_SIZE + 14)
                        .position(x: c.x, y: c.y)
                }
            }
            .frame(width: data.totalW, height: data.totalH)
            .scaleEffect(data.scale, anchor: .topLeading)
            .frame(width: data.totalW * data.scale, height: data.totalH * data.scale)
        }
    }
}

// MARK: - Static avatar (no closures, no computed lookups in body)
struct StaticAvatarDot: View {
    let username: String?
    let avatarUrl: String?
    let size: CGFloat
    let matchupId: UUID?
    let matchups: [Matchup]

    @State private var showSheet = false

    var body: some View {
        Button { if matchupId != nil { showSheet = true } } label: {
            avatarCircle
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            if let mid = matchupId, let m = matchups.first(where: { $0.id == mid }) {
                MatchupDetailSheet(matchup: m)
            }
        }
    }

    @ViewBuilder
    var avatarCircle: some View {
        if let url = avatarUrl, let imageURL = URL(string: url) {
            KFImage(imageURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
        } else if let name = username {
            Circle()
                .fill(dotColor(name))
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

    func dotColor(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        return colors[abs(name.hashValue) % colors.count]
    }
}

// MARK: - Champion Node
struct ChampionNode: View {
    let username: String
    let avatarUrl: String?
    let size: CGFloat
    private static let gold = Color(red: 212/255, green: 168/255, blue: 11/255)

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(Self.gold)
                .shadow(color: Self.gold.opacity(0.8), radius: 6)
                .offset(y: 6)

            ZStack {
                Circle()
                    .fill(Self.gold.opacity(0.15))
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: Self.gold.opacity(0.6), radius: 20)

                if let url = avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Self.gold, lineWidth: 2.5))
                } else {
                    Circle()
                        .fill(dotColor(username))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(String(username.prefix(2)).uppercased())
                                .font(.system(size: size * 0.34, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().strokeBorder(Self.gold, lineWidth: 2.5))
                }
            }
        }
    }

    func dotColor(_ name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
        return colors[abs(name.hashValue) % colors.count]
    }
}
