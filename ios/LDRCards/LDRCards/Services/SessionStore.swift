import AuthenticationServices
import Combine
import ConvexMobile
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(token: String, me: Me)
    }

    @Published private(set) var state: State = .loading
    @Published var errorMessage: String?
    @Published private(set) var isWorking = false

    /// Nil only for previews, which must never open a connection.
    private let client: ConvexClient?
    private var meSubscription: AnyCancellable?

    init(client: ConvexClient = Backend.client) {
        self.client = client
        if let token = KeychainStore.readToken() {
            watchSession(token: token)
        } else {
            state = .signedOut
        }
    }

    #if DEBUG
    /// Offline session for SwiftUI previews. Skips the Keychain and never calls the backend.
    init(previewState: State, isWorking: Bool = false) {
        client = nil
        state = previewState
        self.isWorking = isWorking
    }
    #endif

    var token: String? {
        if case .signedIn(let token, _) = state { return token }
        return nil
    }

    func signInDev(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a name to sign in."
            return
        }
        var args = Backend.deviceTimeArgs
        args["name"] = trimmed
        guard let client else { return }
        await signIn {
            let token: String = try await client.mutation("auth:signInDev", with: args)
            return token
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Sign in with Apple failed: \(error.localizedDescription)"
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple didn't return an identity token. Please try again."
                return
            }
            var args = Backend.deviceTimeArgs
            args["identityToken"] = identityToken
            if let components = credential.fullName {
                let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
                if !name.isEmpty { args["name"] = name }
            }
            guard let client else { return }
            await signIn {
                let token: String = try await client.action("auth:signInWithApple", with: args)
                return token
            }
        }
    }

    func signOut() async {
        guard let token, let client else { return }
        PushRegistration.shared.sessionDidEnd()
        try? await client.mutation("auth:signOut", with: ["sessionToken": token])
        endSession()
    }

    private func signIn(_ call: @escaping () async throws -> String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let token = try await call()
            KeychainStore.saveToken(token)
            state = .loading
            watchSession(token: token)
        } catch {
            errorMessage = Backend.message(for: error)
        }
    }

    private func watchSession(token: String) {
        meSubscription = client?
            .subscribe(to: "users:me", with: ["sessionToken": token], yielding: Me?.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = Backend.message(for: error)
                    }
                },
                receiveValue: { [weak self] me in
                    guard let self else { return }
                    if let me {
                        let wasSignedIn = self.token != nil
                        self.state = .signedIn(token: token, me: me)
                        if !wasSignedIn { PushRegistration.shared.sessionDidStart(token: token) }
                    } else {
                        self.endSession()
                    }
                }
            )
    }

    private func endSession() {
        meSubscription = nil
        KeychainStore.deleteToken()
        state = .signedOut
    }
}
