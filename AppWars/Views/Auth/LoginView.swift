import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)

                    Text("AppWars")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Build. Compete. Win.")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                Spacer()

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onTapGesture {
                    auth.signInWithApple()
                }

                // Error
                if let error = auth.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Legal links
                HStack(spacing: 16) {
                    Button("Privacy Policy") { }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Button("Terms") { }
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
