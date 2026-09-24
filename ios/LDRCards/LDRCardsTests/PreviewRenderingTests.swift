import SwiftUI
import XCTest
@testable import LDRCards

/// Renders the same views the `#Preview` blocks show, offline, so a preview that crashes,
/// traps, or draws nothing fails the test run. Each render is attached to the test result.
@MainActor
final class PreviewRenderingTests: XCTestCase {
    private var scenarios: [(String, AnyView)] {
        let paired = { GameStore.previewPaired() }
        return [
            ("Root · loading", AnyView(RootView().environmentObject(SessionStore(previewState: .loading)))),
            ("Root · signed out", AnyView(RootView().environmentObject(SessionStore.previewSignedOut()))),
            ("Root · Apple sign-in failed", AnyView(RootView().environmentObject(SessionStore.previewAppleSignInFailed()))),
            ("Pair up", AnyView(PairingView().previewEnvironment(.previewUnpaired()))),
            ("Pair up · dark", AnyView(PairingView().previewEnvironment(.previewUnpaired()).preferredColorScheme(.dark))),
            ("Invite code", AnyView(WaitingForPartnerView(couple: PreviewData.waitingCouple).previewEnvironment(.previewWaiting()))),
            ("Invite code · dark", AnyView(WaitingForPartnerView(couple: PreviewData.waitingCouple)
                .previewEnvironment(.previewWaiting()).preferredColorScheme(.dark))),
            ("Main tabs", AnyView(MainTabView().previewEnvironment(paired()))),
            ("Main tabs · season over", AnyView(MainTabView().previewEnvironment(.previewEnded()))),
            ("Season header", AnyView(SeasonHeader(couple: PreviewData.pairedCouple).padding())),
            ("Hand", AnyView(HandView().previewEnvironment(paired()))),
            ("Hand · dark", AnyView(HandView().previewEnvironment(paired()).preferredColorScheme(.dark))),
            ("Hand · empty", AnyView(HandView().previewEnvironment(.previewPaired(hand: PreviewData.emptyHand)))),
            ("Hand · counters only", AnyView(HandView().previewEnvironment(.previewPaired(hand: PreviewData.counterOnlyHand)))),
            ("Play sheet · stack option", AnyView(PlayCardSheet(card: PreviewData.voiceCard).previewEnvironment(
                .previewPaired(inbox: Inbox(incoming: [PreviewData.incomingPending], toReview: [], waitingOnPartner: [])))),
            ),
            ("Play sheet · waiting on partner", AnyView(PlayCardSheet(card: PreviewData.movieCard).previewEnvironment(paired()))),
            ("Custom card", AnyView(CustomCardSheet().previewEnvironment(paired()))),
            ("Card face", AnyView(CardFace(card: PreviewData.callCard).frame(height: 440).padding(28))),
            ("Card faces · every category", AnyView(ScrollView {
                VStack(spacing: 12) { ForEach(PreviewData.fullHand.cards) { CardFace(card: $0, compact: true) } }.padding()
            })),
            ("Card face · dark", AnyView(CardFace(card: PreviewData.stolenCard).frame(height: 440).padding(28).preferredColorScheme(.dark))),
            ("Time zones", AnyView(TimeZonesBar(me: PreviewData.me, partner: PreviewData.partner).padding())),
            ("Inbox", AnyView(InboxView().previewEnvironment(paired()))),
            ("Inbox · empty", AnyView(InboxView().previewEnvironment(.previewPaired(inbox: .empty)))),
            ("Inbox · pending proof", AnyView(InboxView().previewEnvironment(.previewPaired(inbox: PreviewData.pendingProofInbox)))),
            ("Inbox · pending proof · dark", AnyView(InboxView()
                .previewEnvironment(.previewPaired(inbox: PreviewData.pendingProofInbox)).preferredColorScheme(.dark))),
            ("Inbox · held for quiet hours", AnyView(InboxView().previewEnvironment(.previewPaired(inbox: PreviewData.quietHoursInbox)))),
            ("Inbox · dark", AnyView(InboxView().previewEnvironment(paired()).preferredColorScheme(.dark))),
            ("Counter sheet", AnyView(CounterSheet(play: PreviewData.incomingPending).previewEnvironment(paired()))),
            ("Counter sheet · none left", AnyView(CounterSheet(play: PreviewData.incomingPending)
                .previewEnvironment(.previewPaired(hand: PreviewData.emptyHand)))),
            ("Text proof", AnyView(ProofView(play: PreviewData.pendingProofReview).padding())),
            ("Proof sheet · photo", AnyView(CompleteProofSheet(play: PreviewData.incomingPending).previewEnvironment(paired()))),
            ("Proof sheet · note", AnyView(CompleteProofSheet(play: PreviewData.incomingStackedRetry, initialProofType: .text)
                .previewEnvironment(paired()))),
            ("Proof sheet · voice note", AnyView(CompleteProofSheet(play: PreviewData.incomingPending, initialProofType: .audio)
                .previewEnvironment(paired()))),
            ("Proof sheet · sending", AnyView(CompleteProofSheet(play: PreviewData.incomingPending, initialProofType: .text)
                .previewEnvironment(GameStore(previewCouple: PreviewData.pairedCouple, isWorking: true)))),
            ("Proof sheet · dark", AnyView(CompleteProofSheet(play: PreviewData.incomingPending, initialProofType: .text)
                .previewEnvironment(paired()).preferredColorScheme(.dark))),
            ("Timeline", AnyView(TimelineScreen().previewEnvironment(paired()))),
            ("Timeline · empty", AnyView(TimelineScreen().previewEnvironment(.previewPaired(timeline: [])))),
            ("Timeline · dark", AnyView(TimelineScreen().previewEnvironment(paired()).preferredColorScheme(.dark))),
            ("Recap · season so far", AnyView(RecapView().previewEnvironment(paired()))),
            ("Recap · season over", AnyView(RecapView().previewEnvironment(.previewEnded()))),
            ("Recap · unavailable", AnyView(RecapView().previewEnvironment(.previewPaired(recap: nil)))),
            ("Recap · dark", AnyView(RecapView().previewEnvironment(.previewEnded()).preferredColorScheme(.dark))),
            ("Settings", AnyView(SettingsView().previewEnvironment(paired()))),
            ("Settings · dark", AnyView(SettingsView().previewEnvironment(paired()).preferredColorScheme(.dark))),
        ]
    }

