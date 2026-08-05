import SwiftUI

enum MugsyPhotoPlaceholderStyle: Equatable {
    case thumbnail
    case identity
    case card
    case poster
    case hero

    var showsCopy: Bool {
        switch self {
        case .poster, .hero: return true
        case .thumbnail, .identity, .card: return false
        }
    }

    var allowsAnimation: Bool { self == .hero }
}

/// A truthful photo-empty surface. Callers render this only when media is
/// genuinely absent; loading, download failure, privacy, and removed media use
/// their own states. Small instances stay static so lists never animate a wall
/// of characters, while a single hero may opt into the Studio motion model.
struct MugsyPhotoPlaceholderView: View {
    let scene: MugsyScene
    let style: MugsyPhotoPlaceholderStyle
    let photoDescription: String
    var animatesProminentMugsy = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let modelSize = resolvedModelSize(shortSide: shortSide)

            ZStack {
                backdrop

                if style.showsCopy {
                    VStack(spacing: style == .hero ? 7 : 5) {
                        mugsy(size: modelSize)

                        Text(photoTitle)
                            .font(.system(
                                size: style == .hero ? 15 : 13,
                                weight: .semibold,
                                design: style == .hero ? .serif : .default
                            ))
                            .foregroundStyle(Color.espressoBrown)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if style == .hero {
                            Text(photoMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                } else {
                    mugsy(size: modelSize)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(photoDescription). \(scene.accessibilityLabel)")
    }

    @ViewBuilder
    private func mugsy(size: CGFloat) -> some View {
        if animatesProminentMugsy, style.allowsAnimation, !effectiveReduceMotion {
            MugsyAnimatedView(
                configuration: scene.configuration,
                tapBehavior: scene.family.tapBehavior
            )
            .frame(width: size, height: size)
        } else {
            MugsyModelView(configuration: scene.configuration)
                .frame(width: size, height: size)
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.sandBeige.opacity(style == .hero ? 0.66 : 0.72)

            Circle()
                .fill(Color.mugshotMint.opacity(style == .hero ? 0.30 : 0.22))
                .frame(
                    width: style == .hero ? 180 : 96,
                    height: style == .hero ? 180 : 96
                )
                .offset(
                    x: style == .hero ? 112 : 30,
                    y: style == .hero ? -58 : -26
                )
                .accessibilityHidden(true)
        }
    }

    private func resolvedModelSize(shortSide: CGFloat) -> CGFloat {
        switch style {
        case .thumbnail:
            return max(34, shortSide * 0.76)
        case .identity:
            return max(42, shortSide * 0.82)
        case .card:
            return max(54, shortSide * 0.76)
        case .poster:
            return min(94, max(56, shortSide * 0.38))
        case .hero:
            return min(122, max(82, shortSide * 0.52))
        }
    }

    private var photoTitle: String {
        switch scene.family {
        case .cheerfulCafeScout:
            return "No cafe photo yet"
        case .delightedWishlistHolder:
            return "Saved for a future sip"
        case .happyHeartKeeper:
            return "A favorite, photo pending"
        case .proudCameraCompanion:
            return "Your next Mugshot can lead"
        case .joyfulJournalKeeper:
            return "This memory has no photo"
        case .welcomingFriendsPhone:
            return "No shared photo yet"
        case .cozyCoffeeRitual:
            return "The taste memory is still here"
        case .excitedFirstSipCelebration:
            return "You tried it"
        case .happyBuilder:
            return "This cafe is taking shape"
        case .playfulWavingMugsy:
            return "No photo yet"
        }
    }

    private var photoMessage: String {
        switch scene.family {
        case .delightedWishlistHolder:
            return "Mugsy is keeping the spot ready for your first visit."
        case .happyHeartKeeper:
            return "An authorized Mugshot can become this cafe's photo."
        case .proudCameraCompanion:
            return "A future authorized Mugshot can fill this spot."
        case .welcomingFriendsPhone:
            return "Only permitted Mugshots appear here."
        case .joyfulJournalKeeper, .cozyCoffeeRitual:
            return "Your notes and ratings still keep the story useful."
        case .excitedFirstSipCelebration:
            return "Want to Try is cleared, and the memory is yours."
        case .happyBuilder:
            return "An authorized Mugshot can add the first cafe photo."
        case .cheerfulCafeScout, .playfulWavingMugsy:
            return "An authorized Mugshot can add the first photo."
        }
    }
}

#Preview("Dynamic cafe photo placeholders") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(MugsySceneFamily.allCases) { family in
                MugsyPhotoPlaceholderView(
                    scene: MugsyScene(family: family, variant: 0),
                    style: .hero,
                    photoDescription: "No cafe photo yet"
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding()
    }
    .background(Color.creamWhite)
    .environment(\.mugshotReduceMotionOverride, true)
}
