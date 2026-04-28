import SwiftUI
import PhotosUI
import Kingfisher

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var discordUsername = ""
    @State private var displayName = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var saving = false
    @State private var modified = false
    @FocusState private var focusedField: Field?

    enum Field { case discord, displayName }

    // Stats
    @State private var tournamentsEntered = 0
    @State private var tournamentsWon = 0
    @State private var matchesWon = 0
    @State private var matchesLost = 0
    @State private var totalVotes = 0
    @State private var statsLoaded = false

    var winRate: Double {
        let total = matchesWon + matchesLost
        return total > 0 ? Double(matchesWon) / Double(total) : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            ZStack {
                                if let img = avatarImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else if let url = auth.profile?.avatarUrl, let imageURL = URL(string: url) {
                                    KFImage(imageURL)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.yellow.opacity(0.15))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 24))
                                                .foregroundStyle(.yellow)
                                        )
                                }

                                Circle()
                                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 2)
                                    .frame(width: 84, height: 84)
                            }
                        }

                        Text(auth.profile?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Username fields
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discord Username")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("username", text: $discordUsername)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .discord)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .displayName }
                                .onChange(of: discordUsername) { _, _ in modified = true }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Display Name")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("Display name", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .displayName)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .onChange(of: displayName) { _, _ in modified = true }
                        }
                    }
                    .padding(.horizontal)

                    if modified {
                        Button {
                            focusedField = nil
                            Task { await saveProfile() }
                        } label: {
                            HStack {
                                if saving { ProgressView().tint(.black) }
                                Text(saving ? "Saving..." : "Save Changes")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }

                    // Stats
                    VStack(spacing: 12) {
                        Text("YOUR STATS")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)

                        if statsLoaded {
                            LazyVGrid(columns: [.init(), .init()], spacing: 10) {
                                StatBox(value: "\(tournamentsEntered)", label: "Tournaments", icon: "trophy")
                                StatBox(value: "\(tournamentsWon)", label: "Wins", icon: "crown.fill")
                                StatBox(value: "\(matchesWon)-\(matchesLost)", label: "Record", icon: "chart.bar.fill")
                                StatBox(value: "\(totalVotes)", label: "Votes", icon: "hand.thumbsup.fill")
                            }

                            VStack(spacing: 4) {
                                HStack {
                                    Text("Win Rate")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(winRate * 100))%")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.yellow)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.15)).frame(height: 8)
                                        Capsule().fill(Color.yellow).frame(width: geo.size.width * winRate, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        } else {
                            ProgressView().tint(.yellow).padding()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Portfolio link
                    NavigationLink {
                        Text("Portfolio Editor coming soon")
                    } label: {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundStyle(.yellow)
                            Text("My Portfolio")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Links
                    VStack(spacing: 0) {
                        LinkRow(icon: "questionmark.circle", title: "Help & Support")
                        Divider().padding(.leading, 44)
                        LinkRow(icon: "hand.raised", title: "Privacy Policy")
                        Divider().padding(.leading, 44)
                        LinkRow(icon: "doc.text", title: "Terms of Service")
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Sign out
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focusedField = nil }
            .background(Color(.systemBackground))
            .navigationTitle("Profile")
            .task { await loadStats() }
            .onAppear {
                discordUsername = auth.profile?.discordUsername ?? ""
                displayName = auth.profile?.displayName ?? ""
                modified = false
            }
            .onChange(of: avatarItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
                        modified = true
                    }
                }
            }
        }
    }

    func loadStats() async {
        do {
            let matchups: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("status", value: "completed")
                .execute()
                .value

            let participants: [Participant] = try await supabase.from("participants")
                .select()
                .execute()
                .value

            let userParticipantIds = Set(participants.map { $0.id })
            tournamentsEntered = Set(participants.map { $0.tournamentId }).count

            var w = 0, l = 0, v = 0
            for m in matchups {
                guard m.winnerId != nil else { continue }
                if let aId = m.participantAId, userParticipantIds.contains(aId) {
                    if m.winnerId == aId { w += 1 } else { l += 1 }
                    v += m.votesA
                }
                if let bId = m.participantBId, userParticipantIds.contains(bId) {
                    if m.winnerId == bId { w += 1 } else { l += 1 }
                    v += m.votesB
                }
            }
            matchesWon = w
            matchesLost = l
            totalVotes = v
        } catch {
            print("Failed to load stats: \(error)")
        }
        statsLoaded = true
    }

    func saveProfile() async {
        saving = true
        do {
            var updates: [String: String] = [
                "discord_username": discordUsername,
                "display_name": displayName,
            ]

            if let image = avatarImage, let data = image.jpegData(compressionQuality: 0.8) {
                let fileName = "avatars/\(auth.profile?.id.uuidString ?? "unknown").jpg"
                try await supabase.storage.from("appwars").upload(fileName, data: data, options: .init(contentType: "image/jpeg", upsert: true))
                let url = try supabase.storage.from("appwars").getPublicURL(path: fileName)
                updates["avatar_url"] = url.absoluteString
            }

            try await supabase.from("profiles")
                .update(updates)
                .eq("id", value: auth.profile?.id.uuidString ?? "")
                .execute()

            if let profileId = auth.profile?.id {
                await auth.fetchProfile(userId: profileId)
            }
            modified = false
        } catch {
            print("Save failed: \(error)")
        }
        saving = false
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.yellow)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LinkRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
