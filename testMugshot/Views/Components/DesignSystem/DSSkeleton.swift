//
//  DSSkeleton.swift
//  testMugshot
//
//  Skeleton loading views for consistent loading states
//

import SwiftUI

// MARK: - Base Skeleton Component

struct DSSkeleton: View {
    @State private var phase: CGFloat = 0
    var height: CGFloat = 20
    var cornerRadius: CGFloat = DS.Radius.md
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                DS.Colors.cardBackgroundAlt
                
                // Shimmer gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.3), location: 0.3),
                        .init(color: .white.opacity(0.5), location: 0.5),
                        .init(color: .white.opacity(0.3), location: 0.7),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.6)
                .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width * 0.3)
            }
        }
        .frame(height: height)
        .cornerRadius(cornerRadius)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - Card Skeleton

struct DSCardSkeleton: View {
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header with avatar and text
                HStack(spacing: DS.Spacing.md) {
                    // Avatar
                    DSSkeleton(height: 40, cornerRadius: 20)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        DSSkeleton(height: 14, cornerRadius: DS.Radius.sm)
                            .frame(width: 120)
                        DSSkeleton(height: 12, cornerRadius: DS.Radius.sm)
                            .frame(width: 80)
                    }
                    
                    Spacer()
                }
                
                // Image placeholder
                DSSkeleton(height: 200, cornerRadius: DS.Radius.card)
                
                // Content lines
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSkeleton(height: 16, cornerRadius: DS.Radius.sm)
                    DSSkeleton(height: 16, cornerRadius: DS.Radius.sm)
                        .frame(width: 200)
                }
                .padding(.top, DS.Spacing.sm)
            }
            .padding(DS.Spacing.cardPadding)
        }
    }
}

// MARK: - Feed Post Skeleton

struct DSFeedPostSkeleton: View {
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header with avatar and metadata
                HStack(spacing: DS.Spacing.md) {
                    // Avatar
                    DSSkeleton(height: 44, cornerRadius: 22)
                        .frame(width: 44)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        DSSkeleton(height: 16, cornerRadius: DS.Radius.sm)
                            .frame(width: 140)
                        DSSkeleton(height: 12, cornerRadius: DS.Radius.sm)
                            .frame(width: 100)
                    }
                    
                    Spacer()
                }
                
                // Image placeholder
                DSSkeleton(height: 300, cornerRadius: DS.Radius.card)
                
                // Caption lines
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSkeleton(height: 14, cornerRadius: DS.Radius.sm)
                    DSSkeleton(height: 14, cornerRadius: DS.Radius.sm)
                        .frame(width: 180)
                }
                .padding(.top, DS.Spacing.sm)
                
                // Action buttons
                HStack(spacing: DS.Spacing.lg) {
                    DSSkeleton(height: 20, cornerRadius: DS.Radius.sm)
                        .frame(width: 60)
                    DSSkeleton(height: 20, cornerRadius: DS.Radius.sm)
                        .frame(width: 60)
                    Spacer()
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(DS.Spacing.cardPadding)
        }
    }
}

