//
//  WidgetDataModels.swift
//  MugshotWidgets
//
//  Shared data models for widget entries and data transfer between main app and widgets
//

import Foundation
import WidgetKit

// MARK: - App Group Identifier

/// Shared App Group identifier for data sharing between main app and widgets
enum MugshotAppGroup {
    static let identifier = "group.co.mugshot.app.shared"
    
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
    
    static var widgetDataURL: URL? {
        containerURL?.appendingPathComponent("WidgetData.json")
    }
}

// MARK: - Widget Data Container

/// Container for all widget data, synced from main app
struct WidgetDataContainer: Codable {
    var currentUserId: String?
    var currentUserDisplayName: String?
    var currentUserAvatarURL: String?
    
    // Today's Mugshot data
    var todaysVisit: WidgetVisit?
    var userVisits: [WidgetVisit]
    
    // Friends' visits
    var friendsVisits: [WidgetVisit]
    
    // Streak data
    var currentStreak: Int
    var longestStreak: Int
    var weekdayVisitMap: [WidgetWeekdayVisit]
    
    // Favorites
    var favoriteCafes: [WidgetCafe]
    
    // Cafe of the Day
    var cafeOfTheDay: WidgetCafe?
    var cafeOfTheDayDate: Date?
    
    // Nearby cafes
    var nearbyCafes: [WidgetCafe]
    
    // Last sync timestamp
    var lastSyncDate: Date
    
    init() {
        self.currentUserId = nil
        self.currentUserDisplayName = nil
        self.currentUserAvatarURL = nil
        self.todaysVisit = nil
        self.userVisits = []
        self.friendsVisits = []
        self.currentStreak = 0
        self.longestStreak = 0
        self.weekdayVisitMap = []
        self.favoriteCafes = []
        self.cafeOfTheDay = nil
        self.cafeOfTheDayDate = nil
        self.nearbyCafes = []
        self.lastSyncDate = Date()
    }
}

// MARK: - Widget Visit Model

/// Simplified visit model for widget display
struct WidgetVisit: Codable, Identifiable {
    let id: String
    let cafeId: String
    let cafeName: String
    let cafeCity: String?
    let drinkType: String
    let customDrinkType: String?
    let caption: String
    let overallScore: Double
    let posterPhotoURL: String?
    let createdAt: Date
    let visibility: String
    
    // Author info (for friends' visits)
    let authorId: String?
    let authorDisplayName: String?
    let authorUsername: String?
    let authorAvatarURL: String?
    
    /// Display name for the drink
    var drinkDisplayName: String {
        if drinkType.lowercased() == "other", let custom = customDrinkType, !custom.isEmpty {
            return custom
        }
        return drinkType
    }
    
    /// Relative time string (e.g., "2h ago")
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Author display name with fallback
    var authorDisplayNameOrUsername: String {
        authorDisplayName ?? authorUsername ?? "Mugshot Member"
    }
}

// MARK: - Widget Cafe Model

/// Simplified cafe model for widget display
struct WidgetCafe: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let isFavorite: Bool
    let wantToTry: Bool
    let averageRating: Double
    let visitCount: Int
    
    /// Distance from user's current location (calculated at sync time)
    var distanceMeters: Double?
    
    /// Formatted distance string
    var distanceString: String? {
        guard let distance = distanceMeters else { return nil }
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Widget Weekday Visit

/// Represents a day in the weekly visit map
struct WidgetWeekdayVisit: Codable, Identifiable {
    var id: String { dayLetter + dateString }
    let dayLetter: String
    let dateString: String
    let hasVisit: Bool
}

// MARK: - Deep Link URLs

/// Deep link URL schemes for widget tap actions
enum WidgetDeepLink {
    static let scheme = "mugshot"
    
    /// Open a specific visit
    static func visitDetail(visitId: String) -> URL? {
        URL(string: "\(scheme)://visit/\(visitId)")
    }
    
    /// Open Log a Visit flow
    static var logVisit: URL? {
        URL(string: "\(scheme)://log-visit")
    }
    
    /// Open the Feed tab
    static var feed: URL? {
        URL(string: "\(scheme)://feed")
    }
    
    /// Open the Friends Hub
    static var friendsHub: URL? {
        URL(string: "\(scheme)://friends")
    }
    
    /// Open the Journal in Profile
    static var journal: URL? {
        URL(string: "\(scheme)://journal")
    }
    
    /// Open a specific cafe profile
    static func cafeDetail(cafeId: String) -> URL? {
        URL(string: "\(scheme)://cafe/\(cafeId)")
    }
    
    /// Open the Saved tab
    static var saved: URL? {
        URL(string: "\(scheme)://saved")
    }
    
    /// Open the Map tab
    static var map: URL? {
        URL(string: "\(scheme)://map")
    }
    
    /// Open Map centered on a specific cafe
    static func mapCafe(cafeId: String) -> URL? {
        URL(string: "\(scheme)://map/cafe/\(cafeId)")
    }
}

// MARK: - Widget Data Store

/// Handles reading/writing widget data from App Group container
final class WidgetDataStore {
    static let shared = WidgetDataStore()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Load widget data from App Group container
    func load() -> WidgetDataContainer {
        guard let url = MugshotAppGroup.widgetDataURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return WidgetDataContainer()
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(WidgetDataContainer.self, from: data)
        } catch {
            print("[WidgetDataStore] Failed to load data: \(error)")
            return WidgetDataContainer()
        }
    }
    
    /// Save widget data to App Group container
    func save(_ container: WidgetDataContainer) {
        guard let url = MugshotAppGroup.widgetDataURL else {
            print("[WidgetDataStore] No App Group container URL")
            return
        }
        
        do {
            let data = try encoder.encode(container)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[WidgetDataStore] Failed to save data: \(error)")
        }
    }
    
    /// Trigger widget refresh
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Trigger refresh for specific widget
    func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}

