//
//  MapPinService.swift
//  testMugshot
//

import Foundation

/// The private journal data that is eligible to appear as a pin on a person's
/// own map. Pins never come from the public feed: they are derived only from
/// the signed-in person's completed visit logs and active saved-cafe states.
struct RemoteMapPin: Identifiable, Equatable {
    let cafe: SupabaseCafeSummary
    let visitCount: Int
    let averageScore: Double
    let isFavorite: Bool
    let wantToTry: Bool

    var id: UUID { cafe.id }

    var localCafe: Cafe {
        cafe.localCafe(
            isFavorite: isFavorite,
            wantToTry: wantToTry,
            averageRating: averageScore,
            visitCount: visitCount
        )
    }
}

struct RemoteMapPinSnapshot: Equatable {
    let pins: [RemoteMapPin]
    let cafeStates: [RemoteCafeStateSummary]

    static func make(
        visits: [RemoteVisitSummary],
        cafeStates: [RemoteCafeStateSummary]
    ) -> RemoteMapPinSnapshot {
        let activeStates = cafeStates.filter {
            $0.state.isFavorite || $0.state.wantToTry
        }
        let statesByCafeID = Dictionary(
            uniqueKeysWithValues: activeStates.map { ($0.cafe.id, $0) }
        )
        let visitsByCafeID = Dictionary(grouping: visits.compactMap { summary -> RemoteVisitSummary? in
            summary.cafe == nil || summary.visit.overallScore <= 0 ? nil : summary
        }) { $0.cafe!.id }

        let cafeIDs = Set(visitsByCafeID.keys).union(statesByCafeID.keys)
        let pins = cafeIDs.compactMap { cafeID -> RemoteMapPin? in
            let cafeVisits = visitsByCafeID[cafeID] ?? []
            let state = statesByCafeID[cafeID]
            guard let cafe = cafeVisits.first?.cafe ?? state?.cafe else {
                return nil
            }

            let totalScore = cafeVisits.reduce(0.0) { $0 + $1.visit.overallScore }
            return RemoteMapPin(
                cafe: cafe,
                visitCount: cafeVisits.count,
                averageScore: cafeVisits.isEmpty ? 0 : totalScore / Double(cafeVisits.count),
                isFavorite: state?.state.isFavorite ?? false,
                wantToTry: state?.state.wantToTry ?? false
            )
        }
        .sorted { lhs, rhs in
            if lhs.visitCount == rhs.visitCount {
                return lhs.cafe.consumerDisplayName < rhs.cafe.consumerDisplayName
            }
            return lhs.visitCount > rhs.visitCount
        }

        return RemoteMapPinSnapshot(pins: pins, cafeStates: cafeStates)
    }

    static func make(
        mapVisits: [RemoteMapVisitSeed],
        cafeStates: [RemoteCafeStateSummary]
    ) -> RemoteMapPinSnapshot {
        let activeStates = cafeStates.filter { $0.state.isFavorite || $0.state.wantToTry }
        let statesByCafeID = Dictionary(uniqueKeysWithValues: activeStates.map { ($0.cafe.id, $0) })
        let visitsByCafeID = Dictionary(
            grouping: mapVisits.filter { $0.overallScore > 0 },
            by: { $0.cafe.id }
        )
        let cafeIDs = Set(visitsByCafeID.keys).union(statesByCafeID.keys)

        let pins = cafeIDs.compactMap { cafeID -> RemoteMapPin? in
            let visits = visitsByCafeID[cafeID] ?? []
            let state = statesByCafeID[cafeID]
            guard let cafe = visits.first?.cafe ?? state?.cafe else { return nil }
            return RemoteMapPin(
                cafe: cafe,
                visitCount: visits.count,
                averageScore: visits.isEmpty ? 0 : visits.reduce(0) { $0 + $1.overallScore } / Double(visits.count),
                isFavorite: state?.state.isFavorite ?? false,
                wantToTry: state?.state.wantToTry ?? false
            )
        }
        .sorted { lhs, rhs in
            lhs.visitCount == rhs.visitCount
                ? lhs.cafe.consumerDisplayName < rhs.cafe.consumerDisplayName
                : lhs.visitCount > rhs.visitCount
        }

        return RemoteMapPinSnapshot(pins: pins, cafeStates: cafeStates)
    }
}

struct RemoteMapVisitSeed: Equatable {
    let cafe: SupabaseCafeSummary
    let overallScore: Double
}

final class MapPinService {
    private let visitService: VisitService
    private let cafeStateService: CafeStateService

    init(
        visitService: VisitService,
        cafeStateService: CafeStateService
    ) {
        self.visitService = visitService
        self.cafeStateService = cafeStateService
    }

    func fetchSnapshot(userId: UUID) async throws -> RemoteMapPinSnapshot {
        async let visits = visitService.fetchMapVisitSeeds(userId: userId)
        async let cafeStates = cafeStateService.fetchCafeStates(userId: userId)

        return try await RemoteMapPinSnapshot.make(
            mapVisits: visits,
            cafeStates: cafeStates
        )
    }
}
