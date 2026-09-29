import XCTest
@testable import LDRCards

final class NotificationEventTests: XCTestCase {
    private func play(id: String, state: PlayState, stacked: Bool = false, rejectedNote: String? = nil) -> Play {
        Play(
            id: id, cardId: "c-\(id)", title: "Card \(id)", body: "", category: "Calls", kind: .action,
            fromId: "u1", toId: "u2", fromName: "Alice", toName: "Bob", state: state,
            stackedOnPlayId: stacked ? "base" : nil, stackedOnTitle: nil,
            counteredPlayId: nil, counteredTitle: nil, delivered: true, deliverAt: 0, playedAt: 0,
            respondedAt: nil, proofType: nil, proofText: nil, proofUrl: nil,
            proofRejectedNote: rejectedNote, stolenCardTitle: nil
        )
    }

    func testOnlyPendingIncomingAndProofsBecomeEvents() {
        let inbox = Inbox(
            incoming: [play(id: "1", state: .pending), play(id: "2", state: .proofSubmitted)],
            toReview: [play(id: "3", state: .proofSubmitted)],
            waitingOnPartner: [play(id: "4", state: .pending)]
        )
        let events = NotificationService.events(in: inbox)
        XCTAssertEqual(events.map(\.title), ["Alice played a card on you", "Bob sent proof"])
    }

    func testStackedAndRejectedCardsGetDistinctKeysAndTitles() {
        let stacked = NotificationService.events(in: Inbox(incoming: [play(id: "1", state: .pending, stacked: true)], toReview: [], waitingOnPartner: []))
        XCTAssertEqual(stacked.first?.title, "Alice stacked a card on you")

        let retry = NotificationService.events(in: Inbox(incoming: [play(id: "1", state: .pending, rejectedNote: "Closer!")], toReview: [], waitingOnPartner: []))
        XCTAssertEqual(retry.first?.title, "Alice wants another try")
        XCTAssertNotEqual(retry.first?.key, stacked.first?.key)
    }
}
