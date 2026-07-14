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
    @Published private(set) var journalRevision = 0
    
    private let dataKey = "MugshotAppData"
    private let guestDataKey = "MugshotGuestAppData.v1"
    private let userDataKeyPrefix = "MugshotUserAppData.v1."
    private let defaults: UserDefaults
    private var storageScope: StorageScope = .legacy

    private enum StorageScope: Equatable {
        case legacy
        case guest
        case user(UUID)
    }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        PerformanceMonitor.mark("Local data load start")
        defer { PerformanceMonitor.mark("Local data load end") }
        // Try to load existing data, otherwise start fresh
        if let data = defaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
            let reconciliation = CafeIdentityReconciler.reconcile(decoded)
            self.appData = reconciliation.appData
            if reconciliation.mergedCafeCount > 0,
               let encoded = try? JSONEncoder().encode(reconciliation.appData) {
                defaults.set(encoded, forKey: dataKey)
            }
        } else {
            self.appData = AppData()
        }
    }
    
    func save() {
        persist(appData, forKey: activeStorageKey)
    }

    func noteJournalMutation() {
        journalRevision &+= 1
    }
    
    // MARK: - User Operations
    func setCurrentUser(_ user: User) {
        appData.currentUser = user
        save()
    }
    
    func applyAuthenticatedProfile(_ profile: SupabaseUserProfile) {
        activateUserStorage(userId: profile.id)
        appData.currentUser = profile.localUser
        if !appData.hasCompletedOnboarding {
            appData.hasCompletedOnboarding = true
        }
        save()
    }

    func prepareGuestSession() {
        guard storageScope != .guest else { return }

        switch storageScope {
        case .legacy:
            if let userId = appData.currentUser?.id {
                persist(appData, forKey: userDataKey(userId))
            }
        case .user(let userId):
            persist(appData, forKey: userDataKey(userId))
        case .guest:
            break
        }

        appData = loadAppData(forKey: guestDataKey) ?? AppData()
        storageScope = .guest
        noteJournalMutation()
    }

    func guestSavedCafes() -> [Cafe] {
        let guestData = storageScope == .guest
            ? appData
            : (loadAppData(forKey: guestDataKey) ?? AppData())
        return guestData.cafes.filter { $0.isFavorite || $0.wantToTry }
    }

    func clearMergedGuestSavedCafes() {
        let cleared = AppData()
        persist(cleared, forKey: guestDataKey)
        if storageScope == .guest {
            appData = cleared
            noteJournalMutation()
        }
    }

    func clearLocalReleaseState() {
        if case .user(let userId) = storageScope {
            defaults.removeObject(forKey: userDataKey(userId))
        }
        appData = AppData()
        storageScope = .guest
        defaults.removeObject(forKey: dataKey)
        defaults.removeObject(forKey: guestDataKey)
    }

    private var activeStorageKey: String {
        switch storageScope {
        case .legacy:
            return dataKey
        case .guest:
            return guestDataKey
        case .user(let userId):
            return userDataKey(userId)
        }
    }

    private func activateUserStorage(userId: UUID) {
        switch storageScope {
        case .legacy:
            if appData.currentUser?.id != userId,
               let stored = loadAppData(forKey: userDataKey(userId)) {
                appData = stored
            }
        case .guest:
            persist(appData, forKey: guestDataKey)
            appData = loadAppData(forKey: userDataKey(userId)) ?? AppData()
        case .user(let currentUserId):
            guard currentUserId != userId else { return }
            persist(appData, forKey: userDataKey(currentUserId))
            appData = loadAppData(forKey: userDataKey(userId)) ?? AppData()
        }
        storageScope = .user(userId)
        noteJournalMutation()
    }

    private func userDataKey(_ userId: UUID) -> String {
        userDataKeyPrefix + userId.uuidString.lowercased()
    }

    private func persist(_ value: AppData, forKey key: String) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        defaults.set(encoded, forKey: key)
    }

    private func loadAppData(forKey key: String) -> AppData? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppData.self, from: data) else {
            return nil
        }
        return CafeIdentityReconciler.reconcile(decoded).appData
    }

