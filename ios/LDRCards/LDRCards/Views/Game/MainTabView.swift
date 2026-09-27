import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        TabView {
            HandView()
                .tabItem { Label("Hand", systemImage: "rectangle.stack.fill") }
            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.full.fill") }
                .badge(store.inbox.needsAttentionCount)
            TimelineScreen()
                .tabItem { Label("Timeline", systemImage: "clock.fill") }
            RecapView()
                .tabItem { Label("Recap", systemImage: "trophy.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

struct SeasonHeader: View {
    let couple: Couple

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3600)) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(couple.status == .ended ? "Season over" : "\(GameFormatting.daysLeft(endsAt: couple.endsAt, now: context.date)) days left")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(GameFormatting.timeframeLabel(days: Int(couple.timeframeDays)) + " season")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: GameFormatting.seasonProgress(startedAt: couple.startedAt, endsAt: couple.endsAt, now: context.date))
                    .tint(Theme.brand)
            }
        }
    }
}

#if DEBUG
#Preview("Main tabs") {
    MainTabView().previewEnvironment()
}

#Preview("Main tabs · season over") {
    MainTabView().previewEnvironment(.previewEnded())
}

#Preview("Season header", traits: .sizeThatFitsLayout) {
    SeasonHeader(couple: PreviewData.pairedCouple).padding()
}
#endif
