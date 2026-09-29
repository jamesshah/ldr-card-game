import SwiftUI

@main
struct LDRCardsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Theme.brand)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView("Loading your deck…")
            case .signedOut:
                SignInView()
            case .signedIn(let token, _):
                SignedInView(token: token)
                    .id(token)
            }
        }
        .errorAlert($session.errorMessage)
    }
}

/// Owns the game subscriptions for one session and routes between pairing and the game.
struct SignedInView: View {
    @StateObject private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    init(token: String) {
        _store = StateObject(wrappedValue: GameStore(token: token))
    }

    var body: some View {
        Group {
            if !store.coupleLoaded {
                ProgressView("Finding your partner…")
            } else if let couple = store.couple {
                if couple.status == .waiting {
                    WaitingForPartnerView(couple: couple)
                } else {
                    MainTabView()
                }
            } else {
                PairingView()
            }
        }
        .environmentObject(store)
        .errorAlert($store.errorMessage)
        .task { await store.syncDeviceTime() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.syncDeviceTime() } }
        }
    }
}

#if DEBUG
#Preview("Root · loading") {
    RootView().environmentObject(SessionStore(previewState: .loading))
}

#Preview("Root · signed out") {
    RootView().environmentObject(SessionStore.previewSignedOut())
}

#Preview("Root · Apple sign-in failed") {
    RootView().environmentObject(SessionStore.previewAppleSignInFailed())
}
#endif
