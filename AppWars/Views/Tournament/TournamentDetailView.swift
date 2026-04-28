import SwiftUI

struct TournamentDetailView: View {
    let tournament: Tournament
    @State private var selectedTab = 0
    @State private var matchups: [Matchup] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Bracket").tag(0)
                Text("Chat").tag(1)
                Text("Info").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                BracketTab(tournament: tournament, matchups: matchups, loading: loading)
                    .tag(0)
                ChatTab(tournamentId: tournament.id)
                    .tag(1)
                InfoTab(tournament: tournament)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMatchups() }
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
}

// MARK: - Bracket Tab
struct BracketTab: View {
    let tournament: Tournament
    let matchups: [Matchup]
    let loading: Bool

    var body: some View {
        ScrollView {
            if loading {
                ProgressView()
                    .padding(.top, 40)
            } else {
                let rounds = Dictionary(grouping: matchups, by: \.round)
                    .sorted { $0.key < $1.key }

                ForEach(rounds, id: \.key) { round, roundMatchups in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Round \(round)")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(roundMatchups) { matchup in
                            MatchupCardView(matchup: matchup)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
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
                LazyVStack(spacing: 8) {
                    ForEach(messages) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(String(msg.authorName?.prefix(1) ?? "?").uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.yellow)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(msg.authorName ?? "User")
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    if let date = msg.createdAt {
                                        Text(date, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(msg.content)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            // Input
            HStack(spacing: 8) {
                TextField("Message...", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
                Button {
                    // TODO: send message
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
                .disabled(newMessage.isEmpty)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
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
            VStack(alignment: .leading, spacing: 16) {
                if let desc = tournament.description {
                    Text(desc)
                        .font(.body)
                }

                HStack {
                    InfoChip(label: "Status", value: tournament.status.capitalized)
                    InfoChip(label: "Round", value: "\(tournament.currentRound)")
                    if let count = tournament.playerCount {
                        InfoChip(label: "Players", value: "\(count)")
                    }
                }

                if let prizes = tournament.prizes, !prizes.isEmpty {
                    Text("Prizes")
                        .font(.headline)
                    ForEach(prizes, id: \.place) { prize in
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(prize.place == 1 ? .yellow : .gray)
                            Text("#\(prize.place) — \(prize.name)")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct InfoChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MatchupCardView: View {
    let matchup: Matchup

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                PlayerSide(name: matchup.participantAUsername ?? "TBD", votes: matchup.votesA, isWinner: matchup.winnerId == matchup.participantAId)
                Text("vs")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                PlayerSide(name: matchup.participantBUsername ?? "TBD", votes: matchup.votesB, isWinner: matchup.winnerId == matchup.participantBId)
            }

            if let category = matchup.category {
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PlayerSide: View {
    let name: String
    let votes: Int
    let isWinner: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline.weight(isWinner ? .bold : .regular))
                .lineLimit(1)
                .foregroundStyle(isWinner ? .yellow : .primary)
            Text("\(votes) votes")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
