//
//  MugsyEmptyStateView.swift
//  testMugshot
//

import SwiftUI

enum MugsyEmptyStateAsset: String {
    case noFavorites = "MugsyNoFavorites"
    case noWishlist = "MugsyNoWishlist"
    case noCafes = "MugsyNoCafes"
    case noFriends = "MugsyNoFriends"
    case comingSoon = "MugsyComingSoon"

    var placement: MugsyPlacement {
        switch self {
        case .noFavorites: return .savedFavorites
        case .noWishlist: return .savedWishlist
        case .noCafes: return .savedCafes
        case .noFriends: return .friendsEmpty
        case .comingSoon: return .comingSoon
        }
    }
}

struct MugsyEmptyStateView: View {
    let placement: MugsyPlacement
    let title: String
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @State private var gaze: UnitPoint = .center
    @State private var action: MugsyActionState = .resting

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    init(placement: MugsyPlacement, title: String, message: String) {
        self.placement = placement
        self.title = title
        self.message = message
    }

    /// Transitional initializer for callsites that still name an immutable
    /// reference asset. Rendering always uses the canonical layered model.
    init(asset: MugsyEmptyStateAsset, title: String, message: String) {
        self.init(placement: asset.placement, title: title, message: message)
    }

    private var configuration: MugsyModelConfiguration {
        var configuration = placement.configuration
        configuration.gaze = gaze
        return configuration
    }

    var body: some View {
        VStack(spacing: 14) {
            MugsyAnimatedView(
                configuration: configuration,
                action: action,
                tapBehavior: placement.tapBehavior
            )
                .frame(width: 132, height: 146)
                .accessibilityHidden(true)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard !effectiveReduceMotion else { return }
                            gaze = UnitPoint(
                                x: (value.location.x / 132).mugshotClamped(to: 0...1),
                                y: (value.location.y / 146).mugshotClamped(to: 0...1)
                            )
                            action = .focusing
                        }
                        .onEnded { _ in settle() }
                )

            Text(title)
                .mugshotDisplay(size: 22)
                .foregroundColor(.espressoBrown)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .shadow(
            color: DesignSystem.cardShadow.color,
            radius: DesignSystem.cardShadow.radius,
            x: DesignSystem.cardShadow.x,
            y: DesignSystem.cardShadow.y
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }

    private func settle() {
        withAnimation(MugshotMotion.animation(MugshotMotion.settle, reduceMotion: effectiveReduceMotion)) {
            action = .resting
            gaze = .center
        }
    }
}

#Preview("Canonical Mugsy") {
    ScrollView {
        VStack(spacing: 18) {
            MugsyEmptyStateView(
                placement: .savedFavorites,
                title: "Favorites are waiting",
                message: "Save the sips and cafes you want to keep close."
            )
            MugsyEmptyStateView(
                placement: .savedWishlist,
                title: "No want-to-try cafes yet",
                message: "Mark cafes whenever they catch your curiosity."
            )
        }
        .padding()
    }
    .background(Color.creamWhite)
    .environment(\.mugshotReduceMotionOverride, true)
}
