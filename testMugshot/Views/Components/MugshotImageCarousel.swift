//
//  MugshotImageCarousel.swift
//  testMugshot
//
//  Reusable carousel for displaying up to 10 photo paths with Mugshot styling.
//  Updated with indicators inside the image and gradient overlay.
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
        height: CGFloat = 320,
        cornerRadius: CGFloat = DS.Radius.lg,
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
        if photoPaths.isEmpty {
            placeholder
        } else {
            ZStack(alignment: .bottom) {
                carousel
                
                // Indicators inside image with gradient backdrop
                if showIndicators && photoPaths.count > 1 {
                    indicatorsOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    private var carousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(photoPaths.enumerated()), id: \.offset) { index, path in
                PhotoImageView(photoPath: path, remoteURL: remotePhotoURLs[path])
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(DS.Colors.cardBackgroundAlt)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentIndex)
        .onChange(of: photoPaths.count) { _, newCount in
            currentIndex = min(currentIndex, max(0, newCount - 1))
        }
    }
    
    private var indicatorsOverlay: some View {
        VStack {
            Spacer()
            
            // Gradient backdrop for indicators
            ZStack(alignment: .bottom) {
                // Subtle gradient fade
                LinearGradient(
                    colors: [.clear, .black.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                
                // Indicators
                HStack(spacing: 6) {
                    ForEach(photoPaths.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(
                                width: index == currentIndex ? 8 : 6,
                                height: index == currentIndex ? 8 : 6
                            )
                            .animation(.easeInOut(duration: 0.15), value: currentIndex)
                    }
                }
                .padding(.bottom, 12)
            }
        }
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
