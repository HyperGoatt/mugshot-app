//
//  PhotoImageView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

// Reusable view for displaying photos from Visit photo paths
struct PhotoImageView: View {
    let photoPath: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .fill(Color.sandBeige)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.espressoBrown.opacity(0.3))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        if let cachedImage = PhotoCache.shared.retrieve(forKey: photoPath) {
            image = cachedImage
        }
    }
}

// Thumbnail version for small previews
struct PhotoThumbnailView: View {
    let photoPath: String?
    let size: CGFloat
    
    @State private var image: UIImage?
    
    init(photoPath: String?, size: CGFloat = 60) {
        self.photoPath = photoPath
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                    .fill(Color.sandBeige)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.espressoBrown.opacity(0.3))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let photoPath = photoPath else { return }
        if let cachedImage = PhotoCache.shared.retrieve(forKey: photoPath) {
            image = cachedImage
        }
    }
}

