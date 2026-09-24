#if DEBUG
import AuthenticationServices
import SwiftUI

/// Sample data for SwiftUI previews and preview snapshot tests. Nothing here talks to Convex.
enum PreviewData {
    static let now = Date()
    private static let day = 24 * 60 * 60 * 1000.0

    static func ms(minutesAgo: Double) -> Double {
        (now.timeIntervalSince1970 - minutesAgo * 60) * 1000
    }

    // MARK: Players (San Francisco and London)

    static let me = Player(
        id: "user_maya",
        name: "Maya",
        timeZone: "America/Los_Angeles",
        utcOffsetMinutes: -420,
        quietStartMinutes: nil,
        quietEndMinutes: nil
    )

    static let partner = Player(
        id: "user_theo",
        name: "Theo",
        timeZone: "Europe/London",
        utcOffsetMinutes: 60,
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60
    )

    static let meProfile = Me(
        id: me.id,
        name: me.name,
        timeZone: me.timeZone,
        utcOffsetMinutes: me.utcOffsetMinutes,
        quietStartMinutes: nil,
        quietEndMinutes: nil,
        coupleId: "couple_1",
        isDevAccount: true
    )

    // MARK: Couples

    static let pairedCouple = Couple(
        id: "couple_1",
        status: .active,
        inviteCode: "K7M4QX",
        timeframeDays: 30,
        startedAt: ms(minutesAgo: 9 * 24 * 60),
        endsAt: ms(minutesAgo: 9 * 24 * 60) + 30 * day,
        me: me,
        partner: partner
    )

    static let waitingCouple = Couple(
        id: "couple_1",
        status: .waiting,
        inviteCode: "K7M4QX",
        timeframeDays: 30,
        startedAt: nil,
        endsAt: nil,
        me: me,
        partner: nil
    )

    static let endedCouple = Couple(
        id: "couple_1",
        status: .ended,
        inviteCode: "K7M4QX",
        timeframeDays: 7,
        startedAt: ms(minutesAgo: 8 * 24 * 60),
        endsAt: ms(minutesAgo: 24 * 60),
        me: me,
        partner: partner
    )

    // MARK: Cards

    static func card(
        _ id: String, _ title: String, _ body: String, _ category: String,
        kind: CardKind = .action, isCustom: Bool = false, stolenFrom: String? = nil
    ) -> HandCard {
        HandCard(handId: "hand_\(id)", cardId: "card_\(id)", title: title, body: body, category: category,
                 kind: kind, isCustom: isCustom, stolenFromName: stolenFrom)
    }

    static let callCard = card("call", "Video call me right now", "Drop what you're doing (safely) and call me within 15 minutes.", "Calls")
    static let voiceCard = card("voice", "Send a 30s voice note", "Tell me the best part of your day, out loud.", "Voice & Video")
    static let viewCard = card("view", "Photo of your view", "Whatever you're looking at right now. No retakes.", "Photos")
    static let deliveryCard = card("delivery", "Order me a surprise", "Something under $15 delivered to my door this week.", "Deliveries")
    static let movieCard = card("movie", "Movie night, apart", "Pick a film and press play at the same time tonight.", "Together Apart")
    static let stolenCard = card("stolen", "Sing it to me", "One chorus of our song, on video.", "Playful", stolenFrom: "Theo")
    static let customCard = card("custom", "Say the pancake thing", "You know exactly what I mean.", "Custom", isCustom: true)
    static let counterCard = card("counter", "Rain check, forever", "Knock a card played on you out of the game.", "Counter", kind: .counter)

    static let fullHand = Hand(
        cards: [callCard, voiceCard, viewCard, deliveryCard, movieCard, stolenCard, customCard, counterCard],
        usedCount: 6,
        partnerCardsLeft: 24,
        customCardsLeftToWrite: 4
    )

    static let counterOnlyHand = Hand(cards: [counterCard], usedCount: 29, partnerCardsLeft: 12, customCardsLeftToWrite: 0)

    static let emptyHand = Hand(cards: [], usedCount: 30, partnerCardsLeft: 9, customCardsLeftToWrite: 0)

    // MARK: Plays, one per state

    static func play(
        _ id: String, _ card: HandCard, from: Player, to: Player, state: PlayState, minutesAgo: Double,
        kind: CardKind = .action, stackedOn: String? = nil, counteredTitle: String? = nil, delivered: Bool = true,
        deliverInMinutes: Double = 0, proofType: ProofType? = nil, proofText: String? = nil,
        rejectedNote: String? = nil, stolenTitle: String? = nil
    ) -> Play {
        let playedAt = ms(minutesAgo: minutesAgo)
        return Play(
            id: "play_\(id)", cardId: card.cardId, title: card.title, body: card.body, category: card.category,
            kind: kind, fromId: from.id, toId: to.id, fromName: from.name, toName: to.name, state: state,
            stackedOnPlayId: stackedOn.map { _ in "play_stack_base" }, stackedOnTitle: stackedOn,
            counteredPlayId: counteredTitle.map { _ in "play_countered" }, counteredTitle: counteredTitle,
            delivered: delivered, deliverAt: delivered ? playedAt : ms(minutesAgo: -deliverInMinutes),
            playedAt: playedAt, respondedAt: state == .pending ? nil : playedAt + 20 * 60 * 1000,
            proofType: proofType, proofText: proofText, proofUrl: nil, proofRejectedNote: rejectedNote,
            stolenCardTitle: stolenTitle
        )
    }

