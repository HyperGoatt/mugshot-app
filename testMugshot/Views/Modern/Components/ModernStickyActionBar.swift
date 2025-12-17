//
//  ModernStickyActionBar.swift
//  testMugshot
//
//  Sticky action bar for Modern Cafe Detail with glass buttons
//

import SwiftUI

struct ModernStickyActionBar: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let onLogVisit: () -> Void
    let onToggleBookmark: () -> Void
    let onToggleFavorite: () -> Void
    
    private var currentCafe: Cafe {
        dataManager.getCafe(id: cafe.id) ?? cafe
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Primary "Log Visit" button
            Button(action: onLogVisit) {
                Text("Log Visit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.Colors.modernTextOnMint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.Colors.dynamicPrimaryAccent)
                    .cornerRadius(20)
                    .modernMintGlow()
            }
            
            // Bookmark button
            Button(action: onToggleBookmark) {
                Image(systemName: currentCafe.wantToTry ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(currentCafe.wantToTry ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicTextPrimary)
                    .frame(width: 50, height: 50)
                    .modernFloatingGlass(cornerRadius: 25)
            }
            
            // Favorite button
            Button(action: onToggleFavorite) {
                Image(systemName: currentCafe.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(currentCafe.isFavorite ? DS.Colors.redAccent : DS.Colors.dynamicTextPrimary)
                    .frame(width: 50, height: 50)
                    .modernFloatingGlass(cornerRadius: 25)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial
        )
        .background(DS.Colors.dynamicBackground.opacity(0.8))
    }
}


