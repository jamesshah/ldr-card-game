import SwiftUI

struct PairingView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: GameStore
    @State private var timeframeDays = 30
    @State private var inviteCode = ""

    private let timeframes = [7, 30, 90, 180]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    startCard
                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    joinCard
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pair up")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { Task { await session.signOut() } }
                }
            }
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Start a season", systemImage: "sparkles")
                .font(.title3.weight(.bold))
            Text("Pick how long your game runs. When it ends, you'll both get a recap. Nobody keeps score, but you'll know who won.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Timeframe", selection: $timeframeDays) {
                ForEach(timeframes, id: \.self) { days in
                    Text(GameFormatting.timeframeLabel(days: days)).tag(days)
                }
            }
            .pickerStyle(.segmented)
            Button {
                Task { await store.createCouple(timeframeDays: timeframeDays) }
            } label: {
                Text("Create invite code").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isWorking)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Join your partner", systemImage: "person.2.fill")
                .font(.title3.weight(.bold))
            Text("Got a 6-character code from your partner? Enter it here and your hands will be dealt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Invite code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.title2.monospaced().weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button {
                Task { await store.joinCouple(code: inviteCode) }
            } label: {
                Text("Join").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(GameFormatting.normalizedInviteCode(inviteCode).count < 6 || store.isWorking)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WaitingForPartnerView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: GameStore
    let couple: Couple
    @State private var showingCustomCard = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Share this code with your partner")
                            .font(.headline)
                        Text(couple.inviteCode)
                            .font(.system(size: 44, weight: .heavy, design: .monospaced))
                            .kerning(6)
                            .textSelection(.enabled)
                        Text("\(GameFormatting.timeframeLabel(days: Int(couple.timeframeDays))) season · starts when they join")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            ShareLink(item: "Play LDR Cards with me! Join with code \(couple.inviteCode)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            Button {
                                UIPasteboard.general.string = couple.inviteCode
                                copied = true
                            } label: {
                                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                        .controlSize(.large)
                        .padding(.top, 6)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Waiting for your partner to join…")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("While you wait")
                            .font(.headline)
                        Text("Write up to \(Int(store.hand.customCardsLeftToWrite)) custom cards that only you two would understand. They'll be added to your hand.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Write a custom card") { showingCustomCard = true }
                            .disabled(store.hand.customCardsLeftToWrite < 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Invite sent")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel invite", role: .destructive) { Task { await store.cancelInvite() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { Task { await session.signOut() } }
                }
            }
            .sheet(isPresented: $showingCustomCard) { CustomCardSheet() }
        }
    }
}

#if DEBUG
#Preview("Pair up") {
    PairingView().previewEnvironment(.previewUnpaired())
}

#Preview("Pair up · dark") {
    PairingView()
        .previewEnvironment(.previewUnpaired())
        .preferredColorScheme(.dark)
}

#Preview("Invite code") {
    WaitingForPartnerView(couple: PreviewData.waitingCouple).previewEnvironment(.previewWaiting())
}

#Preview("Invite code · dark") {
    WaitingForPartnerView(couple: PreviewData.waitingCouple)
        .previewEnvironment(.previewWaiting())
        .preferredColorScheme(.dark)
}
#endif
