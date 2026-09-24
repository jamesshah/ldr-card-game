import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var devName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        Task { await session.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Sign in with Apple needs a signed build with the capability enabled.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                devSignIn
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            LinearGradient(colors: [Theme.rose.opacity(0.18), Color(.systemBackground)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.gradient(for: "Sweet", kind: .action))
                    .frame(width: 92, height: 124)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -22)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.gradient(for: "Calls", kind: .action))
                    .frame(width: 92, height: 124)
                    .rotationEffect(.degrees(8))
                    .offset(x: 22)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .offset(x: 22)
                    )
            }
            .padding(.top, 40)
            .accessibilityHidden(true)

            Text("LDR Cards")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("A card game for couples who live apart. Play a card on your partner any time. They do what it says, send proof, or pay the price.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var devSignIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quick sign-in for testing", systemImage: "hammer.fill")
                .font(.subheadline.weight(.semibold))
            Text("Creates a throwaway account with just a name. Use a different name on each Simulator to pair two players.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Your name", text: $devName)
                    .textContentType(.givenName)
                    .submitLabel(.go)
                    .focused($nameFocused)
                    .onSubmit(signInDev)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button(action: signInDev) {
                    if session.isWorking {
                        ProgressView()
                    } else {
                        Text("Start")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(devName.trimmingCharacters(in: .whitespaces).isEmpty || session.isWorking)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func signInDev() {
        nameFocused = false
        Task { await session.signInDev(name: devName) }
    }
}

#if DEBUG
#Preview("Sign in") {
    SignInView().previewEnvironment(session: .previewSignedOut())
}

#Preview("Sign in · signing in") {
    SignInView().previewEnvironment(session: .previewSignedOut(isWorking: true))
}

#Preview("Sign in · dark") {
    SignInView()
        .previewEnvironment(session: .previewSignedOut())
        .preferredColorScheme(.dark)
}
#endif
