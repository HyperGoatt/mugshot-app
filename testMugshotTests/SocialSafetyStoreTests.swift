import Foundation
import Testing
@testable import testMugshot

struct SocialSafetyStoreTests {
    @Test func unresolvedReportRetryReusesDurableClientReceipt() throws {
        let suiteName = "SocialSafetyRetry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let visitID = UUID()
        let clientReportID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            idGenerator: { clientReportID },
            now: { timestamp },
            protectedBaseDirectory: directory
        )

        let prepared = try store.prepare(
            accountID: accountID,
            target: .visit(visitID),
            reason: .harassment,
            details: nil
        )
        let failed = try store.markFailed(prepared)

        let reloadedStore = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let retried = try reloadedStore.prepare(
            accountID: accountID,
            target: .visit(visitID),
            reason: .harassment,
            details: nil
        )

        #expect(failed.deliveryState == .failed)
        #expect(retried.clientReportID == clientReportID)
        #expect(retried.deliveryState == .failed)
        #expect(reloadedStore.receipts(accountID: accountID).count == 1)
    }

    @Test func unresolvedReportDetailsUseProtectedBackupExcludedAccountStorage() throws {
        let suiteName = "SocialSafetyProtectedReport.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let target = SocialSafetyTarget.comment(UUID())
        let clientReportID = UUID()
        let sensitiveDetails = "Private context that must not enter preferences"
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            idGenerator: { clientReportID },
            protectedBaseDirectory: directory
        )

        let prepared = try store.prepare(
            accountID: accountID,
            target: target,
            reason: .harassment,
            details: sensitiveDetails
        )
        _ = try store.markFailed(prepared)

        #expect(
            defaults.data(
                forKey: SafetyReportReceiptStore.storageKey(accountID: accountID)
            ) == nil
        )
        let protectedURL = SafetyReportReceiptStore.protectedUnresolvedReportsURL(
            accountID: accountID,
            baseDirectory: directory
        )
        #expect(FileManager.default.fileExists(atPath: protectedURL.path))
        let protectedData = try Data(contentsOf: protectedURL)
        #expect(String(decoding: protectedData, as: UTF8.self).contains(sensitiveDetails))
        let values = try protectedURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )
        #expect(values.isExcludedFromBackup == true)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: protectedURL.path
        )
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #expect(
            protectedURL != SafetyReportReceiptStore.protectedUnresolvedReportsURL(
                accountID: UUID(),
                baseDirectory: directory
            )
        )

        let reloaded = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let retry = try reloaded.prepare(
            accountID: accountID,
            target: target,
            reason: .harassment,
            details: sensitiveDetails
        )
        #expect(retry.clientReportID == clientReportID)
        #expect(retry.details == sensitiveDetails)
    }

    @Test func legacyReportDetailsMigrateOutOfUserDefaultsWithoutChangingRetryID() throws {
        let suiteName = "SocialSafetyLegacyReport.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let target = SocialSafetyTarget.visit(UUID())
        let clientReportID = UUID()
        let sensitiveDetails = "Legacy private report context"
        let legacy = SafetyReportReceipt(
            clientReportID: clientReportID,
            accountID: accountID,
            target: target,
            reason: .other,
            details: sensitiveDetails,
            deliveryState: .failed,
            serverReportID: nil,
            serverStatus: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        defaults.set(
            try JSONEncoder().encode([legacy]),
            forKey: SafetyReportReceiptStore.storageKey(accountID: accountID)
        )
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        #expect(
            defaults.data(
                forKey: SafetyReportReceiptStore.storageKey(accountID: accountID)
            ) == nil
        )

        let retry = try store.prepare(
            accountID: accountID,
            target: target,
            reason: .other,
            details: sensitiveDetails
        )

        #expect(retry.clientReportID == clientReportID)
        #expect(
            defaults.data(
                forKey: SafetyReportReceiptStore.storageKey(accountID: accountID)
            ) == nil
        )
        #expect(
            FileManager.default.fileExists(
                atPath: SafetyReportReceiptStore.protectedUnresolvedReportsURL(
                    accountID: accountID,
                    baseDirectory: directory
                ).path
            )
        )
    }

    @Test func reportReceiptsNeverCrossAccountScopes() throws {
        let suiteName = "SocialSafetyAccounts.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        var generatedIDs = [UUID(), UUID()]
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            idGenerator: { generatedIDs.removeFirst() },
            protectedBaseDirectory: directory
        )

        let first = try store.prepare(
            accountID: firstAccountID,
            target: .comment(UUID()),
            reason: .spam,
            details: nil
        )
        let second = try store.prepare(
            accountID: secondAccountID,
            target: first.target,
            reason: first.reason,
            details: nil
        )

        #expect(first.clientReportID != second.clientReportID)
        #expect(store.receipts(accountID: firstAccountID) == [first])
        #expect(store.receipts(accountID: secondAccountID) == [second])
        #expect(
            SafetyReportReceiptStore.storageKey(accountID: firstAccountID)
                != SafetyReportReceiptStore.storageKey(accountID: secondAccountID)
        )
    }

    @Test func accountDeletionPurgeRemovesProtectedReportEvidence() throws {
        let suiteName = "SocialSafetyPurge.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )

        _ = try store.prepare(
            accountID: accountID,
            target: .visit(UUID()),
            reason: .other,
            details: "Delete this protected report context"
        )
        let protectedURL = SafetyReportReceiptStore.protectedUnresolvedReportsURL(
            accountID: accountID,
            baseDirectory: directory
        )
        #expect(FileManager.default.fileExists(atPath: protectedURL.path))

        try store.purge(accountID: accountID)

        #expect(!FileManager.default.fileExists(atPath: protectedURL.path))
        #expect(store.receipts(accountID: accountID).isEmpty)
    }

    @Test func submittedReceiptClearsSensitiveDetailsAndFutureReportGetsNewID() throws {
        let suiteName = "SocialSafetySubmitted.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstID = UUID()
        let secondID = UUID()
        var generatedIDs = [firstID, secondID]
        let accountID = UUID()
        let target = SocialSafetyTarget.user(UUID())
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            idGenerator: { generatedIDs.removeFirst() },
            protectedBaseDirectory: directory
        )

        let first = try store.prepare(
            accountID: accountID,
            target: target,
            reason: .other,
            details: "Repeated unwanted contact"
        )
        let submitted = try store.markSubmitted(
            first,
            serverReportID: UUID(),
            serverStatus: "open"
        )
        let storedHistoryData = try #require(
            defaults.data(
                forKey: SafetyReportReceiptStore.storageKey(accountID: accountID)
            )
        )
        let storedHistory = try JSONDecoder().decode(
            [SafetyReportReceipt].self,
            from: storedHistoryData
        )
        #expect(storedHistory == [submitted])
        #expect(!String(decoding: storedHistoryData, as: UTF8.self).contains(
            "Repeated unwanted contact"
        ))
        #expect(
            !FileManager.default.fileExists(
                atPath: SafetyReportReceiptStore.protectedUnresolvedReportsURL(
                    accountID: accountID,
                    baseDirectory: directory
                ).path
            )
        )
        let later = try store.prepare(
            accountID: accountID,
            target: target,
            reason: .other,
            details: "Repeated unwanted contact"
        )

        #expect(submitted.deliveryState == .submitted)
        #expect(submitted.details == nil)
        #expect(later.clientReportID == secondID)
        #expect(later.clientReportID != submitted.clientReportID)
    }

    @Test func receiptHistoryCapNeverDropsUnresolvedReports() throws {
        let suiteName = "SocialSafetyUnresolvedRetention.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        var generatedIDs = [UUID(), UUID(), UUID()]
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            maximumReceiptCount: 2,
            idGenerator: { generatedIDs.removeFirst() },
            protectedBaseDirectory: directory
        )

        let first = try store.prepare(
            accountID: accountID,
            target: .visit(UUID()),
            reason: .spam,
            details: nil
        )
        _ = try store.markFailed(first)
        let second = try store.prepare(
            accountID: accountID,
            target: .comment(UUID()),
            reason: .harassment,
            details: nil
        )
        _ = try store.markFailed(second)
        _ = try store.prepare(
            accountID: accountID,
            target: .user(UUID()),
            reason: .impersonation,
            details: nil
        )

        let reloaded = SafetyReportReceiptStore(
            defaults: defaults,
            maximumReceiptCount: 2,
            protectedBaseDirectory: directory
        ).receipts(accountID: accountID)
        #expect(reloaded.count == 3)
        #expect(reloaded.allSatisfy { $0.deliveryState != .submitted })
    }

    @Test func reportPreparationRejectsAnotherAccountBeforePersisting() throws {
        let suiteName = "SocialSafetyPrepareScope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let activeAccountID = UUID()
        let requestedAccountID = UUID()
        let remote = SocialSafetyRemoteStub(currentUserID: activeAccountID)
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let service = SocialSafetyService(remote: remote, reportStore: store)

        #expect(throws: SocialSafetyServiceError.accountScopeChanged) {
            try service.prepareReport(
                accountID: requestedAccountID,
                target: .visit(UUID()),
                reason: .spam,
                details: nil
            )
        }
        #expect(store.receipts(accountID: requestedAccountID).isEmpty)
        #expect(remote.submitReportCallCount == 0)
    }

    @Test func reportSubmissionRejectsAnotherAccountWithoutMutationOrNetwork() async throws {
        let suiteName = "SocialSafetySubmitScope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let receiptAccountID = UUID()
        let remote = SocialSafetyRemoteStub(currentUserID: UUID())
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let prepared = try store.prepare(
            accountID: receiptAccountID,
            target: .comment(UUID()),
            reason: .harassment,
            details: "keep this receipt unchanged"
        )
        let failed = try store.markFailed(prepared)
        let service = SocialSafetyService(remote: remote, reportStore: store)

        do {
            _ = try await service.submit(failed)
            Issue.record("A report owned by another account reached submission.")
        } catch let error as SocialSafetyServiceError {
            #expect(error == .accountScopeChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(remote.submitReportCallCount == 0)
        #expect(store.receipts(accountID: receiptAccountID) == [failed])
    }

    @Test func accountSwitchDuringReportCannotFinalizeTheOldReceipt() async throws {
        let suiteName = "SocialSafetySubmitSwitch.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let gate = SocialSafetySubmissionGate()
        let remote = SocialSafetyRemoteStub(
            currentUserID: firstAccountID,
            submitReport: { receipt in
                await gate.suspend(
                    confirmation: SocialSafetyReportConfirmation(
                        id: UUID(),
                        status: "open"
                    )
                )
            }
        )
        let store = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let receipt = try store.prepare(
            accountID: firstAccountID,
            target: .user(UUID()),
            reason: .impersonation,
            details: nil
        )
        _ = try store.markFailed(receipt)
        let service = SocialSafetyService(remote: remote, reportStore: store)

        let submission = Task {
            try await service.submit(receipt)
        }
        await gate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await gate.release()

        do {
            _ = try await submission.value
            Issue.record("A stale report response finalized after an account switch.")
        } catch let error as SocialSafetyServiceError {
            #expect(error == .accountScopeChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let stored = try #require(
            store.receipts(accountID: firstAccountID).first
        )
        #expect(stored.deliveryState == .pending)
        #expect(stored.serverReportID == nil)
        #expect(remote.submitReportCallCount == 1)
    }

    @Test func blockAndUnblockRejectAnotherAccountBeforeNetwork() async {
        let expectedAccountID = UUID()
        let remote = SocialSafetyRemoteStub(currentUserID: UUID())
        let service = SocialSafetyService(
            remote: remote,
            reportStore: SafetyReportReceiptStore()
        )

        do {
            _ = try await service.block(
                userID: UUID(),
                expectedAccountID: expectedAccountID
            )
            Issue.record("A block owned by another account reached the network.")
        } catch let error as SocialSafetyServiceError {
            #expect(error == .accountScopeChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            try await service.unblock(
                userID: UUID(),
                expectedAccountID: expectedAccountID
            )
            Issue.record("An unblock owned by another account reached the network.")
        } catch let error as SocialSafetyServiceError {
            #expect(error == .accountScopeChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(remote.blockCallCount == 0)
        #expect(remote.unblockCallCount == 0)
    }

    @Test func blockAndUnblockDiscardResponsesAfterAccountSwitch() async {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let targetID = UUID()
        let blockGate = SocialSafetyEndpointGate()
        let unblockGate = SocialSafetyEndpointGate()
        let remote = SocialSafetyRemoteStub(
            currentUserID: firstAccountID,
            block: { userID, _ in
                await blockGate.suspend()
                return SocialSafetyRemoteStub.blockResult(
                    blockerID: firstAccountID,
                    blockedID: userID
                )
            },
            unblock: { _ in await unblockGate.suspend() }
        )
        let service = SocialSafetyService(
            remote: remote,
            reportStore: SafetyReportReceiptStore()
        )

        let blockTask = Task {
            try await service.block(
                userID: targetID,
                expectedAccountID: firstAccountID
            )
        }
        await blockGate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await blockGate.release()
        await expectAccountScopeChanged { _ = try await blockTask.value }

        remote.currentUserID = firstAccountID
        let unblockTask = Task {
            try await service.unblock(
                userID: targetID,
                expectedAccountID: firstAccountID
            )
        }
        await unblockGate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await unblockGate.release()
        await expectAccountScopeChanged { try await unblockTask.value }

        #expect(remote.blockCallCount == 1)
        #expect(remote.unblockCallCount == 1)
    }

    @Test func safetyReadsAndAppealRejectAnotherAccountBeforeRemoteOrPersistence() async throws {
        let suiteName = "SocialSafetyRemainingPreflight.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expectedAccountID = UUID()
        let remote = SocialSafetyRemoteStub(currentUserID: UUID())
        let appealStore = ModerationAppealReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let service = SocialSafetyService(
            remote: remote,
            reportStore: SafetyReportReceiptStore(
                defaults: defaults,
                protectedBaseDirectory: directory
            ),
            appealStore: appealStore
        )

        await expectAccountScopeChanged {
            _ = try await service.blockedUsers(accountID: expectedAccountID)
        }
        await expectAccountScopeChanged {
            _ = try await service.reportReceipts(accountID: expectedAccountID)
        }
        await expectAccountScopeChanged {
            _ = try await service.submitAppeal(
                accountID: expectedAccountID,
                actionID: UUID(),
                statement: "Please review this decision."
            )
        }

        #expect(remote.blockedUsersCallCount == 0)
        #expect(remote.reportReceiptsCallCount == 0)
        #expect(remote.submitAppealCallCount == 0)
        #expect(appealStore.pending(accountID: expectedAccountID).isEmpty)
    }

    @Test func safetyReadsAndAppealDiscardResponsesAfterAccountSwitch() async throws {
        let suiteName = "SocialSafetyRemainingPostflight.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = socialSafetyTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let blockedGate = SocialSafetyEndpointGate()
        let receiptsGate = SocialSafetyEndpointGate()
        let appealGate = SocialSafetyEndpointGate()
        let remote = SocialSafetyRemoteStub(
            currentUserID: firstAccountID,
            blockedUsers: { _ in
                await blockedGate.suspend()
                return []
            },
            submitAppeal: { _ in
                await appealGate.suspend()
                return []
            },
            reportReceipts: { _ in
                await receiptsGate.suspend()
                return []
            }
        )
        let appealStore = ModerationAppealReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let service = SocialSafetyService(
            remote: remote,
            reportStore: SafetyReportReceiptStore(
                defaults: defaults,
                protectedBaseDirectory: directory
            ),
            appealStore: appealStore
        )

        let blockedTask = Task {
            try await service.blockedUsers(accountID: firstAccountID)
        }
        await blockedGate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await blockedGate.release()
        await expectAccountScopeChanged { _ = try await blockedTask.value }

        remote.currentUserID = firstAccountID
        let receiptsTask = Task {
            try await service.reportReceipts(accountID: firstAccountID)
        }
        await receiptsGate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await receiptsGate.release()
        await expectAccountScopeChanged { _ = try await receiptsTask.value }

        remote.currentUserID = firstAccountID
        let actionID = UUID()
        let appealTask = Task {
            try await service.submitAppeal(
                accountID: firstAccountID,
                actionID: actionID,
                statement: "Please review this decision."
            )
        }
        await appealGate.waitUntilStarted()
        remote.currentUserID = secondAccountID
        await appealGate.release()
        await expectAccountScopeChanged { _ = try await appealTask.value }

        #expect(remote.blockedUsersCallCount == 1)
        #expect(remote.reportReceiptsCallCount == 1)
        #expect(remote.submitAppealCallCount == 1)
        #expect(appealStore.pending(accountID: firstAccountID).count == 1)
    }

    @Test func blockConfirmationLeadsWithConsequencesAndProtectsPrivateJournals() {
        #expect(SocialSafetyCopy.blockConsequences.contains("friendship"))
        #expect(SocialSafetyCopy.blockConsequences.contains("interactions"))
        #expect(SocialSafetyCopy.blockConsequences.contains("tags"))
        #expect(SocialSafetyCopy.blockConsequences.contains("invitations"))
        #expect(SocialSafetyCopy.blockConsequences.contains("private journal"))
        #expect(SocialSafetyCopy.blockConsequences.contains("unchanged"))
        #expect(!SocialSafetyCopy.reportSubmitted.lowercased().contains("hour"))
        #expect(!SocialSafetyCopy.reportSubmitted.lowercased().contains("day"))
    }

    @Test func commentActionsFollowOwnerAndPostOwnerPermissions() {
        let commentOwnerID = UUID()
        let postOwnerID = UUID()
        let publicViewerID = UUID()

        #expect(
            SipDetailCommentActionPolicy.actions(
                commentOwnerID: commentOwnerID,
                postOwnerID: postOwnerID,
                viewerID: commentOwnerID
            ).map(\.id) == ["edit", "remove"]
        )
        #expect(
            SipDetailCommentActionPolicy.actions(
                commentOwnerID: commentOwnerID,
                postOwnerID: postOwnerID,
                viewerID: postOwnerID
            ).map(\.id) == ["remove", "report"]
        )
        #expect(
            SipDetailCommentActionPolicy.actions(
                commentOwnerID: commentOwnerID,
                postOwnerID: postOwnerID,
                viewerID: publicViewerID
            ).map(\.id) == ["report"]
        )
        #expect(
            SipDetailCommentActionPolicy.actions(
                commentOwnerID: commentOwnerID,
                postOwnerID: postOwnerID,
                viewerID: nil
            ).map(\.id) == ["report"]
        )
    }

    private func expectAccountScopeChanged(
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("A safety response escaped its originating account scope.")
        } catch let error as SocialSafetyServiceError {
            #expect(error == .accountScopeChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func socialSafetyTestDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
        "SocialSafetyStoreTests-\(UUID().uuidString)",
        isDirectory: true
    )
}

