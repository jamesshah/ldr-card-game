import SwiftUI

struct StartNewSeasonSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let seasonAlreadyOver: Bool

    @State private var timeframeDays = 30

    private let timeframes = [7, 30, 90, 180]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.brand)
                    .padding(.top, 12)
                Text("Start a new season?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(seasonAlreadyOver
                    ? "Pick how long you and \(store.partnerName) want to play next. You'll both get a fresh Deck right away."
                    : "This ends your current season early and starts a new one with \(store.partnerName). You'll both get a fresh Deck.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Picker("Timeframe", selection: $timeframeDays) {
                    ForEach(timeframes, id: \.self) { days in
                        Text(GameFormatting.timeframeLabel(days: days)).tag(days)
                    }
                }
                .pickerStyle(.segmented)
                Spacer(minLength: 0)
                Button {
                    Task {
                        if await store.startNewSeason(timeframeDays: timeframeDays) {
                            dismiss()
                        }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Start new season").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isWorking)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(store.isWorking)
                }
            }
        }
    }
}

struct UnpairSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let seasonAlreadyOver: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.brand)
                    .padding(.top, 12)
                Text("Unpair?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(seasonAlreadyOver
                    ? "You'll leave \(store.partnerName) and return to pairing. You can invite someone new anytime."
                    : "This ends the season for both of you and unpairs you. You'll return to pairing and can invite someone new.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task {
                        if await store.unpair() {
                            dismiss()
                        }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Unpair").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(store.isWorking)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(store.isWorking)
                }
            }
        }
    }
}
