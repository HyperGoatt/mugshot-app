//
//  PhotoUploaderCard.swift
//  testMugshot
//
//  Reusable card for adding and managing visit photos.
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
        FormSectionCard(title: "Photos") {
            if images.isEmpty {
                emptyState
            } else {
                thumbnailsRow
            }
        }
    }
    
    private var emptyState: some View {
        Button(action: onAddTapped) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "camera")
                    .font(.system(size: 32))
                    .foregroundColor(DS.Colors.iconSubtle)
                
                Text("Tap to add photos (\(images.count)/\(maxPhotos))")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
                
                Text("Photos will be compressed automatically.")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.section)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(DS.Colors.borderSubtle)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var thumbnailsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(images.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .onTapGesture {
                                onSetPoster(index)
                            }
                        
                        if index == posterIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DS.Colors.primaryAccent)
                                .background(DS.Colors.cardBackground)
                                .clipShape(Circle())
                                .padding(4)
                        }
                        
                        Button(action: { onRemove(index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DS.Colors.negativeChange)
                                .background(DS.Colors.cardBackground)
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                
                if images.count < maxPhotos {
                    Button(action: onAddTapped) {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.Colors.cardBackgroundAlt)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(DS.Colors.iconSubtle)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


