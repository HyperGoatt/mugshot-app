import CryptoKit
import Foundation
import Supabase

enum SensorySnapshotServiceError: LocalizedError, Equatable {
    case accountScopeMismatch
    case immutableSnapshotConflict
    case snapshotRequiredForCorrection

    var errorDescription: String? {
        switch self {
        case .accountScopeMismatch:
            return "Tasting Lens data cannot be written into another account's scope."
        case .immutableSnapshotConflict:
            return "This sip already has a different Tasting Lens snapshot. The original was kept unchanged."
        case .snapshotRequiredForCorrection:
            return "This correction needs the original Taste Snapshot."
        }
    }
}

/// Owner-private persistence for immutable Taste Snapshots and account-scoped learning.
///
/// Snapshot writes are insert-only. A retry verifies both snapshot identity and a
/// deterministic payload hash before treating an earlier committed insert as success.
final class SensorySnapshotService {
    private let client: SupabaseClient

    private let snapshotColumns = "snapshot_id, payload_hash, snapshot_payload"
    private let preferenceColumns = "user_id, schema_version, payload, updated_at"

    init(client: SupabaseClient) {
        self.client = client
    }

    @discardableResult
    func insertOnce(
        visitID: UUID,
        userID: UUID,
        snapshot: SipSensorySnapshot
    ) async throws -> SipSensorySnapshot {
        let payload = try SupabaseSensorySnapshotInsert.make(
            visitID: visitID,
            userID: userID,
            snapshot: snapshot
        )

        do {
            try await client
                .from("visit_sensory_snapshots")
                .insert(payload)
                .execute()
            return snapshot
        } catch {
            // A network interruption can arrive after Postgres committed. Never
            // upsert an immutable snapshot; verify the committed payload instead.
            if let stored = try? await fetchStoredSnapshot(visitID: visitID, userID: userID) {
                guard stored.snapshotID == snapshot.id,
                      stored.payloadHash == payload.payloadHash else {
                    throw SensorySnapshotServiceError.immutableSnapshotConflict
                }
                return stored.snapshotPayload
            }
            throw error
        }
    }

    func fetchSnapshot(visitID: UUID, userID: UUID) async throws -> SipSensorySnapshot? {
        try await fetchStoredSnapshot(visitID: visitID, userID: userID)?.snapshotPayload
    }

