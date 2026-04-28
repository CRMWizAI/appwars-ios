import Foundation
import AuthenticationServices
import Supabase
import CryptoKit

@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var profile: Profile?
    @Published var error: String?

    private var currentNonce: String?

    override init() {
        super.init()
        Task { await checkSession() }
    }

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            await fetchProfile(userId: session.user.id)
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }

    // MARK: - Apple Sign In

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let hashedNonce = sha256(nonce)

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async {
        guard let nonce = currentNonce,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to get Apple ID token"
            return
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString,
                    nonce: nonce
                )
            )
            isAuthenticated = true
            await fetchProfile(userId: session.user.id)

            // Update profile with Apple name if first sign in
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty {
                    try? await supabase.from("profiles")
                        .update(["display_name": displayName])
                        .eq("id", value: session.user.id.uuidString)
                        .execute()
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Profile

    func fetchProfile(userId: UUID) async {
        do {
            let response: Profile = try await supabase.from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            profile = response
        } catch {
            print("Failed to fetch profile: \(error)")
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            profile = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task { @MainActor in
            await handleAppleSignIn(credential: credential)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
        }
    }
}