#if DEBUG
    func prepareUITestFixture(reset: Bool) {
        guard MugshotLaunchEnvironment.isUITesting else { return }

        let userID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

        if reset {
            appData = AppData()
            defaults.removeObject(forKey: dataKey)
            defaults.removeObject(forKey: guestDataKey)
            defaults.removeObject(forKey: userDataKey(userID))
            UserDefaults.standard.removeObject(forKey: CafeVisibilityPreferenceStore.valueKey)
            SipDraftStore.shared.removeAllForTesting()
            MugshotLaunchEnvironment.resetDeterministicFailures()
        }

        let cafeID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        if !reset, appData.currentUser?.id == userID {
            defaults.set(
                SipComposerExperience.guided.rawValue,
                forKey: SipComposerExperience.storageKey
            )
            return
        }

        appData = AppData(
            currentUser: User(
                id: userID,
                username: "mugshot_ui_test",
                displayName: "Mugshot Test",
                location: "Charleston, SC"
            ),
            cafes: [
                Cafe(
                    id: cafeID,
                    name: "Mugshot Test Cafe",
                    address: "1 Test Street, Charleston, SC",
                    isFavorite: true
                )
            ],
            visits: [],
            ratingTemplate: RatingTemplate(),
            hasCompletedOnboarding: true
        )
        defaults.set(
            SipComposerExperience.guided.rawValue,
            forKey: SipComposerExperience.storageKey
        )
        save()
    }
