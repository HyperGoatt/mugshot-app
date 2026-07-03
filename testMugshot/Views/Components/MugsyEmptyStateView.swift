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
        VStack(spacing: 12) {
            Image(asset.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.espressoBrown.opacity(0.64))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
    }
}
