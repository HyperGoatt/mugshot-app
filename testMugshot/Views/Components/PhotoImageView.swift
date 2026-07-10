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
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(Color.sandBeige.opacity(0.72))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .semibold))
                            Text("Legacy sip")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.roastBrown.opacity(0.46))
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
                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                    .fill(Color.sandBeige.opacity(0.72))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.roastBrown.opacity(0.42))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
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
