import Foundation
import Supabase

enum SocialSafetyLocalStoreError: LocalizedError, Equatable {
    case protectedPayloadUnavailable

    var errorDescription: String? {
        "Mugshot couldn’t securely save or restore this safety action. Unlock this device and try again."
    }
}

private enum SocialSafetyProtectedPayload: String {
    case unresolvedReports = "unresolved-reports.json"
    case pendingAppeals = "pending-appeals.json"
}

private final class SocialSafetyProtectedFileStore {
    private let fileManager: FileManager
    private let baseDirectory: URL

    init(fileManager: FileManager, baseDirectory: URL?) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MugshotSocialSafety", isDirectory: true)
    }

    func read<Value: Decodable>(
        _ type: Value.Type,
        accountID: UUID,
        payload: SocialSafetyProtectedPayload
    ) throws -> Value? {
        let url = fileURL(accountID: accountID, payload: payload)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            try secureExistingItem(at: accountDirectory(accountID))
            try secureExistingItem(at: url)
            return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
    }

    func write<Value: Encodable>(
        _ value: Value,
        accountID: UUID,
        payload: SocialSafetyProtectedPayload
    ) throws {
        do {
            let directory = accountDirectory(accountID)
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try secureExistingItem(at: directory)
            let url = fileURL(accountID: accountID, payload: payload)
            let data = try JSONEncoder().encode(value)
            try data.write(
                to: url,
                options: [.atomic, .completeFileProtection]
            )
            try secureExistingItem(at: url)
        } catch {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
    }

    func remove(accountID: UUID, payload: SocialSafetyProtectedPayload) throws {
        let url = fileURL(accountID: accountID, payload: payload)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
            let directory = accountDirectory(accountID)
            if (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
                try? fileManager.removeItem(at: directory)
            }
        } catch {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
    }

    func fileURL(
        accountID: UUID,
        payload: SocialSafetyProtectedPayload
    ) -> URL {
        accountDirectory(accountID).appendingPathComponent(payload.rawValue)
    }

    private func accountDirectory(_ accountID: UUID) -> URL {
        baseDirectory
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("users", isDirectory: true)
            .appendingPathComponent(
                accountID.uuidString.lowercased(),
                isDirectory: true
            )
    }

    private func secureExistingItem(at url: URL) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        var securedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try securedURL.setResourceValues(values)
    }
}

final class SafetyReportReceiptStore {
    static let shared = SafetyReportReceiptStore()

    private let defaults: UserDefaults
    private let protectedStore: SocialSafetyProtectedFileStore
    private let idGenerator: () -> UUID
    private let now: () -> Date
    private let maximumReceiptCount: Int
    private let lock = NSRecursiveLock()
    private let keyPrefix = "MugshotSafetyReportReceipts.v1."

    init(
        defaults: UserDefaults = .standard,
        maximumReceiptCount: Int = 50,
        idGenerator: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init,
        fileManager: FileManager = .default,
        protectedBaseDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.protectedStore = SocialSafetyProtectedFileStore(
            fileManager: fileManager,
            baseDirectory: protectedBaseDirectory
        )
        self.maximumReceiptCount = max(maximumReceiptCount, 1)
        self.idGenerator = idGenerator
        self.now = now
        migrateLegacyAccountsBestEffort()
    }

