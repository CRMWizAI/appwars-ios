import SwiftUI

struct RoundCountdown: View {
    let endDate: Date?
    @State private var timeRemaining: String = ""
    @State private var isUrgent = false
    @State private var isExpired = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let _ = endDate, !isExpired {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                Text(timeRemaining)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(isUrgent ? .red : .secondary)
            .onReceive(timer) { _ in update() }
            .onAppear { update() }
        } else if isExpired {
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 10))
                Text("Time's up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.orange)
        }
    }

    func update() {
        guard let end = endDate else { return }
        let diff = end.timeIntervalSinceNow
        if diff <= 0 {
            isExpired = true
            timeRemaining = "0s"
            return
        }

        isUrgent = diff < 3600
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60

        if days > 0 {
            timeRemaining = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m \(seconds)s"
        } else {
            timeRemaining = "\(minutes)m \(seconds)s"
        }
    }
}
