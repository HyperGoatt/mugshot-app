//
//  MapPinService.swift
//  testMugshot
//

import Foundation

enum MapPinScoreSource: String, Equatable {
    case cafe
    case sip

    var label: String {
        switch self {
        case .cafe: "Cafe avg"
        case .sip: "Sip avg"
        }
    }
}

enum MapPinScoreAudience: Equatable {
    case personal
    case friends
}

struct MapPinScore: Equatable {
    let value: Double
    let source: MapPinScoreSource
    let audience: MapPinScoreAudience
    let ratedCafeSessionCount: Int
    let physicalSessionCount: Int
    let sipCount: Int
    let contributorCount: Int
    let relationshipStage: CafeRelationshipStage

    var sourceLabel: String { source.label }

    var pinUseTitle: String {
        switch (source, audience) {
        case (.cafe, .personal): "Pin uses your Cafe average"
        case (.sip, .personal): "Pin uses your Sip fallback"
        case (.cafe, .friends): "Pin uses friends’ Cafe average"
        case (.sip, .friends): "Pin uses friends’ Sip fallback"
        }
    }

    var accessibilityLabel: String {
        let owner = audience == .friends ? "Friends’" : "Your"
        return "\(owner) \(source.label.lowercased()) \(String(format: "%.1f", value))"
    }

    var evidenceDescription: String {
        switch (source, audience) {
        case (.cafe, .personal):
            return "\(relationshipStage.title) · \(ratedCafeSessionCount) rated \(Self.sessionNoun(ratedCafeSessionCount))"
        case (.cafe, .friends):
            return "\(ratedCafeSessionCount) rated \(Self.sessionNoun(ratedCafeSessionCount)) · \(contributorCount) \(Self.friendNoun(contributorCount))"
        case (.sip, .personal):
            return "\(sipCount) \(Self.sipNoun(sipCount)) across \(physicalSessionCount) \(Self.visitNoun(physicalSessionCount))"
        case (.sip, .friends):
            return "\(sipCount) \(Self.sipNoun(sipCount)) across \(physicalSessionCount) \(Self.visitNoun(physicalSessionCount)) · \(contributorCount) \(Self.friendNoun(contributorCount))"
        }
    }

    private static func sessionNoun(_ count: Int) -> String {
        count == 1 ? "Cafe Session" : "Cafe Sessions"
    }

    private static func sipNoun(_ count: Int) -> String {
        count == 1 ? "sip" : "sips"
    }

    private static func visitNoun(_ count: Int) -> String {
        count == 1 ? "visit" : "visits"
    }

    private static func friendNoun(_ count: Int) -> String {
        count == 1 ? "friend" : "friends"
    }
}

struct MapSipScoreSeed: Equatable {
    let overallScore: Double
    let cafeSessionID: UUID?
}

enum MapPinScoreResolver {
    static func resolve(
        sips: [MapSipScoreSeed],
        cafeSummary: RemoteCafeExperienceSummary?,
        audience: MapPinScoreAudience,
        contributorCount: Int = 1
    ) -> MapPinScore? {
        if let cafeSummary,
           let cafeScore = cafeSummary.averageCafeRating,
           cafeScore > 0,
           cafeSummary.ratedSessionCount > 0 {
            return MapPinScore(
                value: cafeScore,
                source: .cafe,
                audience: audience,
                ratedCafeSessionCount: cafeSummary.ratedSessionCount,
                physicalSessionCount: cafeSummary.physicalSessionCount,
                sipCount: 0,
                contributorCount: max(cafeSummary.contributorCount, contributorCount),
                relationshipStage: audience == .personal
                    ? cafeSummary.relationshipStage
                    : .unrated
            )
        }

        return sessionBalancedSipScore(
            sips,
            audience: audience,
            contributorCount: contributorCount
        )
    }