    private static let pro = CGSize(width: 402, height: 874)
    private static let se = CGSize(width: 375, height: 667)
    private static let proMax = CGSize(width: 440, height: 956)

    private var signInScenarios: [(String, AnyView, CGSize)] {
        let signIn = { (dev: Bool, dark: Bool) in
            AnyView(SignInView(showsDevSignIn: dev).previewEnvironment(session: .previewSignedOut())
                .preferredColorScheme(dark ? .dark : .light))
        }
        return [
            ("Sign in · dev sign-in hidden", signIn(false, false), Self.pro),
            ("Sign in · dev sign-in hidden · dark", signIn(false, true), Self.pro),
            ("Sign in · dev sign-in", signIn(true, false), Self.pro),
            ("Sign in · dev sign-in · dark", signIn(true, true), Self.pro),
            ("Sign in · signing in", AnyView(SignInView(showsDevSignIn: true)
                .previewEnvironment(session: .previewSignedOut(isWorking: true))), Self.pro),
            ("Sign in · SE · hidden", signIn(false, false), Self.se),
            ("Sign in · SE · dev sign-in · dark", signIn(true, true), Self.se),
            ("Sign in · Pro Max · hidden", signIn(false, false), Self.proMax),
            ("Sign in · Pro Max · dev sign-in · dark", signIn(true, true), Self.proMax),
        ]
    }

    func testEveryPreviewRenders() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let all = signInScenarios + scenarios.map { ($0.0, $0.1, Self.pro) }
        for (name, view, size) in all {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))

            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            window.isHidden = true

            XCTAssertGreaterThan(distinctColors(in: image), 8, "\(name) rendered blank")
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func distinctColors(in image: UIImage) -> Int {
        let side = 48
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        var colors = Set<UInt32>()
        for i in stride(from: 0, to: pixels.count, by: 4) {
            colors.insert(UInt32(pixels[i]) << 16 | UInt32(pixels[i + 1]) << 8 | UInt32(pixels[i + 2]))
        }
        return colors.count
    }
}
