import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: GameStore

    @State private var name = ""
    @State private var quietEnabled = false
    @State private var quietStart = GameFormatting.date(fromMinutes: 22 * 60)
    @State private var quietEnd = GameFormatting.date(fromMinutes: 7 * 60)
    @State private var loaded = false
    @State private var showingCustomCard = false

    private var me: Player? { store.couple?.me }

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
                } footer: {
                    Text("Cards \(store.partnerName) plays during your quiet hours are held and delivered when they end.")
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
                    Button("Write a custom card (\(Int(store.hand.customCardsLeftToWrite)) left)") {
                        showingCustomCard = true
                    }
                    .disabled(store.hand.customCardsLeftToWrite < 1 || store.couple?.status != .active)
                }

                Section {
                    Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCustomCard) { CustomCardSheet() }
            .onAppear(perform: loadFromProfile)
            .onChange(of: quietEnabled) { _, _ in saveQuietHours() }
            .onChange(of: quietStart) { _, _ in saveQuietHours() }
            .onChange(of: quietEnd) { _, _ in saveQuietHours() }
        }
    }

    private func loadFromProfile() {
        guard !loaded, let me else { return }
        name = me.name
        if let quiet = me.quietHours {
            quietEnabled = true
            quietStart = GameFormatting.date(fromMinutes: quiet.startMinutes)
            quietEnd = GameFormatting.date(fromMinutes: quiet.endMinutes)
        }
        // Let the onChange handlers from the initial load settle before saving user edits.
        DispatchQueue.main.async { loaded = true }
    }

    private func saveQuietHours() {
        guard loaded else { return }
        let start = GameFormatting.minutes(from: quietStart)
        let end = GameFormatting.minutes(from: quietEnd)
        Task {
            if quietEnabled {
                await store.setQuietHours(startMinutes: start, endMinutes: end)
            } else {
                await store.setQuietHours(startMinutes: nil, endMinutes: nil)
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