    static let incomingPending = play("in_pending", callCard, from: partner, to: me, state: .pending, minutesAgo: 12)
    static let incomingStackedRetry = play(
        "in_retry", viewCard, from: partner, to: me, state: .pending, minutesAgo: 95,
        stackedOn: "Send a 30s voice note", rejectedNote: "It's too dark, I can't see anything!"
    )
    static let incomingProofSent = play(
        "in_sent", movieCard, from: partner, to: me, state: .proofSubmitted, minutesAgo: 300,
        proofType: .text, proofText: "Watched Before Sunrise and cried at the same scene as you."
    )
    static let pendingProofReview = play(
        "review", voiceCard, from: me, to: partner, state: .proofSubmitted, minutesAgo: 60,
        proofType: .text, proofText: "Best part: the barista remembered your order and asked about you."
    )
    static let waitingDelivered = play("wait", deliveryCard, from: me, to: partner, state: .pending, minutesAgo: 30)
    static let waitingHeld = play(
        "held", callCard, from: me, to: partner, state: .pending, minutesAgo: 5, delivered: false, deliverInMinutes: 6 * 60
    )
    static let completed = play(
        "done", viewCard, from: me, to: partner, state: .completed, minutesAgo: 2 * 24 * 60,
        proofType: .text, proofText: "Rainy Camden high street. You'd hate it."
    )
    static let refused = play(
        "refused", deliveryCard, from: partner, to: me, state: .refused, minutesAgo: 3 * 24 * 60, stolenTitle: "Sing it to me"
    )
    static let countered = play("countered", movieCard, from: partner, to: me, state: .countered, minutesAgo: 4 * 24 * 60)
    static let counterPlay = play(
        "counter", counterCard, from: me, to: partner, state: .completed, minutesAgo: 4 * 24 * 60 - 3,
        kind: .counter, counteredTitle: "Movie night, apart"
    )

    // MARK: Inboxes

    static let busyInbox = Inbox(
        incoming: [incomingPending, incomingStackedRetry, incomingProofSent],
        toReview: [pendingProofReview],
        waitingOnPartner: [waitingDelivered]
    )

    static let pendingProofInbox = Inbox(incoming: [], toReview: [pendingProofReview], waitingOnPartner: [])

    static let quietHoursInbox = Inbox(incoming: [], toReview: [], waitingOnPartner: [waitingHeld])

    static let timeline: [Play] = [
        incomingPending, pendingProofReview, incomingStackedRetry, waitingHeld, completed, refused, counterPlay, countered,
    ]

    // MARK: Recaps

    static func recap(status: CoupleStatus) -> Recap {
        let couple = status == .ended ? endedCouple : pairedCouple
        return Recap(
            status: status,
            startedAt: couple.startedAt,
            endsAt: couple.endsAt,
            players: [
                RecapPlayer(userId: me.id, name: me.name, played: 11, completedByPartner: 8, refusedByPartner: 1,
                            refused: 2, countersUsed: 1, cardsStolen: 1, cardsLeft: 18),
                RecapPlayer(userId: partner.id, name: partner.name, played: 9, completedByPartner: 6, refusedByPartner: 2,
                            refused: 1, countersUsed: 2, cardsStolen: 2, cardsLeft: 21),
            ]
        )
    }
}

extension GameStore {
    static func previewPaired(
        hand: Hand = PreviewData.fullHand,
        inbox: Inbox = PreviewData.busyInbox,
        timeline: [Play] = PreviewData.timeline,
        recap: Recap? = PreviewData.recap(status: .active)
    ) -> GameStore {
        GameStore(previewCouple: PreviewData.pairedCouple, hand: hand, inbox: inbox, timeline: timeline, recap: recap)
    }

    static func previewUnpaired() -> GameStore { GameStore(previewCouple: nil) }

    static func previewWaiting() -> GameStore {
        GameStore(previewCouple: PreviewData.waitingCouple, hand: Hand(cards: [], usedCount: 0, partnerCardsLeft: 0, customCardsLeftToWrite: 5))
    }

    static func previewEnded() -> GameStore {
        GameStore(previewCouple: PreviewData.endedCouple, hand: PreviewData.counterOnlyHand, inbox: .empty,
                  timeline: PreviewData.timeline, recap: PreviewData.recap(status: .ended))
    }
}

extension SessionStore {
    static func previewSignedIn() -> SessionStore {
        SessionStore(previewState: .signedIn(token: "preview", me: PreviewData.meProfile))
    }

    static func previewSignedOut(isWorking: Bool = false) -> SessionStore {
        SessionStore(previewState: .signedOut, isWorking: isWorking)
    }

    /// What an unsigned build shows after tapping Sign in with Apple.
    static func previewAppleSignInFailed() -> SessionStore {
        let session = SessionStore(previewState: .signedOut)
        session.errorMessage = appleSignInErrorMessage(for: ASAuthorizationError(.unknown))
        return session
    }
}

extension View {
    /// Injects offline stores and the app tint, the way `LDRCardsApp` does for live ones.
    @MainActor
    func previewEnvironment(_ store: GameStore? = nil, session: SessionStore? = nil) -> some View {
        environmentObject(store ?? .previewPaired())
            .environmentObject(session ?? .previewSignedIn())
            .tint(Theme.rose)
    }
}
#endif
