//
//  WidgetDeepLinkHandler.swift
//  testMugshot
//
//  Handles deep link URLs from widgets and navigates to appropriate screens.
//

import Foundation
import SwiftUI

// MARK: - Widget Deep Link Handler

final class WidgetDeepLinkHandler {
    static let shared = WidgetDeepLinkHandler()
    
    private init() {}
    
    /// Handle a deep link URL from a widget
    /// - Parameters:
    ///   - url: The deep link URL
    ///   - tabCoordinator: The tab coordinator for navigation
    ///   - dataManager: The data manager for looking up data
    /// - Returns: true if the URL was handled, false otherwise
    @MainActor
    func handleDeepLink(
        url: URL,
        tabCoordinator: TabCoordinator,
        dataManager: DataManager
    ) -> Bool {
        print("[WidgetDeepLink] Handling URL: \(url.absoluteString)")
        
        guard url.scheme == "mugshot" else {
            print("[WidgetDeepLink] Unknown scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let host = url.host
        
        switch host {
        case "visit":
            // mugshot://visit/{visitId}
            if let visitIdString = pathComponents.first,
               let visitId = UUID(uuidString: visitIdString) {
                print("[WidgetDeepLink] Navigating to visit: \(visitId)")
                tabCoordinator.navigateToVisitDetail(visitId: visitId)
                return true
            }
            
        case "log-visit":
            // mugshot://log-visit
            print("[WidgetDeepLink] Navigating to Log Visit")
            tabCoordinator.selectedTab = 2 // Add tab
            return true
            
        case "feed":
            // mugshot://feed
            print("[WidgetDeepLink] Navigating to Feed")
            tabCoordinator.switchToFeed()
            return true
            
        case "friends":
            // mugshot://friends
            print("[WidgetDeepLink] Navigating to Friends Hub")
            tabCoordinator.navigateToFriendsHub()
            return true
            
        case "journal":
            // mugshot://journal
            print("[WidgetDeepLink] Navigating to Journal")
            // Navigate to Profile tab and set a flag to show journal
            tabCoordinator.switchToProfile()
            // Post notification to open journal section
            NotificationCenter.default.post(
                name: .widgetNavigateToJournal,
                object: nil
            )
            return true
            
        case "cafe":
            // mugshot://cafe/{cafeId}
            if let cafeIdString = pathComponents.first,
               let _ = UUID(uuidString: cafeIdString) {
                print("[WidgetDeepLink] Navigating to cafe: \(cafeIdString)")
                // Navigate to saved tab and post notification to open cafe detail
                tabCoordinator.selectedTab = 3 // Saved tab
                NotificationCenter.default.post(
                    name: .widgetNavigateToCafe,
                    object: nil,
                    userInfo: ["cafeId": cafeIdString]
                )
                return true
            }
            
        case "saved":
            // mugshot://saved
            print("[WidgetDeepLink] Navigating to Saved")
            tabCoordinator.selectedTab = 3 // Saved tab
            return true
            
        case "map":
            // mugshot://map or mugshot://map/cafe/{cafeId}
            print("[WidgetDeepLink] Navigating to Map")
            tabCoordinator.switchToMap()
            
            // Check if we need to center on a specific cafe
            if pathComponents.first == "cafe",
               let cafeIdString = pathComponents.dropFirst().first {
                NotificationCenter.default.post(
                    name: .widgetNavigateToMapCafe,
                    object: nil,
                    userInfo: ["cafeId": cafeIdString]
                )
            }
            return true
            
        default:
            print("[WidgetDeepLink] Unknown host: \(host ?? "nil")")
        }
        
        return false
    }
}

// MARK: - Notification Names for Widget Navigation

extension Notification.Name {
    static let widgetNavigateToJournal = Notification.Name("widgetNavigateToJournal")
    static let widgetNavigateToCafe = Notification.Name("widgetNavigateToCafe")
    static let widgetNavigateToMapCafe = Notification.Name("widgetNavigateToMapCafe")
}

