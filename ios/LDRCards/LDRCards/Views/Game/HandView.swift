import SwiftUI

struct HandView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selection: String?
    @State private var cardToPlay: HandCard?
    @State private var showingCustomCard = false

    private var cards: [HandCard] { store.hand.cards }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let couple = store.couple {
                    VStack(spacing: 12) {
                        TimeZonesBar(me: couple.me, partner: couple.partner)
                        SeasonHeader(couple: couple)
                    }
                    .padding(.horizontal)
                }

                if cards.isEmpty {
                    ContentUnavailableView(
                        "Your hand is empty",
                        systemImage: "rectangle.stack.badge.minus",
                        description: Text("You've played every card you had. Write a custom card, or wait for your partner to refuse one so you can steal from them.")
                    )
                } else {
                    deck
                    actionArea
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your hand")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomCard = true
                    } label: {
                        Label("Write a custom card", systemImage: "square.and.pencil")
                    }
                    .disabled(store.hand.customCardsLeftToWrite < 1 || store.couple?.status != .active)
                }
            }
            .sheet(item: $cardToPlay) { card in
                PlayCardSheet(card: card)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingCustomCard) { CustomCardSheet() }
            .onChange(of: cards.map(\.id)) { _, ids in
                if let selection, ids.contains(selection) { return }
                selection = ids.first
            }
            .onAppear { if selection == nil { selection = cards.first?.id } }
        }
    }

    private var deck: some View {
        TabView(selection: $selection) {
            ForEach(cards) { card in
                CardFace(card: card)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
                    .tag(Optional(card.id))
                    .onTapGesture { if card.kind == .action { cardToPlay = card } }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: 460)
    }

    private var selectedCard: HandCard? {
        cards.first { $0.id == selection } ?? cards.first
    }

    private var actionArea: some View {
        VStack(spacing: 8) {
            if let index = cards.firstIndex(where: { $0.id == selectedCard?.id }) {
                Text("Card \(index + 1) of \(cards.count) · \(Int(store.hand.partnerCardsLeft)) left in \(store.partnerName)'s hand")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let card = selectedCard {
                if card.kind == .counter {
                    Text("Save counters for when a card is played on you. Use them from your Inbox.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Button {
                        cardToPlay = card
                    } label: {
                        Label("Play on \(store.partnerName)", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 28)
                    .disabled(store.couple?.status != .active)
                }
            }
        }
    }
}

struct PlayCardSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let card: HandCard
    @State private var stackOnId: String?

    private var stackable: [Play] {
        store.inbox.incoming.filter { $0.state == .pending || $0.state == .proofSubmitted }
    }

    private var waitingOnPartner: Bool {
        store.inbox.waitingOnPartner.contains { $0.state == .pending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardFace(card: card, compact: true)

                    if waitingOnPartner {
                        Label("\(store.partnerName) still has to answer your last card. You can play again once they respond.", systemImage: "hourglass")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    if let partner = store.partner,
                       let quiet = partner.quietHours,
                       quiet.contains(date: Date(), utcOffsetMinutes: partner.utcOffsetMinutes) {
                        Label(
                            "\(partner.name) is in quiet hours. This card will arrive at \(GameFormatting.timeOfDay(minutes: quiet.endMinutes)) their time.",
                            systemImage: "moon.zzz.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                    }

                    if !stackable.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stack it (optional)")
                                .font(.headline)
                            Text("Put this on top of a card \(store.partnerName) played on you. Both cards stay in play.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Picker("Stack on", selection: $stackOnId) {
                                Text("Don't stack").tag(String?.none)
                                ForEach(stackable) { play in
                                    Text(play.title).tag(Optional(play.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Play this card?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play") {
                        Task {
                            let stackOn = stackable.first { $0.id == stackOnId }
                            if await store.play(card, stackedOn: stackOn) { dismiss() }
                        }
                    }
                    .disabled(store.isWorking || waitingOnPartner)
                }
            }
        }
    }
}

struct CustomCardSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title, e.g. \"Say our inside joke\"", text: $title)
                    TextField("What your partner has to do", text: $bodyText, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("\(Int(store.hand.customCardsLeftToWrite)) custom cards left to write this season.")
                }
                Section("Preview") {
                    CardFace(
                        title: trimmedTitle.isEmpty ? "Your card" : trimmedTitle,
                        bodyText: bodyText,
                        category: "Custom",
                        kind: .action,
                        compact: true
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Custom card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            if await store.createCustomCard(title: trimmedTitle, body: bodyText) { dismiss() }
                        }
                    }
                    .disabled(trimmedTitle.count < 3 || trimmedTitle.count > 60 || store.isWorking)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Hand") {
    HandView().previewEnvironment()
}

#Preview("Hand · dark") {
    HandView()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Hand · empty") {
    HandView().previewEnvironment(.previewPaired(hand: PreviewData.emptyHand))
}

#Preview("Hand · counters only") {
    HandView().previewEnvironment(.previewPaired(hand: PreviewData.counterOnlyHand))
}

#Preview("Play sheet · stack option") {
    PlayCardSheet(card: PreviewData.voiceCard)
        .previewEnvironment(.previewPaired(inbox: Inbox(incoming: [PreviewData.incomingPending], toReview: [], waitingOnPartner: [])))
}

#Preview("Play sheet · waiting on partner") {
    PlayCardSheet(card: PreviewData.movieCard).previewEnvironment()
}

#Preview("Custom card") {
    CustomCardSheet().previewEnvironment()
}
#endif
