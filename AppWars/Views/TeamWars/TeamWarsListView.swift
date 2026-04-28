import SwiftUI

struct TeamWarsListView: View {
    @State private var wars: [TeamWar] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if loading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .shimmer()
                        }
                    } else if wars.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray)
                            Text("No team wars yet")
                                .foregroundStyle(.gray)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(wars) { war in
                            NavigationLink(destination: TeamWarDetailView(warId: war.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(war.name)
                                    .font(.headline)
                                HStack {
                                    StatusBadge(status: war.status)
                                    Text("Round \(war.currentRound)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let desc = war.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            }
                            .buttonStyle(.plain)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Team Wars")
            .refreshable { await loadWars() }
            .task { await loadWars() }
        }
    }

    func loadWars() async {
        do {
            let response: [TeamWar] = try await supabase.from("team_wars")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            wars = response
        } catch {
            print("Failed to load team wars: \(error)")
        }
        loading = false
    }
}
