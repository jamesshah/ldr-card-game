import XCTest
@testable import LDRCards

final class ModelDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testDecodesInboxWithOptionalFieldsOmitted() throws {
        let json = """
        {
          "incoming": [{
            "_id": "p1", "cardId": "c1", "title": "Video call me right now",
            "body": "Call me within 15 minutes.", "category": "Calls", "kind": "action",
            "fromId": "u1", "toId": "u2", "fromName": "Alice", "toName": "Bob",
            "state": "pending", "delivered": true, "deliverAt": 1767960000000,
            "playedAt": 1767960000000
          }],
          "toReview": [{
            "_id": "p2", "cardId": "c2", "title": "Photo of your view", "body": "",
            "category": "Photos", "kind": "action", "fromId": "u2", "toId": "u1",
            "fromName": "Bob", "toName": "Alice", "state": "proofSubmitted",
            "delivered": true, "deliverAt": 1767960000000, "playedAt": 1767960000000,
            "respondedAt": 1767963600000, "proofType": "photo",
            "proofUrl": "https://example.convex.cloud/api/storage/abc",
            "stackedOnPlayId": "p1", "stackedOnTitle": "Video call me right now"
          }],
          "waitingOnPartner": []
        }
        """
        let inbox = try decode(Inbox.self, json)
        XCTAssertEqual(inbox.incoming.first?.state, .pending)
        XCTAssertNil(inbox.incoming.first?.proofType)
        XCTAssertEqual(inbox.toReview.first?.proofType, .photo)
        XCTAssertEqual(inbox.toReview.first?.stackedOnTitle, "Video call me right now")
        XCTAssertEqual(inbox.needsAttentionCount, 2)
        XCTAssertEqual(inbox.incoming.first?.playedDate, Date(timeIntervalSince1970: 1_767_960_000))
    }

    func testDecodesCoupleWithoutPartner() throws {
        let json = """
        {
          "_id": "k1", "status": "waiting", "inviteCode": "ABC234", "timeframeDays": 30,
          "me": { "_id": "u1", "name": "Alice", "timeZone": "Europe/London", "utcOffsetMinutes": 0 }
        }
        """
        let couple = try decode(Couple.self, json)
        XCTAssertEqual(couple.status, .waiting)
        XCTAssertNil(couple.partner)
        XCTAssertNil(couple.me.quietHours)
    }

    func testDecodesNullCurrentCouple() throws {
        XCTAssertNil(try decode(Couple?.self, "null"))
    }

    func testDecodesHandAndSplitsCounters() throws {
        let json = """
        {
          "cards": [
            { "handId": "h1", "cardId": "c1", "title": "Veto", "body": "", "category": "Counter", "kind": "counter", "isCustom": false },
            { "handId": "h2", "cardId": "c2", "title": "Sing it", "body": "", "category": "Voice & Video", "kind": "action", "isCustom": false, "stolenFromName": "Bob" }
          ],
          "usedCount": 3, "partnerCardsLeft": 27, "customCardsLeftToWrite": 5
        }
        """
        let hand = try decode(Hand.self, json)
        XCTAssertEqual(hand.counterCards.map(\.handId), ["h1"])
        XCTAssertEqual(hand.actionCards.first?.stolenFromName, "Bob")
        XCTAssertEqual(hand.partnerCardsLeft, 27)
    }

    func testDecodesRecap() throws {
        let json = """
        {
          "status": "ended", "startedAt": 1, "endsAt": 2,
          "players": [{ "userId": "u1", "name": "Alice", "played": 4, "completedByPartner": 3,
            "refusedByPartner": 1, "refused": 0, "countersUsed": 1, "cardsStolen": 1, "cardsLeft": 26 }]
        }
        """
        let recap = try decode(Recap.self, json)
        XCTAssertEqual(recap.status, .ended)
        XCTAssertEqual(recap.players.first?.cardsStolen, 1)
    }
}
