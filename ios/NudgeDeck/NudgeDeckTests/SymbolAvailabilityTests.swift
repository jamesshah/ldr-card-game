import UIKit
import XCTest
@testable import LDRCards

/// A misspelled or unavailable SF Symbol renders as nothing, so check every name the app uses.
final class SymbolAvailabilityTests: XCTestCase {
    private let appSymbols = [
        "arrow.uturn.backward", "arrow.uturn.backward.circle.fill", "camera.fill", "checkmark", "checkmark.circle.fill",
        "checkmark.seal.fill", "clock", "clock.fill", "face.smiling.inverse", "gearshape.fill", "hammer.fill",
        "hand.raised.fill", "heart.fill", "hourglass", "moon.zzz.fill", "paperplane.fill", "pencil.and.scribble",
        "person.2.fill", "photo.badge.exclamationmark", "photo.on.rectangle", "rectangle.stack.badge.minus",
        "rectangle.stack.fill", "shield.lefthalf.filled", "shippingbox.fill", "sparkles", "sparkles.tv.fill",
        "square.and.arrow.up", "square.and.pencil", "square.stack.3d.up.fill", "suit.heart.fill", "tray",
        "tray.full.fill", "trophy", "trophy.fill", "video.fill", "waveform",
        "mic.circle.fill", "stop.circle.fill", "play.circle.fill", "pause.circle.fill", "doc.on.doc",
        "trophy.fill", "xmark.circle.fill", "bolt.fill",
    ]

    func testEverySymbolExists() {
        let missing = appSymbols.filter { UIImage(systemName: $0) == nil }
        XCTAssertEqual(missing, [], "SF Symbols missing on this OS")
    }

    func testThemeAndStateSymbolsExist() {
        let categories = ["Calls", "Voice & Video", "Photos", "Deliveries", "Together Apart", "Sweet", "Playful", "Custom", "Other"]
        for category in categories {
            for kind in [CardKind.action, .counter] {
                let name = Theme.symbol(for: category, kind: kind)
                XCTAssertNotNil(UIImage(systemName: name), "\(category)/\(kind): \(name)")
            }
        }
        for state in [PlayState.pending, .proofSubmitted, .completed, .refused, .countered] {
            let name = GameFormatting.stateSymbol(state)
            XCTAssertNotNil(UIImage(systemName: name), "\(state): \(name)")
        }
    }
}