    /// Reuses an unresolved request so a retry can never create a second report
    /// after an ambiguous network response.
    func prepare(
        accountID: UUID,
        target: SocialSafetyTarget,
        reason: ReportReason,
        details: String?
    ) throws -> SafetyReportReceipt {
        lock.lock()
        defer { lock.unlock() }

        let normalizedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        var receipts = try receiptsWithoutLock(accountID: accountID)
        if let existing = receipts
            .filter({
                $0.deliveryState != .submitted
                    && $0.target == target
                    && $0.reason == reason
                    && $0.details == normalizedDetails
            })
            .max(by: { $0.updatedAt < $1.updatedAt }) {
            return existing
        }

        let timestamp = now()
        let receipt = SafetyReportReceipt(
            clientReportID: idGenerator(),
            accountID: accountID,
            target: target,
            reason: reason,
            details: normalizedDetails,
            deliveryState: .pending,
            serverReportID: nil,
            serverStatus: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        receipts.append(receipt)
        try persist(receipts, accountID: accountID)
        return receipt
    }

    @discardableResult
    func markPending(_ receipt: SafetyReportReceipt) throws -> SafetyReportReceipt {
        try update(receipt) { stored in
            guard stored.deliveryState != .submitted else { return }
            stored.deliveryState = .pending
            stored.updatedAt = now()
        }
    }

    @discardableResult
    func markSubmitted(
        _ receipt: SafetyReportReceipt,
        serverReportID: UUID,
        serverStatus: String
    ) throws -> SafetyReportReceipt {
        try update(receipt) { stored in
            stored.deliveryState = .submitted
            stored.serverReportID = serverReportID
            stored.serverStatus = serverStatus
            // Report details are only needed while delivery is unresolved.
            stored.details = nil
            stored.updatedAt = now()
        }
    }

    @discardableResult
    func markFailed(_ receipt: SafetyReportReceipt) throws -> SafetyReportReceipt {
        try update(receipt) { stored in
            guard stored.deliveryState != .submitted else { return }
            stored.deliveryState = .failed
            stored.updatedAt = now()
        }
    }

    func receipts(accountID: UUID) -> [SafetyReportReceipt] {
        lock.lock()
        defer { lock.unlock() }
        do {
            return try receiptsWithoutLock(accountID: accountID)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            return recoverableSubmittedHistoryWithoutLock(accountID: accountID)
                .sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    static func storageKey(accountID: UUID) -> String {
        "MugshotSafetyReportReceipts.v1."
            + LocalAccountScope.user(accountID).defaultsComponent
    }

    static func protectedUnresolvedReportsURL(
        accountID: UUID,
        baseDirectory: URL
    ) -> URL {
        SocialSafetyProtectedFileStore(
            fileManager: .default,
            baseDirectory: baseDirectory
        ).fileURL(accountID: accountID, payload: .unresolvedReports)
    }

    func removeAll(accountID: UUID) {
        try? purge(accountID: accountID)
    }

    /// Account deletion must be able to distinguish a completed local purge
    /// from a protected-file removal that still needs another attempt.
    func purge(accountID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key(accountID))
        try protectedStore.remove(
            accountID: accountID,
            payload: .unresolvedReports
        )
    }

    private func update(
        _ receipt: SafetyReportReceipt,
        mutation: (inout SafetyReportReceipt) -> Void
    ) throws -> SafetyReportReceipt {
        lock.lock()
        defer { lock.unlock() }

        var receipts = try receiptsWithoutLock(accountID: receipt.accountID)
        guard let index = receipts.firstIndex(where: {
            $0.clientReportID == receipt.clientReportID
        }) else {
            var recovered = receipt
            mutation(&recovered)
            receipts.append(recovered)
            try persist(receipts, accountID: receipt.accountID)
            return recovered
        }
        mutation(&receipts[index])
        let updated = receipts[index]
        try persist(receipts, accountID: receipt.accountID)
        return updated
    }

    private func receiptsWithoutLock(accountID: UUID) throws -> [SafetyReportReceipt] {
        let history = try defaultsReceiptsWithoutLock(accountID: accountID)
        var unresolved = try protectedStore.read(
            [SafetyReportReceipt].self,
            accountID: accountID,
            payload: .unresolvedReports
        ) ?? []
        guard unresolved.allSatisfy({
            $0.accountID == accountID && $0.deliveryState != .submitted
        }), Set(unresolved.map(\.clientReportID)).count == unresolved.count else {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }

        let legacyUnresolved = history.filter { $0.deliveryState != .submitted }
        let sanitizedHistory = history
            .filter { $0.deliveryState == .submitted }
            .map(Self.sanitizedSubmittedReceipt)
        if !legacyUnresolved.isEmpty || sanitizedHistory != history {
            for receipt in legacyUnresolved {
                if let existing = unresolved.first(where: {
                    $0.clientReportID == receipt.clientReportID
                }) {
                    guard existing == receipt else {
                        throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
                    }
                } else {
                    unresolved.append(receipt)
                }
            }
            try persistProtected(unresolved, accountID: accountID)
            try persistSubmittedHistory(sanitizedHistory, accountID: accountID)
        }
        guard Set((unresolved + sanitizedHistory).map(\.clientReportID)).count
                == unresolved.count + sanitizedHistory.count else {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
        return unresolved + sanitizedHistory
    }

    private func persist(
        _ receipts: [SafetyReportReceipt],
        accountID: UUID
    ) throws {
        let sorted = receipts.sorted { $0.updatedAt > $1.updatedAt }
        let unresolved = sorted.filter { $0.deliveryState != .submitted }
        let submittedHistoryLimit = max(maximumReceiptCount - unresolved.count, 0)
        let submitted = Array(
            sorted
                .filter { $0.deliveryState == .submitted }
                .prefix(submittedHistoryLimit)
        ).map(Self.sanitizedSubmittedReceipt)
        try persistProtected(unresolved, accountID: accountID)
        try persistSubmittedHistory(submitted, accountID: accountID)
    }

    private func persistProtected(
        _ receipts: [SafetyReportReceipt],
        accountID: UUID
    ) throws {
        guard !receipts.isEmpty else {
            try protectedStore.remove(
                accountID: accountID,
                payload: .unresolvedReports
            )
            return
        }
        try protectedStore.write(
            receipts,
            accountID: accountID,
            payload: .unresolvedReports
        )
    }

    private func defaultsReceiptsWithoutLock(
        accountID: UUID
    ) throws -> [SafetyReportReceipt] {
        guard let data = defaults.data(forKey: key(accountID)) else { return [] }
        guard let receipts = try? JSONDecoder().decode(
                [SafetyReportReceipt].self,
                from: data
              ), receipts.allSatisfy({ $0.accountID == accountID }),
              Set(receipts.map(\.clientReportID)).count == receipts.count else {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
        return receipts
    }

    private func recoverableSubmittedHistoryWithoutLock(
        accountID: UUID
    ) -> [SafetyReportReceipt] {
        guard let receipts = try? defaultsReceiptsWithoutLock(accountID: accountID) else {
            return []
        }
        return receipts
            .filter { $0.deliveryState == .submitted }
            .map(Self.sanitizedSubmittedReceipt)
    }

    private func persistSubmittedHistory(
        _ receipts: [SafetyReportReceipt],
        accountID: UUID
    ) throws {
        guard !receipts.isEmpty else {
            defaults.removeObject(forKey: key(accountID))
            return
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(receipts)
        } catch {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
        defaults.set(data, forKey: key(accountID))
    }

    private static func sanitizedSubmittedReceipt(
        _ receipt: SafetyReportReceipt
    ) -> SafetyReportReceipt {
        var sanitized = receipt
        sanitized.details = nil
        return sanitized
    }

    private func migrateLegacyAccountsBestEffort() {
        let accountPrefix = keyPrefix + "user."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(accountPrefix) {
            let rawAccountID = String(key.dropFirst(accountPrefix.count))
            guard let accountID = UUID(uuidString: rawAccountID) else { continue }
            _ = try? receiptsWithoutLock(accountID: accountID)
        }
    }

    private func key(_ accountID: UUID) -> String {
        keyPrefix + LocalAccountScope.user(accountID).defaultsComponent
    }
}

final class ModerationAppealReceiptStore {
    static let shared = ModerationAppealReceiptStore()

    private let defaults: UserDefaults
    private let protectedStore: SocialSafetyProtectedFileStore
    private let idGenerator: () -> UUID
    private let now: () -> Date
    private let lock = NSRecursiveLock()
    private let keyPrefix = "MugshotModerationAppeals.v1."

    init(
        defaults: UserDefaults = .standard,
        idGenerator: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init,
        fileManager: FileManager = .default,
        protectedBaseDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.protectedStore = SocialSafetyProtectedFileStore(
            fileManager: fileManager,
            baseDirectory: protectedBaseDirectory
        )
        self.idGenerator = idGenerator
        self.now = now
        migrateLegacyAccountsBestEffort()
    }

    /// Appeal text is frozen with its client receipt. If delivery becomes
    /// ambiguous, retries reuse the exact request instead of creating a second
    /// appeal or silently changing the evidence under the same identifier.
    func prepare(
        accountID: UUID,
        actionID: UUID,
        statement: String
    ) throws -> PendingModerationAppeal {
        lock.lock()
        defer { lock.unlock() }

        var pending = try pendingWithoutLock(accountID: accountID)
        if let existing = pending.first(where: { $0.actionID == actionID }) {
            return existing
        }

        let appeal = PendingModerationAppeal(
            clientAppealID: idGenerator(),
            accountID: accountID,
            actionID: actionID,
            statement: statement.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now()
        )
        pending.append(appeal)
        try persist(pending, accountID: accountID)
        return appeal
    }

    func pending(accountID: UUID, actionID: UUID) -> PendingModerationAppeal? {
        lock.lock()
        defer { lock.unlock() }
        return try? pendingWithoutLock(accountID: accountID)
            .first { $0.actionID == actionID }
    }

    func pending(accountID: UUID) -> [PendingModerationAppeal] {
        lock.lock()
        defer { lock.unlock() }
        return (try? pendingWithoutLock(accountID: accountID))?
            .sorted { $0.createdAt < $1.createdAt } ?? []
    }

    func resolve(accountID: UUID, actionID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        var pending = try pendingWithoutLock(accountID: accountID)
        pending.removeAll { $0.actionID == actionID }
        try persist(pending, accountID: accountID)
    }

    func removeAll(accountID: UUID) {
        try? purge(accountID: accountID)
    }

    /// Account deletion keeps its recovery capability until protected appeal
    /// evidence has actually been removed from this device.
    func purge(accountID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key(accountID))
        try protectedStore.remove(
            accountID: accountID,
            payload: .pendingAppeals
        )
    }

    static func protectedStatementsURL(
        accountID: UUID,
        baseDirectory: URL
    ) -> URL {
        SocialSafetyProtectedFileStore(
            fileManager: .default,
            baseDirectory: baseDirectory
        ).fileURL(accountID: accountID, payload: .pendingAppeals)
    }

    static func storageKey(accountID: UUID) -> String {
        "MugshotModerationAppeals.v1."
            + LocalAccountScope.user(accountID).defaultsComponent
    }

    private func pendingWithoutLock(
        accountID: UUID
    ) throws -> [PendingModerationAppeal] {
        var pending = try protectedStore.read(
            [PendingModerationAppeal].self,
            accountID: accountID,
            payload: .pendingAppeals
        ) ?? []
        guard pending.allSatisfy({ $0.accountID == accountID }),
              Set(pending.map(\.clientAppealID)).count == pending.count,
              Set(pending.map(\.actionID)).count == pending.count else {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
        guard let data = defaults.data(forKey: key(accountID)) else {
            return pending
        }
        guard let legacy = try? JSONDecoder().decode(
                [PendingModerationAppeal].self,
                from: data
              ), legacy.allSatisfy({ $0.accountID == accountID }) else {
            throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
        }
        for appeal in legacy {
            if let existing = pending.first(where: {
                $0.clientAppealID == appeal.clientAppealID
                    || $0.actionID == appeal.actionID
            }) {
                guard existing == appeal else {
                    throw SocialSafetyLocalStoreError.protectedPayloadUnavailable
                }
            } else {
                pending.append(appeal)
            }
        }
        try persist(pending, accountID: accountID)
        return pending
    }

    private func persist(
        _ pending: [PendingModerationAppeal],
        accountID: UUID
    ) throws {
        guard !pending.isEmpty else {
            try protectedStore.remove(
                accountID: accountID,
                payload: .pendingAppeals
            )
            defaults.removeObject(forKey: key(accountID))
            return
        }
        try protectedStore.write(
            pending,
            accountID: accountID,
            payload: .pendingAppeals
        )
        defaults.removeObject(forKey: key(accountID))
    }

    private func migrateLegacyAccountsBestEffort() {
        let accountPrefix = keyPrefix + "user."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(accountPrefix) {
            let rawAccountID = String(key.dropFirst(accountPrefix.count))
            guard let accountID = UUID(uuidString: rawAccountID) else { continue }
            _ = try? pendingWithoutLock(accountID: accountID)
        }
    }

    private func key(_ accountID: UUID) -> String {
        keyPrefix + LocalAccountScope.user(accountID).defaultsComponent
    }
}

struct SocialSafetyReportConfirmation: Equatable {
    let id: UUID
    let status: String
}

protocol SocialSafetyRemoteTransport: AnyObject {
    var currentUserID: UUID? { get }
    func submitReport(
        _ receipt: SafetyReportReceipt
    ) async throws -> SocialSafetyReportConfirmation
    func block(userID: UUID, removeSavedRecipeCopies: Bool) async throws -> SafetyBlockResult
    func unblock(userID: UUID) async throws
    func blockedUsers(limit: Int) async throws -> [SocialConnection]
    func enforcementState() async throws -> [ModerationEnforcementAction]
    func submitAppeal(
        _ pending: PendingModerationAppeal
    ) async throws -> [ModerationAppealRPCReceipt]
    func reportReceipts(limit: Int) async throws -> [SafeReportReceipt]
}

private final class SupabaseSocialSafetyRemoteTransport: SocialSafetyRemoteTransport {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func submitReport(
        _ receipt: SafetyReportReceipt
    ) async throws -> SocialSafetyReportConfirmation {
        let response: SafetyReportRPCResponse = try await client.rpc(
            "submit_report_v2",
            params: SubmitSafetyReportParameters(receipt: receipt)
        ).execute().value
        return SocialSafetyReportConfirmation(
            id: response.id,
            status: response.status
        )
    }

    func block(
        userID: UUID,
        removeSavedRecipeCopies: Bool
    ) async throws -> SafetyBlockResult {
        try await client.rpc(
            "block_user_v2",
            params: SafetyBlockParameters(
                pBlockedUserID: userID,
                pRemoveSavedRecipeCopies: removeSavedRecipeCopies
            )
        ).execute().value
    }

    func unblock(userID: UUID) async throws {
        try await client.rpc(
            "unblock_user",
            params: ["p_blocked_user_id": userID]
        ).execute()
    }

    func blockedUsers(limit: Int) async throws -> [SocialConnection] {
        try await client.rpc(
            "list_social_connections",
            params: SafetySocialListParameters(
                pKind: "blocked",
                pLimit: min(max(limit, 1), 50)
            )
        ).execute().value
    }

    func enforcementState() async throws -> [ModerationEnforcementAction] {
        try await client.rpc("get_my_enforcement_state_v1").execute().value
    }

    func submitAppeal(
        _ pending: PendingModerationAppeal
    ) async throws -> [ModerationAppealRPCReceipt] {
        try await client.rpc(
            "submit_moderation_appeal_v1",
            params: SubmitModerationAppealParameters(pending)
        ).execute().value
    }

    func reportReceipts(limit: Int) async throws -> [SafeReportReceipt] {
        try await client.rpc(
            "list_my_report_receipts_v1",
            params: SafeReportReceiptListParameters(
                pLimit: min(max(limit, 1), 100)
            )
        ).execute().value
    }
}

final class SocialSafetyService {
    private let remote: SocialSafetyRemoteTransport
    private let reportStore: SafetyReportReceiptStore
    private let appealStore: ModerationAppealReceiptStore

    init(
        client: SupabaseClient,
        reportStore: SafetyReportReceiptStore = .shared,
        appealStore: ModerationAppealReceiptStore = .shared
    ) {
        remote = SupabaseSocialSafetyRemoteTransport(client: client)
        self.reportStore = reportStore
        self.appealStore = appealStore
    }

    init(
        remote: SocialSafetyRemoteTransport,
        reportStore: SafetyReportReceiptStore,
        appealStore: ModerationAppealReceiptStore = .shared
    ) {
        self.remote = remote
        self.reportStore = reportStore
        self.appealStore = appealStore
    }

    func prepareReport(
        accountID: UUID,
        target: SocialSafetyTarget,
        reason: ReportReason,
        details: String?
    ) throws -> SafetyReportReceipt {
        try requireAccount(accountID)
        return try reportStore.prepare(
            accountID: accountID,
            target: target,
            reason: reason,
            details: details
        )
    }

    func submit(
        _ receipt: SafetyReportReceipt
    ) async throws -> SafetyReportSubmissionOutcome {
        try requireAccount(receipt.accountID)
        let pendingReceipt = try reportStore.markPending(receipt)
        if pendingReceipt.deliveryState == .submitted {
            return .submitted(pendingReceipt)
        }
        do {
            let response = try await remote.submitReport(pendingReceipt)
            try requireAccount(receipt.accountID)
            return .submitted(try reportStore.markSubmitted(
                pendingReceipt,
                serverReportID: response.id,
                serverStatus: response.status
            ))
        } catch {
            // A response for a previous session must never alter that account's
            // durable receipt after a different person signs in on this device.
            try requireAccount(receipt.accountID)
            // A transport failure may occur after the server committed. Keep the
            // receipt and reuse its client ID rather than claiming it was rejected.
            return .failed(try reportStore.markFailed(pendingReceipt))
        }
    }

    func block(
        userID: UUID,
        expectedAccountID: UUID,
        removeSavedRecipeCopies: Bool = false
    ) async throws -> SafetyBlockResult {
        try requireAccount(expectedAccountID)
        let result = try await remote.block(
            userID: userID,
            removeSavedRecipeCopies: removeSavedRecipeCopies
        )
        try requireAccount(expectedAccountID)
        guard result.blockerID == expectedAccountID,
              result.blockedID == userID else {
            throw SocialSafetyServiceError.invalidServerResponse
        }
        return result
    }

    func unblock(userID: UUID, expectedAccountID: UUID) async throws {
        try requireAccount(expectedAccountID)
        try await remote.unblock(userID: userID)
        try requireAccount(expectedAccountID)
    }

    func blockedUsers(
        accountID: UUID,
        limit: Int = 50
    ) async throws -> [SocialConnection] {
        try requireAccount(accountID)
        let people = try await remote.blockedUsers(limit: limit)
        try requireAccount(accountID)
        return people
    }

    func enforcementState(
        accountID: UUID
    ) async throws -> [ModerationEnforcementAction] {
        try requireAccount(accountID)
        let actions = try await remote.enforcementState()
        try requireAccount(accountID)
        return actions
    }

    func pendingAppeal(
        accountID: UUID,
        actionID: UUID
    ) -> PendingModerationAppeal? {
        appealStore.pending(accountID: accountID, actionID: actionID)
    }

    func submitAppeal(
        accountID: UUID,
        actionID: UUID,
        statement: String
    ) async throws -> ModerationAppealSubmissionOutcome {
        try requireAccount(accountID)
        let pending = try appealStore.prepare(
            accountID: accountID,
            actionID: actionID,
            statement: statement
        )
        do {
            let rows = try await remote.submitAppeal(pending)
            try requireAccount(accountID)
            guard let receipt = rows.first else {
                return .deliveryUnconfirmed(pending)
            }
            try appealStore.resolve(accountID: accountID, actionID: actionID)
            return .submitted(receipt)
        } catch let error as SocialSafetyServiceError {
            throw error
        } catch let error as PostgrestError where [
            "22023", "42501", "55000", "P0002"
        ].contains(error.code) {
            // These are authoritative validation/ownership outcomes, not
            // ambiguous transport failures. Do not leave an impossible retry.
            try requireAccount(accountID)
            try appealStore.resolve(accountID: accountID, actionID: actionID)
            throw error
        } catch {
            try requireAccount(accountID)
            // The server may have committed before transport failed. The frozen
            // client receipt remains available for a safe, exact retry.
            return .deliveryUnconfirmed(pending)
        }
    }

    func reportReceipts(
        accountID: UUID,
        limit: Int = 50
    ) async throws -> [SafeReportReceipt] {
        try requireAccount(accountID)
        let receipts = try await remote.reportReceipts(limit: limit)
        try requireAccount(accountID)
        return receipts
    }

    private func requireAccount(_ expectedAccountID: UUID) throws {
        guard remote.currentUserID == expectedAccountID else {
            throw SocialSafetyServiceError.accountScopeChanged
        }
    }
}

private struct SafetyBlockParameters: Encodable {
    let pBlockedUserID: UUID
    let pRemoveSavedRecipeCopies: Bool

    enum CodingKeys: String, CodingKey {
        case pBlockedUserID = "p_blocked_user_id"
        case pRemoveSavedRecipeCopies = "p_remove_saved_recipe_copies"
    }
}

enum SocialSafetyServiceError: LocalizedError, Equatable {
    case accountScopeChanged
    case invalidServerResponse

    var errorDescription: String? {
        switch self {
        case .accountScopeChanged:
            return "The signed-in account changed before Mugshot could finish that safety action. Nothing was changed for the newly signed-in account."
        case .invalidServerResponse:
            return "Mugshot couldn’t verify that safety action. Refresh and try again."
        }
    }
}

private struct SubmitSafetyReportParameters: Encodable {
    let pClientReportID: UUID
    let pReason: String
    let pTargetKind: String
    let pTargetID: UUID
    let pDetails: String?

    init(receipt: SafetyReportReceipt) {
        pClientReportID = receipt.clientReportID
        pReason = receipt.reason.rawValue
        pTargetKind = receipt.target.kind
        pTargetID = receipt.target.targetID
        pDetails = receipt.details
    }

    enum CodingKeys: String, CodingKey {
        case pClientReportID = "p_client_report_id"
        case pReason = "p_reason"
        case pTargetKind = "p_target_kind"
        case pTargetID = "p_target_id"
        case pDetails = "p_details"
    }
}

private struct SafetyReportRPCResponse: Decodable {
    let id: UUID
    let status: String
}

private struct SafetySocialListParameters: Encodable {
    let pKind: String
    let pLimit: Int

    enum CodingKeys: String, CodingKey {
        case pKind = "p_kind"
        case pLimit = "p_limit"
    }
}

private struct SubmitModerationAppealParameters: Encodable {
    let pActionID: UUID
    let pClientAppealID: UUID
    let pStatement: String

    init(_ pending: PendingModerationAppeal) {
        pActionID = pending.actionID
        pClientAppealID = pending.clientAppealID
        pStatement = pending.statement
    }

    enum CodingKeys: String, CodingKey {
        case pActionID = "p_action_id"
        case pClientAppealID = "p_client_appeal_id"
        case pStatement = "p_statement"
    }
}

private struct SafeReportReceiptListParameters: Encodable {
    let pLimit: Int

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
