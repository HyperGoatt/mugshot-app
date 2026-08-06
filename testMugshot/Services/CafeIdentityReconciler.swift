import Foundation

struct CafeIdentityReconciliationResult {
    let appData: AppData
    let mergedCafeCount: Int
}

enum CafeIdentityReconciler {
    static func reconcile(_ source: AppData) -> CafeIdentityReconciliationResult {
        let groups = Dictionary(grouping: source.cafes, by: CafeIdentity.key(for:))
        guard groups.values.contains(where: { $0.count > 1 }) else {
            return CafeIdentityReconciliationResult(appData: source, mergedCafeCount: 0)
        }

        var replacementByCafeID: [UUID: UUID] = [:]
        var mergedByKeeperID: [UUID: Cafe] = [:]
        var mergedCafeCount = 0
        let visitCounts = Dictionary(grouping: source.visits, by: \.cafeId).mapValues(\.count)

        for cafes in groups.values where cafes.count > 1 {
            let keeper = cafes.max(by: {
                keeperScore($0, visitCounts: visitCounts) < keeperScore($1, visitCounts: visitCounts)
            })!
            var merged = keeper

            for cafe in cafes {
                replacementByCafeID[cafe.id] = keeper.id
                guard cafe.id != keeper.id else { continue }
                mergedCafeCount += 1
                merged.isFavorite = merged.isFavorite || cafe.isFavorite
                merged.wantToTry = merged.wantToTry || cafe.wantToTry
                merged.location = merged.location ?? cafe.location
                if merged.address.isEmpty { merged.address = cafe.address }
                merged.appleMapsPlaceID = merged.appleMapsPlaceID ?? cafe.appleMapsPlaceID
                merged.mapItemURL = merged.mapItemURL ?? cafe.mapItemURL
                merged.websiteURL = merged.websiteURL ?? cafe.websiteURL
                merged.placeCategory = merged.placeCategory ?? cafe.placeCategory
                merged.remoteCafeId = merged.remoteCafeId ?? cafe.remoteCafeId
                merged.discoveryNote = merged.discoveryNote ?? cafe.discoveryNote
                merged.discoverySource = merged.discoverySource ?? cafe.discoverySource
                merged.discoveredAt = [merged.discoveredAt, cafe.discoveredAt]
                    .compactMap { $0 }
                    .min()
                merged.discoveryAttributionConsumedAt = [
                    merged.discoveryAttributionConsumedAt,
                    cafe.discoveryAttributionConsumedAt
                ]
                .compactMap { $0 }
                .min()
                if cafe.visitCount > merged.visitCount {
                    merged.visitCount = cafe.visitCount
                    merged.averageRating = cafe.averageRating
                }
            }
            mergedByKeeperID[keeper.id] = merged
        }

        var visits = source.visits
        for index in visits.indices {
            if let replacement = replacementByCafeID[visits[index].cafeId] {
                visits[index].cafeId = replacement
            }
        }
        let reconciledVisitsByCafeID = Dictionary(grouping: visits, by: \.cafeId)

        var emittedIDs = Set<UUID>()
        var cafes: [Cafe] = []
        for cafe in source.cafes {
            let keeperID = replacementByCafeID[cafe.id] ?? cafe.id
            guard emittedIDs.insert(keeperID).inserted else { continue }
            var reconciled = mergedByKeeperID[keeperID] ?? cafe
            let localVisits = reconciledVisitsByCafeID[keeperID] ?? []
            if !localVisits.isEmpty {
                reconciled.visitCount = localVisits.count
                reconciled.averageRating = localVisits.reduce(0) { $0 + $1.overallScore } / Double(localVisits.count)
            }
            cafes.append(reconciled)
        }

        var appData = source
        appData.cafes = cafes
        appData.visits = visits
        return CafeIdentityReconciliationResult(
            appData: appData,
            mergedCafeCount: mergedCafeCount
        )
    }

    private static func keeperScore(_ cafe: Cafe, visitCounts: [UUID: Int]) -> Int {
        var score = (visitCounts[cafe.id] ?? 0) * 100
        if cafe.remoteCafeId != nil { score += 50 }
        if cafe.isFavorite || cafe.wantToTry { score += 20 }
        if cafe.location != nil { score += 5 }
        if !cafe.address.isEmpty { score += 2 }
        return score
    }
}
