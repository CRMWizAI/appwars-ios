import Foundation

func timeAgo(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) else {
        return ""
    }
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 60 { return "just now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    if seconds < 604800 { return "\(seconds / 86400)d ago" }
    let df = DateFormatter()
    df.dateFormat = "MMM d"
    return df.string(from: date)
}

func parseISO(_ isoString: String?) -> Date? {
    guard let str = isoString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: str) ?? ISO8601DateFormatter().date(from: str)
}
