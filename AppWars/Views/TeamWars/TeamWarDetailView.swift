import SwiftUI
import Kingfisher

struct TeamWarDetailView: View {
    let warId: UUID
    @EnvironmentObject var auth: AuthService
    @State private var war: TeamWar?
    @State private var participants: [TeamWarParticipantData] = []
    @State private var matches: [TeamWarMatchData] = []
    @State private var loading = true
    @State private var showSignup = false

    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 60)
            } else if let war = war {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text(war.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        StatusBadge(status: war.status)
                        if let desc = war.description {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Team scoreboard
                    if let teams = war.teams {
                        TeamScoreboardView(teams: teams, participants: participants, winningKey: war.winningTeamKey)
                    }

                    // Current round matches
                    let currentMatches = matches.filter { $0.round == war.currentRound }
                    if !currentMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("ROUND \(war.currentRound)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let cat = war.currentCategory {
                                    Text(cat)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ForEach(currentMatches) { match in
                                TeamWarMatchRow(match: match)
                            }
                        }
                    }

                    // Past rounds
                    let pastRounds = Set(matches.filter { $0.round < war.currentRound }.map(\.round)).sorted(by: >)
                    ForEach(pastRounds, id: \.self) { round in
                        let roundMatches = matches.filter { $0.round == round }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROUND \(round)")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(.tertiary)
                            ForEach(roundMatches) { match in
                                TeamWarMatchRow(match: match)
                            }
                        }
                    }

                    // Sign up button
                    if war.status == "registration" {
                        Button { showSignup = true } label: {
                            Text("Join This War")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.yellow)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Roster
                    if !participants.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ROSTER")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.secondary)

                            ForEach(participants) { p in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(teamColor(p.teamKey).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(p.discordUsername.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(teamColor(p.teamKey))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.discordUsername)
                                            .font(.system(size: 13, weight: .medium))
                                        Text(p.teamName ?? p.teamKey)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(p.wins)W \(p.losses)L")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(p.status == "eliminated" ? .red : .secondary)
                                }
                                .opacity(p.status == "eliminated" ? 0.5 : 1)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(war?.name ?? "Team War")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .sheet(isPresented: $showSignup) {
            Text("Team War signup coming soon")
        }
    }

    func teamColor(_ key: String) -> Color {
        switch key {
        case "base44": return .blue
        case "lovable": return .pink
        case "replit": return .orange
        case "bolt": return .green
        default: return .purple
        }
    }

    func loadData() async {
        do {
            let wars: [TeamWar] = try await supabase.from("team_wars")
                .select()
                .eq("id", value: warId.uuidString)
                .execute()
                .value
            war = wars.first

            participants = try await supabase.from("team_war_participants")
                .select()
                .eq("war_id", value: warId.uuidString)
                .execute()
                .value

            matches = try await supabase.from("team_war_matches")
                .select()
                .eq("war_id", value: warId.uuidString)
                .order("round")
                .execute()
                .value
        } catch {
            print("Failed to load team war: \(error)")
        }
        loading = false
    }
}

// MARK: - Data models for team wars
struct TeamWarParticipantData: Codable, Identifiable {
    let id: UUID
    let warId: UUID
    let teamKey: String
    var teamName: String?
    let discordUsername: String
    var wins: Int
    var losses: Int
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case warId = "war_id"
        case teamKey = "team_key"
        case teamName = "team_name"
        case discordUsername = "discord_username"
        case wins, losses, status
    }
}

struct TeamWarMatchData: Codable, Identifiable {
    let id: UUID
    let warId: UUID
    let round: Int
    var participantAUsername: String?
    var participantBUsername: String?
    var participantATeamKey: String?
    var participantBTeamKey: String?
    var votesA: Int
    var votesB: Int
    var winnerUsername: String?
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, round, status
        case warId = "war_id"
        case participantAUsername = "participant_a_username"
        case participantBUsername = "participant_b_username"
        case participantATeamKey = "participant_a_team_key"
        case participantBTeamKey = "participant_b_team_key"
        case votesA = "votes_a"
        case votesB = "votes_b"
        case winnerUsername = "winner_username"
    }
}

struct TeamScoreboardView: View {
    let teams: [TeamInfo]?
    let participants: [TeamWarParticipantData]
    let winningKey: String?

    var body: some View {
        if let teams = teams {
            HStack(spacing: 12) {
                ForEach(teams, id: \.key) { team in
                    let teamParticipants = participants.filter { $0.teamKey == team.key }
                    let active = teamParticipants.filter { $0.status == "active" }.count
                    let eliminated = teamParticipants.filter { $0.status == "eliminated" }.count
                    let isWinner = winningKey == team.key

                    VStack(spacing: 6) {
                        Text(team.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isWinner ? .yellow : .primary)
                        HStack(spacing: 4) {
                            Text("\(active)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("active")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        if eliminated > 0 {
                            Text("\(eliminated) eliminated")
                                .font(.system(size: 9))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        if isWinner {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isWinner ? Color.yellow.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
    }
}

struct TeamWarMatchRow: View {
    let match: TeamWarMatchData

    var totalVotes: Int { match.votesA + match.votesB }
    var isCompleted: Bool { match.status == "completed" }

    func teamColor(_ key: String?) -> Color {
        switch key {
        case "base44": return .blue
        case "lovable": return .pink
        case "replit": return .orange
        case "bolt": return .green
        default: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Side A
            VStack(spacing: 2) {
                Text(match.participantAUsername ?? "TBD")
                    .font(.system(size: 12, weight: match.winnerUsername == match.participantAUsername ? .bold : .regular))
                    .lineLimit(1)
                if let key = match.participantATeamKey {
                    Text(key.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(teamColor(key))
                }
            }
            .frame(maxWidth: .infinity)

            // Score
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(match.votesA)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("-")
                        .foregroundStyle(.secondary)
                    Text("\(match.votesB)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Text(isCompleted ? "Final" : "Live")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isCompleted ? .gray : .green)
            }

            // Side B
            VStack(spacing: 2) {
                Text(match.participantBUsername ?? "TBD")
                    .font(.system(size: 12, weight: match.winnerUsername == match.participantBUsername ? .bold : .regular))
                    .lineLimit(1)
                if let key = match.participantBTeamKey {
                    Text(key.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(teamColor(key))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