    func fetchOwnHistory(
        userID: UUID,
        limit: Int = 200
    ) async throws -> [SipSensorySnapshot] {
        let boundedLimit = min(max(limit, 1), 500)
        let rows: [SupabaseSensorySnapshotPayloadRow] = try await client
            .from("visit_sensory_snapshots")
            .select(snapshotColumns)
            .eq("user_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .order("visit_id", ascending: false)
            .limit(boundedLimit)
            .execute()
            .value
        return rows.map(\.snapshotPayload)
    }

    func fetchPreferences(userID: UUID) async throws -> TastingLensUserPreferences? {
        let rows: [SupabaseTastingLensPreferencesRow] = try await client
            .from("tasting_lens_preferences")
            .select(preferenceColumns)
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        guard let preferences = rows.first?.payload else { return nil }
        guard preferences.userID == userID else {
            throw SensorySnapshotServiceError.accountScopeMismatch
        }
        return preferences
    }

    @discardableResult
    func upsertPreferences(
        _ preferences: TastingLensUserPreferences,
        userID: UUID
    ) async throws -> TastingLensUserPreferences {
        guard preferences.userID == userID else {
            throw SensorySnapshotServiceError.accountScopeMismatch
        }
        let row: SupabaseTastingLensPreferencesRow = try await client
            .from("tasting_lens_preferences")
            .upsert(
                SupabaseTastingLensPreferencesUpsert(
                    userID: userID,
                    schemaVersion: preferences.schemaVersion,
                    payload: preferences,
                    updatedAt: preferences.updatedAt
                ),
                onConflict: "user_id"
            )
            .select(preferenceColumns)
            .single()
            .execute()
            .value
        return row.payload
    }

    /// Mirrors a snapshot-specific correction into append-only server history.
    /// Global prompt preferences remain in the mutable preferences payload.
    func appendCorrection(
        _ dismissal: SensorySuggestionDismissal,
        userID: UUID
    ) async throws {
        guard let snapshotID = dismissal.snapshotID else {
            throw SensorySnapshotServiceError.snapshotRequiredForCorrection
        }
        try await client
            .from("tasting_lens_corrections")
            .insert(SupabaseTastingLensCorrectionInsert(
                id: dismissal.id,
                userID: userID,
                snapshotID: snapshotID,
                targetID: dismissal.targetID,
                scopeID: dismissal.scopeID,
                reason: dismissal.reason.rawValue,
                metadata: [:],
                createdAt: dismissal.createdAt
            ))
            .execute()
    }

    func fetchCorrections(userID: UUID) async throws -> [SensorySuggestionDismissal] {
        let rows: [SupabaseTastingLensCorrectionRow] = try await client
            .from("tasting_lens_corrections")
            .select("id, user_id, snapshot_id, target_id, scope_id, reason, created_at")
            .eq("user_id", value: userID.uuidString)
            .order("created_at", ascending: true)
            .order("id", ascending: true)
            .execute()
            .value
        return rows.map(\.dismissal)
    }

    /// Creates or replaces the deliberately lossy social projection. Call this
    /// only after an explicit user sharing choice; full answers stay owner-only.
    func replacePublicProjection(
        visitID: UUID,
        userID: UUID,
        snapshot: SipSensorySnapshot
    ) async throws {
        try await client
            .from("visit_sensory_public_projections")
            .upsert(
                SupabaseSensoryPublicProjectionUpsert.make(
                    visitID: visitID,
                    userID: userID,
                    snapshot: snapshot
                ),
                onConflict: "visit_id"
            )
            .execute()
    }

    func revokePublicProjection(visitID: UUID, userID: UUID) async throws {
        try await client
            .from("visit_sensory_public_projections")
            .delete()
            .eq("visit_id", value: visitID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    private func fetchStoredSnapshot(
        visitID: UUID,
        userID: UUID
    ) async throws -> SupabaseSensorySnapshotPayloadRow? {
        let rows: [SupabaseSensorySnapshotPayloadRow] = try await client
            .from("visit_sensory_snapshots")
            .select(snapshotColumns)
            .eq("visit_id", value: visitID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}

private struct SupabaseSensorySnapshotInsert: Encodable {
    let visitID: UUID
    let snapshotID: UUID
    let userID: UUID
    let schemaVersion: Int
    let bundleID: String
    let bundleContentVersion: String
    let personalizationScopeID: String
    let depth: String
    let identity: SensoryDrinkIdentity
    let responses: [SipSensoryResponseSnapshot]
    let ownWords: String
    let personalEnjoyment: Double?
    let snapshotPayload: SipSensorySnapshot
    let payloadHash: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case snapshotID = "snapshot_id"
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case bundleID = "bundle_id"
        case bundleContentVersion = "bundle_content_version"
        case personalizationScopeID = "personalization_scope_id"
        case depth, identity, responses
        case ownWords = "own_words"
        case personalEnjoyment = "personal_enjoyment"
        case snapshotPayload = "snapshot_payload"
        case payloadHash = "payload_hash"
        case createdAt = "created_at"
    }

    static func make(
        visitID: UUID,
        userID: UUID,
        snapshot: SipSensorySnapshot
    ) throws -> Self {
        Self(
            visitID: visitID,
            snapshotID: snapshot.id,
            userID: userID,
            schemaVersion: snapshot.schemaVersion,
            bundleID: snapshot.bundleID,
            bundleContentVersion: snapshot.bundleContentVersion,
            personalizationScopeID: snapshot.personalizationScopeID,
            depth: snapshot.depth.rawValue,
            identity: snapshot.identity,
            responses: snapshot.responses,
            ownWords: snapshot.ownWords,
            personalEnjoyment: snapshot.personalEnjoyment?.value,
            snapshotPayload: snapshot,
            payloadHash: try SensoryPayloadHash.make(snapshot),
            createdAt: snapshot.createdAt
        )
    }
}

private struct SupabaseSensorySnapshotPayloadRow: Decodable {
    let snapshotID: UUID
    let payloadHash: String
    let snapshotPayload: SipSensorySnapshot

    enum CodingKeys: String, CodingKey {
        case snapshotID = "snapshot_id"
        case payloadHash = "payload_hash"
        case snapshotPayload = "snapshot_payload"
    }
}

private struct SupabaseTastingLensPreferencesRow: Decodable {
    let userID: UUID
    let schemaVersion: Int
    let payload: TastingLensUserPreferences
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case payload
        case updatedAt = "updated_at"
    }
}

private struct SupabaseTastingLensPreferencesUpsert: Encodable {
    let userID: UUID
    let schemaVersion: Int
    let payload: TastingLensUserPreferences
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case payload
        case updatedAt = "updated_at"
    }
}

private struct SupabaseTastingLensCorrectionInsert: Encodable {
    let id: UUID
    let userID: UUID
    let snapshotID: UUID
    let targetID: String
    let scopeID: String
    let reason: String
    let metadata: [String: String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case snapshotID = "snapshot_id"
        case targetID = "target_id"
        case scopeID = "scope_id"
        case reason, metadata
        case createdAt = "created_at"
    }
}

private struct SupabaseTastingLensCorrectionRow: Decodable {
    let id: UUID
    let userID: UUID
    let snapshotID: UUID
    let targetID: String
    let scopeID: String
    let reason: SensorySuggestionDismissalReason
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case snapshotID = "snapshot_id"
        case targetID = "target_id"
        case scopeID = "scope_id"
        case reason
        case createdAt = "created_at"
    }

    var dismissal: SensorySuggestionDismissal {
        SensorySuggestionDismissal(
            id: id,
            targetID: targetID,
            scopeID: scopeID,
            snapshotID: snapshotID,
            reason: reason,
            createdAt: createdAt
        )
    }
}

private struct SupabaseSensoryPublicProjectionUpsert: Encodable {
    let visitID: UUID
    let snapshotID: UUID
    let userID: UUID
    let schemaVersion: Int
    let bundleID: String
    let bundleContentVersion: String
    let depth: String
    let personalEnjoyment: Double?
    let descriptorIDs: [String]
    let dimensionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case visitID = "visit_id"
        case snapshotID = "snapshot_id"
        case userID = "user_id"
        case schemaVersion = "schema_version"
        case bundleID = "bundle_id"
        case bundleContentVersion = "bundle_content_version"
        case depth
        case personalEnjoyment = "personal_enjoyment"
        case descriptorIDs = "descriptor_ids"
        case dimensionIDs = "dimension_ids"
    }

    static func make(
        visitID: UUID,
        userID: UUID,
        snapshot: SipSensorySnapshot
    ) -> Self {
        let observed = snapshot.responses.filter {
            $0.state == .observed && $0.userConfirmed
        }
        return Self(
            visitID: visitID,
            snapshotID: snapshot.id,
            userID: userID,
            schemaVersion: snapshot.schemaVersion,
            bundleID: snapshot.bundleID,
            bundleContentVersion: snapshot.bundleContentVersion,
            depth: snapshot.depth.rawValue,
            personalEnjoyment: snapshot.personalEnjoyment?.value,
            descriptorIDs: Array(observed.flatMap(\.descriptors).map(\.id).sensoryUnique.prefix(8)),
            dimensionIDs: Array(observed.map { $0.dimension.rawValue }.sensoryUnique.prefix(8))
        )
    }
}

private enum SensoryPayloadHash {
    static func make(_ snapshot: SipSensorySnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(snapshot))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension Array where Element: Hashable {
    var sensoryUnique: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
