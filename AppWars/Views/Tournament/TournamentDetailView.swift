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

    var body: some View {
        VStack(spacing: 0) {
            // Hero banner
            ZStack(alignment: .bottomLeading) {
                if let url = tournament.imageUrl, let imageURL = URL(string: url) {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2), .black],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(height: 180)
                }

                VStack(alignment: .leading, spacing: 6) {
                    StatusBadge(status: tournament.status)

                    Text(tournament.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
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
                .padding(16)
            }

            // Round countdown
            if let endDate = tournament.roundEndDateParsed {
                HStack {
                    RoundCountdown(endDate: endDate)
                    Spacer()
                    if let cat = tournament.currentCategory {
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            // Tab picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    TabButton(title: "Bracket", isSelected: selectedTab == 0) { selectedTab = 0 }
                    TabButton(title: "Vote Now", isSelected: selectedTab == 1) { selectedTab = 1 }
                    TabButton(title: "Chat", isSelected: selectedTab == 2) { selectedTab = 2 }
                    TabButton(title: "Sponsors", isSelected: selectedTab == 3) { selectedTab = 3 }
                    TabButton(title: "Prizes", isSelected: selectedTab == 4) { selectedTab = 4 }
                    TabButton(title: "Info", isSelected: selectedTab == 5) { selectedTab = 5 }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)

            // Content — lazy switch instead of TabView to avoid rendering all tabs at once
            Group {
                switch selectedTab {
                case 0:
                    if loading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Custom Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .yellow : .secondary)
                Rectangle()
                    .fill(isSelected ? Color.yellow : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Chat Tab
struct ChatTab: View {
    let tournamentId: UUID
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(String(msg.authorName?.prefix(1) ?? "?").uppercased())
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.yellow)
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(msg.authorName ?? "User")
                                        .font(.system(size: 12, weight: .semibold))
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
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
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
                        .font(.system(size: 28))
                        .foregroundStyle(.yellow)
                }
                .disabled(newMessage.isEmpty)
                .opacity(newMessage.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

                // Stats row
                HStack(spacing: 0) {
                    StatPill(value: "\(tournament.currentRound)", label: "Round", icon: "flag.fill")
                    StatPill(value: "\(tournament.playerCount ?? 0)", label: "Players", icon: "person.2.fill")
                    StatPill(value: "\(tournament.roundDurationHours ?? 48)h", label: "Per Round", icon: "clock.fill")
                }

                // Prizes
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
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(prize.place == 1 ? .yellow : .gray)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("#\(prize.place) Place")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(prize.name)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
