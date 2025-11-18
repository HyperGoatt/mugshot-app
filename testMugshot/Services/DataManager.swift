//
//  DataManager.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import Combine
import MapKit

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var appData: AppData
    
    private let dataKey = "MugshotAppData"
    
    private init() {
        // Try to load existing data, otherwise start fresh
        if let data = UserDefaults.standard.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
            self.appData = decoded
            // Preload images for all visits
            preloadVisitImages()
        } else {
            self.appData = AppData()
        }
    }
    
    // Preload images for all visits when app starts
    private func preloadVisitImages() {
        let allPhotoPaths = appData.visits.flatMap { $0.photos }
        PhotoCache.shared.preloadImages(for: allPhotoPaths)
        
        // Also preload profile and banner images
        var profileImagePaths: [String] = []
        if let profileId = appData.currentUserProfileImageId {
            profileImagePaths.append(profileId)
        }
        if let bannerId = appData.currentUserBannerImageId {
            profileImagePaths.append(bannerId)
        }
        if !profileImagePaths.isEmpty {
            PhotoCache.shared.preloadImages(for: profileImagePaths)
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(appData) {
            UserDefaults.standard.set(encoded, forKey: dataKey)
        }
    }
    
    // MARK: - User Operations
    func setCurrentUser(_ user: User) {
        appData.currentUser = user
        save()
    }
    
    func updateCurrentUser(_ user: User) {
        appData.currentUser = user
        save()
    }
    
    func logout() {
        // Clear all data and reset to initial state
        appData = AppData()
        save()
        // Clear photo cache
        PhotoCache.shared.clear()
    }
    
    // MARK: - Cafe Operations
    func addCafe(_ cafe: Cafe) {
        appData.cafes.append(cafe)
        save()
    }
    
    func updateCafe(_ cafe: Cafe) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
            appData.cafes[index] = cafe
            save()
        }
    }
    
    func getCafe(id: UUID) -> Cafe? {
        return appData.cafes.first(where: { $0.id == id })
    }
    
    func toggleCafeFavorite(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].isFavorite.toggle()
            save()
        }
    }
    
    func toggleCafeWantToTry(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].wantToTry.toggle()
            save()
        }
    }
    
    // Find existing Cafe by location (within ~50 meters) or create new one
    func findOrCreateCafe(from mapItem: MKMapItem) -> Cafe {
        guard let location = mapItem.placemark.location?.coordinate else {
            // If no location, just create a new cafe
            let cafe = Cafe(
                name: mapItem.name ?? "Unknown Cafe",
                address: formatAddress(from: mapItem.placemark),
                mapItemURL: mapItem.url?.absoluteString,
                websiteURL: mapItem.url?.absoluteString, // For now, use mapItem URL as fallback
                placeCategory: mapItem.pointOfInterestCategory?.rawValue
            )
            addCafe(cafe)
            return cafe
        }
        
        // Check if a cafe exists at this location (within ~50 meters)
        let threshold: Double = 0.0005 // approximately 50 meters
        
        if let existingCafe = appData.cafes.first(where: { cafe in
            guard let cafeLocation = cafe.location else { return false }
            let latDiff = abs(cafeLocation.latitude - location.latitude)
            let lonDiff = abs(cafeLocation.longitude - location.longitude)
            return latDiff < threshold && lonDiff < threshold
        }) {
            // Update existing cafe with mapItem data if missing
            if let index = appData.cafes.firstIndex(where: { $0.id == existingCafe.id }) {
                var updatedCafe = appData.cafes[index]
                if updatedCafe.mapItemURL == nil {
                    updatedCafe.mapItemURL = mapItem.url?.absoluteString
                }
                if updatedCafe.websiteURL == nil {
                    updatedCafe.websiteURL = mapItem.url?.absoluteString
                }
                if updatedCafe.placeCategory == nil {
                    updatedCafe.placeCategory = mapItem.pointOfInterestCategory?.rawValue
                }
                appData.cafes[index] = updatedCafe
                save()
            }
            return existingCafe
        }
        
        // Extract website URL from placemark if available
        var websiteURL: String? = nil
        if let url = mapItem.url, url.scheme == "http" || url.scheme == "https" {
            websiteURL = url.absoluteString
        }
        
        // Create new cafe with Apple Maps data
        let cafe = Cafe(
            name: mapItem.name ?? "Unknown Cafe",
            location: location,
            address: formatAddress(from: mapItem.placemark),
            mapItemURL: mapItem.url?.absoluteString,
            websiteURL: websiteURL,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
        )
        addCafe(cafe)
        return cafe
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Visit Operations
    func addVisit(_ visit: Visit) {
        appData.visits.append(visit)
        
        // Preload images for the new visit
        PhotoCache.shared.preloadImages(for: visit.photos)
        
        // Update cafe stats
        if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == visit.cafeId }) {
            appData.cafes[cafeIndex].visitCount += 1
            
            // Recalculate average rating for the cafe
            let cafeVisits = appData.visits.filter { $0.cafeId == visit.cafeId }
            let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
            appData.cafes[cafeIndex].averageRating = totalRating / Double(cafeVisits.count)
        }
        
        save()
    }
    
    func getVisit(id: UUID) -> Visit? {
        return appData.visits.first(where: { $0.id == id })
    }
        
        // Update an existing visit and refresh related cafe stats
        func updateVisit(_ updatedVisit: Visit) {
            guard let index = appData.visits.firstIndex(where: { $0.id == updatedVisit.id }) else { return }
            appData.visits[index] = updatedVisit
            
            // Recalculate cafe stats
            if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == updatedVisit.cafeId }) {
                let cafeVisits = appData.visits.filter { $0.cafeId == updatedVisit.cafeId }
                appData.cafes[cafeIndex].visitCount = cafeVisits.count
                let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
                appData.cafes[cafeIndex].averageRating = cafeVisits.isEmpty ? 0.0 : (totalRating / Double(cafeVisits.count))
            }
            save()
        }
        
        // Delete a visit and update cafe stats accordingly
        func deleteVisit(id: UUID) {
            guard let visit = getVisit(id: id) else { return }
            appData.visits.removeAll { $0.id == id }
            
            // Update cafe stats
            if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == visit.cafeId }) {
                let cafeVisits = appData.visits.filter { $0.cafeId == visit.cafeId }
                appData.cafes[cafeIndex].visitCount = cafeVisits.count
                let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
                appData.cafes[cafeIndex].averageRating = cafeVisits.isEmpty ? 0.0 : (totalRating / Double(cafeVisits.count))
            }
            save()
        }
    
    func getVisitsForCafe(_ cafeId: UUID) -> [Visit] {
        return appData.visits.filter { $0.cafeId == cafeId }.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Like Operations
    func toggleVisitLike(_ visitId: UUID, userId: UUID) {
        guard let index = appData.visits.firstIndex(where: { $0.id == visitId }),
              appData.currentUser != nil else {
            return
        }
        
        var visit = appData.visits[index]
        
        if visit.likedByUserIds.contains(userId) {
            // Unlike
            visit.likedByUserIds.removeAll { $0 == userId }
            visit.likeCount = max(0, visit.likeCount - 1)
        } else {
            // Like
            visit.likedByUserIds.append(userId)
            visit.likeCount += 1
        }
        
        appData.visits[index] = visit
        save()
    }
    
    // MARK: - Feed Operations
    func getFeedVisits(scope: FeedScope, currentUserId: UUID) -> [Visit] {
        let allVisits = appData.visits.sorted { $0.createdAt > $1.createdAt }
        
        switch scope {
        case .everyone:
            // Show visits with visibility == .everyone
            return allVisits.filter { $0.visibility == .everyone }
        case .friends:
            // Show visits with visibility == .friends OR .everyone (for current user)
            // For now, since we're single-user, this shows non-private visits
            return allVisits.filter { visit in
                visit.visibility == .friends || visit.visibility == .everyone
            }
        }
    }
    
    // MARK: - Comment Operations
    func addComment(to visitId: UUID, userId: UUID, text: String) {
        guard let index = appData.visits.firstIndex(where: { $0.id == visitId }) else {
            return
        }
        
        // Parse mentions from comment text
        let mentions = MentionParser.parseMentions(from: text)
        
        let comment = Comment(
            visitId: visitId,
            userId: userId,
            text: text,
            mentions: mentions
        )
        
        appData.visits[index].comments.append(comment)
        save()
    }
    
    func getComments(for visitId: UUID) -> [Comment] {
        guard let visit = appData.visits.first(where: { $0.id == visitId }) else {
            return []
        }
        return visit.comments.sorted { $0.createdAt < $1.createdAt } // Oldest first
    }
    
    // MARK: - Rating Template Operations
    func updateRatingTemplate(_ template: RatingTemplate) {
        appData.ratingTemplate = template
        save()
    }
    
    // MARK: - Onboarding
    func completeOnboarding() {
        appData.hasCompletedOnboarding = true
        save()
    }
    
    // MARK: - Statistics
    func getUserStats() -> (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        let visits = appData.visits
        let cafes = Set(visits.map { $0.cafeId })
        let totalScore = visits.reduce(0.0) { $0 + $1.overallScore }
        let averageScore = visits.isEmpty ? 0.0 : totalScore / Double(visits.count)
        
        // Find favorite drink type
        let drinkTypeCounts = Dictionary(grouping: visits, by: { $0.drinkType })
            .mapValues { $0.count }
        let favoriteDrinkType = drinkTypeCounts.max(by: { $0.value < $1.value })?.key
        
        return (
            totalVisits: visits.count,
            totalCafes: cafes.count,
            averageScore: averageScore,
            favoriteDrinkType: favoriteDrinkType
        )
    }
    
    // Get most visited café
    func getMostVisitedCafe() -> (cafe: Cafe, visitCount: Int)? {
        let visitsByCafe = Dictionary(grouping: appData.visits, by: { $0.cafeId })
        guard let (cafeId, visits) = visitsByCafe.max(by: { $0.value.count < $1.value.count }),
              let cafe = getCafe(id: cafeId) else {
            return nil
        }
        return (cafe: cafe, visitCount: visits.count)
    }
    
    // Get favorite café (highest average rating)
    func getFavoriteCafe() -> (cafe: Cafe, avgScore: Double)? {
        let visitsByCafe = Dictionary(grouping: appData.visits, by: { $0.cafeId })
        var cafeScores: [(cafeId: UUID, avgScore: Double)] = []
        
        for (cafeId, visits) in visitsByCafe {
            let avgScore = visits.reduce(0.0) { $0 + $1.overallScore } / Double(visits.count)
            cafeScores.append((cafeId: cafeId, avgScore: avgScore))
        }
        
        guard let topCafe = cafeScores.max(by: { $0.avgScore < $1.avgScore }),
              let cafe = getCafe(id: topCafe.cafeId) else {
            return nil
        }
        return (cafe: cafe, avgScore: topCafe.avgScore)
    }
    
    // Get beverage breakdown (percentage of each drink type)
    func getBeverageBreakdown() -> [(drinkType: DrinkType, count: Int, fraction: Double)] {
        let totalVisits = appData.visits.count
        guard totalVisits > 0 else { return [] }
        
        let drinkTypeCounts = Dictionary(grouping: appData.visits, by: { $0.drinkType })
            .mapValues { $0.count }
        
        return drinkTypeCounts.map { (drinkType: $0.key, count: $0.value, fraction: Double($0.value) / Double(totalVisits)) }
            .sorted { $0.count > $1.count }
    }
}

