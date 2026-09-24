import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var store: GameStore
    @State private var completing: Play?
    @State private var countering: Play?
    @State private var refusing: Play?
    @State private var rejecting: Play?
    @State private var rejectNote = ""

    private var inbox: Inbox { store.inbox }
    private var isEmpty: Bool {
        inbox.incoming.isEmpty && inbox.toReview.isEmpty && inbox.waitingOnPartner.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView(
                        "Nothing waiting",
                        systemImage: "tray",
                        description: Text("When \(store.partnerName) plays a card on you, it shows up here. Your move: go play one from your hand.")
                    )
                } else {
                    list
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Inbox")
            .sheet(item: $completing) { play in CompleteProofSheet(play: play) }
            .sheet(item: $countering) { play in
                CounterSheet(play: play)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                "Refuse this card?",
                isPresented: Binding(get: { refusing != nil }, set: { if !$0 { refusing = nil } }),
                titleVisibility: .visible,
                presenting: refusing
            ) { play in
                Button("Refuse \"\(play.title)\"", role: .destructive) {
                    Task { await store.refuse(play) }
                }
            } message: { _ in
                Text("\(store.partnerName) gets to steal a card from your hand and use it against you.")
            }
            .alert(
                "Ask for another try",
                isPresented: Binding(get: { rejecting != nil }, set: { if !$0 { rejecting = nil } }),
                presenting: rejecting
            ) { play in
                TextField("What's missing?", text: $rejectNote)
                Button("Send back") {
                    let note = rejectNote
                    rejectNote = ""
                    Task { await store.rejectProof(play, note: note) }
                }
                Button("Cancel", role: .cancel) { rejectNote = "" }
            } message: { _ in
                Text("The card goes back to \(store.partnerName) to try again.")
            }
        }
    }

    private var list: some View {
        List {
            if !inbox.incoming.isEmpty {
                Section("Played on you") {
                    ForEach(inbox.incoming) { play in
                        IncomingRow(
                            play: play,
                            partnerName: store.partnerName,
                            hasCounter: !store.hand.counterCards.isEmpty,
                            onComplete: { completing = play },
                            onCounter: { countering = play },
                            onRefuse: { refusing = play }
                        )
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            if !inbox.toReview.isEmpty {
                Section("Proof to review") {
                    ForEach(inbox.toReview) { play in
                        VStack(alignment: .leading, spacing: 12) {
                            CardFace(play: play)
                            ProofView(play: play)
                            HStack {
                                Button {
                                    Task { await store.acceptProof(play) }
                                } label: {
                                    Label("Accept", systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                Button {
                                    rejecting = play
                                } label: {
                                    Label("Try again", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Theme.secondaryText)
                            }
                            // Inside a List row the automatic label style drops the icon.
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                            .font(.subheadline.weight(.semibold))
                            .disabled(store.isWorking)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            if !inbox.waitingOnPartner.isEmpty {
                Section("Waiting on \(store.partnerName)") {
                    ForEach(inbox.waitingOnPartner) { play in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(play.title).font(.headline)
                            if play.delivered {
                                Text("Delivered \(play.playedDate.formatted(.relative(presentation: .named)))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label(
                                    "Held for quiet hours. Arrives \(play.deliverDate.formatted(date: .omitted, time: .shortened)) your time.",
                                    systemImage: "moon.zzz.fill"
                                )
                                .font(.subheadline)
                                .foregroundStyle(Theme.warning)
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
    }
}

private struct IncomingRow: View {
    let play: Play
    let partnerName: String
    let hasCounter: Bool
    let onComplete: () -> Void
    let onCounter: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardFace(play: play)
            if let stackedOn = play.stackedOnTitle {
                Label("Stacked on \"\(stackedOn)\"", systemImage: "square.stack.3d.up.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let note = play.proofRejectedNote {
                Label("\(partnerName) asked for another try: \(note)", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }
            if play.state == .proofSubmitted {
                Label("Proof sent. Waiting for \(partnerName) to accept.", systemImage: "paperplane.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Button(action: onComplete) {
                        Label("Complete", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    HStack(spacing: 8) {
                        Button(action: onCounter) {
                            Label("Counter", systemImage: "shield.lefthalf.filled").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.secondaryText)
                        .disabled(!hasCounter)
                        Button(role: .destructive, action: onRefuse) {
                            Label("Refuse", systemImage: "hand.raised.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.destructive)
                    }
                }
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }
}

struct CounterSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let play: Play

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CardFace(play: play)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("A counter knocks this card out of the game for good. Your counter card is used up too.")
                }
                Section("Your counter cards") {
                    if store.hand.counterCards.isEmpty {
                        Text("You don't have any counter cards left.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.hand.counterCards) { card in
                        Button {
                            Task {
                                if await store.counter(play, with: card) { dismiss() }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title).font(.headline)
                                Text(card.body).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.isWorking)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Shut it down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Shows a submitted proof: text, photo, or voice note.
struct ProofView: View {
    let play: Play
    @StateObject private var audio = AudioProofPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch play.proofType {
            case .some(.photo):
                if let urlString = play.proofUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            Label("Couldn't load the photo", systemImage: "photo.badge.exclamationmark")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            case .some(.audio):
                if let urlString = play.proofUrl, let url = URL(string: urlString) {
                    Button {
                        audio.toggle(url: url)
                    } label: {
                        Label(audio.isPlaying ? "Pause voice note" : "Play voice note",
                              systemImage: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
            case .some(.text), .none:
                EmptyView()
            }
            if let text = play.proofText {
                Text("“\(text)”")
                    .font(.body)
                    .italic()
            }
        }
    }
}

#if DEBUG
#Preview("Inbox") {
    InboxView().previewEnvironment()
}

#Preview("Inbox · empty") {
    InboxView().previewEnvironment(.previewPaired(inbox: .empty))
}

#Preview("Inbox · pending proof") {
    InboxView().previewEnvironment(.previewPaired(inbox: PreviewData.pendingProofInbox))
}

#Preview("Inbox · pending proof · dark") {
    InboxView()
        .previewEnvironment(.previewPaired(inbox: PreviewData.pendingProofInbox))
        .preferredColorScheme(.dark)
}

#Preview("Inbox · held for quiet hours") {
    InboxView().previewEnvironment(.previewPaired(inbox: PreviewData.quietHoursInbox))
}

#Preview("Inbox · dark") {
    InboxView()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Counter sheet") {
    CounterSheet(play: PreviewData.incomingPending).previewEnvironment()
}

#Preview("Counter sheet · none left") {
    CounterSheet(play: PreviewData.incomingPending).previewEnvironment(.previewPaired(hand: PreviewData.emptyHand))
}

#Preview("Text proof", traits: .sizeThatFitsLayout) {
    ProofView(play: PreviewData.pendingProofReview).padding()
}
#endif
