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
}

struct MugsyEmptyStateView: View {
    let asset: MugsyEmptyStateAsset
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(asset.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 118, height: 118)
                .accessibilityHidden(true)
                .shadow(color: Color.espressoBrown.opacity(0.08), radius: 10, x: 0, y: 5)

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
    }
}
