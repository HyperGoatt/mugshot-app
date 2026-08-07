import Foundation
import Supabase

struct DiscoveryCandidateEnrichmentSnapshot: Equatable {
    let candidates: [DiscoveryPlaceCandidate]
    let evidenceByCandidateID: [String: [DiscoveryEvidence]]
}

struct DiscoveryCandidateEnrichmentRow: Decodable, Equatable {
    let candidateIndex: Int
    let appleMapsPlaceID: String?
    let cafeID: UUID?
    let isFavorite: Bool
    let wantToTry: Bool
    let friendEvidence: [FriendEvidence]
    let publicListEvidence: [PublicListEvidence]
    let practicalEvidence: [PracticalEvidence]

    struct FriendEvidence: Decodable, Equatable {
        let visitID: UUID
        let author: CafeListPerson
        let drink: String?
        let score: Double?
        let photoURL: String?

        enum CodingKeys: String, CodingKey {
            case visitID = "visit_id"
            case author, drink, score
            case photoURL = "photo_url"
        }
    }

    struct PublicListEvidence: Decodable, Equatable {
        let listID: UUID
        let title: String
        let creator: CafeListPerson

        enum CodingKeys: String, CodingKey {
            case listID = "list_id"
            case title, creator
        }
    }

    struct PracticalEvidence: Decodable, Equatable {
        let descriptorID: String
        let sessionCount: Int
        let contributorCount: Int

        enum CodingKeys: String, CodingKey {
            case descriptorID = "descriptor_id"
            case sessionCount = "session_count"
            case contributorCount = "contributor_count"
        }
    }

    enum CodingKeys: String, CodingKey {
        case candidateIndex = "candidate_index"
        case appleMapsPlaceID = "apple_maps_place_id"
        case cafeID = "cafe_id"
        case isFavorite = "is_favorite"
        case wantToTry = "want_to_try"
        case friendEvidence = "friend_evidence"
        case publicListEvidence = "public_list_evidence"
        case practicalEvidence = "practical_evidence"
    }
}

enum DiscoveryCandidateEnrichmentMapper {
    static func map(
        candidates: [DiscoveryPlaceCandidate],
        rows: [DiscoveryCandidateEnrichmentRow]
    ) -> DiscoveryCandidateEnrichmentSnapshot {
        var enriched = candidates
        var evidenceByCandidateID: [String: [DiscoveryEvidence]] = [:]

        for row in rows {
            // PostgreSQL WITH ORDINALITY is one-based.
            let index = row.candidateIndex - 1
            guard enriched.indices.contains(index) else { continue }

            let original = enriched[index]
            let candidate = original.applying(
                remoteCafeID: row.cafeID,
                isFavorite: row.isFavorite,
                isWantToTry: row.wantToTry
            )
            enriched[index] = candidate

            var evidence: [DiscoveryEvidence] = []
            if row.wantToTry {
                evidence.append(DiscoveryEvidence(
                    kind: .wantToTry,
                    reason: "Saved in your Want to Try"
                ))
            }
            evidence.append(contentsOf: row.friendEvidence.compactMap(friendEvidence))
            evidence.append(contentsOf: row.publicListEvidence.compactMap(publicListEvidence))
            evidence.append(contentsOf: row.practicalEvidence.compactMap(practicalEvidence))
            evidenceByCandidateID[candidate.id] = evidence
        }

        return DiscoveryCandidateEnrichmentSnapshot(
            candidates: enriched,
            evidenceByCandidateID: evidenceByCandidateID
        )
    }

    private static func friendEvidence(
        _ row: DiscoveryCandidateEnrichmentRow.FriendEvidence
    ) -> DiscoveryEvidence? {
        guard row.author.identityState == .visible,
              let authorID = row.author.userID else { return nil }
        let authorName = row.author.visibleName
        let drink = row.drink?.remoteTrimmedNonEmpty?.lowercased()
        let reason: String
        if let drink, (row.score ?? 0) >= 4 {
            reason = "\(authorName) loved the \(drink)"
        } else if let drink {
            reason = "\(authorName) ordered the \(drink)"
        } else {
            reason = "\(authorName) logged a Mugshot here"
        }
        let strength = row.score.map { min(max($0 / 5, 0.25), 1) } ?? 0.65
        return DiscoveryEvidence(
            kind: .friendVisit,
            reason: reason,
            strength: strength,
            authorID: authorID,
            authorName: authorName,
            tags: ["visit:\(row.visitID.uuidString.lowercased())"]
        )
    }

