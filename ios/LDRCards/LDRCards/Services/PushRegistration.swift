import ConvexMobile
import Foundation

/// Connects the APNs device token to the signed-in player's account.
@MainActor
final class PushRegistration {
    static let shared = PushRegistration()

    private(set) var deviceToken: String?
    private var sessionToken: String?

    var isRegisteredWithAPNs: Bool { deviceToken != nil }

    private var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await registerIfReady() }
    }

    func didFailToRegister(_ error: Error) {
        // Expected without an APNs entitlement (e.g. Simulator builds with no team).
        print("APNs registration unavailable, using local notifications: \(error.localizedDescription)")
    }

    func sessionDidStart(token: String) {
        sessionToken = token
        Task {
            await NotificationService.shared.requestAuthorization()
            await registerIfReady()
        }
    }

    func sessionDidEnd() {
        if let deviceToken, let sessionToken {
            let args: [String: ConvexEncodable?] = ["sessionToken": sessionToken, "apnsToken": deviceToken]
            Task { try? await Backend.client.mutation("devices:unregister", with: args) }
        }
        sessionToken = nil
        NotificationService.shared.reset()
    }

    private func registerIfReady() async {
        guard let deviceToken, let sessionToken else { return }
        do {
            try await Backend.client.mutation(
                "devices:register",
                with: ["sessionToken": sessionToken, "apnsToken": deviceToken, "environment": environment]
            )
        } catch {
            print("Couldn't register device for push: \(Backend.message(for: error))")
        }
    }
}