    static func sessionBalancedSipScore(
        _ sips: [MapSipScoreSeed],
        audience: MapPinScoreAudience,
        contributorCount: Int = 1
    ) -> MapPinScore? {
        let ratedSips = sips.filter { $0.overallScore > 0 && $0.overallScore.isFinite }
        guard !ratedSips.isEmpty else { return nil }

        let linkedSessionScores = Dictionary(
            grouping: ratedSips.compactMap { sip in
                sip.cafeSessionID.map { ($0, sip.overallScore) }
            },
            by: \.0
        )
        .values
        .map { entries in
            entries.map(\.1).reduce(0, +) / Double(entries.count)
        }
        let legacySessionScores = ratedSips
            .filter { $0.cafeSessionID == nil }
            .map(\.overallScore)
        let physicalSessionScores = linkedSessionScores + legacySessionScores
        guard !physicalSessionScores.isEmpty else { return nil }

        return MapPinScore(
            value: physicalSessionScores.reduce(0, +) / Double(physicalSessionScores.count),
            source: .sip,
            audience: audience,
            ratedCafeSessionCount: 0,
            physicalSessionCount: physicalSessionScores.count,
            sipCount: ratedSips.count,
            contributorCount: contributorCount,
            relationshipStage: .unrated
        )
    }
}

/// The private journal data that is eligible to appear as a pin on a person's
/// own map. Pins never come from the public feed: they are derived only from
/// the signed-in person's completed sip logs and active saved-cafe states.
///
/// A true Cafe Pulse aggregate wins immediately. When none exists, a
/// session-balanced Sip average is an explicitly typed fallback rather than a
/// synthetic Cafe rating.
struct RemoteMapPin: Identifiable, Equatable {
    let cafe: SupabaseCafeSummary
    let visitCount: Int
    let score: MapPinScore?
    let isFavorite: Bool
    let wantToTry: Bool
    let lastActivityAt: Date?
    let coverPhotoURL: String?

