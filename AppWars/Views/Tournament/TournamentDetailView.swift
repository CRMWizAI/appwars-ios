import SwiftUI
import Kingfisher

struct TournamentDetailView: View {
    let tournament: Tournament
    @State private var selectedTab = 0
    @State private var matchups: [Matchup] = []
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
        (title: "Bracket", icon: "trophy.fill"),
        (title: "Vote Now", icon: "hand.thumbsup.fill"),
        (title: "Chat", icon: "bubble.left.fill"),
        (title: "Sponsors", icon: "building.2.fill"),
        (title: "Prizes", icon: "gift.fill"),
        (title: "Info", icon: "info.circle.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── HERO BANNER ──
            ZStack(alignment: .bottomLeading) {
                if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.4), location: 0.4),
                                    .init(color: .black.opacity(0.9), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2), .black],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow.opacity(0.15))
                    }
                    .frame(height: 200)
                }

                VStack(alignment: .leading, spacing: 8) {
                    StatusBadge(status: tournament.status)

                    Text(tournament.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)

                    HStack(spacing: 14) {
                        Label("Round \(tournament.currentRound)/\(tournament.totalRounds ?? 3)", systemImage: "flag.fill")
                        if let count = tournament.playerCount {
                            Label("\(count) builders", systemImage: "person.2.fill")
                        }
                        if let hours = tournament.roundDurationHours {
                            Label("\(hours)h rounds", systemImage: "clock.fill")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            // ── COUNTDOWN + CATEGORY BAR ──
            HStack {
                if let endDate = tournament.roundEndDateParsed {
                    RoundCountdown(endDate: endDate)
                }
                Spacer()
                if let cat = tournament.currentCategory {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.yellow.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // ── TAB PILLS ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == index
                                    ? Color.yellow
                                    : Color(.secondarySystemBackground)
                            )
                            .foregroundStyle(
                                selectedTab == index ? .black : .secondary
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Subtle separator
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.top, 6)

            // ── TAB CONTENT ──
            Group {
                switch selectedTab {
                case 0:
                    if loading {
                        VStack {
                            Spacer()
                            ProgressView()
                                .tint(.yellow)
                            Spacer()
                        }
                    } else if matchups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 44))
                                .foregroundStyle(.gray.opacity(0.3))
                            Text("No matchups yet")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SimpleBracketList(matchups: matchups, tournament: tournament)
                    }
                case 1: VoteNowTab(tournament: tournament, matchups: matchups)
                case 2: ChatTab(tournamentId: tournament.id)
                case 3: SponsorsTab(tournamentId: tournament.id)
                case 4: PrizesTab(tournament: tournament)
                case 5: InfoTab(tournament: tournament)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadMatchups() }
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
        print("Loading matchups for tournament: \(tournament.id.uuidString)")
        do {
            let response: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("tournament_id", value: tournament.id.uuidString)
                .order("round")
                .order("bracket_position")
                .execute()
                .value
            print("Loaded \(response.count) matchups")
            matchups = response
        } catch {
            print("Failed to load matchups: \(error)")
        }
        loading = false
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

            // Input bar
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

// MARK: - Info Tab
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

                if let prizes = tournament.prizes, !prizes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PRIZES")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)

                        ForEach(prizes, id: \.place) { prize in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(prize.place == 1 ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: prize.place == 1 ? "trophy.fill" : "medal.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(prize.place == 1 ? .yellow : .gray)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prize.place == 1 ? "1st Place" : "\(prize.place)th Place")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(prize.name)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                Spacer()
                                if let url = prize.imageUrl, let imageURL = URL(string: url) {
                                    KFImage(imageURL)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
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
