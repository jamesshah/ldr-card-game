import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: GameStore

    @State private var name = ""
    @State private var quietEnabled = false
    @State private var quietStart = GameFormatting.date(fromMinutes: 22 * 60)
    @State private var quietEnd = GameFormatting.date(fromMinutes: 7 * 60)
    /// Last successfully saved quiet hours (`nil` = off). Draft is compared against this.
    @State private var savedQuietHours: QuietHours?
    @State private var loaded = false
    @State private var showingCustomCard = false
    @State private var confirmingEndAndUnpair = false

    private var me: Player? { store.couple?.me }
    private var canEndAndUnpair: Bool {
        guard let status = store.couple?.status else { return false }
        return status == .active || status == .ended
    }

    /// True when the draft differs from the last saved quiet-hours setting.
    private var hasUnsavedQuietHours: Bool {
        guard loaded else { return false }
        if quietEnabled {
            let start = GameFormatting.minutes(from: quietStart)
            let end = GameFormatting.minutes(from: quietEnd)
            guard let saved = savedQuietHours else { return true }
            return saved.startMinutes != start || saved.endMinutes != end
        }
        return savedQuietHours != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        TextField("Name", text: $name)
                            .textContentType(.givenName)
                        if let me, name.trimmingCharacters(in: .whitespaces) != me.name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Save") { Task { await store.rename(to: name.trimmingCharacters(in: .whitespaces)) } }
                        }
                    }
                    if let me {
                        LabeledContent("Time zone", value: me.timeZone)
                    }
                }

                Section {
                    Toggle("Quiet hours", isOn: $quietEnabled)
                    if quietEnabled {
                        DatePicker("From", selection: $quietStart, displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: $quietEnd, displayedComponents: .hourAndMinute)
                    }
                    Button {
                        Task { await saveQuietHours() }
                    } label: {
                        if store.isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(hasUnsavedQuietHours ? "Save quiet hours" : "Quiet hours saved")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isWorking || !hasUnsavedQuietHours)
                } footer: {
                    Text("Nudges \(store.partnerName) sends during quiet hours are held and delivered when they end.")
                }

                Section("Season") {
                    if let couple = store.couple {
                        LabeledContent("Length", value: GameFormatting.timeframeLabel(days: Int(couple.timeframeDays)))
                        if let end = couple.endsAt {
                            LabeledContent(couple.status == .ended ? "Ended" : "Ends",
                                           value: Date(timeIntervalSince1970: end / 1000).formatted(date: .abbreviated, time: .shortened))
                        }
                        if let partner = couple.partner {
                            LabeledContent("Partner", value: partner.name)
                        }
                    }
                    Button("Write a custom Nudge (\(Int(store.hand.customCardsLeftToWrite)) left)") {
                        showingCustomCard = true
                    }
                    .disabled(store.hand.customCardsLeftToWrite < 1 || store.couple?.status != .active)
                }

                if canEndAndUnpair {
                    Section {
                        Button("End season & unpair", role: .destructive) {
                            confirmingEndAndUnpair = true
                        }
                        .disabled(store.isWorking)
                    } footer: {
                        Text("Ends the season for both of you and returns each of you to pairing. You can start a new season anytime.")
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCustomCard) { CustomCardSheet() }
            .sheet(isPresented: $confirmingEndAndUnpair) {
                EndSeasonUnpairSheet()
                    .presentationDetents([.medium])
                    .environmentObject(store)
            }
            .onAppear(perform: loadFromProfile)
        }
    }

    private func loadFromProfile() {
        guard !loaded, let me else { return }
        name = me.name
        savedQuietHours = me.quietHours
        if let quiet = me.quietHours {
            quietEnabled = true
            quietStart = GameFormatting.date(fromMinutes: quiet.startMinutes)
            quietEnd = GameFormatting.date(fromMinutes: quiet.endMinutes)
        }
        loaded = true
    }

    private func saveQuietHours() async {
        guard loaded, hasUnsavedQuietHours else { return }
        let start = GameFormatting.minutes(from: quietStart)
        let end = GameFormatting.minutes(from: quietEnd)
        if quietEnabled {
            if await store.setQuietHours(startMinutes: start, endMinutes: end) {
                savedQuietHours = QuietHours(startMinutes: start, endMinutes: end)
            }
        } else if await store.setQuietHours(startMinutes: nil, endMinutes: nil) {
            savedQuietHours = nil
        }
    }
}

private struct EndSeasonUnpairSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.brand)
                    .padding(.top, 12)
                Text("End season & unpair?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("This ends the season for you and \(store.partnerName), then unpairs you both. This can’t be undone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task {
                        if await store.endSeasonAndUnpair() {
                            dismiss()
                        }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("End season & unpair").frame(maxWidth: .infinity)
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

#if DEBUG
#Preview("Settings") {
    SettingsView().previewEnvironment()
}

#Preview("Settings · dark") {
    SettingsView()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}
#endif
