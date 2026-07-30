import Foundation
import Supabase

final class TastePassportService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchPassport(userID: UUID) async throws -> TastePassportAccessState {
        do {
            let projection: TastePassportProjection? = try await client.rpc(
                "get_taste_passport_v1",
                params: TastePassportUserParameters(userID: userID)
            ).execute().value

            return try TastePassportAccessState.resolve(
                projection,
                requestedUserID: userID
            )
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            return try await fetchCompatibilityPassport(userID: userID)
        }
    }

    func fetchVisibility(accountID: UUID) async throws -> TastePassportVisibility {
        guard client.auth.currentUser?.id == accountID else {
            throw TastePassportContractError.accountScopeMismatch
        }
        let projection: TastePassportVisibilityProjection
        do {
            projection = try await client.rpc(
                "get_taste_passport_visibility_v1"
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw TastePassportContractError.audienceControlsUnavailable
        }
        return try projection.value(forAccountID: accountID)
    }

    @discardableResult
    func setVisibility(
        _ visibility: TastePassportVisibility,
        accountID: UUID
    ) async throws -> TastePassportVisibility {
        guard client.auth.currentUser?.id == accountID else {
            throw TastePassportContractError.accountScopeMismatch
        }
        let rpcConfirmation: String
        do {
            rpcConfirmation = try await client.rpc(
                "set_taste_passport_visibility_v1",
                params: TastePassportVisibilityParameters(
                    visibility: visibility,
                    accountID: accountID
                )
            ).execute().value
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            throw TastePassportContractError.audienceControlsUnavailable
        }
        guard rpcConfirmation == visibility.rawValue else {
            throw TastePassportContractError.saveWasNotConfirmed
        }

        let persistedVisibility = try await fetchVisibility(accountID: accountID)
        guard persistedVisibility == visibility else {
            throw TastePassportContractError.saveWasNotConfirmed
        }
        return persistedVisibility
    }

    private func fetchCompatibilityPassport(
        userID: UUID
    ) async throws -> TastePassportAccessState {
        if client.auth.currentUser?.id == userID {
            async let signalsRequest = TasteGraphService(client: client)
                .fetchSignals(userID: userID)
            async let visitsRequest = VisitService(client: client)
                .fetchRecentVisits(userId: userID, limit: 500)
            let (signals, visits) = try await (signalsRequest, visitsRequest)
            let summary = TasteIdentitySummary.calculate(from: signals, visits: visits)
            return try TastePassportCompatibility.accessState(
                userID: userID,
                summary: summary,
                confidenceBand: TastePassportCompatibility.confidenceBand(signals: signals),
                updatedAt: signals.map(\.updatedAt).max()
            )
        }

        // A missing projection RPC alone is not enough evidence that the
        // backend predates independent Taste Passport audiences. During a
        // partial rollout, falling back to visible posts could bypass an
        // owner's private or friends-only Passport setting. Only the legacy
        // backend, where the independent visibility RPC is also definitively
        // absent, may show this clearly labelled compatibility preview.
        guard await permitsLegacyViewerCompatibilityPreview() else {
            return .hidden
        }

        let payload = try await SocialDiscoveryService(client: client)
            .publicProfile(userID: userID)
        guard payload.profile.id == userID,
              payload.visits.allSatisfy({ $0.userID == nil || $0.userID == userID }) else {
            throw TastePassportContractError.accountScopeMismatch
        }
        let summary = TasteIdentitySummary.publicPassport(from: payload.visits)
        return try TastePassportCompatibility.accessState(
            userID: userID,
            summary: summary,
            confidenceBand: TastePassportCompatibility.publicConfidenceBand(
                visibleVisitCount: payload.visits.count
            )
        )
    }

    private func permitsLegacyViewerCompatibilityPreview() async -> Bool {
        // Taste Passports are an authenticated Mugshot surface. Apart from
        // matching that product contract, this avoids mistaking an anonymous
        // role's lack of RPC access for evidence that the RPC is absent.
        guard client.auth.currentUser != nil else { return false }

        do {
            let _: TastePassportVisibilityProjection = try await client.rpc(
                "get_taste_passport_visibility_v1"
            ).execute().value
            return false
        } catch where SupabaseBackendCompatibility.isMissingFunction(error) {
            return true
        } catch {
            // Authentication, authorization, decoding, transport, and backend
            // failures are not proof of a legacy contract. Fail closed.
            return false
        }
    }
}

private struct TastePassportUserParameters: Encodable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "p_user_id"
    }
}

private struct TastePassportVisibilityParameters: Encodable {
    let visibility: TastePassportVisibility
    let accountID: UUID

    enum CodingKeys: String, CodingKey {
        case visibility = "p_visibility"
        case accountID = "p_account_id"
    }
}
