//
//  PostcardRenderer.swift
//  testMugshot
//
//  Utility for rendering SwiftUI views to UIImage for sharing.
//  Uses iOS 16+ ImageRenderer for high-quality output.
//

import SwiftUI
import UIKit

/// Service for rendering SwiftUI views to UIImage
@MainActor
struct PostcardRenderer {
    
    /// Standard Instagram Stories size (9:16 aspect ratio)
    nonisolated static let storiesSize = CGSize(width: 1080, height: 1920)
    
    /// Renders a SwiftUI view to a UIImage at the specified size
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: The target size in points (will be scaled for screen density)
    /// - Returns: A UIImage of the rendered view, or nil if rendering fails
    static func render<V: View>(_ view: V, size: CGSize = PostcardRenderer.storiesSize) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        
        // Set scale for high-resolution output
        renderer.scale = 1.0 // Use 1.0 for exact pixel dimensions
        
        // Render to UIImage
        return renderer.uiImage
    }
    
    /// Renders a postcard view with visit data
    /// - Parameters:
    ///   - data: The postcard data containing visit information
    ///   - visitPhoto: Optional photo from the visit
    ///   - variant: Light or dark variant
    /// - Returns: A UIImage of the rendered postcard
    static func renderPostcard(
        data: PostcardData,
        visitPhoto: UIImage?,
        variant: MugshotPostcardView.PostcardVariant = .light
    ) -> UIImage? {
        let postcardView = MugshotPostcardView(
            data: data,
            visitPhoto: visitPhoto,
            variant: variant
        )
        
        return render(postcardView, size: storiesSize)
    }
    
    /// Renders a postcard asynchronously (for large images)
    /// - Parameters:
    ///   - data: The postcard data
    ///   - visitPhoto: Optional visit photo
    ///   - variant: Light or dark variant
    ///   - completion: Callback with the rendered image
    static func renderPostcardAsync(
        data: PostcardData,
        visitPhoto: UIImage?,
        variant: MugshotPostcardView.PostcardVariant = .light,
        completion: @escaping (UIImage?) -> Void
    ) {
        Task { @MainActor in
            let image = renderPostcard(data: data, visitPhoto: visitPhoto, variant: variant)
            completion(image)
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Renders this view to a UIImage
    @MainActor
    func renderToImage(size: CGSize) -> UIImage? {
        PostcardRenderer.render(self, size: size)
    }
}

