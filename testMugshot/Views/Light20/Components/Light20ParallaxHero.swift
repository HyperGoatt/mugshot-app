//
//  Light20ParallaxHero.swift
//  testMugshot
//
//  Light 2.0 parallax hero header
//  Smooth parallax effect with avatar overlay
//

import SwiftUI

struct Light20ParallaxHero: View {
    let imageURL: String?
    let avatarURL: String?
    let scrollOffset: CGFloat
    
    private let parallaxMultiplier: CGFloat = 0.5
    private let heroHeight: CGFloat = 250
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Banner image with parallax
            if let imageURL = imageURL, !imageURL.isEmpty {
                CachedImageView(url: imageURL)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: heroHeight + max(0, scrollOffset))
                    .clipped()
                    .offset(y: -scrollOffset * parallaxMultiplier)
            } else {
                // Default gradient background
                LinearGradient(
                    colors: [DS.Colors.light20MintPrimary, DS.Colors.light20MintPrimary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: heroHeight + max(0, scrollOffset))
                .offset(y: -scrollOffset * parallaxMultiplier)
            }
            
            // Avatar overlay
            if let avatarURL = avatarURL {
                CachedAvatarImage(
                    imageURL: avatarURL,
                    cacheNamespace: "profile-avatar"
                ) {
                    avatarPlaceholder
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DS.Colors.light20Background, lineWidth: 4)
                )
                .offset(y: 50)
            } else {
                avatarPlaceholder
                    .offset(y: 50)
            }
        }
        .frame(height: heroHeight)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.light20Surface)
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.light20IconInactive)
            )
            .overlay(
                Circle()
                    .stroke(DS.Colors.light20Background, lineWidth: 4)
            )
    }
}

// Placeholder for CachedImageView if not already defined
struct CachedImageView: View {
    let url: String
    
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
            case .failure, .empty:
                Rectangle()
                    .fill(DS.Colors.light20Surface)
            @unknown default:
                Rectangle()
                    .fill(DS.Colors.light20Surface)
            }
        }
    }
}