    var id: UUID { cafe.id }
    var averageScore: Double { score?.value ?? 0 }

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
        cafeStates: [RemoteCafeStateSummary],
        cafeExperienceSummaries: [RemoteCafeExperienceSummary] = []
    ) -> RemoteMapPinSnapshot {
        let activeStates = cafeStates.filter {
            $0.state.isFavorite || $0.state.wantToTry
        }
        let cafeIndex = stitchedCafeIndex(
            visits.compactMap(\.cafe) + activeStates.map(\.cafe)
        )
        let statesByCafeID = Dictionary(grouping: activeStates) {
            cafeIndex.canonicalIDByCafeID[$0.cafe.id] ?? $0.cafe.id
        }
        let visitsByCafeID = Dictionary(grouping: visits.compactMap { summary -> RemoteVisitSummary? in
            summary.cafe == nil ? nil : summary
        }) { cafeIndex.canonicalIDByCafeID[$0.cafe!.id] ?? $0.cafe!.id }
        let experienceByCafeID = Dictionary(grouping: cafeExperienceSummaries) {
            cafeIndex.canonicalIDByCafeID[$0.cafeID] ?? $0.cafeID
        }

        let cafeIDs = Set(visitsByCafeID.keys).union(statesByCafeID.keys)
        let pins = cafeIDs.compactMap { cafeID -> RemoteMapPin? in
            let cafeVisits = visitsByCafeID[cafeID] ?? []
            let states = statesByCafeID[cafeID] ?? []
            let experience = aggregateExperience(
                experienceByCafeID[cafeID] ?? [],
                canonicalCafeID: cafeID
            )
            let legacySipCount = cafeVisits.filter { $0.visit.cafeSessionID == nil }.count
            let linkedSessionCount = Set(cafeVisits.compactMap(\.visit.cafeSessionID)).count
            guard let cafe = cafeIndex.cafeByCanonicalID[cafeID]
                ?? cafeVisits.first?.cafe
                ?? states.first?.cafe else {
                return nil
            }
            let score = MapPinScoreResolver.resolve(
                sips: cafeVisits.map {
                    MapSipScoreSeed(
                        overallScore: $0.visit.overallScore,
                        cafeSessionID: $0.visit.cafeSessionID
                    )
                },
                cafeSummary: experience,
                audience: .personal
            )
            let latestVisit = cafeVisits.map(\.visit.createdAtDate).max()
            let latestState = states.compactMap {
                RemoteMapPinDateParser.activityDate(for: $0.state)
            }.max()

            return RemoteMapPin(
                cafe: cafe,
                visitCount: legacySipCount
                    + max(experience?.physicalSessionCount ?? 0, linkedSessionCount),
                score: score,
                isFavorite: states.contains(where: { $0.state.isFavorite }),
                wantToTry: states.contains(where: { $0.state.wantToTry }),
                lastActivityAt: [latestVisit, latestState].compactMap { $0 }.max(),
                coverPhotoURL: cafeVisits
                    .sorted { $0.visit.createdAtDate > $1.visit.createdAtDate }
                    .compactMap { $0.visit.posterPhotoURL?.remoteTrimmedNonEmpty }
                    .first
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
        cafeStates: [RemoteCafeStateSummary],
        cafeExperienceSummaries: [RemoteCafeExperienceSummary] = []
    ) -> RemoteMapPinSnapshot {
        let activeStates = cafeStates.filter { $0.state.isFavorite || $0.state.wantToTry }
        let cafeIndex = stitchedCafeIndex(mapVisits.map(\.cafe) + activeStates.map(\.cafe))
        let statesByCafeID = Dictionary(grouping: activeStates) {
            cafeIndex.canonicalIDByCafeID[$0.cafe.id] ?? $0.cafe.id
        }
        let visitsByCafeID = Dictionary(grouping: mapVisits) {
            cafeIndex.canonicalIDByCafeID[$0.cafe.id] ?? $0.cafe.id
        }
        let cafeIDs = Set(visitsByCafeID.keys).union(statesByCafeID.keys)
        let experienceByCafeID = Dictionary(grouping: cafeExperienceSummaries) {
            cafeIndex.canonicalIDByCafeID[$0.cafeID] ?? $0.cafeID
        }

        let pins = cafeIDs.compactMap { cafeID -> RemoteMapPin? in
            let visits = visitsByCafeID[cafeID] ?? []
            let states = statesByCafeID[cafeID] ?? []
            let experience = aggregateExperience(
                experienceByCafeID[cafeID] ?? [],
                canonicalCafeID: cafeID
            )
            let legacySipCount = visits.filter { $0.cafeSessionID == nil }.count
            let linkedSessionCount = Set(visits.compactMap(\.cafeSessionID)).count
            guard let cafe = cafeIndex.cafeByCanonicalID[cafeID]
                ?? visits.first?.cafe
                ?? states.first?.cafe else { return nil }
            let score = MapPinScoreResolver.resolve(
                sips: visits.map {
                    MapSipScoreSeed(
                        overallScore: $0.overallScore,
                        cafeSessionID: $0.cafeSessionID
                    )
                },
                cafeSummary: experience,
                audience: .personal
            )
            let latestVisit = visits.map(\.createdAt).max()
            let latestState = states.compactMap {
                RemoteMapPinDateParser.activityDate(for: $0.state)
            }.max()
            return RemoteMapPin(
                cafe: cafe,
                visitCount: legacySipCount
                    + max(experience?.physicalSessionCount ?? 0, linkedSessionCount),
                score: score,
                isFavorite: states.contains(where: { $0.state.isFavorite }),
                wantToTry: states.contains(where: { $0.state.wantToTry }),
                lastActivityAt: [latestVisit, latestState].compactMap { $0 }.max(),
                coverPhotoURL: visits
                    .sorted { $0.createdAt > $1.createdAt }
                    .compactMap { $0.posterPhotoURL?.remoteTrimmedNonEmpty }
                    .first
            )
        }
        .sorted { lhs, rhs in
            lhs.visitCount == rhs.visitCount
                ? lhs.cafe.consumerDisplayName < rhs.cafe.consumerDisplayName
                : lhs.visitCount > rhs.visitCount
        }

        return RemoteMapPinSnapshot(pins: pins, cafeStates: cafeStates)
    }

    private static func stitchedCafeIndex(
        _ cafes: [SupabaseCafeSummary]
    ) -> (
        canonicalIDByCafeID: [UUID: UUID],
        cafeByCanonicalID: [UUID: SupabaseCafeSummary]
    ) {
        let cafesByID = Dictionary(
            cafes.map { ($0.id, $0) },
            uniquingKeysWith: { current, incoming in
                canonicalCafeScore(current) >= canonicalCafeScore(incoming)
                    ? current
                    : incoming
            }
        )
        let groups = CafeIdentity.stitchGroups(cafesByID.values.map { $0.localCafe() })
        var canonicalIDByCafeID: [UUID: UUID] = [:]
        var cafeByCanonicalID: [UUID: SupabaseCafeSummary] = [:]

        for group in groups {
            let summaries = group.compactMap { cafesByID[$0.id] }
            guard let canonical = summaries.max(by: {
                canonicalCafeScore($0) < canonicalCafeScore($1)
            }) else { continue }
            cafeByCanonicalID[canonical.id] = canonical
            for summary in summaries {
                canonicalIDByCafeID[summary.id] = canonical.id
            }
        }

        return (canonicalIDByCafeID, cafeByCanonicalID)
    }

    private static func canonicalCafeScore(_ cafe: SupabaseCafeSummary) -> Int {
        var score = 0
        if cafe.appleMapsPlaceID?.remoteTrimmedNonEmpty != nil { score += 100 }
        if cafe.identityKey?.hasPrefix("apple-mapkit:") == true { score += 50 }
        if cafe.address?.remoteTrimmedNonEmpty != nil { score += 10 }
        if cafe.latitude != nil, cafe.longitude != nil { score += 5 }
        return score
    }

    private static func aggregateExperience(
        _ summaries: [RemoteCafeExperienceSummary],
        canonicalCafeID: UUID
    ) -> RemoteCafeExperienceSummary? {
        guard let preferred = summaries.first(where: { $0.cafeID == canonicalCafeID })
            ?? summaries.first else { return nil }
        let ratedSessionCount = summaries.reduce(0) { $0 + $1.ratedSessionCount }
        let weightedRatingTotal = summaries.reduce(0.0) { total, summary in
            total + ((summary.averageCafeRating ?? 0) * Double(summary.ratedSessionCount))
        }
        return RemoteCafeExperienceSummary(
            schemaVersion: summaries.map(\.schemaVersion).max() ?? preferred.schemaVersion,
            cafeID: canonicalCafeID,
            scope: preferred.scope,
            physicalSessionCount: summaries.reduce(0) { $0 + $1.physicalSessionCount },
            ratedSessionCount: ratedSessionCount,
            contributorCount: summaries.map(\.contributorCount).max() ?? 0,
            averageCafeRating: ratedSessionCount > 0
                ? weightedRatingTotal / Double(ratedSessionCount)
                : nil,
            latestNextMove: preferred.latestNextMove,
            relationshipStageValue: CafeRelationshipStage
                .resolve(ratedSessionCount: ratedSessionCount)
                .rawValue,
            communityThresholdMet: summaries.contains(where: \.communityThresholdMet)
        )
    }
}

struct RemoteMapVisitSeed: Equatable {
    let cafe: SupabaseCafeSummary
    let overallScore: Double
    let cafeSessionID: UUID?
    let createdAt: Date
    let posterPhotoURL: String?
}

private enum RemoteMapPinDateParser {
    static func activityDate(for state: SupabaseCafeStateRow) -> Date? {
        date(from: state.updatedAt) ?? date(from: state.createdAt)
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) {
            return date
        }
        return try? Date(value, strategy: Date.ISO8601FormatStyle())
    }
}

final class MapPinService {
    private let visitService: VisitService
    private let cafeStateService: CafeStateService
    private let cafeSessionService: CafeSessionService

    init(
        visitService: VisitService,
        cafeStateService: CafeStateService,
        cafeSessionService: CafeSessionService
    ) {
        self.visitService = visitService
        self.cafeStateService = cafeStateService
        self.cafeSessionService = cafeSessionService
    }

    func fetchSnapshot(userId: UUID) async throws -> RemoteMapPinSnapshot {
        async let visitsRequest = visitService.fetchMapVisitSeeds(userId: userId)
        async let cafeStatesRequest = cafeStateService.fetchCafeStates(userId: userId)
        let (visits, cafeStates) = try await (visitsRequest, cafeStatesRequest)
        let cafeIDs = Set(visits.map(\.cafe.id)).union(cafeStates.map(\.cafe.id))
        let summaries = try await cafeSessionService.fetchCafeSummaries(
            cafeIDs: Array(cafeIDs),
            scope: .personal
        )

        return RemoteMapPinSnapshot.make(
            mapVisits: visits,
            cafeStates: cafeStates,
            cafeExperienceSummaries: summaries
        )
    }
}
