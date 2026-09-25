import Foundation
import Supabase

struct PendingPlaceImportRecovery: Identifiable, Equatable {
    let command: PendingPlaceImport
    let eligibleLists: [ShareExtensionCafeListCacheEntry]
    var id: UUID { command.commandID }
}

enum PendingPlaceImportNotice: Equatable {
    case completed(cafeName: String)
    case waiting(cafeName: String)
}

struct PendingPlaceImportRunScope: Equatable {
    let accountID: UUID?
    let generation: UInt64
}

struct PendingPlaceImportRunState {
    private(set) var scope: PendingPlaceImportRunScope?

    mutating func activate(accountID: UUID?) {
        if let scope, scope.accountID == accountID { return }
        scope = PendingPlaceImportRunScope(
            accountID: accountID,
            generation: (scope?.generation ?? 0) + 1
        )
    }

    func accepts(_ captured: PendingPlaceImportRunScope) -> Bool {
        scope == captured
    }
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
    @Published private(set) var notice: PendingPlaceImportNotice?

    private var isDraining = false
    private var runState = PendingPlaceImportRunState()

    func activate(accountID: UUID?) {
        if let scope = runState.scope, scope.accountID == accountID { return }
        runState.activate(accountID: accountID)
        recovery = nil
        notice = nil
    }

    func dismissNotice() {
        notice = nil
    }

    func drain(dataManager: DataManager, accountID: UUID?) async {
        guard !isDraining,
              let runScope = runState.scope,
              runScope.accountID == accountID else { return }
        isDraining = true
        defer {
            isDraining = false
            if let nextScope = runState.scope, nextScope != runScope {
                Task { [weak self] in
                    await self?.drain(dataManager: dataManager, accountID: nextScope.accountID)
                }
            }
        }

        let queue = PendingPlaceImportQueue.shared
        for command in await queue.imports() {
            guard runState.accepts(runScope) else { return }
            guard command.accountContext == nil || command.accountContext == accountID else { continue }
            do {
                try await process(
                    command,
                    dataManager: dataManager,
                    accountID: accountID,
                    runScope: runScope
                )
                guard runState.accepts(runScope) else { return }
                await queue.remove(command.commandID)
                guard runState.accepts(runScope) else { return }
                notice = .completed(cafeName: command.name)
                if recovery?.id == command.commandID { recovery = nil }
            } catch {
                guard runState.accepts(runScope) else { return }
                var retry = command
                if PendingPlaceImportFailurePolicy.disposition(
                    for: error,
                    hasDestination: command.destinationListID != nil
                ) == .destinationRecovery {
                    retry.retryState = .needsDestinationRecovery
                    await queue.update(retry)
                    guard runState.accepts(runScope) else { return }
                    let eligibleLists = await queue.eligibleLists(accountID: accountID)
                    guard runState.accepts(runScope) else { return }
                    notice = nil
                    recovery = PendingPlaceImportRecovery(
                        command: retry,
                        eligibleLists: eligibleLists
                    )
                } else {
                    // Transport and session failures stay queued. The app drains
                    // them again on its next active cycle without telling the
                    // person that a still-valid list has gone stale.
                    retry.retryState = .queued
                    await queue.update(retry)
                    guard runState.accepts(runScope) else { return }
                    notice = .waiting(cafeName: command.name)
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
        guard let runScope = runState.scope,
              runScope.accountID == accountID else { return }
        var recovered = command
        recovered.destinationListID = nil
        recovered.destinationListTitle = nil
        recovered.retryState = .queued
        await PendingPlaceImportQueue.shared.update(recovered)
        guard runState.accepts(runScope) else { return }
        recovery = nil
        await drain(dataManager: dataManager, accountID: accountID)
    }

    func retry(
        _ command: PendingPlaceImport,
        in list: ShareExtensionCafeListCacheEntry,
        dataManager: DataManager,
        accountID: UUID?
    ) async {
        guard let runScope = runState.scope,
              runScope.accountID == accountID else { return }
        var recovered = command
        recovered.destinationListID = list.id
        recovered.destinationListTitle = list.title
        recovered.retryState = .queued
        await PendingPlaceImportQueue.shared.update(recovered)
        guard runState.accepts(runScope) else { return }
        recovery = nil
        await drain(dataManager: dataManager, accountID: accountID)
    }

    func dismissRecovery() {
        recovery = nil
    }

    private func process(
        _ command: PendingPlaceImport,
        dataManager: DataManager,
        accountID: UUID?,
        runScope: PendingPlaceImportRunScope
    ) async throws {
        try requireCurrent(runScope)
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
        try requireCurrent(runScope)
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
        try requireCurrent(runScope)

        if let listID = command.destinationListID {
            try await CollaborativeCafeListService(client: client).add(
                cafeID: result.cafe.id,
                to: listID,
                accountID: accountID
            )
            try requireCurrent(runScope)
        }
    }

    private func requireCurrent(_ runScope: PendingPlaceImportRunScope) throws {
        guard runState.accepts(runScope) else { throw CancellationError() }
    }

}
