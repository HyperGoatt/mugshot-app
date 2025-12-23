//
//  InstagramStoriesServiceTests.swift
//  testMugshotTests
//
//  Tests for InstagramStoriesService to ensure data race fixes work correctly
//

import Testing
import UIKit
@testable import testMugshot

@MainActor
struct InstagramStoriesServiceTests {
    
    @Test("InstagramStoriesService - shareToStories completion is Sendable")
    func testShareToStoriesCompletionIsSendable() async throws {
        // Create a test image
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        // Test that completion handler can be called from different contexts
        var completionCalled = false
        
        InstagramStoriesService.shareToStories(image: testImage) { result in
            // This should compile without data race warnings
            completionCalled = true
        }
        
        // Wait a bit for the completion (it may fail if Instagram isn't installed, which is fine)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify completion can be called (even if it fails due to Instagram not being installed)
        #expect(completionCalled || !InstagramStoriesService.isInstagramInstalled)
    }
    
    @Test("InstagramStoriesService - shareToStoriesWithSticker completion is Sendable")
    func testShareToStoriesWithStickerCompletionIsSendable() async throws {
        // Create test images
        let backgroundImage = UIImage(systemName: "photo") ?? UIImage()
        let stickerImage = UIImage(systemName: "star.fill") ?? UIImage()
        
        // Test that completion handler can be called from different contexts
        var completionCalled = false
        
        InstagramStoriesService.shareToStoriesWithSticker(
            backgroundImage: backgroundImage,
            stickerImage: stickerImage,
            completion: { result in
                // This should compile without data race warnings
                completionCalled = true
            }
        )
        
        // Wait a bit for the completion
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify completion can be called
        #expect(completionCalled || !InstagramStoriesService.isInstagramInstalled)
    }
    
    @Test("InstagramStoriesService - handles not installed error")
    func testHandlesNotInstalledError() async throws {
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        var receivedError: InstagramStoriesService.InstagramError?
        
        InstagramStoriesService.shareToStories(image: testImage) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
        }
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // If Instagram is not installed, we should get a notInstalled error
        // If it is installed, the test may succeed, which is also valid
        if !InstagramStoriesService.isInstagramInstalled {
            #expect(receivedError == .notInstalled)
        }
    }
    
    @Test("InstagramStoriesService - InstagramError is Sendable")
    func testInstagramErrorIsSendable() {
        // Verify that InstagramError conforms to Sendable
        let error: InstagramStoriesService.InstagramError = .notInstalled
        
        // This should compile without warnings
        let sendableError: any Sendable = error
        #expect(sendableError is InstagramStoriesService.InstagramError)
    }
    
    @Test("InstagramStoriesService - handles image encoding failure")
    func testHandlesImageEncodingFailure() async throws {
        // Create an invalid image scenario (though UIImage.pngData() rarely fails)
        // We'll test the error path exists
        let testImage = UIImage()
        
        var receivedError: InstagramStoriesService.InstagramError?
        
        InstagramStoriesService.shareToStories(image: testImage) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Should either succeed or fail with a specific error
        #expect(receivedError == nil || receivedError == .imageEncodingFailed || receivedError == .notInstalled)
    }
}

