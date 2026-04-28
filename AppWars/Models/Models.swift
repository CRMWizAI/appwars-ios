import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let email: String
    var role: String
    var discordUsername: String?
    var displayName: String?
    var avatarUrl: String?
    let createdAt: Date?

    var isAdmin: Bool { role == "admin" }

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case discordUsername = "discord_username"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct Tournament: Codable, Identifiable {
    let id: UUID
    var name: String
    var imageUrl: String?
    var description: String?
    var status: String
    var currentRound: Int
    var totalRounds: Int?
    var roundEndDate: Date?
    var currentCategory: String?
    var playerCount: Int?
    var roundDurationHours: Int?
    var prizeTiers: Int?
    var prizes: [Prize]?
    let createdAt: Date?

    var isRegistration: Bool { status == "registration" }
    var isActive: Bool { status == "active" }
    var isCompleted: Bool { status == "completed" }

    enum CodingKeys: String, CodingKey {
        case id, name, description, status, prizes
        case imageUrl = "image_url"
        case currentRound = "current_round"
        case totalRounds = "total_rounds"
        case roundEndDate = "round_end_date"
        case currentCategory = "current_category"
        case playerCount = "player_count"
        case roundDurationHours = "round_duration_hours"
        case prizeTiers = "prize_tiers"
        case createdAt = "created_at"
    }
}

struct Prize: Codable {
    let place: Int
    let name: String
    var imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case place, name
        case imageUrl = "image_url"
    }
}

struct Participant: Codable, Identifiable {
    let id: UUID
    var discordUsername: String
    let tournamentId: UUID
    var status: String
    var seed: Int?
    var avatarUrl: String?
    var matchesWon: Int
    var matchesLost: Int
    var totalVotesReceived: Int

    var isActive: Bool { status == "active" }

    enum CodingKeys: String, CodingKey {
        case id, status, seed
        case discordUsername = "discord_username"
        case tournamentId = "tournament_id"
        case avatarUrl = "avatar_url"
        case matchesWon = "matches_won"
        case matchesLost = "matches_lost"
        case totalVotesReceived = "total_votes_received"
    }
}

struct Matchup: Codable, Identifiable {
    let id: UUID
    let tournamentId: UUID
    let round: Int
    var bracketPosition: Int?
    var participantAId: UUID?
    var participantBId: UUID?
    var participantAUsername: String?
    var participantBUsername: String?
    var participantASubmissionUrl: String?
    var participantBSubmissionUrl: String?
    var participantAScreenshotUrl: String?
    var participantBScreenshotUrl: String?
    var participantADescription: String?
    var participantBDescription: String?
    var votesA: Int
    var votesB: Int
    var winnerId: UUID?
    var winnerUsername: String?
    var status: String
    var category: String?
    var isBye: Bool

    enum CodingKeys: String, CodingKey {
        case id, round, status, category
        case tournamentId = "tournament_id"
        case bracketPosition = "bracket_position"
        case participantAId = "participant_a_id"
        case participantBId = "participant_b_id"
        case participantAUsername = "participant_a_username"
        case participantBUsername = "participant_b_username"
        case participantASubmissionUrl = "participant_a_submission_url"
        case participantBSubmissionUrl = "participant_b_submission_url"
        case participantAScreenshotUrl = "participant_a_screenshot_url"
        case participantBScreenshotUrl = "participant_b_screenshot_url"
        case participantADescription = "participant_a_description"
        case participantBDescription = "participant_b_description"
        case votesA = "votes_a"
        case votesB = "votes_b"
        case winnerId = "winner_id"
        case winnerUsername = "winner_username"
        case isBye = "is_bye"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let tournamentId: UUID
    var authorName: String?
    let authorEmail: String
    var authorAvatarUrl: String?
    let content: String
    var replyToId: UUID?
    var replyToAuthorName: String?
    var replyToContent: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, content
        case tournamentId = "tournament_id"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case authorAvatarUrl = "author_avatar_url"
        case replyToId = "reply_to_id"
        case replyToAuthorName = "reply_to_author_name"
        case replyToContent = "reply_to_content"
        case createdAt = "created_at"
    }
}

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    var isRead: Bool
    var targetEmail: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case isRead = "is_read"
        case targetEmail = "target_email"
        case createdAt = "created_at"
    }
}

struct TeamWar: Codable, Identifiable {
    let id: UUID
    var name: String
    var imageUrl: String?
    var description: String?
    var status: String
    var currentRound: Int
    var currentCategory: String?
    var roundEndDate: Date?
    var winningTeamKey: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case imageUrl = "image_url"
        case currentRound = "current_round"
        case currentCategory = "current_category"
        case roundEndDate = "round_end_date"
        case winningTeamKey = "winning_team_key"
        case createdAt = "created_at"
    }
}
