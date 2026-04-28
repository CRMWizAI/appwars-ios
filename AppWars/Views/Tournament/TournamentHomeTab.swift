import SwiftUI
import Kingfisher

/// Tournament home/overview tab — hero, stats, current round, prizes, sponsors.
struct TournamentHomeTab: View {
    let tournament: Tournament
    let matchups: [Matchup]
    let sponsors: [SponsorData]

    var currentRoundMatchups: [Matchup] {
        matchups.filter { $0.round == tournament.currentRound }
            .sorted { ($0.bracketPosition ?? 0) < ($1.bracketPosition ?? 0) }
    }

    var topSponsor: SponsorData? {
        sponsors.sorted { tierOrder($0.tier ?? "") < tierOrder($1.tier ?? "") }.first
    }

    var champion: (name: String, avatarUrl: String?)? {
        guard tournament.isCompleted,
              let finals = matchups.first(where: { $0.round == (tournament.totalRounds ?? 3) }),
              let winnerName = finals.winnerUsername else { return nil }
        let avatarUrl = finals.winnerId == finals.participantAId
            ? finals.participantAScreenshotUrl : finals.participantBScreenshotUrl
        return (winnerName, avatarUrl)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Presented by sponsor
                if let sponsor = topSponsor {
                    HStack(spacing: 8) {
                        Text("BROUGHT TO YOU BY")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.yellow.opacity(0.6))
                        if let url = sponsor.logoUrl, let imageURL = URL(string: url) {
                            KFImage(imageURL)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 22)
                        }
                        Text(sponsor.sponsorName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1))
                }

                // Champion banner (if completed)
                if let champ = champion {
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 6)

                        if let url = champ.avatarUrl, let imageURL = URL(string: url) {
                            KFImage(imageURL)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 2.5))
                        }

                        Text(champ.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text("SEASON CHAMPION")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.yellow.opacity(0.5))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1))
                }

                // Description
                if let desc = tournament.description {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                // Stats row
                HStack(spacing: 8) {
                    StatPill(value: "\(tournament.currentRound)/\(tournament.totalRounds ?? 3)", label: "Round", icon: "flag.fill")
                    StatPill(value: "\(tournament.playerCount ?? 0)", label: "Builders", icon: "person.2.fill")
                    StatPill(value: "\(tournament.roundDurationHours ?? 48)h", label: "Per Round", icon: "clock.fill")
                }

                // Current round matchups preview
                if !currentRoundMatchups.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CURRENT ROUND")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let cat = tournament.currentCategory {
                                Text(cat)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.yellow)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.yellow.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        ForEach(currentRoundMatchups) { matchup in
                            HStack(spacing: 8) {
                                Text(matchup.participantAUsername ?? "TBD")
                                    .font(.system(size: 13, weight: matchup.winnerId == matchup.participantAId ? .bold : .regular))
                                    .foregroundColor(matchup.winnerId == matchup.participantAId ? .yellow : .white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("\(matchup.votesA) - \(matchup.votesB)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50)
                                Text(matchup.participantBUsername ?? "TBD")
                                    .font(.system(size: 13, weight: matchup.winnerId == matchup.participantBId ? .bold : .regular))
                                    .foregroundColor(matchup.winnerId == matchup.participantBId ? .yellow : .white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
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
                                Image(systemName: prize.place == 1 ? "trophy.fill" : "medal.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(prize.place == 1 ? .yellow : .gray)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prize.place == 1 ? "1st Place" : "\(prize.place)th Place")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(prize.name)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                // Sponsor logos grid
                if !sponsors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SPONSORS")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [.init(), .init(), .init()], spacing: 10) {
                            ForEach(sponsors) { sponsor in
                                Button {
                                    if let link = sponsor.linkUrl, let url = URL(string: link) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        if let url = sponsor.logoUrl, let imageURL = URL(string: url) {
                                            KFImage(imageURL)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 36)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.15))
                                                .frame(height: 36)
                                                .overlay(Text(String(sponsor.sponsorName.prefix(2)).uppercased()).font(.system(size: 12, weight: .bold)).foregroundStyle(.gray))
                                        }
                                        Text(sponsor.sponsorName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    func tierOrder(_ tier: String) -> Int {
        switch tier {
        case "platinum": return 0
        case "gold": return 1
        case "premium": return 2
        default: return 3
        }
    }
}
