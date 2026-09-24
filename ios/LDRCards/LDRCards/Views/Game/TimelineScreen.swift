import SwiftUI

struct TimelineScreen: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        NavigationStack {
            Group {
                if store.timeline.isEmpty {
                    ContentUnavailableView(
                        "No cards played yet",
                        systemImage: "clock",
                        description: Text("Every card you two play lands here, with the time it was for each of you.")
                    )
                } else {
                    List {
                        if let couple = store.couple {
                            Section {
                                TimeZonesBar(me: couple.me, partner: couple.partner)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                        }
                        Section {
                            ForEach(store.timeline) { play in
                                TimelineRow(play: play, me: store.couple?.me, partner: store.couple?.partner)
                                    .listRowBackground(Theme.surface)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Timeline")
        }
    }
}

private struct TimelineRow: View {
    let play: Play
    let me: Player?
    let partner: Player?

    private var tint: Color {
        Theme.statusColor(play.state, delivered: play.delivered)
    }

    private var headline: String {
        if play.kind == .counter {
            return "\(play.fromName) shut down \(play.counteredTitle.map { "\"\($0)\"" } ?? "a card")"
        }
        return "\(play.fromName) → \(play.toName)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: play.kind == .counter ? "shield.lefthalf.filled" : GameFormatting.stateSymbol(play.state))
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(play.title)
                    .font(.headline)
                if let stacked = play.stackedOnTitle {
                    Text("Stacked on \"\(stacked)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if play.kind == .action {
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                }
                if play.state == .completed || play.state == .proofSubmitted {
                    ProofView(play: play)
                }
                Text(timesLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLine: String {
        var line = GameFormatting.stateLabel(play.state)
        if !play.delivered {
            line = "Held for quiet hours"
        } else if play.state == .refused, let stolen = play.stolenCardTitle {
            line += " · \(play.fromName) stole \"\(stolen)\""
        }
        return line
    }

    private var timesLine: String {
        let date = play.playedDate
        var parts: [String] = [date.formatted(date: .abbreviated, time: .omitted)]
        if let me {
            let zone = GameFormatting.timeZone(identifier: me.timeZone, utcOffsetMinutes: me.utcOffsetMinutes)
            parts.append("\(GameFormatting.clockTime(date, timeZone: zone)) for you")
        }
        if let partner {
            let zone = GameFormatting.timeZone(identifier: partner.timeZone, utcOffsetMinutes: partner.utcOffsetMinutes)
            parts.append("\(GameFormatting.clockTime(date, timeZone: zone)) for \(partner.name)")
        }
        return parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview("Timeline") {
    TimelineScreen().previewEnvironment()
}

#Preview("Timeline · empty") {
    TimelineScreen().previewEnvironment(.previewPaired(timeline: []))
}

#Preview("Timeline · dark") {
    TimelineScreen()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}
#endif
