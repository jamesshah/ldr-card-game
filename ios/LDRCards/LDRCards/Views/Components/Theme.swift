import SwiftUI

enum Theme {
    /// One brand accent, warm neutral surfaces, and semantic colors used only for state.
    static let brandUIColor = UIColor(red: 0.79, green: 0.31, blue: 0.39, alpha: 1)
    static let brand = Color(uiColor: brandUIColor)
    static let rose = brand
    static let canvas = adaptive(light: 0xF7F5F4, dark: 0x121011)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1B1819)
    static let secondarySurface = adaptive(light: 0xF0ECEA, dark: 0x252123)
    static let cardSurface = adaptive(light: 0xFCF8F7, dark: 0x201B1D)
    static let primaryText = adaptive(light: 0x211D1E, dark: 0xF8F4F3)
    static let secondaryText = adaptive(light: 0x71696C, dark: 0xB7AFB1)
    static let hairline = adaptive(light: 0xDED7D5, dark: 0x383235)
    static let brandTint = adaptive(light: 0xF5E4E7, dark: 0x3A2026)
    static let success = adaptive(light: 0x2F7D5B, dark: 0x61B58C)
    static let warning = adaptive(light: 0x9A6A1D, dark: 0xD2A451)
    static let destructive = adaptive(light: 0xB8404D, dark: 0xE0717C)
    static let mutedStatus = adaptive(light: 0x777174, dark: 0xA7A0A2)
    static let counterSurface = adaptive(light: 0x292729, dark: 0x242123)

    static func statusColor(_ state: PlayState, delivered: Bool = true) -> Color {
        if !delivered { return warning }
        switch state {
        case .completed: return success
        case .refused: return destructive
        case .countered: return mutedStatus
        case .proofSubmitted: return brand
        case .pending: return warning
        }
    }

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        for item in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            item.normal.badgeBackgroundColor = brandUIColor
            item.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct CalmSurface: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.75)
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
    func calmSurface(radius: CGFloat = 20) -> some View {
        modifier(CalmSurface(radius: radius))
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        modifier(ErrorAlert(message: message))
    }
}
