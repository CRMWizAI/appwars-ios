import SwiftUI
import Kingfisher

/// Bracket that computes everything on a background thread, then renders.
struct BracketView: View {
    let matchups: [Matchup]
    let tournament: Tournament

    @State private var avatars: [AvatarInfo] = []
    @State private var champion: ChampionInfo?
    @State private var layoutInfo: LayoutInfo?
    @State private var ready = false

    struct LayoutInfo {
        let totalW: CGFloat
        let totalH: CGFloat
        let halfH: CGFloat
        let halfRounds: Int
        let halfPlayers: Int
        let scale: CGFloat
    }

    struct AvatarInfo: Identifiable {
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

    var body: some View {
        Group {
            if !ready {
                ProgressView().tint(.yellow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matchups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy").font(.system(size: 44)).foregroundStyle(.gray.opacity(0.3))
                    Text("No matchups yet").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let layout = layoutInfo {
                bracketContent(layout: layout)
            }
        }
        .onAppear {
            guard !ready else { return }
            let screenW = UIScreen.main.bounds.width
            Task {
                await computeOnBackground(screenWidth: screenW)
                ready = true
            }
        }
    }

    @ViewBuilder
    func bracketContent(layout: LayoutInfo) -> some View {
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Single canvas for all lines — no ForEach, no Path views
                Canvas { ctx, _ in
                    drawAllLines(ctx: ctx, layout: layout)
                }
                .frame(width: layout.totalW, height: layout.totalH)
                .allowsHitTesting(false)

                // Avatars
                ForEach(avatars) { a in
                    avatarView(a)
                        .position(x: a.x, y: a.y)
                }

                // Champion
                if let c = champion {
                    championView(c)
                        .position(x: c.x, y: c.y)
                }
            }
            .frame(width: layout.totalW, height: layout.totalH)
            .scaleEffect(layout.scale, anchor: .topLeading)
            .frame(width: layout.totalW * layout.scale, height: layout.totalH * layout.scale)
        }
    }

