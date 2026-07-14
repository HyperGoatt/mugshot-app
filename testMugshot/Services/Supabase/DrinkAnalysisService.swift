import Foundation
import Supabase

private struct DrinkAnalysisRequest: Encodable {
    let visitId: UUID

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
    }
}

private struct DrinkAnalysisResponse: Decodable {
    let accepted: Bool
}

final class DrinkAnalysisService {
    private let client: SupabaseClient
    private let retryStore: DrinkAnalysisRetryStore

    init(
        client: SupabaseClient,
        retryStore: DrinkAnalysisRetryStore = .shared
    ) {
        self.client = client
        self.retryStore = retryStore
    }

    func requestAnalysis(visitId: UUID) async throws {
        let response: DrinkAnalysisResponse = try await client.functions.invoke(
            "analyze-drink",
            options: FunctionInvokeOptions(
                method: .post,
                body: DrinkAnalysisRequest(visitId: visitId)
            )
        )
        guard response.accepted else { throw DrinkAnalysisServiceError.notAccepted }
    }

    /// Persists first so termination or a transient network failure cannot
    /// lose the analysis request after the visit itself has been saved.
    func requestAnalysisDurably(visitId: UUID, userId: UUID) async {
        retryStore.enqueue(visitId: visitId, userId: userId)
        do {
            try await requestAnalysis(visitId: visitId)
            retryStore.remove(visitId: visitId, userId: userId)
        } catch {
            // Keep the account-scoped request for the next signed-in launch.
        }
    }

    func retryPendingAnalyses(userId: UUID) async {
        for visitId in retryStore.pendingVisitIDs(userId: userId) {
            do {
                try await requestAnalysis(visitId: visitId)
                retryStore.remove(visitId: visitId, userId: userId)
            } catch {
                // Continue with the remaining requests; each one stays queued.
            }
        }
    }
}

enum DrinkAnalysisServiceError: Error {
    case notAccepted
}

final class DrinkAnalysisRetryStore {
    static let shared = DrinkAnalysisRetryStore()

    private let defaults: UserDefaults
    private let keyPrefix = "MugshotDrinkAnalysisRetry.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pendingVisitIDs(userId: UUID) -> [UUID] {
        (defaults.stringArray(forKey: key(userId)) ?? []).compactMap(UUID.init(uuidString:))
    }

    func enqueue(visitId: UUID, userId: UUID) {
        let ids = Set(pendingVisitIDs(userId: userId)).union([visitId])
        defaults.set(ids.map(\.uuidString).sorted(), forKey: key(userId))
    }

    func remove(visitId: UUID, userId: UUID) {
        let ids = Set(pendingVisitIDs(userId: userId)).subtracting([visitId])
        if ids.isEmpty {
            defaults.removeObject(forKey: key(userId))
        } else {
            defaults.set(ids.map(\.uuidString).sorted(), forKey: key(userId))
        }
    }

    private func key(_ userId: UUID) -> String {
        keyPrefix + userId.uuidString.lowercased()
    }
}