private final class SocialSafetyRemoteStub: SocialSafetyRemoteTransport,
    @unchecked Sendable {
    var currentUserID: UUID?
    private(set) var submitReportCallCount = 0
    private(set) var blockCallCount = 0
    private(set) var unblockCallCount = 0
    private(set) var blockedUsersCallCount = 0
    private(set) var submitAppealCallCount = 0
    private(set) var reportReceiptsCallCount = 0
    private let submitReportHandler: (
        SafetyReportReceipt
    ) async throws -> SocialSafetyReportConfirmation
    private let blockHandler: ((UUID, Bool) async throws -> SafetyBlockResult)?
    private let unblockHandler: ((UUID) async throws -> Void)?
    private let blockedUsersHandler: (Int) async throws -> [SocialConnection]
    private let submitAppealHandler: (
        PendingModerationAppeal
    ) async throws -> [ModerationAppealRPCReceipt]
    private let reportReceiptsHandler: (Int) async throws -> [SafeReportReceipt]

    init(
        currentUserID: UUID?,
        submitReport: @escaping (
            SafetyReportReceipt
        ) async throws -> SocialSafetyReportConfirmation = { _ in
            SocialSafetyReportConfirmation(id: UUID(), status: "open")
        },
        block: ((UUID, Bool) async throws -> SafetyBlockResult)? = nil,
        unblock: ((UUID) async throws -> Void)? = nil,
        blockedUsers: @escaping (Int) async throws -> [SocialConnection] = { _ in [] },
        submitAppeal: @escaping (
            PendingModerationAppeal
        ) async throws -> [ModerationAppealRPCReceipt] = { _ in [] },
        reportReceipts: @escaping (Int) async throws -> [SafeReportReceipt] = { _ in [] }
    ) {
        self.currentUserID = currentUserID
        submitReportHandler = submitReport
        blockHandler = block
        unblockHandler = unblock
        blockedUsersHandler = blockedUsers
        submitAppealHandler = submitAppeal
        reportReceiptsHandler = reportReceipts
    }

    func submitReport(
        _ receipt: SafetyReportReceipt
    ) async throws -> SocialSafetyReportConfirmation {
        submitReportCallCount += 1
        return try await submitReportHandler(receipt)
    }

    func block(
        userID: UUID,
        removeSavedRecipeCopies: Bool
    ) async throws -> SafetyBlockResult {
        blockCallCount += 1
        if let blockHandler {
            return try await blockHandler(userID, removeSavedRecipeCopies)
        }
        return Self.blockResult(
            blockerID: currentUserID ?? UUID(),
            blockedID: userID
        )
    }

    static func blockResult(
        blockerID: UUID,
        blockedID: UUID
    ) -> SafetyBlockResult {
        SafetyBlockResult(
            blockerID: blockerID,
            blockedID: blockedID,
            blockedAt: "2026-07-22T12:00:00Z",
            severed: SafetyBlockConsequences(
                friendships: 0,
                friendRequests: 0,
                comments: 0,
                mentions: 0,
                likes: 0,
                reactions: 0,
                companions: 0,
                recommendations: 0,
                listMemberships: 0,
                sharedInvitations: 0,
                sharedMemories: 0,
                savedRecipeCopies: 0
            )
        )
    }

    func unblock(userID: UUID) async throws {
        unblockCallCount += 1
        try await unblockHandler?(userID)
    }

    func blockedUsers(limit: Int) async throws -> [SocialConnection] {
        blockedUsersCallCount += 1
        return try await blockedUsersHandler(limit)
    }

    func enforcementState() async throws -> [ModerationEnforcementAction] { [] }

    func submitAppeal(
        _ pending: PendingModerationAppeal
    ) async throws -> [ModerationAppealRPCReceipt] {
        submitAppealCallCount += 1
        return try await submitAppealHandler(pending)
    }

    func reportReceipts(limit: Int) async throws -> [SafeReportReceipt] {
        reportReceiptsCallCount += 1
        return try await reportReceiptsHandler(limit)
    }
}

private actor SocialSafetySubmissionGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend(
        confirmation: SocialSafetyReportConfirmation
    ) async -> SocialSafetyReportConfirmation {
        started = true
        let pendingStartWaiters = startWaiters
        startWaiters = []
        pendingStartWaiters.forEach { $0.resume() }
        if !released {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return confirmation
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let pendingReleaseWaiters = releaseWaiters
        releaseWaiters = []
        pendingReleaseWaiters.forEach { $0.resume() }
    }
}

private actor SocialSafetyEndpointGate {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend() async {
        started = true
        let pendingStartWaiters = startWaiters
        startWaiters = []
        pendingStartWaiters.forEach { $0.resume() }
        if !released {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let pendingReleaseWaiters = releaseWaiters
        releaseWaiters = []
        pendingReleaseWaiters.forEach { $0.resume() }
    }
}
