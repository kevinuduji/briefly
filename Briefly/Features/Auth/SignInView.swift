import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Briefly")
                .font(.largeTitle.bold())
            Text("You don’t build your business dashboard anymore.\nYou speak, and your business builds itself.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            SignInWithAppleButton(.signIn) { request in
                auth.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task { await auth.handleAppleCompletion(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 32)

            if auth.isLoading {
                ProgressView()
            }
            if let err = auth.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            Spacer()
        }
        .padding()
    }
}
