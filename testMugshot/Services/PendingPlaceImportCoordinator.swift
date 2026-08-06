import Foundation
import Supabase

struct PendingPlaceImportRecovery: Identifiable, Equatable {
    let command: PendingPlaceImport
    let eligibleLists: [ShareExtensionCafeListCacheEntry]
    var id: UUID { command.commandID }
}

enum PendingPlaceImportFailureDisposition: Equatable {
    case retry
    case destinationRecovery
}

enum PendingPlaceImportFailurePolicy {
    static func disposition(
        for error: Error,
        hasDestination: Bool
    ) -> PendingPlaceImportFailureDisposition {
        guard hasDestination,
              let postgrestError = error as? PostgrestError,
              postgrestError.code == "42501" else {
            return .retry
        }
        return .destinationRecovery
    }
}

@MainActor
final class PendingPlaceImportCoordinator: ObservableObject {
    @Published private(set) var recovery: PendingPlaceImportRecovery?
    @Published private(set) var lastImportedCafeName: String?

    private var isDraining = false

    func drain(dataManager: DataManager, accountID: UUID?) async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        let queue = PendingPlaceImportQueue.shared
        for command in await queue.imports() {
            guard command.accountContext == nil || command.accountContext == accountID else { continue }
            do {
                try await process(command, dataManager: dataManager, accountID: accountID)
                await queue.remove(command.commandID)
                lastImportedCafeName = command.name
                if recovery?.id == command.commandID { recovery = nil }
            } catch {
                var retry = command
                if PendingPlaceImportFailurePolicy.disposition(
                    for: error,
                    hasDestination: command.destinationListID != nil
                ) == .destinationRecovery {
                    retry.retryState = .needsDestinationRecovery
                    await queue.update(retry)
                    recovery = PendingPlaceImportRecovery(
                        command: retry,
                        eligibleLists: await queue.eligibleLists(accountID: accountID)
                    )
                } else {
                    // Transport and session failures stay queued. The app drains
                    // them again on its next active cycle without telling the
                    // person that a still-valid list has gone stale.
                    retry.retryState = .queued
                    await queue.update(retry)
                }
                break
            }
        }
    }

    func keepInWantToTry(
        _ command: PendingPlaceImport,
        dataManager: DataManager,
        accountID: UUID?
    ) async {
        var recovered = command
        recovered.destinationListID = nil
        recovered.destinationListTitle = nil
        recovered.retryState = .queued
        await PendingPlaceImportQueue.shared.update(recovered)
        recovery = nil
        await drain(dataManager: dataManager, accountID: accountID)
    }

    func retry(
        _ command: PendingPlaceImport,
        in list: ShareExtensionCafeListCacheEntry,
        dataManager: DataManager,
        accountID: UUID?
    ) async {
        var recovered = command
        recovered.destinationListID = list.id
        recovered.destinationListTitle = list.title
        recovered.retryState = .queued
        await PendingPlaceImportQueue.shared.update(recovered)
        recovery = nil
        await drain(dataManager: dataManager, accountID: accountID)
    }

    func dismissRecovery() {
        recovery = nil
    }

    private func process(
        _ command: PendingPlaceImport,
        dataManager: DataManager,
        accountID: UUID?
    ) async throws {
        let candidate = DiscoveryPlaceCandidate(cafe: command.cafe)
        let localCafe = dataManager.saveDiscoveryCandidate(
            candidate,
            wantToTry: command.wantToTry,
            note: command.note,
            source: .shareImport
        )

        guard let accountID else { return }
        let client = try SupabaseClientProvider.shared.client()
        let result = try await CafeStateService(client: client).setCafeState(
            userId: accountID,
            cafe: localCafe,
            isFavorite: localCafe.isFavorite,
            wantToTry: command.wantToTry,
            discoveryNote: command.note,
            discoverySource: .shareImport,
            discoveredAt: command.createdAt
        )
        let synced = dataManager.upsertRemoteCafe(
            result.cafe,
            isFavorite: result.state.isFavorite,
            wantToTry: result.state.wantToTry
        )
        dataManager.updateDiscoveryNote(command.note, for: synced.id)
        _ = try? await DiscoveryInteractionService(client: client).record(
            id: command.id,
            cafeID: result.cafe.id,
            appleMapsPlaceID: result.cafe.appleMapsPlaceID,
            source: .shareImport,
            kind: .shareImported,
            occurredAt: command.createdAt
        )

        if let listID = command.destinationListID {
            try await CollaborativeCafeListService(client: client).add(
                cafeID: result.cafe.id,
                to: listID,
                accountID: accountID
            )
        }
    }

}
