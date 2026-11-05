import SwiftUI

/// A confirmed post has one result destination; controls never wait for motion.
struct MugshotPostedResultView: View {
    let receipt: MugshotSaveReceipt
    let contextName: String
    let isOpening: Bool
    let statusMessage: String?
    let onShare: () -> Void
    let onSeePost: () -> Void
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("MUGSHOT").font(.caption.weight(.bold)).tracking(3)
                            .foregroundStyle(Color.mugshotSageText)
                            .dynamicTypeSize(.medium).accessibilityHidden(true)
                        Spacer()
                        Button(action: onDone) {
                            Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(Color.foamWhite, in: Circle())
                        }
                        .accessibilityLabel("Done")
                        .accessibilityIdentifier("mugshot.posted.done")
                    }
                    Spacer(minLength: 12)
                    MugshotSaveReceiptView(receipt: receipt,
                        detail: typeSize.isAccessibilitySize ? contextName : "A little moment from \(contextName).", isCelebration: true)
                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 24).padding(.vertical, 16)
                .frame(minHeight: geometry.size.height)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(typeSize.isAccessibilitySize ? "mugshot.posted.layout.accessibility" : "mugshot.posted.fullScreen")
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                if let statusMessage {
                    Text(statusMessage).font(.subheadline).foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("mugshot.posted.share")
                Button(action: onSeePost) {
                    HStack(spacing: 10) {
                        if isOpening { ProgressView() }
                        Text(isOpening ? "Opening post…" : "See post")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isOpening)
                .accessibilityIdentifier("mugshot.posted.seePost")
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(Color.creamWhite)
        }
        .background(Color.creamWhite.ignoresSafeArea())
        .foregroundStyle(Color.espressoBrown)
    }
}
