import SwiftUI
import Kingfisher

struct PrizesTab: View {
    let tournament: Tournament

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let prizes = tournament.prizes, !prizes.isEmpty {
                    ForEach(prizes, id: \.place) { prize in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(prize.place == 1 ? Color.yellow.opacity(0.2) : prize.place == 2 ? Color.gray.opacity(0.2) : Color.orange.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                Image(systemName: prize.place == 1 ? "trophy.fill" : prize.place == 2 ? "medal.fill" : "star.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(prize.place == 1 ? .yellow : prize.place == 2 ? .gray : .orange)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(placeLabel(prize.place))
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(1)
                                    .foregroundStyle(.secondary)
                                Text(prize.name)
                                    .font(.system(size: 16, weight: .semibold))
                            }

                            Spacer()

                            if let url = prize.imageUrl, let imageURL = URL(string: url) {
                                KFImage(imageURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray.opacity(0.3))
                        Text("No prizes listed")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }

    func placeLabel(_ place: Int) -> String {
        switch place {
        case 1: return "1ST PLACE"
        case 2: return "2ND PLACE"
        case 3: return "3RD PLACE"
        default: return "\(place)TH PLACE"
        }
    }
}
