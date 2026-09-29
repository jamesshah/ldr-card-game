import SwiftUI

struct CardFace: View {
    let title: String
    let bodyText: String
    let category: String
    let kind: CardKind
    var footnote: String?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            HStack {
                Label(kind == .counter ? "Counter" : category, systemImage: Theme.symbol(for: category, kind: kind))
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(kind == .counter ? .white : Theme.brand)
                    .padding(.horizontal, compact ? 9 : 11)
                    .padding(.vertical, compact ? 5 : 6)
                    .background(
                        kind == .counter ? Color.white.opacity(0.12) : Theme.brandTint,
                        in: Capsule()
                    )
                Spacer()
            }
            if !compact { Spacer(minLength: 0) }
            Text(title)
                .font(compact ? .headline : .system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(kind == .counter ? .white : Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(compact ? .subheadline : .title3)
                    .foregroundStyle(kind == .counter ? Color.white.opacity(0.78) : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !compact { Spacer(minLength: 0) }
            if let footnote {
                Text(footnote)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(kind == .counter ? .white : Theme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        kind == .counter ? Color.white.opacity(0.12) : Theme.secondarySurface,
                        in: Capsule()
                    )
            }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .leading)
        .background(
            kind == .counter ? Theme.counterSurface : Theme.cardSurface,
            in: RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 18 : 28, style: .continuous)
                .strokeBorder(kind == .counter ? Color.white.opacity(0.08) : Theme.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(compact ? 0.04 : 0.08), radius: compact ? 4 : 10, y: compact ? 2 : 5)
        .accessibilityElement(children: .combine)
    }
}

extension CardFace {
    init(card: HandCard, compact: Bool = false) {
        var footnote: String?
        if let from = card.stolenFromName {
            footnote = "Stolen from \(from)"
        } else if card.isCustom {
            footnote = "Your custom card"
        }
        self.init(title: card.title, bodyText: card.body, category: card.category, kind: card.kind, footnote: footnote, compact: compact)
    }

    init(play: Play, compact: Bool = true) {
        self.init(title: play.title, bodyText: play.body, category: play.category, kind: play.kind, footnote: nil, compact: compact)
    }
}

/// "Your time 9:41 PM · Sam 4:41 AM (quiet hours)". Refreshes every minute.
struct TimeZonesBar: View {
    let me: Player
    let partner: Player?

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 12) {
                clock(label: "You", player: me, now: context.date)
                if let partner {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.brand)
                    clock(label: partner.name, player: partner, now: context.date)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .calmSurface(radius: 16)
        }
    }

    private func clock(label: String, player: Player, now: Date) -> some View {
        let zone = GameFormatting.timeZone(identifier: player.timeZone, utcOffsetMinutes: player.utcOffsetMinutes)
        let quiet = player.quietHours?.contains(date: now, utcOffsetMinutes: player.utcOffsetMinutes) ?? false
        return VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if quiet { Image(systemName: "moon.zzz.fill").foregroundStyle(Theme.warning) }
                Text(GameFormatting.clockTime(now, timeZone: zone))
                    .font(.headline.monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(GameFormatting.clockTime(now, timeZone: zone))\(quiet ? ", quiet hours" : "")")
    }
}

#if DEBUG
#Preview("Card face") {
    CardFace(card: PreviewData.callCard)
        .frame(height: 440)
        .padding(28)
}

#Preview("Card faces · every category") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PreviewData.fullHand.cards) { CardFace(card: $0, compact: true) }
        }
        .padding()
    }
}

#Preview("Card face · dark") {
    CardFace(card: PreviewData.stolenCard)
        .frame(height: 440)
        .padding(28)
        .preferredColorScheme(.dark)
}

#Preview("Time zones · partner in quiet hours", traits: .sizeThatFitsLayout) {
    TimeZonesBar(
        me: PreviewData.me,
        partner: Player(id: "user_theo", name: "Theo", timeZone: "Europe/London", utcOffsetMinutes: 60,
                        quietStartMinutes: 0, quietEndMinutes: 24 * 60 - 1)
    )
    .padding()
}
#endif
