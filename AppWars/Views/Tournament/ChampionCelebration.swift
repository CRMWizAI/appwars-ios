import SwiftUI
import Kingfisher
import ConfettiSwiftUI

/// Full-screen champion celebration modal — confetti, crown, glow, prize display.
/// Fires once per session when tournament is completed with a winner.
struct ChampionCelebration: View {
    let tournament: Tournament
    let winnerName: String
    let winnerAvatarUrl: String?
    let onDismiss: () -> Void

    @State private var confettiCounter = 0
    @State private var showContent = false
    @State private var crownBounce = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Radial glow
            RadialGradient(
                colors: [Color.yellow.opacity(glowPulse ? 0.15 : 0.08), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

            if showContent {
                VStack(spacing: 20) {
                    // Close button
                    HStack {
                        Spacer()
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Trophy label
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text("TOURNAMENT CHAMPION")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.yellow)
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                    }

                    // Tournament name
                    Text(tournament.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)

                    // Crown
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 16)
                        .offset(y: crownBounce ? -4 : 4)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: crownBounce)

                    // Champion avatar
                    ZStack {
                        // Rotating aura
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.yellow.opacity(0.3), .orange.opacity(0.1), .yellow.opacity(0.3)],
                                    center: .center
                                )
                            )
                            .frame(width: 130, height: 130)
                            .blur(radius: 10)
                            .rotationEffect(.degrees(glowPulse ? 360 : 0))
                            .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: glowPulse)

                        // Pulsing glow ring
                        Circle()
                            .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 3)
                            .frame(width: 110, height: 110)
                            .scaleEffect(glowPulse ? 1.05 : 0.95)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

                        // Avatar
                        if let url = winnerAvatarUrl, let imageURL = URL(string: url) {
                            KFImage(imageURL)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 3))
                        } else {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Text(String(winnerName.prefix(2)).uppercased())
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.yellow)
                                )
                                .overlay(Circle().strokeBorder(Color.yellow, lineWidth: 3))
                        }
                    }

                    // Winner name
                    Text(winnerName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // Prize
                    if let prizes = tournament.prizes, let first = prizes.first {
                        VStack(spacing: 6) {
                            Text("GRAND PRIZE")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.yellow.opacity(0.6))

                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text(first.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
                        }
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 10) {
                        Button {
                            confettiCounter += 1
                        } label: {
                            HStack {
                                Image(systemName: "party.popper.fill")
                                Text("Celebrate!")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            onDismiss()
                        } label: {
                            Text("View Bracket")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .confettiCannon(counter: $confettiCounter, num: 80, colors: [.yellow, .orange, .white, .red], confettiSize: 12, rainHeight: 800, radius: 400)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            crownBounce = true
            glowPulse = true
            // Initial confetti burst
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                confettiCounter += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                confettiCounter += 1
            }
        }
    }
}
