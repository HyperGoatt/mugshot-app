//
//  ModernParallaxHero.swift
//  testMugshot
//
//  Parallax hero image component for Modern Cafe Detail
//

import SwiftUI

struct ModernParallaxHero: View {
    let title: String
    let subtitle: String
    let imageURL: String?
    let scrollOffset: CGFloat
    
    private var parallaxOffset: CGFloat {
        scrollOffset > 0 ? -scrollOffset * 0.5 : 0
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image with parallax
            Group {
                if let imageURL = imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
            }
            .frame(height: 300 + max(0, scrollOffset))
            .clipped()
            .offset(y: parallaxOffset)
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    DS.Colors.dynamicBackground.opacity(0.8),
                    DS.Colors.dynamicBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            
            // Title overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 300)
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        DS.Colors.dynamicCardBackgroundAlt,
                        DS.Colors.dynamicBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}


