import SwiftUI

struct AdminView: View {
    @EnvironmentObject var auth: AuthService
    @State private var tournaments: [Tournament] = []
    @State private var categories: [BuildCategoryData] = []
    @State private var loading = true
    @State private var newCategoryName = ""
    @State private var showNewTournament = false

    var body: some View {
        NavigationStack {
            if auth.profile?.role != "admin" {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 44))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("Admin access required")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    // Tournaments
                    Section("Tournaments") {
                        ForEach(tournaments) { t in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(t.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    StatusBadge(status: t.status)
                                }
                                HStack(spacing: 12) {
                                    Text("Round \(t.currentRound)/\(t.totalRounds ?? 0)")
                                    Text("\(t.playerCount ?? 0) players")
                                    if let cat = t.currentCategory {
                                        Text(cat).lineLimit(1)
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                                // Action buttons
                                HStack(spacing: 8) {
                                    if t.isRegistration {
                                        AdminButton(title: "Start", color: .green) {
                                            // TODO: start tournament
                                        }
                                    }
                                    if t.isActive {
                                        AdminButton(title: "Advance Round", color: .blue) {
                                            // TODO: advance round
                                        }
                                        AdminButton(title: "Email Voters", color: .purple) {
                                            // TODO: send voter emails
                                        }
                                    }
                                    NavigationLink {
                                        TournamentDetailView(tournament: t)
                                    } label: {
                                        Text("View")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Build categories
                    Section("Build Categories") {
                        ForEach(categories) { cat in
                            HStack {
                                Text(cat.name)
                                    .font(.system(size: 13))
                                Spacer()
                                if cat.used {
                                    Text("Used")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        HStack {
                            TextField("New category", text: $newCategoryName)
                                .font(.system(size: 13))
                            Button("Add") {
                                Task { await addCategory() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .disabled(newCategoryName.isEmpty)
                        }
                    }
                }
                .navigationTitle("Admin")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showNewTournament = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .refreshable { await loadData() }
                .task { await loadData() }
                .sheet(isPresented: $showNewTournament) {
                    NewTournamentSheet(onCreated: { Task { await loadData() } })
                }
            }
        }
    }

    func loadData() async {
        do {
            tournaments = try await supabase.from("tournaments")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            categories = try await supabase.from("build_categories")
                .select()
                .order("name")
                .execute()
                .value
        } catch {
            print("Failed to load admin data: \(error)")
        }
        loading = false
    }

    func addCategory() async {
        guard !newCategoryName.isEmpty else { return }
        do {
            try await supabase.from("build_categories")
                .insert(["name": newCategoryName, "used": "false"])
                .execute()
            newCategoryName = ""
            await loadData()
        } catch {
            print("Failed to add category: \(error)")
        }
    }
}

struct AdminButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
    }
}

struct BuildCategoryData: Codable, Identifiable {
    let id: UUID
    let name: String
    var used: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, used
    }
}

struct NewTournamentSheet: View {
    let onCreated: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var playerCount = "8"
    @State private var roundDuration = "48"
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Tournament Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Config") {
                    Picker("Players", selection: $playerCount) {
                        Text("8").tag("8")
                        Text("16").tag("16")
                        Text("32").tag("32")
                    }
                    Picker("Round Duration", selection: $roundDuration) {
                        Text("24 hours").tag("24")
                        Text("48 hours").tag("48")
                        Text("72 hours").tag("72")
                    }
                }
            }
            .navigationTitle("New Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task { await createTournament() }
                    }
                    .disabled(name.isEmpty || saving)
                }
            }
        }
    }

    func createTournament() async {
        saving = true
        let pc = Int(playerCount) ?? 8
        let totalRounds = Int(log2(Double(pc)))
        do {
            try await supabase.from("tournaments").insert([
                "name": name,
                "description": description,
                "player_count": "\(pc)",
                "total_rounds": "\(totalRounds)",
                "round_duration_hours": roundDuration,
                "status": "registration",
                "current_round": "1",
            ]).execute()
            onCreated()
            dismiss()
        } catch {
            print("Failed to create tournament: \(error)")
        }
        saving = false
    }
}
