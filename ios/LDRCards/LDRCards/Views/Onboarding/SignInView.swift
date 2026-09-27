import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var devName = ""
    @FocusState private var nameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let showsDevSignIn: Bool

    init(showsDevSignIn: Bool = AppConfig.devSignInEnabled) {
        self.showsDevSignIn = showsDevSignIn
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                // Equal spacers center the content when it fits; they collapse and the view scrolls when it doesn't.
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    content
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var content: some View {
        VStack(spacing: 28) {
            hero

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                Task { await session.handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            // The underlying Apple button keeps its first style, so rebuild it when the scheme changes.
            .id(colorScheme)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            #if DEBUG
            if showsDevSignIn { devSignIn }
            #endif
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.brandTint)
                    .frame(width: 92, height: 124)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -22)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.brand)
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
            .padding(.vertical, 8)
            .accessibilityHidden(true)

            Text("LDR Cards")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("A card game for couples who live apart. Play a card on your partner any time. They do what it says, send proof, or pay the price.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    #if DEBUG
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
        .calmSurface(radius: 18)
    }

    private func signInDev() {
        nameFocused = false
        Task { await session.signInDev(name: devName) }
    }
    #endif
}

#if DEBUG
#Preview("Sign in · dev sign-in hidden") {
    SignInView(showsDevSignIn: false).previewEnvironment(session: .previewSignedOut())
}

#Preview("Sign in · dev sign-in hidden · dark") {
    SignInView(showsDevSignIn: false)
        .previewEnvironment(session: .previewSignedOut())
        .preferredColorScheme(.dark)
}

#Preview("Sign in · dev sign-in") {
    SignInView(showsDevSignIn: true).previewEnvironment(session: .previewSignedOut())
}

#Preview("Sign in · dev sign-in · dark") {
    SignInView(showsDevSignIn: true)
        .previewEnvironment(session: .previewSignedOut())
        .preferredColorScheme(.dark)
}

#Preview("Sign in · signing in") {
    SignInView(showsDevSignIn: true).previewEnvironment(session: .previewSignedOut(isWorking: true))
}

#Preview("Sign in · SE · hidden", traits: .fixedLayout(width: 375, height: 667)) {
    SignInView(showsDevSignIn: false).previewEnvironment(session: .previewSignedOut())
}

#Preview("Sign in · SE · dev sign-in · dark", traits: .fixedLayout(width: 375, height: 667)) {
    SignInView(showsDevSignIn: true)
        .previewEnvironment(session: .previewSignedOut())
        .preferredColorScheme(.dark)
}

#Preview("Sign in · Pro Max · hidden", traits: .fixedLayout(width: 440, height: 956)) {
    SignInView(showsDevSignIn: false).previewEnvironment(session: .previewSignedOut())
}

#Preview("Sign in · Pro Max · dev sign-in · dark", traits: .fixedLayout(width: 440, height: 956)) {
    SignInView(showsDevSignIn: true)
        .previewEnvironment(session: .previewSignedOut())
        .preferredColorScheme(.dark)
}
#endif
