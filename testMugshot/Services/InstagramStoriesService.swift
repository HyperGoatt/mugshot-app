//
//  InstagramStoriesService.swift
//  testMugshot
//
//  Handles sharing images to Instagram Stories using the URL scheme API.
//  Documentation: https://developers.facebook.com/docs/instagram/sharing-to-stories
//

import UIKit
import UniformTypeIdentifiers

/// Service for sharing content to Instagram Stories
struct InstagramStoriesService {
    
    /// Facebook App ID for Instagram Stories sharing
    /// Note: Replace with your actual Facebook App ID if you have one registered
    private static let facebookAppID = "YOUR_FACEBOOK_APP_ID"
    
    /// Checks if Instagram is installed on the device
    static var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Shares an image to Instagram Stories as a background
    /// - Parameters:
    ///   - image: The image to share as the story background
    ///   - completion: Callback indicating success or failure with optional error message
    static func shareToStories(
        image: UIImage,
        completion: @escaping (Result<Void, InstagramError>) -> Void
    ) {
        guard isInstagramInstalled else {
            completion(.failure(.notInstalled))
            return
        }
        
        guard let imageData = image.pngData() else {
            completion(.failure(.imageEncodingFailed))
            return
        }
        
        // Prepare pasteboard items
        let pasteboardItems: [[String: Any]] = [
            [
                "com.instagram.sharedSticker.backgroundImage": imageData
            ]
        ]
        
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // 5 minutes expiration
        ]
        
        // Set pasteboard
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        
        // Open Instagram Stories
        guard let url = URL(string: "instagram-stories://share?source_application=\(facebookAppID)") else {
            completion(.failure(.urlCreationFailed))
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(.openFailed))
            }
        }
    }
    
    /// Shares an image to Instagram Stories with a sticker overlay
    /// - Parameters:
    ///   - backgroundImage: The background image for the story
    ///   - stickerImage: Optional sticker image to overlay
    ///   - topBackgroundColor: Optional top gradient color (hex string)
    ///   - bottomBackgroundColor: Optional bottom gradient color (hex string)
    ///   - completion: Callback indicating success or failure
    static func shareToStoriesWithSticker(
        backgroundImage: UIImage?,
        stickerImage: UIImage?,
        topBackgroundColor: String? = nil,
        bottomBackgroundColor: String? = nil,
        completion: @escaping (Result<Void, InstagramError>) -> Void
    ) {
        guard isInstagramInstalled else {
            completion(.failure(.notInstalled))
            return
        }
        
        var pasteboardItems: [String: Any] = [:]
        
        // Add background image
        if let bgImage = backgroundImage, let bgData = bgImage.pngData() {
            pasteboardItems["com.instagram.sharedSticker.backgroundImage"] = bgData
        }
        
        // Add sticker image
        if let sticker = stickerImage, let stickerData = sticker.pngData() {
            pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerData
        }
        
        // Add background colors (for gradient when no image)
        if let topColor = topBackgroundColor {
            pasteboardItems["com.instagram.sharedSticker.backgroundTopColor"] = topColor
        }
        if let bottomColor = bottomBackgroundColor {
            pasteboardItems["com.instagram.sharedSticker.backgroundBottomColor"] = bottomColor
        }
        
        guard !pasteboardItems.isEmpty else {
            completion(.failure(.noContentToShare))
            return
        }
        
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        
        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)
        
        guard let url = URL(string: "instagram-stories://share?source_application=\(facebookAppID)") else {
            completion(.failure(.urlCreationFailed))
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(.openFailed))
            }
        }
    }
    
    // MARK: - Error Types
    
    enum InstagramError: LocalizedError {
        case notInstalled
        case imageEncodingFailed
        case urlCreationFailed
        case openFailed
        case noContentToShare
        
        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Instagram is not installed on your device."
            case .imageEncodingFailed:
                return "Failed to encode image for sharing."
            case .urlCreationFailed:
                return "Failed to create Instagram URL."
            case .openFailed:
                return "Failed to open Instagram."
            case .noContentToShare:
                return "No content to share."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .notInstalled:
                return "Please install Instagram from the App Store to share stories."
            default:
                return "Please try again."
            }
        }
    }
}

// MARK: - URL Scheme Configuration Reminder
/*
 To enable Instagram sharing, add the following to your Info.plist:
 
 <key>LSApplicationQueriesSchemes</key>
 <array>
     <string>instagram-stories</string>
     <string>instagram</string>
 </array>
 
 This allows the app to check if Instagram is installed.
*/

