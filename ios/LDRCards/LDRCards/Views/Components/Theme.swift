import SwiftUI

enum Theme {
    static let rose = Color(red: 0.91, green: 0.29, blue: 0.38)
    static let plum = Color(red: 0.36, green: 0.16, blue: 0.45)
    static let night = Color(red: 0.12, green: 0.10, blue: 0.22)

    static func gradient(for category: String, kind: CardKind) -> LinearGradient {
        let colors: [Color]
        if kind == .counter {
            colors = [Color(red: 0.20, green: 0.22, blue: 0.30), Color(red: 0.08, green: 0.09, blue: 0.14)]
        } else {
            switch category {
            case "Calls": colors = [Color(red: 0.98, green: 0.45, blue: 0.40), Color(red: 0.85, green: 0.22, blue: 0.40)]
            case "Voice & Video": colors = [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.36, green: 0.18, blue: 0.70)]
            case "Photos": colors = [Color(red: 0.99, green: 0.66, blue: 0.30), Color(red: 0.93, green: 0.40, blue: 0.25)]
            case "Deliveries": colors = [Color(red: 0.20, green: 0.70, blue: 0.62), Color(red: 0.10, green: 0.45, blue: 0.50)]
            case "Together Apart": colors = [Color(red: 0.25, green: 0.52, blue: 0.95), Color(red: 0.20, green: 0.25, blue: 0.70)]
            case "Sweet": colors = [Color(red: 0.98, green: 0.52, blue: 0.70), Color(red: 0.86, green: 0.30, blue: 0.55)]
            case "Playful": colors = [Color(red: 0.95, green: 0.75, blue: 0.20), Color(red: 0.90, green: 0.45, blue: 0.15)]
            case "Custom": colors = [Theme.plum, Theme.night]
            default: colors = [Theme.rose, Theme.plum]
            }
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func symbol(for category: String, kind: CardKind) -> String {
        if kind == .counter { return "shield.lefthalf.filled" }
        switch category {
        case "Calls": return "video.fill"
        case "Voice & Video": return "waveform"
        case "Photos": return "camera.fill"
        case "Deliveries": return "shippingbox.fill"
        case "Together Apart": return "sparkles.tv.fill"
        case "Sweet": return "heart.fill"
        case "Playful": return "face.smiling.inverse"
        case "Custom": return "pencil.and.scribble"
        default: return "suit.heart.fill"
        }
    }
}

struct ErrorAlert: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            "Hold on",
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(message ?? "") }
        )
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>) -> some View {
        modifier(ErrorAlert(message: message))
    }
}
