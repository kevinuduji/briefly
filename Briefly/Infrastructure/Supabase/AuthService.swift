import AuthenticationServices
import Auth
import CryptoKit
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let client: SupabaseClient
    private var currentNonce: String?

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }
        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            session = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func activeUserId() async throws -> UUID {
        let currentSession = try await client.auth.session
        session = currentSession
        return currentSession.user.id
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            lastError = error.localizedDescription
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = apple.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                lastError = "Missing Apple identity token."
                return
            }
            guard let nonce = currentNonce else {
                lastError = "Missing nonce."
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: OpenIDConnectCredentials.Provider.apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                session = try await client.auth.session
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                guard remaining > 0 else { return }
                if random < charset.count {
                    result.append(charset[Int(random) % charset.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
