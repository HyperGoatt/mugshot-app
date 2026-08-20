import SwiftUI
import UIKit

struct MugshotPassportStats: Equatable {
    let sips: Int
    let cafes: Int
    let homeSips: Int
    let averageRating: Double?
}

/// A compact, interactive tasting business card. The title is deterministic
/// from three evidence-backed descriptors, so it can evolve without becoming
/// a manually selected badge.
struct MugshotPassportCard: View {
    let displayName: String
    let username: String
    let avatarURL: String?
    let bannerURL: String?
    let identity: TasteIdentitySummary
    let stats: MugshotPassportStats
    var allowsSharing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsStats = false
    @State private var ornamentIsAlive = false
    @State private var shareItems: MugshotPassportShareItems?

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                    showsStats.toggle()
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                passportSurface
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Taste Passport, \(identity.title)")
            .accessibilityHint(showsStats ? "Shows tasting identity. Double tap to return" : "Shows passport statistics. Double tap to open")

            HStack(spacing: 10) {
                Label(showsStats ? "Tap for identity" : "Tap for passport stats", systemImage: "hand.tap.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Spacer()
                if allowsSharing, !identity.isForming {
                    Button {
                        createShareItems()
                    } label: {
                        Label("Share passport", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.mugshotSage)
                }
            }
        }
        .sheet(item: $shareItems) { payload in
            MugshotPassportActivitySheet(items: payload.items)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                ornamentIsAlive = true
            }
        }
    }

    private var passportSurface: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                MugshotProfileBanner(imageURL: bannerURL, height: 154)

                LinearGradient(
                    colors: [.clear, Color.espressoBrown.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    MugshotAvatar(name: displayName, size: 66, imageURL: avatarURL)
                        .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.foamWhite)
                        Text("@\(username)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.foamWhite.opacity(0.82))
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .rotationEffect(.degrees(ornamentIsAlive ? 8 : -8))
                        .scaleEffect(ornamentIsAlive ? 1.08 : 0.94)
                }
                .padding(16)
            }

            Group {
                if showsStats {
                    statsContent
                        .transition(.opacity)
                } else {
                    identityContent
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .padding(18)
            .background(Color.foamWhite)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .shadow(color: Color.espressoBrown.opacity(0.10), radius: 18, x: 0, y: 10)
    }

    private var identityContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MUGSHOT PASSPORT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(.mugshotSage)
            Text(identity.title)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
            descriptorChips
            Text(identity.description)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR SIPPING JOURNEY")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.3)
                .foregroundColor(.mugshotSage)
            HStack(spacing: 8) {
                passportStat("Sips", value: "\(stats.sips)")
                passportStat("Cafes", value: "\(stats.cafes)")
                passportStat("Home", value: "\(stats.homeSips)")
                passportStat(
                    "Sip average",
                    value: stats.averageRating.map { String(format: "%.1f", $0) } ?? "—"
                )
            }
            descriptorChips
            Text("This card summarizes memories and taste—not consumption rank or status.")
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
        }
    }

    private var descriptorChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(identity.descriptors, id: \.self) { descriptor in
                    Text(descriptor)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.mugshotMint.opacity(0.46), in: Capsule())
                }
            }
        }
    }

    private func passportStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.espressoBrown)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.sandBeige.opacity(0.52), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    @MainActor
    private func createShareItems() {
        let artwork = passportSurface
            .frame(width: 540)
            .padding(28)
            .background(Color.creamWhite)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 2
        let text = "\(displayName)’s Taste Passport — \(identity.title) · \(identity.descriptors.joined(separator: " · "))"
        if let image = renderer.uiImage {
            shareItems = MugshotPassportShareItems(items: [image, text])
        } else {
            shareItems = MugshotPassportShareItems(items: [text])
        }
    }
}

private struct MugshotPassportShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct MugshotPassportActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
