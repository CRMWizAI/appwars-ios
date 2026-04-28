import SwiftUI
import Kingfisher

struct TournamentDetailView: View {
    let tournament: Tournament
    @State private var selectedTab = 0
    @State private var matchups: [Matchup] = []
    @State private var sponsors: [SponsorData] = []
    @State private var loading = true
    @State private var showChampion = false

    var champion: (name: String, avatarUrl: String?)? {
        guard tournament.isCompleted,
              let finals = matchups.first(where: { $0.round == (tournament.totalRounds ?? 3) }),
              let winnerName = finals.winnerUsername else { return nil }
        let avatarUrl = finals.winnerId == finals.participantAId
            ? finals.participantAScreenshotUrl
            : finals.participantBScreenshotUrl
        return (winnerName, avatarUrl)
    }

    let tabs = [
        (title: "Home", icon: "house.fill"),
        (title: "Bracket", icon: "trophy.fill"),
        (title: "Vote", icon: "hand.thumbsup.fill"),
        (title: "Chat", icon: "bubble.left.fill"),
        (title: "Sponsors", icon: "building.2.fill"),
        (title: "Prizes", icon: "gift.fill"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // ── HERO BANNER (compact) ──
                ZStack(alignment: .bottomLeading) {
                    if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                        KFImage(imageURL)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black.opacity(0.5), location: 0.5),
                                        .init(color: .black.opacity(0.95), location: 1),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    } else {
                        LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.2), .black], startPoint: .topTrailing, endPoint: .bottomLeading)
                            .frame(height: 140)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Presented by
                        if let topSponsor = sponsors.first {
                            HStack(spacing: 4) {
                                Text("PRESENTED BY")
                                    .font(.system(size: 8, weight: .heavy))
                                    .tracking(1)
                                Text(topSponsor.sponsorName)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.yellow.opacity(0.7))
                        }

                        HStack(spacing: 8) {
                            Text(tournament.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            StatusBadge(status: tournament.status)
                        }

                        HStack(spacing: 12) {
                            Label("\(tournament.playerCount ?? 0) builders", systemImage: "person.2.fill")
                            if let endDate = tournament.roundEndDateParsed {
                                RoundCountdown(endDate: endDate)
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                // ── TAB PILLS ──
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                                    withAnimation { scrollProxy.scrollTo(index, anchor: .center) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 10))
                                        Text(tab.title)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedTab == index ? Color.yellow : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedTab == index ? .black : .secondary)
                                    .clipShape(Capsule())
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedTab) { _, newValue in
                        withAnimation { scrollProxy.scrollTo(newValue, anchor: .center) }
                    }
                }

                // ── TAB CONTENT (swipeable) ──
                TabView(selection: $selectedTab) {
                    TournamentHomeTab(tournament: tournament, matchups: matchups, sponsors: sponsors)
                        .tag(0)

                    Group {
                        if loading {
                            VStack { Spacer(); ProgressView().tint(.yellow); Spacer() }
                        } else {
                            SimpleBracketList(matchups: matchups, tournament: tournament)
                        }
                    }
                    .tag(1)

                    VoteNowTab(tournament: tournament, matchups: matchups)
                        .tag(2)
                    ChatTab(tournamentId: tournament.id)
                        .tag(3)
                    SponsorsTab(tournamentId: tournament.id)
                        .tag(4)
                    PrizesTab(tournament: tournament)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            // Pad bottom for marquee
            .padding(.bottom, sponsors.isEmpty ? 0 : 48)

            // ── SPONSOR MARQUEE (sticky bottom) ──
            if selectedTab != 3 { // hide on chat
                SponsorMarquee(sponsors: sponsors)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadMatchups()
            await loadSponsors()
        }
        .onChange(of: matchups.count) { _, _ in
            if champion != nil && !showChampion {
                let key = "champion_shown_\(tournament.id)"
                if UserDefaults.standard.bool(forKey: key) == false {
                    UserDefaults.standard.set(true, forKey: key)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showChampion = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showChampion) {
            if let champ = champion {
                ChampionCelebration(
                    tournament: tournament,
                    winnerName: champ.name,
                    winnerAvatarUrl: champ.avatarUrl,
                    onDismiss: { showChampion = false }
                )
            }
        }
    }

    func loadMatchups() async {
        do {
            let response: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("tournament_id", value: tournament.id.uuidString)
                .order("round")
                .order("bracket_position")
                .execute()
                .value
            matchups = response
        } catch {
            print("Failed to load matchups: \(error)")
        }
        loading = false
    }

    func loadSponsors() async {
        do {
            let response: [SponsorData] = try await supabase.from("tournament_sponsors")
                .select()
                .eq("tournament_id", value: tournament.id.uuidString)
                .eq("status", value: "active")
                .execute()
                .value
            sponsors = response
        } catch {
            print("Failed to load sponsors: \(error)")
        }
    }
}

// MARK: - Chat Tab
struct ChatTab: View {
    let tournamentId: UUID
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            if loading {
                VStack { Spacer(); ProgressView().tint(.yellow); Spacer() }
            } else if messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("No messages yet")
                        .foregroundStyle(.secondary)
                    Text("Be the first to say something!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { msg in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(chatColor(msg.authorName ?? "?").opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(msg.authorName?.prefix(1) ?? "?").uppercased())
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(chatColor(msg.authorName ?? "?"))
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(msg.authorName ?? "User")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(chatColor(msg.authorName ?? "?"))
                                        if let dateStr = msg.createdAt {
                                            Text(timeAgo(dateStr))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Text(msg.content)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary.opacity(0.9))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            HStack(spacing: 10) {
                TextField("Message...", text: $newMessage)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())

                Button {
                    // TODO: send message
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.yellow)
                }
                .disabled(newMessage.isEmpty)
                .opacity(newMessage.isEmpty ? 0.3 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .task { await loadMessages() }
    }

    func loadMessages() async {
        do {
            let response: [ChatMessage] = try await supabase.from("chat_messages")
                .select()
                .eq("tournament_id", value: tournamentId.uuidString)
                .order("created_at")
                .execute()
                .value
            messages = response
        } catch {
            print("Failed to load chat: \(error)")
        }
        loading = false
    }

    func chatColor(_ name: String) -> Color {
        let colors: [Color] = [.yellow, .orange, .cyan, .green, .pink, .purple, .blue, .mint, .indigo, .red]
        return colors[abs(name.hashValue) % colors.count]
    }
}

// MARK: - Info Tab (kept for backward compat but Home tab replaces it)
struct InfoTab: View {
    let tournament: Tournament

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let desc = tournament.description {
                    Text(desc)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineSpacing(4)
                }
                HStack(spacing: 8) {
                    StatPill(value: "\(tournament.currentRound)", label: "Round", icon: "flag.fill")
                    StatPill(value: "\(tournament.playerCount ?? 0)", label: "Players", icon: "person.2.fill")
                    StatPill(value: "\(tournament.roundDurationHours ?? 48)h", label: "Per Round", icon: "clock.fill")
                }
            }
            .padding(16)
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.yellow)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
