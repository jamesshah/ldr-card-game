import Foundation
import UIKit
import UserNotifications

/// Local-notification fallback: while the app is running, new cards and proofs seen on the
/// realtime inbox subscription become banners. Skipped once APNs is registered, since the
/// backend then sends real pushes.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var seenKeys: Set<String>?

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func inboxDidUpdate(_ inbox: Inbox) {
        let events = Self.events(in: inbox)
        let keys = Set(events.map(\.key))
        defer { seenKeys = (seenKeys ?? []).union(keys) }
        // The first snapshot after launch is existing state, not news.
        guard let seen = seenKeys else { return }
        guard !PushRegistration.shared.isRegisteredWithAPNs else { return }
        for event in events where !seen.contains(event.key) {
            post(title: event.title, body: event.body, id: event.key)
        }
    }

    func reset() {
        seenKeys = nil
    }

    struct Event: Equatable {
        let key: String
        let title: String
        let body: String
    }

    nonisolated static func events(in inbox: Inbox) -> [Event] {
        let incoming = inbox.incoming
            .filter { $0.state == .pending }
            .map { play in
                Event(
                    key: "\(play.id):\(play.state.rawValue):\(play.proofRejectedNote ?? "")",
                    title: play.proofRejectedNote == nil
                        ? (play.stackedOnPlayId == nil ? "\(play.fromName) played a card on you" : "\(play.fromName) stacked a card on you")
                        : "\(play.fromName) wants another try",
                    body: play.title
                )
            }
        let proofs = inbox.toReview.map { play in
            Event(key: "\(play.id):proof", title: "\(play.toName) sent proof", body: play.title)
        }
        return incoming + proofs
    }

    private func post(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
