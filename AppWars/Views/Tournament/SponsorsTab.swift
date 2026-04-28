import SwiftUI
import Kingfisher

struct SponsorData: Codable, Identifiable {
    let id: UUID
    let sponsorName: String
    let logoUrl: String?
    let linkUrl: String?
    let tier: String?
    let status: String
    var clickCount: Int
    var impressionCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sponsorName = "sponsor_name"
        case logoUrl = "logo_url"
        case linkUrl = "link_url"
        case tier, status
        case clickCount = "click_count"
        case impressionCount = "impression_count"
    }
}

struct SponsorsTab: View {
    let tournamentId: UUID
    @State private var sponsors: [SponsorData] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if loading {
                    ProgressView()
                        .padding(.top, 40)
                } else if sponsors.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray.opacity(0.3))
                        Text("No sponsors yet")
                            .foregroundStyle(.secondary)
                        Text("Be the first to support this tournament")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 60)
                } else {
                    // Group by tier
                    let grouped = Dictionary(grouping: sponsors, by: { $0.tier ?? "standard" })
                    let sortedTiers = grouped.keys.sorted { tierOrder($0) < tierOrder($1) }

                    ForEach(sortedTiers, id: \.self) { tier in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(tier.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(tier == "platinum" ? .yellow : .secondary)

                            let tierSponsors = grouped[tier] ?? []
                            ForEach(tierSponsors) { sponsor in
                                SponsorCard(sponsor: sponsor)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .task { await loadSponsors() }
    }

    func loadSponsors() async {
        do {
            let result: [SponsorData] = try await supabase.from("tournament_sponsors")
                .select()
                .eq("tournament_id", value: tournamentId.uuidString)
                .eq("status", value: "active")
                .execute()
                .value
            sponsors = result
        } catch {
            print("Failed to load sponsors: \(error)")
        }
        loading = false
    }

    func tierOrder(_ tier: String) -> Int {
        switch tier {
        case "platinum": return 0
        case "gold": return 1
        case "premium": return 2
        case "silver": return 3
        case "standard": return 4
        default: return 5
        }
    }
}

struct SponsorCard: View {
    let sponsor: SponsorData

    var body: some View {
        HStack(spacing: 12) {
            if let url = sponsor.logoUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundStyle(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(sponsor.sponsorName)
                    .font(.system(size: 14, weight: .semibold))
                if let tier = sponsor.tier {
                    Text(tier.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let url = sponsor.linkUrl, let link = URL(string: url) {
                Link(destination: link) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
