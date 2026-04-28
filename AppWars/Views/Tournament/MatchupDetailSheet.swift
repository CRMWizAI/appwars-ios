import SwiftUI
import Kingfisher

struct MatchupDetailSheet: View {
    let matchup: Matchup
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let category = matchup.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    SubmissionCard(
                        name: matchup.participantAUsername ?? "TBD",
                        screenshotUrl: matchup.participantAScreenshotUrl,
                        submissionUrl: matchup.participantASubmissionUrl,
                        description: matchup.participantADescription,
                        votes: matchup.votesA,
                        isWinner: matchup.winnerId == matchup.participantAId
                    )

                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)

                    SubmissionCard(
                        name: matchup.participantBUsername ?? "TBD",
                        screenshotUrl: matchup.participantBScreenshotUrl,
                        submissionUrl: matchup.participantBSubmissionUrl,
                        description: matchup.participantBDescription,
                        votes: matchup.votesB,
                        isWinner: matchup.winnerId == matchup.participantBId
                    )
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Round \(matchup.round)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct SubmissionCard: View {
    let name: String
    let screenshotUrl: String?
    let submissionUrl: String?
    let description: String?
    let votes: Int
    let isWinner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.headline)
                        if isWinner {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                    Text("\(votes) votes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = submissionUrl, let link = URL(string: url) {
                    Link(destination: link) {
                        Text("View App")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
            }

            if let desc = description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isWinner ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}
