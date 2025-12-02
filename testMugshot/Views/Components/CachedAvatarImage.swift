//
//  CachedAvatarImage.swift
//  testMugshot
//
//  Reusable avatar renderer that prefers cached bitmaps to avoid flicker
//

import SwiftUI
import UIKit

struct CachedAvatarImage<Placeholder: View>: View {
    let image: UIImage?
    let imageId: String?
    let imageURL: String?
    let cacheNamespace: String
    let placeholder: () -> Placeholder
    
    @State private var displayedImage: UIImage?
    @State private var isLoading = false
    
    private var cacheIdentifier: String {
        "\(imageId ?? "nil")|\(imageURL ?? "nil")"
    }
    
    init(
        image: UIImage? = nil,
        imageId: String? = nil,
        imageURL: String? = nil,
        cacheNamespace: String = "avatar",
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.image = image
        self.imageId = imageId
        self.imageURL = imageURL
        self.cacheNamespace = cacheNamespace
        self.placeholder = placeholder
        
        if let provided = image {
            _displayedImage = State(initialValue: provided)
        } else if let id = imageId,
                  let cached = PhotoCache.shared.retrieve(forKey: id) {
            _displayedImage = State(initialValue: cached)
        } else if let urlString = imageURL {
            let cacheKey = CachedAvatarImage.cacheKey(for: urlString, namespace: cacheNamespace)
            let cached = PhotoCache.shared.retrieve(forKey: cacheKey)
            _displayedImage = State(initialValue: cached)
        } else {
            _displayedImage = State(initialValue: nil)
        }
    }
    
    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: cacheIdentifier) {
            await loadImageIfNeeded()
        }
    }
    
    @MainActor
    private func loadImageIfNeeded() async {
        if let provided = image {
            displayedImage = provided
            return
        }
        
        if let id = imageId,
           let cached = PhotoCache.shared.retrieve(forKey: id) {
            displayedImage = cached
            return
        }
        
        guard let urlString = imageURL,
              let url = URL(string: urlString) else {
            return
        }
        
        let cacheKey = CachedAvatarImage.cacheKey(for: urlString, namespace: cacheNamespace)
        
        if let cached = PhotoCache.shared.retrieve(forKey: cacheKey) {
            displayedImage = cached
            return
        }
        
        if isLoading { return }
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloaded = UIImage(data: data) else {
                isLoading = false
                return
            }
            
            PhotoCache.shared.store(downloaded, forKey: cacheKey)
            displayedImage = downloaded
        } catch {
            print("⚠️ [CachedAvatarImage] Failed to load avatar: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private static func cacheKey(for urlString: String, namespace: String) -> String {
        if let data = urlString.data(using: .utf8) {
            var encoded = data.base64EncodedString()
            encoded = encoded
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return "\(namespace)_\(encoded)"
        }
        
        let sanitized = urlString
            .replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression)
        return "\(namespace)_\(sanitized)"
    }
}


