import SwiftUI
import Kingfisher

/// Sticky bottom scrolling sponsor logo banner — mirrors the web SponsorMarquee.
/// Shows only sponsors with marquee_logo perk. Tracks impressions once per session.
struct SponsorMarquee: View {
    let sponsors: [SponsorData]
    @State private var offset: CGFloat = 0
    @State private var impressionTracked = false

    let logoHeight: CGFloat = 32
    let scrollSpeed: CGFloat = 30 // points per second

    var body: some View {
        if sponsors.isEmpty { EmptyView() }
        else {
            HStack(spacing: 0) {
                // Gradient fade left
                LinearGradient(colors: [Color(.systemBackground), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 24)
                    .zIndex(1)

                GeometryReader { geo in
                    let totalWidth = CGFloat(sponsors.count) * 160
                    HStack(spacing: 24) {
                        // Double the logos for seamless loop
                        ForEach(0..<2, id: \.self) { _ in
                            ForEach(sponsors) { sponsor in
                                if let url = sponsor.logoUrl, let imageURL = URL(string: url) {
                                    Button {
                                        trackClick(sponsor)
                                        if let link = sponsor.linkUrl, let linkURL = URL(string: link) {
                                            UIApplication.shared.open(linkURL)
                                        }
                                    } label: {
                                        KFImage(imageURL)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: logoHeight)
                                            .frame(maxWidth: 120)
                                    }
                                }
                            }
                        }
                    }
                    .offset(x: offset)
                    .onAppear {
                        // Start scrolling animation
                        let duration = Double(totalWidth) / Double(scrollSpeed)
                        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                            offset = -totalWidth - 24
                        }
                        // Track impressions once
                        if !impressionTracked {
                            impressionTracked = true
                            for s in sponsors { trackImpression(s) }
                        }
                    }
                }

                // Gradient fade right
                LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 24)
                    .zIndex(1)
            }
            .frame(height: 48)
            .background(Color(.systemBackground).opacity(0.95))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            }
        }
    }

    func trackClick(_ sponsor: SponsorData) {
        Task {
            try? await supabase.from("tournament_sponsors")
                .update(["click_count": sponsor.clickCount + 1])
                .eq("id", value: sponsor.id.uuidString)
                .execute()
        }
    }

    func trackImpression(_ sponsor: SponsorData) {
        Task {
            try? await supabase.from("tournament_sponsors")
                .update(["impression_count": sponsor.impressionCount + 1])
                .eq("id", value: sponsor.id.uuidString)
                .execute()
        }
    }
}