    private static func publicListEvidence(
        _ row: DiscoveryCandidateEnrichmentRow.PublicListEvidence
    ) -> DiscoveryEvidence? {
        guard row.creator.identityState == .visible else { return nil }
        let title = row.title.remoteTrimmedNonEmpty ?? "a list you follow"
        let creatorName = row.creator.attributionName
        return DiscoveryEvidence(
            kind: .publicList,
            reason: "From \(creatorName)'s \(title)",
            strength: 0.75,
            authorID: row.creator.userID,
            authorName: creatorName,
            tags: ["list:\(row.listID.uuidString.lowercased())"]
        )
    }

    private static func practicalEvidence(
        _ row: DiscoveryCandidateEnrichmentRow.PracticalEvidence
    ) -> DiscoveryEvidence? {
        let presentation: (reason: String, tags: [String])?
        switch row.descriptorID {
        case "cafe.fit.work_study":
            presentation = ("Visitors found it good for work", ["work_study"])
        case "cafe.descriptor.comfort_and_practicality.wifi":
            presentation = ("Visitors liked the Wi-Fi", ["wifi"])
        case "cafe.descriptor.comfort_and_practicality.outlets":
            presentation = ("Visitors liked the outlet setup", ["outlets"])
        case "cafe.descriptor.comfort_and_practicality.table_space":
            presentation = ("Visitors liked the table space", ["table_space"])
        case "cafe.descriptor.comfort_and_practicality.seating":
            presentation = ("Visitors liked the seating", ["seating"])
        case "cafe.descriptor.comfort_and_practicality.accessibility":
            presentation = ("Visitors noted useful accessibility", ["accessible"])
        case "cafe.descriptor.comfort_and_practicality.group_seating":
            presentation = ("Visitors found it good for groups", ["group_friendly"])
        case "cafe.descriptor.music_and_sound.volume":
            presentation = ("Visitors liked the sound level", ["sound"])
        case "cafe.descriptor.music_and_sound.conversation_noise":
            presentation = ("Visitors liked the conversation level", ["sound"])
        case "cafe.descriptor.music_and_sound.calm_or_stimulation":
            presentation = ("Visitors liked the atmosphere's energy", ["atmosphere"])
        default:
            presentation = nil
        }
        guard let presentation else { return nil }
        let strength = min(1, 0.55 + Double(row.contributorCount - 3) * 0.08)
        return DiscoveryEvidence(
            kind: .practicalFit,
            reason: presentation.reason,
            strength: strength,
            tags: presentation.tags + ["sessions:\(row.sessionCount)"]
        )
    }
}

final class DiscoveryCandidateEnrichmentService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func enrich(
        _ candidates: [DiscoveryPlaceCandidate]
    ) async throws -> DiscoveryCandidateEnrichmentSnapshot {
        let bounded = Array(candidates.prefix(100))
        guard !bounded.isEmpty else {
            return DiscoveryCandidateEnrichmentSnapshot(
                candidates: [],
                evidenceByCandidateID: [:]
            )
        }
        let rows: [DiscoveryCandidateEnrichmentRow] = try await client.rpc(
            "enrich_discovery_candidates_v1",
            params: EnrichmentParameters(
                candidates: bounded.map(EnrichmentCandidate.init)
            )
        ).execute().value
        return DiscoveryCandidateEnrichmentMapper.map(
            candidates: bounded,
            rows: rows
        )
    }
}

private struct EnrichmentParameters: Encodable {
    let candidates: [EnrichmentCandidate]
    enum CodingKeys: String, CodingKey { case candidates = "p_candidates" }
}

private struct EnrichmentCandidate: Encodable {
    let appleMapsPlaceID: String?
    let name: String
    let latitude: Double
    let longitude: Double

    init(_ candidate: DiscoveryPlaceCandidate) {
        appleMapsPlaceID = candidate.appleMapsPlaceID
        name = candidate.name
        latitude = candidate.latitude
        longitude = candidate.longitude
    }

    enum CodingKeys: String, CodingKey {
        case appleMapsPlaceID = "apple_maps_place_id"
        case name, latitude, longitude
    }
}
