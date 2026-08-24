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
    @Published private var personalMapSnapshotCache: RemoteMapPinSnapshot?
    private var personalMapSnapshotUserID: UUID?
    
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
        self.personalMapSnapshotCache = nil
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
        save()
    }

    /// Selects only the proven account's existing local snapshot. This is used
    /// when session refresh is temporarily unavailable, before a remote profile
    /// can be bootstrapped. It never relabels guest or another account's data.
    func preserveAuthenticatedAccountScope(userID: UUID) {
        activateUserStorage(userId: userID)
    }

    func prepareGuestSession() {
        clearPersonalMapSnapshot()
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

    /// Removes only one authenticated account's local snapshot. Guest data and
    /// every other signed-in account remain intact on a shared device.
    func clearLocalReleaseState(for userID: UUID) {
        defaults.removeObject(forKey: userDataKey(userID))
        if personalMapSnapshotUserID == userID {
            clearPersonalMapSnapshot()
        }

        let isActiveDeletedAccount: Bool
        switch storageScope {
        case .user(let activeUserID):
            isActiveDeletedAccount = activeUserID == userID
        case .legacy:
            isActiveDeletedAccount = appData.currentUser?.id == userID
            if isActiveDeletedAccount {
                defaults.removeObject(forKey: dataKey)
            }
        case .guest:
            isActiveDeletedAccount = false
        }

        guard isActiveDeletedAccount else { return }
        appData = loadAppData(forKey: guestDataKey) ?? AppData()
        storageScope = .guest
        noteJournalMutation()
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
        if personalMapSnapshotUserID != nil,
           personalMapSnapshotUserID != userId {
            clearPersonalMapSnapshot()
        }
        switch storageScope {
        case .legacy:
            if let legacyOwnerID = appData.currentUser?.id {
                if legacyOwnerID != userId {
                    // A legacy payload with a different explicit owner belongs
                    // to that owner. Preserve it in their account scope and
                    // never relabel it as the account now authenticating on
                    // this device.
                    persist(appData, forKey: userDataKey(legacyOwnerID))
                    appData = loadAppData(forKey: userDataKey(userId)) ?? AppData()
                } else if persist(appData, forKey: userDataKey(userId)) {
                    // An explicitly owned legacy payload is now durably scoped
                    // to that account. Remove the legacy copy so account
                    // deletion cannot reveal it again on a later launch.
                    defaults.removeObject(forKey: dataKey)
                }
            } else {
                // An ownerless legacy payload is not proof that it belongs to
                // the first account that authenticates after upgrade. Leave
                // the original legacy key intact for support recovery and
                // start this account from only its proven snapshot.
                appData = loadAppData(forKey: userDataKey(userId)) ?? AppData()
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

    @discardableResult
    private func persist(_ value: AppData, forKey key: String) -> Bool {
        guard let encoded = try? JSONEncoder().encode(value) else { return false }
        defaults.set(encoded, forKey: key)
        return true
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
        let mapSearchScope: LocalAccountScope = MugshotLaunchEnvironment.isUITestingSignedOut
            ? .guest
            : .user(userID)
        let mapSearchRecentsKey = MapSearchService.recentsKey(for: mapSearchScope)

        if reset {
            appData = AppData()
            defaults.removeObject(forKey: dataKey)
            defaults.removeObject(forKey: guestDataKey)
            defaults.removeObject(forKey: userDataKey(userID))
            UserDefaults.standard.removeObject(forKey: CafeVisibilityPreferenceStore.valueKey)
            UserDefaults.standard.removeObject(
                forKey: CafeVisibilityPreferenceStore.storageKey(for: .guest)
            )
            UserDefaults.standard.removeObject(
                forKey: CafeVisibilityPreferenceStore.storageKey(for: .user(userID))
            )
            SipDraftStore.shared.removeAllForTesting()
            CafeSessionContinuationStore.shared.removeAllForTesting()
            V3PublishedCompletionStore.shared.removeAllForTesting()
            RecentCriterionSetupStore.shared.removeAllForTesting()
            PinnedCriterionStore.shared.removeAllForTesting()
            HomeLibraryStore.shared.removeAllForTesting()
            defaults.removeObject(forKey: mapSearchRecentsKey)
            defaults.removeObject(forKey: "MugshotMap.discoveryScope.v1")
            defaults.removeObject(forKey: "saved.library.sort")
            defaults.removeObject(forKey: "saved.library.density")
            MugshotLaunchEnvironment.resetDeterministicFailures()
        }

        if let savedAuditScenario = MugshotLaunchEnvironment.savedAuditScenario {
            if !reset,
               appData.currentUser?.id == SavedAuditFixtures.userID || MugshotLaunchEnvironment.isUITestingSignedOut {
                SavedAuditFixtures.seedLocalPhotos()
                return
            }
            appData = SavedAuditFixtures.appData(
                for: savedAuditScenario,
                signedOut: MugshotLaunchEnvironment.isUITestingSignedOut
            )
            SavedAuditFixtures.seedLocalPhotos()
            save()
            return
        }

        let cafeID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        if !reset, appData.currentUser?.id == userID {
            seedUITestMapSearchRecentIfRequested(key: mapSearchRecentsKey)
            seedUITestV3LabParityIfRequested(userID: userID)
            defaults.set(
                SipComposerExperience.guided.rawValue,
                forKey: SipComposerExperience.storageKey
            )
            return
        }

        let adaptiveMapFixture = adaptiveMapUITestFixture(userID: userID)
        let fixtureCafes = adaptiveMapFixture?.cafes ?? [
            Cafe(
                id: cafeID,
                name: "Mugshot Test Cafe",
                address: "1 Test Street, Charleston, SC",
                isFavorite: true
            )
        ]
        appData = AppData(
            currentUser: User(
                id: userID,
                username: "mugshot_ui_test",
                displayName: "Mugshot Test",
                location: "Charleston, SC"
            ),
            cafes: fixtureCafes,
            personalLibraryCafeIDs: Set(fixtureCafes.map(\.id)),
            visits: adaptiveMapFixture?.visits ?? [],
            ratingTemplate: RatingTemplate()
        )
        seedUITestMapSearchRecentIfRequested(key: mapSearchRecentsKey)
        defaults.set(
            SipComposerExperience.guided.rawValue,
            forKey: SipComposerExperience.storageKey
        )
        save()
        seedUITestV3LabParityIfRequested(userID: userID)
    }

    private func adaptiveMapUITestFixture(
        userID: UUID
    ) -> (cafes: [Cafe], visits: [Visit])? {
        guard MugshotLaunchEnvironment.shouldSeedUITestAdaptiveMap else { return nil }
        let seeds: [(name: String, latitude: Double, longitude: Double, city: String)] = [
            ("North Beach Coffee", 37.8060, -122.4103, "San Francisco"),
            ("Market Street Coffee", 37.7890, -122.4010, "San Francisco"),
            ("Mission Coffee", 37.7599, -122.4148, "San Francisco"),
            ("Hayes Valley Coffee", 37.7764, -122.4242, "San Francisco"),
            ("SoMa Coffee", 37.7812, -122.3972, "San Francisco"),
            ("Castro Coffee", 37.7609, -122.4350, "San Francisco"),
            ("Twin Peaks Coffee", 37.7544, -122.4477, "San Francisco"),
            ("Overlapping Espresso", 37.7890, -122.4010, "San Francisco"),
            ("Oakland Uptown Coffee", 37.8087, -122.2680, "Oakland"),
            ("Oakland Lake Coffee", 37.8044, -122.2584, "Oakland"),
            ("Oakland Temescal Coffee", 37.8378, -122.2627, "Oakland"),
            ("Berkeley Coffee", 37.8715, -122.2730, "Berkeley"),
            ("Sacramento Coffee", 38.5816, -121.4944, "Sacramento"),
            ("Sacramento Midtown Coffee", 38.5747, -121.4810, "Sacramento")
        ]
        let cafes = seeds.enumerated().map { index, seed in
            Cafe(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8001-%012d", index + 1))!,
                name: seed.name,
                location: CLLocationCoordinate2D(
                    latitude: seed.latitude,
                    longitude: seed.longitude
                ),
                address: "\(index + 1) Test Street, \(seed.city), CA",
                isFavorite: index.isMultiple(of: 4),
                wantToTry: index.isMultiple(of: 5),
                averageRating: 2.5 + (Double(index % 5) * 0.5),
                visitCount: 1
            )
        }
        let visits = cafes.enumerated().map { index, cafe in
            Visit(
                cafeId: cafe.id,
                userId: userID,
                drinkType: .coffee,
                overallScore: 2.5 + (Double(index % 5) * 0.5),
                cafeSessionID: UUID(
                    uuidString: String(format: "00000000-0000-4000-8002-%012d", index + 1)
                )
            )
        }
        return (cafes, visits)
    }

    private func seedUITestMapSearchRecentIfRequested(key: String) {
        guard MugshotLaunchEnvironment.shouldSeedUITestMapSearchRecent else { return }

        let recent = MapSearchRecent(
            title: "Mugshot Test Cafe",
            subtitle: "1 Test Street, Charleston, SC",
            query: "Mugshot Test Cafe, 1 Test Street, Charleston, SC"
        )
        guard let encoded = try? JSONEncoder().encode([recent]) else { return }
        defaults.set(encoded, forKey: key)
    }

    private func seedUITestV3LabParityIfRequested(userID: UUID) {
        guard MugshotLaunchEnvironment.shouldSeedUITestV3LabParity,
              let cafe = appData.cafes.first(where: {
                  $0.id == UUID(uuidString: "00000000-0000-4000-8000-000000000002")
              }) else {
            return
        }

        let sipCriteria = [
            SipRatingCriterionSnapshot(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
                name: "Body / Smoothness",
                score: 1.5,
                weight: SipCriterionImportance.more.weight,
                sortOrder: 0,
                isPinned: true
            ),
            SipRatingCriterionSnapshot(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
                name: "Presentation",
                score: 4,
                weight: SipCriterionImportance.less.weight,
                sortOrder: 1,
                isPinned: false
            ),
            SipRatingCriterionSnapshot(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!,
                name: "Flavor balance",
                score: 3,
                weight: SipCriterionImportance.normal.weight,
                sortOrder: 2,
                isPinned: false
            )
        ]

        let cafeCriteria = [
            SipRatingCriterionSnapshot(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
                name: "Atmosphere",
                score: 3,
                weight: SipCriterionImportance.most.weight,
                sortOrder: 0,
                isPinned: true
            ),
            SipRatingCriterionSnapshot(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
                name: "Value",
                score: 2,
                weight: SipCriterionImportance.more.weight,
                sortOrder: 1,
                isPinned: true
            )
        ]

        let draft = SipDraft(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000100")!,
            ownerUserID: userID,
            context: .cafe,
            cafe: cafe,
            locationName: cafe.consumerDisplayName,
            drinkName: "Iced Orange Creamsicle",
            overallScore: 2.5,
            socialCaption: "Still thinking about that creamsicle.",
            privateNotes: "Orange arrives fast, then leaves a thin milky finish.",
            visibility: .friends,
            ratingCriteria: sipCriteria,
            v3Step: .sip,
            contextNotes: "Bright front room, calmer in the back.",
            rawNoteVisibility: .private,
            contextScore: 3.5,
            contextRatingCriteria: cafeCriteria
        )

        let ownerScope = userID.uuidString.lowercased()
        PinnedCriterionStore.shared.synchronize(sipCriteria, scope: "\(ownerScope).sip")
        PinnedCriterionStore.shared.synchronize(cafeCriteria, scope: "\(ownerScope).context.cafe")
        RecentCriterionSetupStore.shared.remember(sipCriteria, scope: "\(ownerScope).sip")
        RecentCriterionSetupStore.shared.remember(cafeCriteria, scope: "\(ownerScope).context.cafe")
        _ = try? SipDraftStore.shared.save(draft, images: [], in: .user(userID))
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
            let cafe = upsertRemoteCafe(
                summary.cafe,
                isFavorite: summary.state.isFavorite,
                wantToTry: summary.state.wantToTry,
                persist: false
            )
            appData.personalLibraryCafeIDs.insert(cafe.id)
        }
        prunePersonalLibraryMembership()
        save()
    }

    /// Applies the authoritative visited-or-saved projection shared with Map.
    /// Search-only cafes can remain in the local identity cache without leaking
    /// into Saved's All Cafes section.
    func applyPersonalMapSnapshot(_ snapshot: RemoteMapPinSnapshot, for userID: UUID) {
        let belongsToActiveAccount: Bool
        switch storageScope {
        case .user(let activeUserID):
            belongsToActiveAccount = activeUserID == userID
        case .legacy:
            belongsToActiveAccount = appData.currentUser?.id == userID
        case .guest:
            belongsToActiveAccount = false
        }
        guard belongsToActiveAccount else { return }

        personalMapSnapshotUserID = userID
        personalMapSnapshotCache = snapshot

        var authoritativeIDs = Set(
            appData.visits
                .filter { $0.context == .cafe }
                .map(\.cafeId)
        )

        for pin in snapshot.pins {
            let cafe = upsertRemoteCafe(
                pin.cafe,
                isFavorite: pin.isFavorite,
                wantToTry: pin.wantToTry,
                averageRating: pin.score?.value,
                visitCount: pin.visitCount,
                persist: false
            )
            authoritativeIDs.insert(cafe.id)
        }

        appData.personalLibraryCafeIDs = authoritativeIDs
        prunePersonalLibraryMembership()
        save()
    }

    func personalMapSnapshot(for userID: UUID) -> RemoteMapPinSnapshot? {
        personalMapSnapshotUserID == userID ? personalMapSnapshotCache : nil
    }

    private func clearPersonalMapSnapshot() {
        personalMapSnapshotUserID = nil
        personalMapSnapshotCache = nil
    }

    var personalLibraryCafes: [Cafe] {
        appData.cafes.filter { appData.personalLibraryCafeIDs.contains($0.id) }
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
            appleMapsPlaceID: remote.appleMapsPlaceID ?? existing.appleMapsPlaceID,
            mapItemURL: existing.mapItemURL ?? remote.mapItemURL,
            websiteURL: remote.websiteURL ?? existing.websiteURL,
            placeCategory: existing.placeCategory,
            remoteCafeId: summary.cafeID,
            discoveryNote: existing.discoveryNote,
            discoverySource: existing.discoverySource,
            discoveredAt: existing.discoveredAt,
            discoveryAttributionConsumedAt: existing.discoveryAttributionConsumedAt
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
            applePlaceId: remoteCafe.appleMapsPlaceID ?? remoteCafe.applePlaceId
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
            if isFavorite || wantToTry || hasPersonalCafeVisit(cafeId: cafeId) {
                appData.personalLibraryCafeIDs.insert(cafeId)
            } else {
                appData.personalLibraryCafeIDs.remove(cafeId)
            }
            save()
        }
    }

    /// Completes the Want to Try lifecycle after a cafe sip is durably saved.
    /// The cafe remains in All Cafes even before the next remote snapshot.
    @discardableResult
    func completeWantToTryAfterSip(at cafe: Cafe) -> Cafe? {
        guard let index = appData.cafes.firstIndex(where: {
            $0.id == cafe.id
                || (cafe.remoteCafeId != nil && $0.remoteCafeId == cafe.remoteCafeId)
                || ($0.remoteCafeId != nil && $0.remoteCafeId == cafe.id)
        }), appData.cafes[index].wantToTry else { return nil }
        let previous = appData.cafes[index]
        appData.cafes[index].wantToTry = false
        appData.personalLibraryCafeIDs.insert(appData.cafes[index].id)
        save()
        return previous
    }

    func restoreWantToTry(after completionCafe: Cafe) {
        guard let index = appData.cafes.firstIndex(where: {
            $0.id == completionCafe.id
                || (completionCafe.remoteCafeId != nil && $0.remoteCafeId == completionCafe.remoteCafeId)
                || ($0.remoteCafeId != nil && $0.remoteCafeId == completionCafe.id)
        }) else { return }
        appData.cafes[index].wantToTry = true
        appData.personalLibraryCafeIDs.insert(appData.cafes[index].id)
        save()
    }
    
    func getCafe(id: UUID) -> Cafe? {
        return appData.cafes.first(where: { $0.id == id })
    }
    
    func toggleCafeFavorite(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].isFavorite.toggle()
            synchronizePersonalLibraryMembership(for: cafeId)
            save()
        }
    }
    
    func toggleCafeWantToTry(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].wantToTry.toggle()
            synchronizePersonalLibraryMembership(for: cafeId)
            save()
        }
    }

    @discardableResult
    func saveDiscoveryCandidate(
        _ candidate: DiscoveryPlaceCandidate,
        wantToTry: Bool,
        note: String?,
        source: DiscoveryAttributionSource
    ) -> Cafe {
        var cafe = candidate.cafe
        if let existing = appData.cafes.first(where: {
            ($0.appleMapsPlaceID != nil && $0.appleMapsPlaceID == candidate.appleMapsPlaceID)
                || CafeIdentity.key(for: $0) == CafeIdentity.key(for: cafe)
        }) {
            cafe = existing
        } else {
            addCafe(cafe)
        }

        guard let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) else {
            return cafe
        }
        appData.cafes[index].appleMapsPlaceID = candidate.appleMapsPlaceID
            ?? appData.cafes[index].appleMapsPlaceID
        appData.cafes[index].websiteURL = candidate.websiteURL
            ?? appData.cafes[index].websiteURL
        appData.cafes[index].wantToTry = wantToTry || appData.cafes[index].wantToTry
        appData.cafes[index].discoveryNote = note?.remoteTrimmedNonEmpty
            ?? appData.cafes[index].discoveryNote
        appData.cafes[index].discoverySource = source
        appData.cafes[index].discoveredAt = appData.cafes[index].discoveredAt ?? Date()
        synchronizePersonalLibraryMembership(for: cafe.id)
        save()
        return appData.cafes[index]
    }

    func updateDiscoveryNote(_ note: String?, for cafeID: UUID) {
        guard let index = appData.cafes.firstIndex(where: { $0.id == cafeID }) else { return }
        appData.cafes[index].discoveryNote = note?.remoteTrimmedNonEmpty
        save()
    }

    @discardableResult
    func consumeDiscoveryAttribution(for cafeID: UUID, at date: Date = Date()) -> Bool {
        guard let index = appData.cafes.firstIndex(where: { $0.id == cafeID }),
              appData.cafes[index].discoverySource != nil,
              appData.cafes[index].discoveryAttributionConsumedAt == nil else { return false }
        appData.cafes[index].discoveryAttributionConsumedAt = date
        save()
        return true
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
            appleMapsPlaceID: existing.appleMapsPlaceID ?? remote.appleMapsPlaceID,
            mapItemURL: existing.mapItemURL ?? remote.mapItemURL,
            websiteURL: existing.websiteURL ?? remote.websiteURL,
            placeCategory: existing.placeCategory,
            remoteCafeId: remote.remoteCafeId ?? existing.remoteCafeId ?? remote.id,
            discoveryNote: existing.discoveryNote,
            discoverySource: existing.discoverySource,
            discoveredAt: existing.discoveredAt,
            discoveryAttributionConsumedAt: existing.discoveryAttributionConsumedAt
        )
    }
    
    // Find existing Cafe by location (within ~50 meters) or create new one
    func findOrCreateCafe(from mapItem: MKMapItem) -> Cafe {
        let appleMapsPlaceID = mapItem.identifier?.rawValue.remoteTrimmedNonEmpty
        guard let location = mapItem.placemark.location?.coordinate else {
            let cafe = Cafe(
                name: mapItem.name ?? "Cafe",
                address: formatAddress(from: mapItem.placemark),
                appleMapsPlaceID: appleMapsPlaceID,
                websiteURL: mapItem.url?.absoluteString,
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
            appleMapsPlaceID: appleMapsPlaceID,
            websiteURL: mapItem.url?.absoluteString,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
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
                if updatedCafe.appleMapsPlaceID == nil {
                    updatedCafe.appleMapsPlaceID = appleMapsPlaceID
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
            appleMapsPlaceID: appleMapsPlaceID,
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
        if visit.context == .cafe {
            appData.personalLibraryCafeIDs.insert(visit.cafeId)
        }
        
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

    /// Inserts a visit once or replaces every stale copy that shares its
    /// stable identifier. This is the local recovery-safe counterpart to the
    /// remote idempotent visit write.
    func upsertVisit(_ visit: Visit) {
        let matchingIndices = appData.visits.indices.filter {
            appData.visits[$0].id == visit.id
        }
        let priorCafeIDs = Set(matchingIndices.map { appData.visits[$0].cafeId })

        if let firstMatchingIndex = matchingIndices.first {
            appData.visits.removeAll { $0.id == visit.id }
            appData.visits.insert(
                visit,
                at: min(firstMatchingIndex, appData.visits.endIndex)
            )
        } else {
            appData.visits.append(visit)
        }

        if visit.context == .cafe {
            appData.personalLibraryCafeIDs.insert(visit.cafeId)
        }

        recalculateCafeStats(for: priorCafeIDs.union([visit.cafeId]))
        for cafeID in priorCafeIDs where cafeID != visit.cafeId {
            synchronizePersonalLibraryMembership(for: cafeID)
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
            synchronizePersonalLibraryMembership(for: visit.cafeId)
            save()
        }

    private func hasPersonalCafeVisit(cafeId: UUID) -> Bool {
        appData.visits.contains { $0.context == .cafe && $0.cafeId == cafeId }
    }

    private func synchronizePersonalLibraryMembership(for cafeId: UUID) {
        guard let cafe = appData.cafes.first(where: { $0.id == cafeId }) else {
            appData.personalLibraryCafeIDs.remove(cafeId)
            return
        }
        if cafe.isFavorite || cafe.wantToTry || hasPersonalCafeVisit(cafeId: cafeId) {
            appData.personalLibraryCafeIDs.insert(cafeId)
        } else {
            appData.personalLibraryCafeIDs.remove(cafeId)
        }
    }

    private func prunePersonalLibraryMembership() {
        let knownCafeIDs = Set(appData.cafes.map(\.id))
        appData.personalLibraryCafeIDs.formIntersection(knownCafeIDs)
        for cafe in appData.cafes where cafe.isFavorite || cafe.wantToTry || hasPersonalCafeVisit(cafeId: cafe.id) {
            appData.personalLibraryCafeIDs.insert(cafe.id)
        }
    }

    private func recalculateCafeStats(for cafeIDs: Set<UUID>) {
        for cafeID in cafeIDs {
            guard let cafeIndex = appData.cafes.firstIndex(where: { $0.id == cafeID }) else {
                continue
            }
            let cafeVisits = appData.visits.filter {
                $0.context == .cafe && $0.cafeId == cafeID
            }
            appData.cafes[cafeIndex].visitCount = cafeVisits.count
            let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
            appData.cafes[cafeIndex].averageRating = cafeVisits.isEmpty
                ? 0
                : totalRating / Double(cafeVisits.count)
        }
    }
    
    func getVisitsForCafe(_ cafeId: UUID) -> [Visit] {
        return appData.visits.filter { $0.cafeId == cafeId }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Cafe Session Operations

    func upsertCafeSession(_ session: CafeSession) {
        if let index = appData.cafeSessions.firstIndex(where: { $0.id == session.id }) {
            appData.cafeSessions[index] = session
        } else {
            appData.cafeSessions.append(session)
        }
        save()
    }

    func getCafeSession(id: UUID) -> CafeSession? {
        appData.cafeSessions.first { $0.id == id }
    }

    func getCafeSessions(for cafeId: UUID) -> [CafeSession] {
        appData.cafeSessions
            .filter { $0.cafeID == cafeId }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func cafeRelationshipStats(for cafeId: UUID) -> CafeRelationshipStats {
        CafeRelationshipStats(cafeID: cafeId, sessions: appData.cafeSessions)
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
        let allVisits = appData.visits
            .filter {
                $0.cafeSessionID == nil || $0.cafeSessionSipRole == .primary
            }
            .sorted { $0.createdAt > $1.createdAt }
        
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
