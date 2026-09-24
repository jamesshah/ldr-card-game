import PhotosUI
import SwiftUI
import UIKit

struct CompleteProofSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let play: Play

    @State private var proofType: ProofType = .photo
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var loadingPhoto = false
    @StateObject private var recorder = VoiceRecorder()

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        guard !store.isWorking else { return false }
        switch proofType {
        case .text: return !trimmedNote.isEmpty
        case .photo: return photoData != nil
        case .audio: return recorder.recordingURL != nil && !recorder.isRecording
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardFace(play: play)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Proof", selection: $proofType) {
                        Text("Photo").tag(ProofType.photo)
                        Text("Voice note").tag(ProofType.audio)
                        Text("Note").tag(ProofType.text)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("\(play.fromName) reviews your proof and marks the card complete.")
                }

                switch proofType {
                case .photo: photoSection
                case .audio: audioSection
                case .text: EmptyView()
                }

                Section(proofType == .text ? "Your note" : "Add a caption (optional)") {
                    TextField(proofType == .text ? "Tell them how it went" : "Caption", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Complete card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.discard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if store.isWorking {
                        ProgressView()
                    } else {
                        Button("Send") { Task { await submit() } }
                            .disabled(!canSubmit)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .errorAlert($recorder.errorMessage)
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoData == nil ? "Choose a photo" : "Choose a different photo", systemImage: "photo.on.rectangle")
            }
            if loadingPhoto {
                ProgressView()
            } else if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var audioSection: some View {
        Section("Voice note") {
            HStack {
                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        Task { await recorder.start() }
                    }
                } label: {
                    Label(recorder.isRecording ? "Stop" : (recorder.recordingURL == nil ? "Record" : "Record again"),
                          systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.headline)
                }
                .tint(recorder.isRecording ? .red : Theme.rose)
                Spacer()
                Text(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .minuteSecond)))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if recorder.recordingURL != nil && !recorder.isRecording {
                Label("Voice note ready to send", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text("Up to \(Int(VoiceRecorder.maxDuration)) seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loadingPhoto = true
        defer { loadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            store.errorMessage = "That photo couldn't be loaded. Try another one."
            return
        }
        photoData = Self.downscaledJPEG(image) ?? data
    }

    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1600) -> Data? {
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maxDimension ? maxDimension / largest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func submit() async {
        let caption = trimmedNote.isEmpty ? nil : trimmedNote
        var ok = false
        switch proofType {
        case .text:
            ok = await store.completeWithText(play, text: trimmedNote)
        case .photo:
            guard let photoData else { return }
            ok = await store.completeWithFile(play, type: .photo, data: photoData, contentType: "image/jpeg", caption: caption)
        case .audio:
            guard let url = recorder.recordingURL, let data = try? Data(contentsOf: url) else { return }
            ok = await store.completeWithFile(play, type: .audio, data: data, contentType: "audio/mp4", caption: caption)
            if ok { recorder.discard() }
        }
        if ok { dismiss() }
    }
}
