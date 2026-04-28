import SwiftUI

struct NotificationBellView: View {
    @State private var unreadCount = 0

    var body: some View {
        Button {
            // TODO: navigate to notifications
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(.primary)

                if unreadCount > 0 {
                    Text("\(min(unreadCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .task { await loadUnread() }
    }

    func loadUnread() async {
        // TODO: query notifications
    }
}
