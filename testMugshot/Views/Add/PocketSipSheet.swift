import CoreTransferable
import PhotosUI
import SwiftUI

private struct PocketSipPickedPhoto: Transferable {
    let jpeg: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            Self(jpeg: try PocketSipPhoto.draftJPEG(at: received.file))
        }
    }
}

struct PocketSipSheet: View {
    let scope: LocalAccountScope
    let canSave: () -> Bool
    let onSaved: () -> Void
    let onOpen: (SipDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: [PhotosPickerItem] = []
    @State private var request = 0
    @State private var captureID = UUID()
    @State private var isSaving = false
    @State private var savedDraft: SipDraft?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: savedDraft == nil ? "photo.on.rectangle.angled" : "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                        .frame(width: 52, height: 52)
                        .background(Color.mugshotMint.opacity(0.42), in: .rect(cornerRadius: 15))
                        .accessibilityHidden(true)

                    Text(savedDraft == nil ? "Pocket Sip" : "Draft saved")
                        .mugshotDisplay(size: 34)
                        .foregroundStyle(Color.espressoBrown)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(savedDraft == nil ? "pocketSip.title" : "pocketSip.saved")

                    if let savedDraft {
                        let count = savedDraft.localPhotoNames.count
                        Text(count == 1 ? "1 photo is ready in your private draft."
                             : "\(count) photos are ready in your private draft.")
                            .font(.body)
                            .foregroundStyle(Color.secondaryText)
                        Button {
                            dismiss()
                            onOpen(savedDraft)
                        } label: {
                            Label("Open draft", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("pocketSip.open")
                    } else {
                        Text("Save the photos now. Add the details whenever you’re ready.")
                            .font(.body)
                            .foregroundStyle(Color.secondaryText)

                        if isSaving {
                            ProgressView("Saving your photos…")
                        } else {
                            PhotosPicker(
                                selection: $selection,
                                maxSelectionCount: PocketSipPhoto.maximumCount,
                                selectionBehavior: .ordered,
                                matching: .images,
                                preferredItemEncoding: .current
                            ) {
                                Label("Choose photos", systemImage: "photo.stack")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("pocketSip.choose")
                        }
                        if let message {
                            Label(message, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Color.espressoBrown)
                                .accessibilityIdentifier("pocketSip.error")
                            if !isSaving, !selection.isEmpty {
                                Button("Try again") { request += 1 }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.mugshotSageText)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color.creamWhite.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedDraft == nil ? "Cancel" : "Done") { dismiss() }
                        .accessibilityIdentifier("pocketSip.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: selection) { _, _ in
            captureID = UUID()
            request += 1
        }
        .task(id: request) { await saveSelection() }
    }

    @MainActor
    private func saveSelection() async {
        guard !selection.isEmpty, savedDraft == nil else { return }
        let items = selection
        let id = captureID
        isSaving = true
        message = nil
        defer {
            if id == captureID { isSaving = false }
        }
        do {
            var photos: [Data] = []
            for item in items {
                try Task.checkCancellation()
                guard let photo = try await item.loadTransferable(type: PocketSipPickedPhoto.self) else {
                    throw PocketSipCaptureError.unreadablePhoto
                }
                photos.append(photo.jpeg)
            }
            try Task.checkCancellation()
            guard id == captureID else { return }
            guard canSave() else { throw PocketSipCaptureError.accountChanged }
            let capture = PocketSipCapture(
                id: id, date: .now, owner: PocketSipOwner(userID: scope.userID), photos: photos
            )
            guard let saved = try SipDraftStore.shared.importPocketSip(capture, in: scope) else { return }
            savedDraft = saved
            onSaved()
            MugshotHaptic.success.play()
            UIAccessibility.post(notification: .announcement, argument: "Pocket Sip draft saved")
        } catch is CancellationError {
            return
        } catch {
            guard id == captureID else { return }
            message = (error as? PocketSipCaptureError)?.localizedDescription
                ?? "These photos couldn’t be saved. Try again to keep them in a draft."
        }
    }
}