    @ViewBuilder
    func avatarView(_ a: AvatarInfo) -> some View {
        let size: CGFloat = 38
        if let url = a.avatarUrl, let imageURL = URL(string: url) {
            KFImage(imageURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
        } else if let name = a.username {
            let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
            Circle()
                .fill(colors[abs(name.hashValue) % colors.count])
                .frame(width: size, height: size)
                .overlay(Text(String(name.prefix(2)).uppercased()).font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
        }
    }

    @ViewBuilder
    func championView(_ c: ChampionInfo) -> some View {
        let gold = Color(red: 212/255, green: 168/255, blue: 11/255)
        let size: CGFloat = 52
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22))
                .foregroundStyle(gold)
                .shadow(color: gold.opacity(0.8), radius: 6)
                .offset(y: 6)
            ZStack {
                Circle().fill(gold.opacity(0.15)).frame(width: size + 8, height: size + 8)
                    .shadow(color: gold.opacity(0.6), radius: 20)
                if let url = c.avatarUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size).clipShape(Circle())
                        .overlay(Circle().strokeBorder(gold, lineWidth: 2.5))
                } else {
                    let colors: [Color] = [.purple, .blue, .green, .red, .orange, .cyan, .pink, .indigo, .teal, .mint]
                    Circle().fill(colors[abs(c.username.hashValue) % colors.count])
                        .frame(width: size, height: size)
                        .overlay(Text(String(c.username.prefix(2)).uppercased()).font(.system(size: 18, weight: .bold)).foregroundColor(.white))
                        .overlay(Circle().strokeBorder(gold, lineWidth: 2.5))
                }
            }
        }
    }

    // MARK: - Canvas line drawing (pure function, no state)
    func drawAllLines(ctx: GraphicsContext, layout: LayoutInfo) {
        let gold = Color(red: 212/255, green: 168/255, blue: 11/255)
        let lw: CGFloat = 2.5
        let slotW: CGFloat = 80
        let uHeight: CGFloat = 42
        let stem: CGFloat = 36
        let pad: CGFloat = 44

        func cx(_ r: Int, _ i: Int) -> CGFloat { (CGFloat(i) + 0.5) * pow(2, CGFloat(r + 1)) * slotW }
        func off(_ r: Int) -> CGFloat { pow(2, CGFloat(r)) * slotW / 2 }

        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            var p = Path(); p.move(to: .init(x: x1, y: y1)); p.addLine(to: .init(x: x2, y: y2))
            ctx.stroke(p, with: .color(gold), lineWidth: lw)
        }

        func drawHalf(_ yStart: CGFloat, _ dir: CGFloat) {
            var armY = yStart
            for r in 0..<layout.halfRounds {
                let n = layout.halfPlayers / Int(pow(2, Double(r + 1)))
                let o = off(r)
                let barY = armY + dir * uHeight
                let stemEnd = barY + dir * stem
                for i in 0..<n {
                    let c = cx(r, i); let l = c - o; let rr = c + o
                    let a = r == 0 ? armY + dir * 8 : armY
                    line(l, a, l, barY); line(rr, a, rr, barY)
                    line(l, barY, rr, barY); line(c, barY, c, stemEnd)
                }
                armY = stemEnd
            }
        }

        drawHalf(pad, 1)
        drawHalf(layout.totalH - pad, -1)
        line(layout.totalW / 2, layout.halfH, layout.totalW / 2, layout.totalH - layout.halfH)
    }

    // MARK: - Background computation
    func computeOnBackground(screenWidth: CGFloat) async {
        let totalRounds = tournament.totalRounds ?? max(1, Int(ceil(log2(Double(max(matchups.count * 2, 2))))))
        let playerCount = Int(pow(2, Double(totalRounds)))
        let halfPlayers = playerCount / 2
        let halfRounds = max(1, Int(log2(Double(max(halfPlayers, 2)))))
        let totalW = CGFloat(halfPlayers) * 80
        let halfH = CGFloat(halfRounds) * 78 + 44
        let totalH = halfH * 2 + 70
        let scale = min(1, screenWidth / totalW)

        let layout = LayoutInfo(totalW: totalW, totalH: totalH, halfH: halfH,
                                halfRounds: halfRounds, halfPlayers: halfPlayers, scale: scale)

        let br = Dictionary(grouping: matchups, by: \.round)
            .mapValues { $0.sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) } }

        var topH: [[Matchup]] = []
        var botH: [[Matchup]] = []
        for r in 1...totalRounds {
            let rm = br[r] ?? []
            let exp = Int(pow(2, Double(totalRounds - r)))
            let tc = Int(ceil(Double(exp) / 2.0))
            topH.append(Array(rm.prefix(tc)))
            botH.append(Array(rm.dropFirst(tc).prefix(max(0, exp - tc))))
        }

        let finals = br[totalRounds]?.first
        var avs: [AvatarInfo] = []

        func doHalf(_ hd: [[Matchup]], _ dir: CGFloat, _ pfx: String) {
            var armY = dir == 1 ? CGFloat(44) : totalH - 44
            for r in 0..<halfRounds {
                let nm = halfPlayers / Int(pow(2, Double(r + 1)))
                let o = pow(2, CGFloat(r)) * 40
                let barY = armY + dir * 42
                let stemEnd = barY + dir * 36
                let rd = r < hd.count ? hd[r] : []

                for i in 0..<nm {
                    let c = (CGFloat(i) + 0.5) * pow(2, CGFloat(r + 1)) * 80
                    let lx = c - o; let rx = c + o
                    let m = i < rd.count ? rd[i] : nil
                    let done = m?.status == "completed" && m?.winnerId != nil
                    let aw = done && m?.winnerId == m?.participantAId
                    let bw = done && m?.winnerId == m?.participantBId

                    if r == 0 {
                        if !aw { avs.append(.init(id: "\(pfx)\(r)\(i)a", x: lx, y: armY, username: m?.participantAUsername, avatarUrl: m?.participantAScreenshotUrl, matchupId: m?.id)) }
                        if m?.isBye != true && !bw { avs.append(.init(id: "\(pfx)\(r)\(i)b", x: rx, y: armY, username: m?.participantBUsername, avatarUrl: m?.participantBScreenshotUrl, matchupId: m?.id)) }
                    } else {
                        let ny = armY - dir * 21
                        if done {
                            let la = !aw
                            avs.append(.init(id: "\(pfx)\(r)\(i)l", x: la ? lx : rx, y: ny,
                                username: la ? m?.participantAUsername : m?.participantBUsername,
                                avatarUrl: la ? m?.participantAScreenshotUrl : m?.participantBScreenshotUrl, matchupId: m?.id))
                        }
                    }

                    if let wid = m?.winnerId {
                        var adv = false
                        let nri = r + 1
                        if nri < hd.count && nri < halfRounds {
                            let nmi = i / 2
                            if nmi < hd[nri].count {
                                let nx = hd[nri][nmi]
                                adv = nx.participantAId == wid || nx.participantBId == wid
                            }
                        }
                        if !adv, r == halfRounds - 1, let f = finals {
                            adv = f.participantAId == wid || f.participantBId == wid
                        }
                        if !adv {
                            let ny = stemEnd - dir * 21
                            let isA = wid == m?.participantAId
                            avs.append(.init(id: "\(pfx)\(r)\(i)w", x: c, y: ny,
                                username: isA ? m?.participantAUsername : m?.participantBUsername,
                                avatarUrl: isA ? m?.participantAScreenshotUrl : m?.participantBScreenshotUrl, matchupId: m?.id))
                        }
                    }
                }
                armY = stemEnd
            }
        }

        doHalf(topH, 1, "t")
        doHalf(botH, -1, "b")

        if let f = finals {
            let cx = totalW / 2
            let cid = f.winnerId
            if f.participantAId != nil && f.participantAId != cid {
                avs.append(.init(id: "fa", x: cx, y: halfH - 21, username: f.participantAUsername, avatarUrl: f.participantAScreenshotUrl, matchupId: f.id))
            }
            if f.participantBId != nil && f.participantBId != cid {
                avs.append(.init(id: "fb", x: cx, y: totalH - halfH + 21, username: f.participantBUsername, avatarUrl: f.participantBScreenshotUrl, matchupId: f.id))
            }
        }

        var ch: ChampionInfo? = nil
        if let f = finals, let wn = f.winnerUsername {
            let wa = f.winnerId == f.participantAId ? f.participantAScreenshotUrl : f.participantBScreenshotUrl
            ch = ChampionInfo(x: totalW / 2, y: halfH + 35, username: wn, avatarUrl: wa)
        }

        // Update state on main thread
        await MainActor.run {
            self.layoutInfo = layout
            self.avatars = avs
            self.champion = ch
        }
    }
}
