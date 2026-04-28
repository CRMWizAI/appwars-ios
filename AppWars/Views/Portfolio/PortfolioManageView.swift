import SwiftUI
import Kingfisher

struct PortfolioData: Codable, Identifiable {
    let id: UUID
    let ownerEmail: String
    var discordUsername: String?
    var displayName: String?
    var bio: String?
    var isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerEmail = "owner_email"
        case discordUsername = "discord_username"
        case displayName = "display_name"
        case bio
        case isPublic = "is_public"
    }
}

struct PortfolioItemData: Codable, Identifiable {
    let id: UUID
    let ownerEmail: String
    var tournamentName: String?
    var round: Int?
    var category: String?
    var submissionUrl: String?
    var screenshotUrl: String?
    var originalDescription: String?
    var customTitle: String?
    var customDescription: String?
    var orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case ownerEmail = "owner_email"
        case tournamentName = "tournament_name"
        case round, category
        case submissionUrl = "submission_url"
        case screenshotUrl = "screenshot_url"
        case originalDescription = "original_description"
        case customTitle = "custom_title"
        case customDescription = "custom_description"
        case orderIndex = "order_index"
    }
}

struct PortfolioManageView: View {
    @EnvironmentObject var auth: AuthService
    @State private var portfolio: PortfolioData?
    @State private var items: [PortfolioItemData] = []
    @State private var loading = true
    @State private var bio = ""
    @State private var isPublic = true

    var shareUrl: String {
        guard let username = portfolio?.discordUsername, !username.isEmpty else { return "" }
        return "appwars.io/portfolio/\(username)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if loading {
                        ProgressView().padding(.top, 60)
                    } else {
                        // Visibility toggle
                        HStack {
                            Text("Portfolio Visibility")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Toggle("", isOn: $isPublic)
                                .tint(.yellow)
                                .onChange(of: isPublic) { _, newValue in
                                    Task { await updateVisibility(newValue) }
                                }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Share link
                        if isPublic && !shareUrl.isEmpty {
                            HStack {
                                Text(shareUrl)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = "https://\(shareUrl)"
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .padding()
                            .background(Color.yellow.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1))
                        }

                        // Bio
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bio")
                                .font(.system(size: 13, weight: .semibold))
                            TextEditor(text: $bio)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: bio) { _, newValue in
                                    Task { await updateBio(newValue) }
                                }
                        }

                        // Items
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("YOUR BUILDS")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(items.count) items")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            if items.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.stack")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.gray.opacity(0.3))
                                    Text("No builds yet")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Text("Submit builds in tournaments to build your portfolio")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            } else {
                                ForEach(items) { item in
                                    PortfolioItemRow(item: item)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Portfolio")
            .refreshable { await loadPortfolio() }
            .task { await loadPortfolio() }
        }
    }

    func loadPortfolio() async {
        guard let email = auth.profile?.email else { loading = false; return }
        do {
            let portfolios: [PortfolioData] = try await supabase.from("user_portfolios")
                .select()
                .eq("owner_email", value: email)
                .execute()
                .value
            portfolio = portfolios.first
            bio = portfolio?.bio ?? ""
            isPublic = portfolio?.isPublic ?? true

            items = try await supabase.from("portfolio_items")
                .select()
                .eq("owner_email", value: email)
                .order("order_index")
                .execute()
                .value
        } catch {
            print("Failed to load portfolio: \(error)")
        }
        loading = false
    }

    func updateVisibility(_ value: Bool) async {
        guard let pid = portfolio?.id else { return }
        try? await supabase.from("user_portfolios")
            .update(["is_public": value])
            .eq("id", value: pid.uuidString)
            .execute()
    }

    func updateBio(_ value: String) async {
        guard let pid = portfolio?.id else { return }
        try? await supabase.from("user_portfolios")
            .update(["bio": value])
            .eq("id", value: pid.uuidString)
            .execute()
    }
}

struct PortfolioItemRow: View {
    let item: PortfolioItemData

    var body: some View {
        HStack(spacing: 12) {
            if let url = item.screenshotUrl, let imageURL = URL(string: url) {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 60, height: 45)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.customTitle ?? item.category ?? "Build")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let tn = item.tournamentName {
                        Text(tn)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if let r = item.round {
                        Text("R\(r)")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.1))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if let url = item.submissionUrl, let link = URL(string: url) {
                Link(destination: link) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
