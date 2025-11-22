//
//  MugshotImageCarousel.swift
//  testMugshot
//
//  Reusable carousel for displaying up to 10 photo paths with Mugshot styling.
//

import SwiftUI

struct MugshotImageCarousel: View {
    private let photoPaths: [String]
    private let remotePhotoURLs: [String: String]
    private let height: CGFloat
    private let cornerRadius: CGFloat
    private let showIndicators: Bool
    
    @State private var currentIndex: Int = 0
    
    init(
        photoPaths: [String],
        remotePhotoURLs: [String: String] = [:],
        height: CGFloat = 280,
        cornerRadius: CGFloat = DS.Radius.card,
        showIndicators: Bool = true
    ) {
        // Limit to 10 images for performance + UX
        let trimmed = Array(photoPaths.prefix(10))
        self.photoPaths = trimmed
        var filteredRemote: [String: String] = [:]
        for key in trimmed {
            if let value = remotePhotoURLs[key] {
                filteredRemote[key] = value
            }
        }
        self.remotePhotoURLs = filteredRemote
        self.height = height
        self.cornerRadius = cornerRadius
        self.showIndicators = showIndicators
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if photoPaths.isEmpty {
                placeholder
            } else {
                carousel
                
                if showIndicators && photoPaths.count > 1 {
                    indicators
                }
            }
        }
    }
    
    private var carousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(photoPaths.enumerated()), id: \.offset) { index, path in
                PhotoImageView(photoPath: path, remoteURL: remotePhotoURLs[path])
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(DS.Colors.cardBackgroundAlt)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .tag(index)
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentIndex)
        .onChange(of: photoPaths.count) { _, newCount in
            currentIndex = min(currentIndex, max(0, newCount - 1))
        }
    }
    
    private var indicators: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(photoPaths.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? DS.Colors.primaryAccent : DS.Colors.iconSubtle.opacity(0.35))
                    .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                    .animation(.easeInOut(duration: 0.15), value: currentIndex)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.Colors.cardBackgroundAlt)
            .frame(height: height)
            .overlay(
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(DS.Colors.iconSubtle)
                    Text("No photos yet")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            )
    }
}

