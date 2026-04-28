import SwiftUI
import Kingfisher

/// Full matchup voting sheet — see both submissions, vote, confirm.
struct MatchupVotingSheet: View {
    let matchup: Matchup
    let tournament: Tournament
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService

    @State private var hasVoted = false
    @State private var votedFor: UUID?
    @State private var confirmingVoteFor: UUID?
    @State private var voting = false
    @State private var localVotesA: Int
    @State private var localVotesB: Int
    @State private var showImageA = false
    @State private var showImageB = false

    init(matchup: Matchup, tournament: Tournament) {
        self.matchup = matchup
        self.tournament = tournament
        _localVotesA = State(initialValue: matchup.votesA)
        _localVotesB = State(initialValue: matchup.votesB)
    }

    var totalVotes: Int { localVotesA + localVotesB }
    var pctA: Double { totalVotes > 0 ? Double(localVotesA) / Double(totalVotes) : 0.5 }
    var pctB: Double { totalVotes > 0 ? Double(localVotesB) / Double(totalVotes) : 0.5 }
    var isVoting: Bool { matchup.status == "voting" }
    var isTied: Bool { localVotesA == localVotesB && localVotesA > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Round + Category
                    VStack(spacing: 4) {
                        Text("ROUND \(matchup.round)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                        if let cat = matchup.category {
                            Text(cat)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        if isTied && isVoting {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                                Text("Tiebreaker — next vote wins!")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Submission A
                    SubmissionPanel(
                        name: matchup.participantAUsername ?? "TBD",
                        screenshotUrl: matchup.participantAScreenshotUrl,
                        submissionUrl: matchup.participantASubmissionUrl,
                        description: matchup.participantADescription,
                        votes: localVotesA,
                        pct: pctA,
                        isWinner: matchup.winnerId == matchup.participantAId,
                        isVotedFor: votedFor == matchup.participantAId,
                        isConfirming: confirmingVoteFor == matchup.participantAId,
                        canVote: isVoting && !hasVoted,
                        onVote: { initiateVote(for: matchup.participantAId, username: matchup.participantAUsername) },
                        onConfirm: { Task { await confirmVote(for: matchup.participantAId!, username: matchup.participantAUsername ?? "") } }
                    )

                    Text("VS")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.3))

                    // Submission B
                    SubmissionPanel(
                        name: matchup.participantBUsername ?? "TBD",
                        screenshotUrl: matchup.participantBScreenshotUrl,
                        submissionUrl: matchup.participantBSubmissionUrl,
                        description: matchup.participantBDescription,
                        votes: localVotesB,
                        pct: pctB,
                        isWinner: matchup.winnerId == matchup.participantBId,
                        isVotedFor: votedFor == matchup.participantBId,
                        isConfirming: confirmingVoteFor == matchup.participantBId,
                        canVote: isVoting && !hasVoted,
                        onVote: { initiateVote(for: matchup.participantBId, username: matchup.participantBUsername) },
                        onConfirm: { Task { await confirmVote(for: matchup.participantBId!, username: matchup.participantBUsername ?? "") } }
                    )

                    // Vote receipt
                    if hasVoted {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Vote recorded — \(totalVotes) total votes")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(matchup.category ?? "Matchup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await checkExistingVote() }
    }

    func initiateVote(for participantId: UUID?, username: String?) {
        guard let pid = participantId else { return }
        if confirmingVoteFor == pid {
            confirmingVoteFor = nil
        } else {
            confirmingVoteFor = pid
        }
    }

    func confirmVote(for participantId: UUID, username: String) async {
        guard let email = auth.profile?.email, !voting else { return }
        voting = true
        do {
            try await supabase.from("votes").insert([
                "matchup_id": matchup.id.uuidString,
                "voted_for_id": participantId.uuidString,
                "voted_for_username": username,
                "voter_fingerprint": email,
            ]).execute()

            // Optimistic update
            if participantId == matchup.participantAId {
                localVotesA += 1
            } else {
                localVotesB += 1
            }

            // Update matchup vote counts
            try await supabase.from("matchups")
                .update([
                    "votes_a": localVotesA,
                    "votes_b": localVotesB,
                ] as [String: Int])
                .eq("id", value: matchup.id.uuidString)
                .execute()

            hasVoted = true
            votedFor = participantId
            confirmingVoteFor = nil
        } catch {
            print("Vote failed: \(error)")
        }
        voting = false
    }

    func checkExistingVote() async {
        guard let email = auth.profile?.email else { return }
        do {
            let votes: [VoteRecord] = try await supabase.from("votes")
                .select()
                .eq("matchup_id", value: matchup.id.uuidString)
                .eq("voter_fingerprint", value: email)
                .execute()
                .value
            if let vote = votes.first {
                hasVoted = true
                votedFor = vote.votedForId
            }
        } catch {}
    }
}

// MARK: - Submission Panel
struct SubmissionPanel: View {
    let name: String
    let screenshotUrl: String?
    let submissionUrl: String?
    let description: String?
    let votes: Int
    let pct: Double
    let isWinner: Bool
    let isVotedFor: Bool
    let isConfirming: Bool
    let canVote: Bool
    let onVote: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Screenshot
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 160)
                    .overlay(
                        Text("No submission yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    )
            }

            // Name + votes
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                        if isWinner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("\(votes) votes")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("(\(Int(pct * 100))%)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                // View App link
                if let url = submissionUrl, let link = URL(string: url) {
                    Link(destination: link) {
                        Text("View App")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
            }

            // Vote bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 6)
                    Capsule().fill(isWinner ? Color.yellow : Color.blue).frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)

            // Description
            if let desc = description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            // Vote button
            if canVote {
                if isConfirming {
                    Button(action: onConfirm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Vote for \(name)")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Button(action: onVote) {
                        Text("Vote for \(name)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else if isVotedFor {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Your vote")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isWinner ? Color.yellow.opacity(0.3) : isVotedFor ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}
