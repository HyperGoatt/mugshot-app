//
//  ModernMasonryGrid.swift
//  testMugshot
//
//  2-column masonry grid for photos in Modern Cafe Detail
//

import SwiftUI

struct ModernMasonryGrid: View {
    let photos: [(visit: Visit, photoPath: String)]
    let dataManager: DataManager
    let onPhotoTap: (Int) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, item in
                Button(action: {
                    HapticsManager.shared.lightTap()
                    onPhotoTap(index)
                }) {
                    if let url = URL(string: item.visit.remoteURL(for: item.photoPath) ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(minHeight: 150, maxHeight: 250)
                                    .clipped()
                            default:
                                photoPlaceholder
                            }
                        }
                    } else {
                        photoPlaceholder
                    }
                }
                .cornerRadius(16)
                .buttonStyle(.plain)
            }
        }
    }
    
    private var photoPlaceholder: some View {
        Rectangle()
            .fill(DS.Colors.dynamicCardBackgroundAlt)
            .frame(minHeight: 150, maxHeight: 250)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            )
    }
}


