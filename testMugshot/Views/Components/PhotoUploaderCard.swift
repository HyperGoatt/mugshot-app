//
//  PhotoUploaderCard.swift
//  testMugshot
//
//  Hero photo upload area with modern empty state and gallery view.
//

import SwiftUI

struct PhotoUploaderCard: View {
    let images: [UIImage]
    let posterIndex: Int
    let maxPhotos: Int
    let onAddTapped: () -> Void
    let onRemove: (Int) -> Void
    let onSetPoster: (Int) -> Void
    
    init(
        images: [UIImage],
        posterIndex: Int,
        maxPhotos: Int = 10,
        onAddTapped: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void,
        onSetPoster: @escaping (Int) -> Void
    ) {
        self.images = images
        self.posterIndex = posterIndex
        self.maxPhotos = maxPhotos
        self.onAddTapped = onAddTapped
        self.onRemove = onRemove
        self.onSetPoster = onSetPoster
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(DS.Colors.primaryAccent)
                        .font(.system(size: 16))
                    Text("Show us!")
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                Spacer()
                
                if images.isEmpty {
                    Text("Optional")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                } else {
                    Text("\(images.count) of \(maxPhotos)")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            
            if images.isEmpty {
                emptyState
            } else {
                thumbnailsRow
            }
        }
    }
    
    // MARK: - Empty State (Hero Design)
    
    private var emptyState: some View {
        Button(action: onAddTapped) {
            VStack(spacing: DS.Spacing.md) {
                // Large camera icon
                ZStack {
                    Circle()
                        .fill(DS.Colors.primaryAccentSoftFill)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(DS.Colors.primaryAccent)
                }
                
                VStack(spacing: DS.Spacing.xs) {
                    Text("Add Photos")
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text("Up to \(maxPhotos) • Auto-optimized")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(DS.Colors.cardBackgroundAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Thumbnails Row
    
    private var thumbnailsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(images.indices, id: \.self) { index in
                    PhotoThumbnail(
                        image: images[index],
                        isPoster: index == posterIndex,
                        onTap: { onSetPoster(index) },
                        onRemove: { onRemove(index) }
                    )
                }
                
                // Add more button
                if images.count < maxPhotos {
                    Button(action: onAddTapped) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(DS.Colors.cardBackgroundAlt)
                                .frame(width: 120, height: 120)
                            
                            VStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(DS.Colors.iconSubtle)
                                
                                Text("Add")
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textTertiary)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnail: View {
    let image: UIImage
    let isPoster: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .onTapGesture(perform: onTap)
            
            // Cover badge
            if isPoster {
                Text("Cover")
                    .font(DS.Typography.caption2(.semibold))
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.xs)
                    .padding(DS.Spacing.xs)
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DS.Colors.negativeChange, DS.Colors.cardBackground)
            }
            .offset(x: 8, y: -8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(isPoster ? DS.Colors.primaryAccent : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
