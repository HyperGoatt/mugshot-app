import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PocketSipShareView: View {
    let providers: [NSItemProvider]
    let onClose: () -> Void

    @State private var captureID = UUID()
    @State private var session: PocketSipShareSession?
    @State private var images: [Data] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saved = false
    @State private var message: String?
    @State private var reload = 0

    private let espresso = Color(red: 0.22, green: 0.15, blue: 0.11)
    private let sage = Color(red: 0.23, green: 0.36, blue: 0.27)

    /// A share containing a true web URL belongs to the existing place flow,
    /// even when the provider supplies a link preview image.
    static func photoProviders(in items: [Any]) -> [NSItemProvider]? {
        let providers = items.compactMap { $0 as? NSExtensionItem }.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty,
              !providers.contains(where: { $0.registeredTypeIdentifiers.contains(UTType.url.identifier) }),
              providers.allSatisfy({ $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else { return nil }
        return providers
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Label("Mugshot", systemImage: "cup.and.saucer.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sage)
                    Spacer()
                    Button(saved ? "Done" : "Cancel", action: onClose)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sage)
                        .frame(minHeight: 44)
                        .disabled(isSaving)
                }
                Text(saved ? "Draft saved" : "Pocket Sip")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .foregroundStyle(espresso)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(saved ? "pocketSip.share.saved" : "pocketSip.share.title")

                if saved {
                    Label("Open Mugshot and tap Your drafts in Add to finish your sip.", systemImage: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(sage)
                } else {
                    Text("Keep these photos in a private draft to finish in Mugshot.")
                        .font(.subheadline)
                        .foregroundStyle(espresso)

                    if isLoading {
                        ProgressView("Preparing photos…")
                    } else if !images.isEmpty {
                        previews
                    }

                    if let message {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(espresso)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pocketSip.share.error")
                    }

                    if !images.isEmpty {
                        Button(action: save) {
                            Label("Save draft", systemImage: "lock")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundStyle(.white)
                                .background(sage, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .font(.body.weight(.semibold))
                        .disabled(isSaving)
                        .accessibilityIdentifier("pocketSip.share.save")
                    } else if !isLoading, session != nil {
                        Button("Try again") { reload += 1 }
                            .foregroundStyle(sage)
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 250 / 255, green: 246 / 255, blue: 240 / 255).ignoresSafeArea())
        .preferredColorScheme(.light)
        .task(id: reload) { await prepare() }
    }

    private var previews: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    if let image = PocketSipPhoto.preview(from: images[index]) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 63, height: 63)
                            .clipped()
                            .clipShape(.rect(cornerRadius: 10))
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("\(images.count) selected photos")
    }

    @MainActor
    private func prepare() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            guard let current = PocketSipInbox.shared?.activeSession() else {
                throw PocketSipCaptureError.inboxUnavailable
            }
            if let session, session != current { throw PocketSipCaptureError.accountChanged }
            session = current
            guard (1...PocketSipPhoto.maximumCount).contains(providers.count) else {
                throw PocketSipCaptureError.invalidSelection
            }
            var selected: [Data] = []
            for provider in providers {
                try Task.checkCancellation()
                selected.append(try await loadPhoto(provider))
            }
            try Task.checkCancellation()
            images = selected
        } catch is CancellationError {
            return
        } catch {
            message = (error as? PocketSipCaptureError)?.localizedDescription
                ?? PocketSipCaptureError.unreadablePhoto.localizedDescription
        }
    }

    private func loadPhoto(_ provider: NSItemProvider) async throws -> Data {
        guard let type = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) else { throw PocketSipCaptureError.unreadablePhoto }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                guard let url else {
                    continuation.resume(throwing: PocketSipCaptureError.unreadablePhoto)
                    return
                }
                continuation.resume(with: Result { try PocketSipPhoto.draftJPEG(at: url) })
            }
        }
    }

    @MainActor
    private func save() {
        guard let session, let inbox = PocketSipInbox.shared, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let capture = PocketSipCapture(id: captureID, date: .now, owner: session.owner, photos: images)
            try inbox.enqueue(capture, for: session)
            saved = true
            message = nil
            images = []
            UIAccessibility.post(notification: .announcement, argument: "Pocket Sip draft saved")
        } catch {
            message = (error as? PocketSipCaptureError)?.localizedDescription
                ?? "These photos couldn’t be saved. Keep this sheet open and try again."
        }
    }
}
