import Foundation
import Testing
@testable import testMugshot

struct ModerationAppealStoreTests {
    @Test func pendingAppealIsAccountScopedAndFreezesExactRetryEvidence() throws {
        let suiteName = "ModerationAppealStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ModerationAppealStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstAccount = UUID()
        let secondAccount = UUID()
        let actionID = UUID()
        let firstReceiptID = UUID()
        let secondReceiptID = UUID()
        var generated = [firstReceiptID, secondReceiptID].makeIterator()
        let store = ModerationAppealReceiptStore(
            defaults: defaults,
            idGenerator: { generated.next() ?? UUID() },
            now: { Date(timeIntervalSince1970: 1_721_600_000) },
            protectedBaseDirectory: directory
        )

        let first = try store.prepare(
            accountID: firstAccount,
            actionID: actionID,
            statement: "  The first account’s original appeal statement.  "
        )
        #expect(
            defaults.data(
                forKey: ModerationAppealReceiptStore.storageKey(
                    accountID: firstAccount
                )
            ) == nil
        )
        let protectedURL = ModerationAppealReceiptStore.protectedStatementsURL(
            accountID: firstAccount,
            baseDirectory: directory
        )
        #expect(FileManager.default.fileExists(atPath: protectedURL.path))
        let values = try protectedURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )
        #expect(values.isExcludedFromBackup == true)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: protectedURL.path
        )
        #expect(
            SocialSafetyFileProtectionPolicy.protectionType == .complete
        )
        #expect(
            SocialSafetyFileProtectionPolicy.writingOptions.contains(
                .completeFileProtection
            )
        )
#if targetEnvironment(simulator)
        if let reportedProtection = attributes[.protectionKey] as? FileProtectionType {
            #expect(reportedProtection == .complete)
        }
#else
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
#endif
        let exactRetry = try store.prepare(
            accountID: firstAccount,
            actionID: actionID,
            statement: "A changed statement must not replace ambiguous evidence."
        )
        let second = try store.prepare(
            accountID: secondAccount,
            actionID: actionID,
            statement: "The second account has an independent receipt."
        )

        #expect(first.clientAppealID == firstReceiptID)
        #expect(exactRetry == first)
        #expect(first.statement == "The first account’s original appeal statement.")
        #expect(second.clientAppealID == secondReceiptID)
        #expect(second.accountID == secondAccount)

        let reloaded = ModerationAppealReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        let retryAfterReload = try reloaded.prepare(
            accountID: firstAccount,
            actionID: actionID,
            statement: "A relaunch must not replace the frozen evidence."
        )
        #expect(retryAfterReload == first)

        try store.resolve(accountID: firstAccount, actionID: actionID)

        #expect(store.pending(accountID: firstAccount, actionID: actionID) == nil)
        #expect(!FileManager.default.fileExists(atPath: protectedURL.path))
        #expect(store.pending(accountID: secondAccount, actionID: actionID) == second)

        try store.purge(accountID: secondAccount)
        #expect(store.pending(accountID: secondAccount, actionID: actionID) == nil)
    }

    @Test func legacyAppealStatementMigratesOutOfUserDefaults() throws {
        let suiteName = "ModerationAppealLegacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ModerationAppealLegacy-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let accountID = UUID()
        let actionID = UUID()
        let legacy = PendingModerationAppeal(
            clientAppealID: UUID(),
            accountID: accountID,
            actionID: actionID,
            statement: "Legacy private appeal statement",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        defaults.set(
            try JSONEncoder().encode([legacy]),
            forKey: ModerationAppealReceiptStore.storageKey(accountID: accountID)
        )
        let store = ModerationAppealReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: directory
        )
        #expect(
            defaults.data(
                forKey: ModerationAppealReceiptStore.storageKey(
                    accountID: accountID
                )
            ) == nil
        )

        let retry = try store.prepare(
            accountID: accountID,
            actionID: actionID,
            statement: "Changed text must not replace legacy retry evidence."
        )

        #expect(retry == legacy)
        #expect(
            defaults.data(
                forKey: ModerationAppealReceiptStore.storageKey(
                    accountID: accountID
                )
            ) == nil
        )
        #expect(
            FileManager.default.fileExists(
                atPath: ModerationAppealReceiptStore.protectedStatementsURL(
                    accountID: accountID,
                    baseDirectory: directory
                ).path
            )
        )
    }
}
