import SwiftUI
import PhotosUI

/// Build submission page — upload app URL, screenshot, and description.
struct SubmitBuildView: View {
    let matchupId: UUID
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService

    @State private var matchup: Matchup?
    @State private var loading = true
    @State private var mySide: String? // "a" or "b"
    @State private var appUrl = ""
    @State private var description = ""
    @State private var screenshotItem: PhotosPickerItem?
    @State private var screenshotImage: UIImage?
    @State private var submitting = false
    @State private var submitted = false
    @State private var alreadySubmitted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView()
                        .padding(.top, 60)
                } else if submitted || alreadySubmitted {
                    // Success state
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("Build Submitted!")
                            .font(.system(size: 22, weight: .bold))
                        Text("Your submission is in. Good luck!")
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                            .padding(.top, 8)
                    }
                    .padding(.top, 60)
                } else if let matchup = matchup {
                    VStack(alignment: .leading, spacing: 20) {
                        // Category
                        if let cat = matchup.category {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(.yellow)
                                Text(cat)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Matchup info
                        HStack {
                            Text(matchup.participantAUsername ?? "?")
                                .font(.system(size: 14, weight: mySide == "a" ? .bold : .regular))
                                .foregroundStyle(mySide == "a" ? .yellow : .secondary)
                            Text("vs")
                                .foregroundStyle(.secondary)
                            Text(matchup.participantBUsername ?? "?")
                                .font(.system(size: 14, weight: mySide == "b" ? .bold : .regular))
                                .foregroundStyle(mySide == "b" ? .yellow : .secondary)
                        }

                        // App URL
                        VStack(alignment: .leading, spacing: 6) {
                            Text("App URL *")
                                .font(.system(size: 13, weight: .semibold))
                            TextField("https://your-app.base44.app", text: $appUrl)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }

                        // Screenshot
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Screenshot")
                                .font(.system(size: 13, weight: .semibold))

                            if let image = screenshotImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Button {
                                        screenshotImage = nil
                                        screenshotItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .padding(6)
                                }
                            } else {
                                PhotosPicker(selection: $screenshotItem, matching: .images) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.secondary)
                                        Text("Add Screenshot")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                                            .foregroundStyle(.secondary.opacity(0.3))
                                    )
                                }
                            }
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Description")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(description.count)/1000")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: description) { _, new in
                                    if new.count > 1000 { description = String(new.prefix(1000)) }
                                }
                        }

                        // Submit
                        Button {
                            Task { await submitBuild() }
                        } label: {
                            HStack {
                                if submitting {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(submitting ? "Submitting..." : "Submit Build")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(appUrl.isEmpty ? Color.gray : Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(appUrl.isEmpty || submitting)
                    }
                    .padding()
                } else {
                    Text("Matchup not found")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                }
            }
            .navigationTitle("Submit Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadMatchup() }
            .onChange(of: screenshotItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        screenshotImage = image
                    }
                }
            }
        }
    }

    func loadMatchup() async {
        do {
            let results: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("id", value: matchupId.uuidString)
                .execute()
                .value
            matchup = results.first

            // Auto-detect side
            if let email = auth.profile?.email, let m = matchup {
                let participants: [Participant] = try await supabase.from("participants")
                    .select()
                    .eq("tournament_id", value: m.tournamentId.uuidString)
                    .execute()
                    .value

                // Find which participant belongs to this user
                // For now, check if either side has a submission already
                if m.participantASubmissionUrl != nil && m.participantAId != nil {
                    // A already submitted
                    if m.participantBSubmissionUrl == nil { mySide = "b" }
                } else if m.participantBSubmissionUrl != nil {
                    if m.participantASubmissionUrl == nil { mySide = "a" }
                }

                // Check if already submitted for my side
                if (mySide == "a" && m.participantASubmissionUrl != nil) ||
                   (mySide == "b" && m.participantBSubmissionUrl != nil) {
                    alreadySubmitted = true
                }
            }
        } catch {
            print("Failed to load matchup: \(error)")
        }
        loading = false
    }

    func submitBuild() async {
        guard let matchup = matchup, let side = mySide else { return }
        submitting = true

        do {
            // Upload screenshot if provided
            var screenshotUrl: String? = nil
            if let image = screenshotImage, let data = image.jpegData(compressionQuality: 0.8) {
                let fileName = "submissions/\(matchup.id.uuidString)_\(side).jpg"
                try await supabase.storage.from("appwars").upload(fileName, data: data, options: .init(contentType: "image/jpeg"))
                let url = try supabase.storage.from("appwars").getPublicURL(path: fileName)
                screenshotUrl = url.absoluteString
            }

            // Update matchup with submission
            var updateData: [String: String] = [:]
            if side == "a" {
                updateData["participant_a_submission_url"] = appUrl
                updateData["participant_a_description"] = description
                if let ss = screenshotUrl { updateData["participant_a_screenshot_url"] = ss }
            } else {
                updateData["participant_b_submission_url"] = appUrl
                updateData["participant_b_description"] = description
                if let ss = screenshotUrl { updateData["participant_b_screenshot_url"] = ss }
            }

            try await supabase.from("matchups")
                .update(updateData)
                .eq("id", value: matchup.id.uuidString)
                .execute()

            // If both sides submitted, move to voting
            let updatedMatchups: [Matchup] = try await supabase.from("matchups")
                .select()
                .eq("id", value: matchup.id.uuidString)
                .execute()
                .value

            if let updated = updatedMatchups.first,
               updated.participantASubmissionUrl != nil && updated.participantBSubmissionUrl != nil && updated.status == "pending_submission" {
                try await supabase.from("matchups")
                    .update(["status": "voting"])
                    .eq("id", value: matchup.id.uuidString)
                    .execute()
            }

            submitted = true
        } catch {
            print("Submit failed: \(error)")
        }
        submitting = false
    }
}
