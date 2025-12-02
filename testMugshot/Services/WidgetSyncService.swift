//
//  WidgetSyncService.swift
//  testMugshot
//
//  Syncs data from the main app to the widget extension via App Groups.
//

import Foundation
import WidgetKit
import CoreLocation

// MARK: - App Group Identifier (must match widget extension)

enum MugshotAppGroup {
    static let identifier = "group.co.mugshot.app.shared"
    
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
    
    static var widgetDataURL: URL? {
        containerURL?.appendingPathComponent("WidgetData.json")
    }
}

// MARK: - Widget Data Container (must match widget extension)

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

// MARK: - Widget Visit Model (must match widget extension)

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
    
    let authorId: String?
    let authorDisplayName: String?
    let authorUsername: String?
    let authorAvatarURL: String?
}

// MARK: - Widget Cafe Model (must match widget extension)

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
    var distanceMeters: Double?
}

// MARK: - Widget Weekday Visit (must match widget extension)

struct WidgetWeekdayVisit: Codable, Identifiable {
    var id: String { dayLetter + dateString }
    let dayLetter: String
    let dateString: String
    let hasVisit: Bool
}

// MARK: - Widget Sync Service

@MainActor
final class WidgetSyncService {
    static let shared = WidgetSyncService()
    
    private let encoder = JSONEncoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
    }
    
    /// Sync all widget data from the main app
    func syncWidgetData(
        dataManager: DataManager,
        friendsVisits: [Visit] = [],
        userLocation: CLLocation? = nil
    ) {
        print("[WidgetSync] Starting widget data sync...")
        
        let appData = dataManager.appData
        var container = WidgetDataContainer()
        
        // Current user info
        container.currentUserId = appData.supabaseUserId
        container.currentUserDisplayName = appData.currentUserDisplayName
        container.currentUserAvatarURL = appData.currentUserAvatarURL
        
        // Convert user visits
        container.userVisits = appData.visits
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { mapVisitToWidget($0, cafes: appData.cafes) }
        
        // Today's visit
        let calendar = Calendar.current
        container.todaysVisit = container.userVisits.first { visit in
            if let createdAt = ISO8601DateFormatter().date(from: visit.createdAt.description) {
                return calendar.isDateInToday(createdAt)
            }
            return calendar.isDateInToday(visit.createdAt)
        }
        
        // Friends' visits
        container.friendsVisits = friendsVisits
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { mapVisitToWidget($0, cafes: appData.cafes) }
        
        // Streak data
        container.currentStreak = JournalStatsHelper.calculateCurrentStreak(visits: appData.visits)
        container.longestStreak = JournalStatsHelper.calculateLongestStreak(visits: appData.visits)
        container.weekdayVisitMap = mapWeekdayVisits(visits: appData.visits)
        
        // Favorite cafes
        container.favoriteCafes = appData.cafes
            .filter { $0.isFavorite }
            .map { mapCafeToWidget($0, userLocation: userLocation) }
        
        // Cafe of the Day selection
        container.cafeOfTheDay = selectCafeOfTheDay(from: appData.cafes, userLocation: userLocation)
        container.cafeOfTheDayDate = Date()
        
        // Nearby cafes (if we have location)
        if let location = userLocation {
            container.nearbyCafes = appData.cafes
                .compactMap { cafe -> (WidgetCafe, Double)? in
                    guard let lat = cafe.location?.latitude,
                          let lon = cafe.location?.longitude else { return nil }
                    let cafeLocation = CLLocation(latitude: lat, longitude: lon)
                    let distance = location.distance(from: cafeLocation)
                    var widgetCafe = mapCafeToWidget(cafe, userLocation: location)
                    widgetCafe.distanceMeters = distance
                    return (widgetCafe, distance)
                }
                .sorted { $0.1 < $1.1 }
                .prefix(10)
                .map { $0.0 }
        }
        
        container.lastSyncDate = Date()
        
        // Save to App Group container
        saveWidgetData(container)
        
        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        
        print("[WidgetSync] Widget data sync complete")
    }
    
    /// Quick sync for specific widget kinds
    func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
    
    /// Reload all widgets
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Private Helpers
    
    private func saveWidgetData(_ container: WidgetDataContainer) {
        guard let url = MugshotAppGroup.widgetDataURL else {
            print("[WidgetSync] Error: No App Group container URL")
            return
        }
        
        do {
            let data = try encoder.encode(container)
            try data.write(to: url, options: .atomic)
            print("[WidgetSync] Saved widget data to: \(url.path)")
        } catch {
            print("[WidgetSync] Error saving widget data: \(error)")
        }
    }
    
    private func mapVisitToWidget(_ visit: Visit, cafes: [Cafe]) -> WidgetVisit {
        let cafe = cafes.first { $0.id == visit.cafeId }
        
        return WidgetVisit(
            id: visit.id.uuidString,
            cafeId: visit.cafeId.uuidString,
            cafeName: cafe?.name ?? "Unknown Cafe",
            cafeCity: cafe?.city,
            drinkType: visit.drinkType.rawValue,
            customDrinkType: visit.customDrinkType,
            caption: visit.caption,
            overallScore: visit.overallScore,
            posterPhotoURL: visit.posterPhotoURL,
            createdAt: visit.createdAt,
            visibility: visit.visibility.rawValue,
            authorId: visit.supabaseUserId,
            authorDisplayName: visit.authorDisplayName,
            authorUsername: visit.authorUsername,
            authorAvatarURL: visit.authorAvatarURL
        )
    }
    
    private func mapCafeToWidget(_ cafe: Cafe, userLocation: CLLocation?) -> WidgetCafe {
        var distanceMeters: Double? = nil
        
        if let userLoc = userLocation,
           let lat = cafe.location?.latitude,
           let lon = cafe.location?.longitude {
            let cafeLocation = CLLocation(latitude: lat, longitude: lon)
            distanceMeters = userLoc.distance(from: cafeLocation)
        }
        
        return WidgetCafe(
            id: cafe.id.uuidString,
            name: cafe.name,
            address: cafe.address,
            city: cafe.city,
            country: cafe.country,
            latitude: cafe.location?.latitude,
            longitude: cafe.location?.longitude,
            isFavorite: cafe.isFavorite,
            wantToTry: cafe.wantToTry,
            averageRating: cafe.averageRating,
            visitCount: cafe.visitCount,
            distanceMeters: distanceMeters
        )
    }
    
    private func mapWeekdayVisits(visits: [Visit]) -> [WidgetWeekdayVisit] {
        let weekMap = JournalStatsHelper.weekdayVisitMap(visits: visits)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return weekMap.map { day in
            WidgetWeekdayVisit(
                dayLetter: day.dayLetter,
                dateString: dateFormatter.string(from: day.date),
                hasVisit: day.hasVisit
            )
        }
    }
    
    private func selectCafeOfTheDay(from cafes: [Cafe], userLocation: CLLocation?) -> WidgetCafe? {
        // Priority: favorites > high-rated > any
        var candidates = cafes.filter { $0.isFavorite }
        
        if candidates.isEmpty {
            candidates = cafes.filter { $0.averageRating >= 4.0 }.sorted { $0.averageRating > $1.averageRating }
        }
        
        if candidates.isEmpty {
            candidates = cafes
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // Use day of year for deterministic selection
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % candidates.count
        
        return mapCafeToWidget(candidates[index], userLocation: userLocation)
    }
}