#endif
    
    // MARK: - Cafe Operations
    func addCafe(_ cafe: Cafe) {
        appData.cafes.append(cafe)
        save()
    }

    func findOrCreateCafe(named name: String) -> Cafe {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingCafe = appData.cafes.first(where: {
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return existingCafe
        }

        let cafe = Cafe(name: trimmedName)
        addCafe(cafe)
        return cafe
    }
    
    func updateCafe(_ cafe: Cafe) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
            appData.cafes[index] = cafe
            save()
        }
    }

    @discardableResult
    func applyRemoteCafeState(_ summary: RemoteCafeStateSummary) -> Cafe {
        upsertRemoteCafe(
            summary.cafe,
            isFavorite: summary.state.isFavorite,
            wantToTry: summary.state.wantToTry
        )
    }

    func applyRemoteCafeStates(_ summaries: [RemoteCafeStateSummary]) {
        // A fetched snapshot is authoritative for the signed-in account.
        // Reset first so remotely removed states cannot survive locally.
        for index in appData.cafes.indices {
            appData.cafes[index].isFavorite = false
            appData.cafes[index].wantToTry = false
        }
        for summary in summaries {
            upsertRemoteCafe(
                summary.cafe,
                isFavorite: summary.state.isFavorite,
                wantToTry: summary.state.wantToTry,
                persist: false
            )
        }
        save()
    }

    @discardableResult
    func applyResolvedCafeSummary(
        _ summary: ResolvedCafeSummary,
        toLocalCafeID localCafeID: UUID
    ) -> Cafe {
        guard let index = appData.cafes.firstIndex(where: { $0.id == localCafeID }) else {
            return upsertRemoteCafe(
                summary.remoteCafe,
                isFavorite: summary.isFavorite,
                wantToTry: summary.wantToTry,
                averageRating: summary.averageRating,
                visitCount: summary.visibleVisitCount
            )
        }

        let existing = appData.cafes[index]
        let remote = summary.remoteCafe.localCafe(
            isFavorite: summary.isFavorite,
            wantToTry: summary.wantToTry,
            averageRating: summary.averageRating ?? 0,
            visitCount: summary.visibleVisitCount
        )
        appData.cafes[index] = Cafe(
            id: existing.id,
            name: remote.name,
            location: remote.location ?? existing.location,
            address: !remote.address.isEmpty ? remote.address : existing.address,
            isFavorite: summary.isFavorite,
            wantToTry: summary.wantToTry,
            averageRating: summary.averageRating ?? existing.averageRating,
            visitCount: max(summary.visibleVisitCount, existing.visitCount),
            mapItemURL: existing.mapItemURL ?? remote.mapItemURL,
            websiteURL: remote.websiteURL ?? existing.websiteURL,
            placeCategory: existing.placeCategory,
            remoteCafeId: summary.cafeID
        )
        save()
        return appData.cafes[index]
    }

    @discardableResult
    func upsertRemoteCafe(
        _ remoteCafe: SupabaseCafeSummary,
        isFavorite: Bool? = nil,
        wantToTry: Bool? = nil,
        averageRating: Double? = nil,
        visitCount: Int? = nil,
        persist: Bool = true
    ) -> Cafe {
        let remoteLocalCafe = remoteCafe.localCafe(
            isFavorite: isFavorite ?? false,
            wantToTry: wantToTry ?? false,
            averageRating: averageRating ?? 0,
            visitCount: visitCount ?? 0
        )

        if let index = appData.cafes.firstIndex(where: { $0.remoteCafeId == remoteCafe.id || $0.id == remoteCafe.id }) {
            appData.cafes[index] = mergedCafe(
                existing: appData.cafes[index],
                remote: remoteLocalCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry,
                averageRating: averageRating,
                visitCount: visitCount
            )
            if persist { save() }
            return appData.cafes[index]
        }

        let remoteIdentity = CafeIdentity.key(
            name: remoteCafe.name,
            address: remoteCafe.address,
            location: remoteLocalCafe.location,
            applePlaceId: remoteCafe.applePlaceId
        )
        if let index = appData.cafes.firstIndex(where: { CafeIdentity.key(for: $0) == remoteIdentity }) {
            appData.cafes[index] = mergedCafe(
                existing: appData.cafes[index],
                remote: remoteLocalCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry,
                averageRating: averageRating,
                visitCount: visitCount
            )
            if persist { save() }
            return appData.cafes[index]
        }

        appData.cafes.append(remoteLocalCafe)
        if persist { save() }
        return remoteLocalCafe
    }

    func setCafeState(
        cafeId: UUID,
        isFavorite: Bool,
        wantToTry: Bool
    ) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].isFavorite = isFavorite
            appData.cafes[index].wantToTry = wantToTry
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

    private func mergedCafe(
        existing: Cafe,
        remote: Cafe,
        isFavorite: Bool?,
        wantToTry: Bool?,
        averageRating: Double?,
        visitCount: Int?
    ) -> Cafe {
        Cafe(
            id: existing.id,
            name: remote.name,
            location: remote.location ?? existing.location,
            address: !remote.address.isEmpty ? remote.address : existing.address,
            isFavorite: isFavorite ?? existing.isFavorite,
            wantToTry: wantToTry ?? existing.wantToTry,
            averageRating: averageRating ?? existing.averageRating,
            visitCount: visitCount ?? existing.visitCount,
            mapItemURL: existing.mapItemURL ?? remote.mapItemURL,
            websiteURL: existing.websiteURL ?? remote.websiteURL,
            placeCategory: existing.placeCategory,
            remoteCafeId: remote.remoteCafeId ?? existing.remoteCafeId ?? remote.id
        )
    }
    
    // Find existing Cafe by location (within ~50 meters) or create new one
    func findOrCreateCafe(from mapItem: MKMapItem) -> Cafe {
        guard let location = mapItem.placemark.location?.coordinate else {
            let cafe = Cafe(
                name: mapItem.name ?? "Cafe",
                address: formatAddress(from: mapItem.placemark),
                mapItemURL: mapItem.url?.absoluteString,
                websiteURL: mapItem.url?.absoluteString, // For now, use mapItem URL as fallback
                placeCategory: mapItem.pointOfInterestCategory?.rawValue
            )
            if let existing = appData.cafes.first(where: {
                CafeIdentity.key(for: $0) == CafeIdentity.key(for: cafe)
            }) {
                return existing
            }
            addCafe(cafe)
            return cafe
        }
        
        let candidate = Cafe(
            name: mapItem.name ?? "Cafe",
            location: location,
            address: formatAddress(from: mapItem.placemark),
            mapItemURL: mapItem.url?.absoluteString
        )
        let candidateIdentity = CafeIdentity.key(for: candidate)
        let threshold: Double = 0.00025
        
        if let existingCafe = appData.cafes.first(where: { cafe in
            if CafeIdentity.key(for: cafe) == candidateIdentity { return true }
            guard let cafeLocation = cafe.location else { return false }
            let latDiff = abs(cafeLocation.latitude - location.latitude)
            let lonDiff = abs(cafeLocation.longitude - location.longitude)
            let sameName = cafe.name.compare(
                mapItem.name ?? "Cafe",
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
            return sameName && latDiff < threshold && lonDiff < threshold
        }) {
            // Update existing cafe with mapItem data if missing
            if let index = appData.cafes.firstIndex(where: { $0.id == existingCafe.id }) {
                var updatedCafe = appData.cafes[index]
                let currentAddress = formatAddress(from: mapItem.placemark)
                if !currentAddress.isEmpty {
                    updatedCafe.address = currentAddress
                }
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
                return updatedCafe
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
            name: mapItem.name ?? "Cafe",
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

        let streetAddress = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        if !streetAddress.isEmpty {
            components.append(streetAddress)
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
        guard let index = appData.visits.firstIndex(where: { $0.id == visitId }) else {
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
        case .ranked:
            return allVisits.filter { $0.visibility != .private }
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
}
