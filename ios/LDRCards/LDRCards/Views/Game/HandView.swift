import SwiftUI

enum HandDisplayMode: String, CaseIterable, Identifiable {
    case cards
    case list

    var id: String { rawValue }
    var symbol: String { self == .cards ? "rectangle.stack.fill" : "list.bullet" }
    var label: String { self == .cards ? "Cards" : "List" }
}

struct HandView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selection: String?
    @State private var cardToPlay: HandCard?
    @State private var showingCustomCard = false
    @AppStorage("handDisplayMode") private var displayModeRaw = HandDisplayMode.cards.rawValue
    @AppStorage("handCategoryFilter") private var savedCategory = "All"

    private let previewDisplayMode: HandDisplayMode?
    private let previewCategory: String?

    static let allCategories = "All"

    init(previewDisplayMode: HandDisplayMode? = nil, previewCategory: String? = nil) {
        self.previewDisplayMode = previewDisplayMode
        self.previewCategory = previewCategory
    }

    private var cards: [HandCard] { store.hand.cards }
    private var activeCategory: String { previewCategory ?? savedCategory }
    private var displayMode: HandDisplayMode {
        previewDisplayMode ?? HandDisplayMode(rawValue: displayModeRaw) ?? .cards
    }
    private var filteredCards: [HandCard] {
        guard activeCategory != Self.allCategories else { return cards }
        return cards.filter { $0.filterCategory == activeCategory }
    }
    private var categories: [String] {
        Array(Set(cards.map(\.filterCategory))).sorted { lhs, rhs in
            let trailing = ["Custom", "Counter"]
            let leftRank = trailing.firstIndex(of: lhs) ?? -1
            let rightRank = trailing.firstIndex(of: rhs) ?? -1
            if leftRank >= 0 || rightRank >= 0 {
                if leftRank < 0 { return true }
                if rightRank < 0 { return false }
                return leftRank < rightRank
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

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

                if !cards.isEmpty {
                    browseControls
                        .padding(.horizontal)
                }

                if cards.isEmpty {
                    ContentUnavailableView(
                        "Your hand is empty",
                        systemImage: "rectangle.stack.badge.minus",
                        description: Text("You've played every card you had. Write a custom card, or wait for your partner to refuse one so you can steal from them.")
                    )
                } else if filteredCards.isEmpty {
                    ContentUnavailableView(
                        "No \(activeCategory) cards",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Choose All or another category to see the rest of your hand.")
                    )
                } else {
                    if displayMode == .cards {
                        deck
                        actionArea
                    } else {
                        cardList
                    }
                }
            }
            .padding(.vertical, 12)
            .background(Theme.canvas)
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
            .onChange(of: cards.map(\.id)) { oldIDs, newIDs in
                let visible = filteredCards.map(\.id)
                if let newFirst = newIDs.first,
                   !oldIDs.contains(newFirst),
                   visible.contains(newFirst) {
                    selection = newFirst
                    return
                }
                if let selection, visible.contains(selection) { return }
                selection = visible.first
            }
            .onChange(of: activeCategory) { _, _ in selection = filteredCards.first?.id }
            .onAppear { if selection == nil { selection = filteredCards.first?.id } }
        }
    }

    private var browseControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(HandDisplayMode.allCases) { mode in
                    Button {
                        displayModeRaw = mode.rawValue
                    } label: {
                        Image(systemName: mode.symbol)
                            .foregroundStyle(displayMode == mode ? Theme.brand : Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                displayMode == mode ? Theme.brandTint : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.label)
                    .accessibilityAddTraits(displayMode == mode ? .isSelected : [])
                }
            }
            .padding(2)
            .calmSurface(radius: 10)
            .frame(width: 112)

            Menu {
                Button {
                    savedCategory = Self.allCategories
                } label: {
                    if activeCategory == Self.allCategories {
                        Label("All", systemImage: "checkmark")
                    } else {
                        Text("All")
                    }
                }
                ForEach(categories, id: \.self) { category in
                    Button {
                        savedCategory = category
                    } label: {
                        if activeCategory == category {
                            Label(category, systemImage: "checkmark")
                        } else {
                            Text(category)
                        }
                    }
                }
            } label: {
                Label(
                    activeCategory,
                    systemImage: activeCategory == Self.allCategories
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activeCategory == Self.allCategories ? Theme.primaryText : Theme.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .calmSurface(radius: 10)
            }
            .accessibilityLabel("Card category: \(activeCategory)")
        }
    }

    private var deck: some View {
        TabView(selection: $selection) {
            ForEach(filteredCards) { card in
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

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredCards) { card in
                    Button {
                        if card.kind == .action {
                            cardToPlay = card
                        } else {
                            selection = card.id
                            displayModeRaw = HandDisplayMode.cards.rawValue
                        }
                    } label: {
                        CardFace(card: card, compact: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(card.kind == .action ? "Opens the play sheet" : "Opens this counter card")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var selectedCard: HandCard? {
        filteredCards.first { $0.id == selection } ?? filteredCards.first
    }

    private var actionArea: some View {
        VStack(spacing: 8) {
            if let index = filteredCards.firstIndex(where: { $0.id == selectedCard?.id }) {
                Text("Card \(index + 1) of \(filteredCards.count) · \(Int(store.hand.partnerCardsLeft)) left in \(store.partnerName)'s hand")
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
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .controlSize(.large)
                    .padding(.horizontal, 28)
                    .disabled(store.couple?.status != .active)
                }
            }
        }
    }
}

private extension HandCard {
    var filterCategory: String { kind == .counter ? "Counter" : category }
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
                            .foregroundStyle(Theme.warning)
                    }

                    if let partner = store.partner,
                       let quiet = partner.quietHours,
                       quiet.contains(date: Date(), utcOffsetMinutes: partner.utcOffsetMinutes) {
                        Label(
                            "\(partner.name) is in quiet hours. This card will arrive at \(GameFormatting.timeOfDay(minutes: quiet.endMinutes)) their time.",
                            systemImage: "moon.zzz.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(Theme.warning)
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
            .background(Theme.canvas)
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
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
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

#Preview("Hand · list") {
    HandView(previewDisplayMode: .list).previewEnvironment()
}

#Preview("Hand · list · dark") {
    HandView(previewDisplayMode: .list)
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Hand · filtered Custom") {
    HandView(previewCategory: "Custom").previewEnvironment()
}

#Preview("Hand · filtered Custom · dark") {
    HandView(previewCategory: "Custom")
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Hand · SE", traits: .fixedLayout(width: 375, height: 667)) {
    HandView().previewEnvironment()
}

#Preview("Hand · Pro Max", traits: .fixedLayout(width: 440, height: 956)) {
    HandView().previewEnvironment()
}

#Preview("Hand · Pro Max · dark", traits: .fixedLayout(width: 440, height: 956)) {
    HandView()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Hand · grayscale") {
    HandView()
        .previewEnvironment()
        .grayscale(1)
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
