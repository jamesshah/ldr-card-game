import SwiftUI

struct RecapView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let recap = store.recap {
                    VStack(spacing: 20) {
                        header(recap)
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(orderedPlayers(recap)) { player in
                                PlayerStatsCard(player: player, isMe: player.userId == store.couple?.me.id)
                            }
                        }
                        Text("Nobody keeps score. At the end of the season, you both just know who won.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(20)
                } else {
                    ContentUnavailableView(
                        "Recap unavailable",
                        systemImage: "trophy",
                        description: Text("Your recap appears once your partner joins and the season begins.")
                    )
                    .padding(.top, 80)
                }
            }
            .background(Theme.canvas)
            .navigationTitle(store.recap?.status == .ended ? "Season recap" : "Season so far")
        }
    }

    private func orderedPlayers(_ recap: Recap) -> [RecapPlayer] {
        guard let myID = store.couple?.me.id else { return recap.players }
        return recap.players.sorted { lhs, rhs in
            (lhs.userId == myID ? 1 : 0) < (rhs.userId == myID ? 1 : 0)
        }
    }

    private func header(_ recap: Recap) -> some View {
        VStack(spacing: 8) {
            Image(systemName: recap.status == .ended ? "trophy.fill" : "hourglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.brand)
            if recap.status == .ended {
                Text("That's a wrap!")
                    .font(.title.weight(.bold))
            } else {
                Text("\(GameFormatting.daysLeft(endsAt: recap.endsAt, now: Date())) days to go")
                    .font(.title.weight(.bold))
            }
            if let start = recap.startedAt, let end = recap.endsAt {
                Text("\(Date(timeIntervalSince1970: start / 1000).formatted(date: .abbreviated, time: .omitted)) – \(Date(timeIntervalSince1970: end / 1000).formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .calmSurface(radius: 24)
    }
}

private struct PlayerStatsCard: View {
    let player: RecapPlayer
    let isMe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isMe ? "You" : player.name)
                .font(.headline)
            stat("Cards played", player.played, "paperplane.fill")
            stat("Completed for them", player.completedByPartner, "checkmark.seal.fill")
            stat("Refused by partner", player.refusedByPartner, "hand.raised.fill")
            stat("Refused", player.refused, "xmark.circle.fill")
            stat("Counters used", player.countersUsed, "shield.lefthalf.filled")
            stat("Cards stolen", player.cardsStolen, "bolt.fill")
            stat("Cards left", player.cardsLeft, "rectangle.stack.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isMe ? Theme.brand.opacity(0.55) : Theme.hairline, lineWidth: isMe ? 1.5 : 0.75)
        )
    }

    private func stat(_ label: String, _ value: Double, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text("\(Int(value))")
                .font(.headline.monospacedDigit())
        }
    }
}

#if DEBUG
#Preview("Recap · season so far") {
    RecapView().previewEnvironment()
}

#Preview("Recap · season over") {
    RecapView().previewEnvironment(.previewEnded())
}

#Preview("Recap · unavailable") {
    RecapView().previewEnvironment(.previewPaired(recap: nil))
}

#Preview("Recap · dark") {
    RecapView()
        .previewEnvironment(.previewEnded())
        .preferredColorScheme(.dark)
}
#endif
