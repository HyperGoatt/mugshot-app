import Foundation
import Supabase
import Testing
import UIKit
@testable import testMugshot

struct AccountDataLifecycleTests {
    @Test func unsafeCapabilityFailsClosedWithoutPostingOrClearingAuth() async throws {
        let transport = DeletionTransportStub(
            capability: AccountDeletionCapability(
                protocolName: "legacy-account-deletion",
                protocolVersion: 1,
                destructiveAction: "delete",
                requiresExplicitAction: false,
                identityBeforeStorage: false,
                buckets: ["visit-photos"]
            )
        )
        let service = AccountDeletionService(transport: transport)

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .supportRequired(.upgradeRequired))
        #expect(transport.deletionRequestIDs.isEmpty)
        #expect(transport.localAuthClearCount == 0)
    }

    @Test func unconfirmedIdentityRevokesLocalAuthAndReturnsSupportReceipt() async throws {
        let jobID = UUID()
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: jobID,
            subjectId: transport.userID,
            identityDeleted: false,
            cleanupStatus: "not_started",
            status: "identity_deletion_pending"
        )
        let service = AccountDeletionService(transport: transport)

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            requestID: transport.expectedRequestID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .supportRequired(.identityDeletionPending(jobID: jobID)))
        #expect(transport.deletionRequestIDs == [transport.expectedRequestID])
        #expect(transport.localAuthClearCount == 1)
    }

    @Test func confirmedIdentityClearsAuthEvenWhenDurableCleanupIsPending() async throws {
        let jobID = UUID()
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: jobID,
            subjectId: transport.userID,
            identityDeleted: true,
            cleanupStatus: "pending",
            status: "cleanup_pending"
        )
        let service = AccountDeletionService(transport: transport)

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            requestID: transport.expectedRequestID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .identityDeleted(cleanup: .pending(jobID: jobID)))
        #expect(transport.localAuthClearCount == 1)
    }

    @Test func contradictoryDeletionReceiptDoesNotClearLocalAuth() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: UUID(),
            subjectId: transport.userID,
            identityDeleted: true,
            cleanupStatus: "pending",
            status: "completed"
        )
        let service = AccountDeletionService(transport: transport)

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("A contradictory deletion receipt was accepted.")
        } catch {
            #expect(error as? AccountDeletionError == .invalidV3Response)
        }
        #expect(transport.localAuthClearCount == 0)
    }

    @Test func accountSwitchAfterCapabilityHandshakeCannotReachDeletionPost() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.userIDAfterCapabilityFetch = UUID()
        let service = AccountDeletionService(transport: transport)

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("Deletion continued after the authenticated account changed.")
        } catch {
            #expect(error as? AccountDeletionError == .accountScopeChanged)
        }

        #expect(transport.deletionRequestIDs.isEmpty)
        #expect(transport.localAuthClearCount == 0)
    }

    @Test func deletionReceiptForAnotherSubjectFailsClosed() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: UUID(),
            subjectId: UUID(),
            identityDeleted: true,
            cleanupStatus: "completed",
            completionProofState: "completed",
            status: "completed"
        )
        let service = AccountDeletionService(transport: transport)

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("A deletion receipt for another subject was accepted.")
        } catch {
            #expect(error as? AccountDeletionError == .invalidV3Response)
        }

        #expect(transport.localAuthClearCount == 0)
    }

    @Test func lostDeletionResponsePersistsCapabilityAndRelaunchRecoveryCompletes() async throws {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        transport.deletionError = FunctionsError.relayError
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("A lost deletion response was treated as confirmation.")
        } catch {
            #expect(error as? AccountDeletionError == .deletionCouldNotBeConfirmed)
        }

        let record = try #require(store.values.first)
        #expect(record.subjectID == transport.userID)
        #expect(record.requestID == transport.expectedRequestID)
        #expect(record.recoverySecret.count == 43)

        let jobID = UUID()
        transport.recoveryResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: record.requestID,
            jobId: jobID,
            subjectId: record.subjectID,
            identityDeleted: true,
            cleanupStatus: "completed",
            completionProofState: "expired_completed",
            status: "completed"
        )
        let resolution = try await service.resumePendingDeletion()
        #expect(
            resolution == .resolved(
                subjectID: transport.userID,
                outcome: .identityDeleted(cleanup: .completed)
            )
        )
        #expect(store.values.count == 1)
        #expect(transport.localAuthClearCount == 1)

        try await service.acknowledgeLocalDeletion(subjectID: transport.userID)
        #expect(store.values.isEmpty)
    }

    @Test func authoritativeRecoveryNotFoundRemovesUnusedCapability() async throws {
        let transport = DeletionTransportStub(capability: safeCapability)
        let record = AccountDeletionRecoveryRecord(
            subjectID: transport.userID,
            requestID: transport.expectedRequestID,
            recoverySecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            createdAt: Date()
        )
        let store = DeletionRecoveryStoreStub(values: [record])
        transport.recoveryResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: record.requestID,
            jobId: nil,
            subjectId: record.subjectID,
            found: false,
            identityDeleted: nil,
            cleanupStatus: nil,
            status: "not_found"
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        #expect(try await service.resumePendingDeletion() == .none)
        #expect(store.values.isEmpty)
        #expect(transport.localAuthClearCount == 0)
    }

    @Test func invalidCompletionAcknowledgementKeepsRecoveryCapability() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        let record = AccountDeletionRecoveryRecord(
            subjectID: transport.userID,
            requestID: transport.expectedRequestID,
            recoverySecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            createdAt: Date()
        )
        let store = DeletionRecoveryStoreStub(values: [record])
        transport.acknowledgementResponse = AccountDeletionAcknowledgementResponse(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            action: AccountDeletionService.acknowledgementAction,
            requestId: UUID(),
            subjectId: record.subjectID,
            acknowledged: true,
            status: "acknowledged",
            finalRetentionDays: AccountDeletionService.completionTombstoneFinalRetentionDays
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            try await service.acknowledgeLocalDeletion(subjectID: record.subjectID)
            Issue.record("A mismatched completion acknowledgement was trusted.")
        } catch {
            #expect(error as? AccountDeletionError == .invalidV3Response)
        }

        #expect(store.values == [record])
    }

    @Test func deletionRetryResumesExistingCapabilityBeforeAnyNewPost() async throws {
        let jobID = UUID()
        let transport = DeletionTransportStub(capability: safeCapability)
        let record = AccountDeletionRecoveryRecord(
            subjectID: transport.userID,
            requestID: transport.expectedRequestID,
            recoverySecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            createdAt: Date()
        )
        let store = DeletionRecoveryStoreStub(values: [record])
        transport.recoveryResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: record.requestID,
            jobId: jobID,
            subjectId: record.subjectID,
            identityDeleted: true,
            cleanupStatus: "completed",
            completionProofState: "completed",
            status: "completed"
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .identityDeleted(cleanup: .completed))
        #expect(transport.recoveryRequestIDs == [record.requestID])
        #expect(transport.deletionRequestIDs.isEmpty)
        #expect(store.values == [record])
        #expect(transport.localAuthClearCount == 1)
    }

    @Test func deletionRetryRetainsEveryCapturedLegacyPhotoKey() async throws {
        let transport = DeletionTransportStub(capability: safeCapability)
        let record = AccountDeletionRecoveryRecord(
            subjectID: transport.userID,
            requestID: transport.expectedRequestID,
            recoverySecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            createdAt: Date(),
            attributableLegacyPhotoKeys: ["older/local-photo.jpg"]
        )
        let store = DeletionRecoveryStoreStub(values: [record])
        transport.recoveryResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: record.requestID,
            jobId: UUID(),
            subjectId: record.subjectID,
            identityDeleted: true,
            cleanupStatus: "completed",
            completionProofState: "completed",
            status: "completed"
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        _ = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            attributableLegacyPhotoKeys: ["newer/local-photo.jpg"],
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(
            store.values.first?.capturedLegacyPhotoKeys
                == ["older/local-photo.jpg", "newer/local-photo.jpg"]
        )
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func recoveryRecordRoundTripPreservesCapturedLegacyPhotoKeys() throws {
        let record = AccountDeletionRecoveryRecord(
            subjectID: UUID(),
            requestID: UUID(),
            recoverySecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            attributableLegacyPhotoKeys: ["one.jpg", "two.jpg"]
        )

        let decoded = try JSONDecoder().decode(
            AccountDeletionRecoveryRecord.self,
            from: JSONEncoder().encode(record)
        )

        #expect(decoded == record)
        #expect(decoded.capturedLegacyPhotoKeys == ["one.jpg", "two.jpg"])
    }

    @Test func recentAuthenticationFailureDoesNotLeavePhantomRecovery() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        transport.deletionError = FunctionsError.httpError(
            code: 403,
            data: Data("{\"error\":\"recent_authentication_required\"}".utf8)
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("Deletion accepted an old authentication session.")
        } catch {
            #expect(error as? AccountDeletionError == .stepUpAuthenticationExpired)
        }
        #expect(store.values.isEmpty)
        #expect(transport.localAuthClearCount == 0)
    }

    @Test func stepUpCapabilityFieldsFailClosedBeforeChallenge() async throws {
        let capability = AccountDeletionCapability(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            destructiveAction: AccountDeletionService.deletionAction,
            requiresExplicitAction: true,
            stepUpClientConfigured: false,
            identityBeforeStorage: true,
            buckets: Array(AccountDeletionService.requiredBuckets),
            cleanupWorkerAction: AccountDeletionService.cleanupWorkerAction,
            cleanupWorkerAuthentication: "service_role_bearer",
            cleanupWorkerInvocation: "scheduled_service_role_batch",
            cleanupDelivery: "durable_scheduled_retry",
            automaticCleanupScheduled: true,
            liveSessionGateConfigured: true
        )
        let transport = DeletionTransportStub(capability: capability)
        let service = AccountDeletionService(transport: transport)

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .supportRequired(.upgradeRequired))
        #expect(transport.events.isEmpty)
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func durableRecoveryCapabilityFieldsFailClosedBeforeChallenge() async throws {
        let capability = AccountDeletionCapability(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            destructiveAction: AccountDeletionService.deletionAction,
            requiresExplicitAction: true,
            localCleanupAcknowledgementAction: nil,
            completionReceiptFreshDays: nil,
            completionTombstoneRetention: nil,
            completionTombstoneFinalRetentionDays: nil,
            recoveryCapabilityExpires: nil,
            recoveryCapabilityExpiresAfterLocalAcknowledgement: nil,
            identityBeforeStorage: true,
            buckets: Array(AccountDeletionService.requiredBuckets),
            cleanupWorkerAction: AccountDeletionService.cleanupWorkerAction,
            cleanupWorkerAuthentication: "service_role_bearer",
            cleanupWorkerInvocation: "scheduled_service_role_batch",
            cleanupDelivery: "durable_scheduled_retry",
            automaticCleanupScheduled: true,
            liveSessionGateConfigured: true
        )
        let transport = DeletionTransportStub(capability: capability)
        let service = AccountDeletionService(transport: transport)

        let outcome = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            authenticateFreshSession: { transport.freshAuthentication() }
        )

        #expect(outcome == .supportRequired(.upgradeRequired))
        #expect(transport.events.isEmpty)
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func completedDeletionWithoutProofStateFailsClosed() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: UUID(),
            subjectId: transport.userID,
            identityDeleted: true,
            cleanupStatus: "completed",
            status: "completed"
        )
        let service = AccountDeletionService(transport: transport)

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("A completed deletion without durable proof was accepted.")
        } catch {
            #expect(error as? AccountDeletionError == .invalidV3Response)
        }

        #expect(transport.localAuthClearCount == 0)
    }

    @Test func recoveryIsPersistedBeforeFreshAuthenticationAndPostsInOrder() async throws {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        transport.deletionResponse = AccountDeletionV3Response(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            requestId: transport.expectedRequestID,
            jobId: UUID(),
            subjectId: transport.userID,
            identityDeleted: true,
            cleanupStatus: "completed",
            completionProofState: "completed",
            status: "completed"
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        _ = try await service.deleteCurrentAccount(
            expectedUserID: transport.userID,
            requestID: transport.expectedRequestID,
            authenticateFreshSession: {
                #expect(store.values.first?.requestID == transport.expectedRequestID)
                return transport.freshAuthentication()
            }
        )

        #expect(
            transport.events
                == ["begin_step_up", "fresh_authentication", "authorize_step_up", "delete"]
        )
    }

    @Test func freshAuthenticationForAnotherSubjectFailsBeforeAuthorization() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: {
                    transport.freshAuthentication(subjectID: UUID())
                }
            )
            Issue.record("A fresh session for another account reached authorization.")
        } catch {
            #expect(error as? AccountDeletionError == .accountScopeChanged)
        }

        #expect(transport.events == ["begin_step_up", "fresh_authentication"])
        #expect(transport.discardedLocalSessionCount == 1)
        #expect(store.values.isEmpty)
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func mismatchedAuthorizationReceiptFailsBeforeDestructivePost() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        transport.authorizationResponse = AccountDeletionStepUpAuthorization(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            action: AccountDeletionService.authorizeStepUpAction,
            requestId: transport.expectedRequestID,
            subjectId: transport.userID,
            challengeId: UUID(),
            authorizationSecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            expiresAt: "2099-01-01T00:00:00Z",
            singleUse: true
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("A mismatched step-up receipt reached deletion.")
        } catch {
            #expect(error as? AccountDeletionError == .invalidV3Response)
        }

        #expect(store.values.isEmpty)
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func expiredStepUpAuthorizationCanRestartWithoutPhantomRecovery() async {
        let transport = DeletionTransportStub(capability: safeCapability)
        let store = DeletionRecoveryStoreStub()
        transport.authorizationError = FunctionsError.httpError(
            code: 403,
            data: Data("{\"error\":\"step_up_reauthentication_required\"}".utf8)
        )
        let service = AccountDeletionService(
            transport: transport,
            recoveryStore: store
        )

        do {
            _ = try await service.deleteCurrentAccount(
                expectedUserID: transport.userID,
                requestID: transport.expectedRequestID,
                authenticateFreshSession: { transport.freshAuthentication() }
            )
            Issue.record("An expired authorization was accepted.")
        } catch {
            #expect(error as? AccountDeletionError == .stepUpAuthenticationExpired)
        }

        #expect(store.values.isEmpty)
        #expect(transport.deletionRequestIDs.isEmpty)
    }

    @Test func purgeRemovesOnlyOneOfTwoAccountsAndPreservesGuestState() throws {
        let firstUserID = UUID()
        let secondUserID = UUID()
        let root = temporaryDirectory(named: "AccountPurge")
        let defaultsName = "AccountPurge.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        let drafts = SipDraftStore(
            baseDirectory: root.appendingPathComponent("Drafts", isDirectory: true)
        )
        let guestDraft = SipDraft(
            context: .home,
            drinkName: "Guest sip",
            visibility: .private
        )
        let firstDraft = SipDraft(
            ownerUserID: firstUserID,
            context: .home,
            drinkName: "First sip",
            visibility: .private
        )
        let secondDraft = SipDraft(
            ownerUserID: secondUserID,
            context: .home,
            drinkName: "Second sip",
            visibility: .private
        )
        _ = try drafts.save(guestDraft, images: [], in: .guest)
        _ = try drafts.save(firstDraft, images: [image(.red)], in: .user(firstUserID))
        _ = try drafts.save(secondDraft, images: [image(.blue)], in: .user(secondUserID))
        try drafts.purge(ownerUserID: firstUserID)

        #expect(drafts.load(id: firstDraft.id, in: .user(firstUserID)) == nil)
        #expect(drafts.load(id: secondDraft.id, in: .user(secondUserID)) != nil)
        #expect(drafts.load(id: guestDraft.id, in: .guest) != nil)

        let pending = PendingVisitSubmissionStore(
            defaults: defaults,
            baseDirectory: root.appendingPathComponent("Pending", isDirectory: true)
        )
        let firstPending = try preparePending(
            store: pending,
            userID: firstUserID,
            image: image(.orange)
        )
        let secondPending = try preparePending(
            store: pending,
            userID: secondUserID,
            image: image(.green)
        )
        try pending.purge(userId: firstUserID)

        #expect(try pending.loadAll(userId: firstUserID).isEmpty)
        #expect(try pending.loadAll(userId: secondUserID) == [secondPending])
        #expect(try pending.loadImages(for: secondPending).count == 1)
        #expect(firstPending.userId == firstUserID)

        let cache = PhotoCache(
            photosDirectory: root.appendingPathComponent("Photos", isDirectory: true),
            initialScope: .guest
        )
        try cache.storeDurably(image(.gray), forKey: "guest")
        try cache.activate(scope: .user(firstUserID))
        try cache.storeDurably(image(.red), forKey: "first")
        try cache.activate(scope: .user(secondUserID))
        try cache.storeDurably(image(.blue), forKey: "second")
        try cache.purge(ownerUserID: firstUserID)

        try cache.activate(scope: .user(firstUserID))
        #expect(cache.retrieve(forKey: "first") == nil)
        try cache.activate(scope: .user(secondUserID))
        #expect(cache.retrieve(forKey: "second") != nil)
        try cache.activate(scope: .guest)
        #expect(cache.retrieve(forKey: "guest") != nil)

        let dataManager = DataManager(defaults: defaults)
        dataManager.prepareGuestSession()
        dataManager.addCafe(Cafe(name: "Guest Cafe", isFavorite: true))
        dataManager.applyAuthenticatedProfile(profile(id: secondUserID, name: "Second"))
        dataManager.addCafe(Cafe(name: "Second Cafe"))
        dataManager.applyAuthenticatedProfile(profile(id: firstUserID, name: "First"))
        dataManager.addCafe(Cafe(name: "First Cafe"))
        dataManager.clearLocalReleaseState(for: firstUserID)

        #expect(dataManager.guestSavedCafes().map(\.name) == ["Guest Cafe"])
        dataManager.applyAuthenticatedProfile(profile(id: secondUserID, name: "Second"))
        #expect(dataManager.appData.cafes.map(\.name) == ["Second Cafe"])
        dataManager.applyAuthenticatedProfile(profile(id: firstUserID, name: "First"))
        #expect(dataManager.appData.cafes.isEmpty)
    }

    @Test func ownerExportFallbackIsExplicitlyPartial() async throws {
        let resources = try makePendingResources(named: "ExportFallback")
        defer { resources.cleanup() }
        let remote = OwnerExportTransportStub(userID: UUID())
        remote.v2Error = PostgrestError(
            code: "PGRST202",
            message: "function is unavailable"
        )
        remote.v1Data = Data("{\"schema_version\":1}".utf8)
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            fileManager: .default,
            session: .shared
        )

        let package = try await service.prepareExport()
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }

        #expect(package.sourceSchemaVersion == 1)
        #expect(package.completeness == .partial)
        #expect(package.omittedCollections == OwnerDataExportService.v1OmittedCollections.sorted())
    }

    @Test func ownerExportPackagesPendingMediaWithoutSandboxPaths() async throws {
        let resources = try makePendingResources(named: "PendingExport")
        defer { resources.cleanup() }
        let ownerID = UUID()
        let pending = try preparePending(
            store: resources.store,
            userID: ownerID,
            image: image(.purple)
        )
        let remote = OwnerExportTransportStub(userID: ownerID)
        remote.v2Data = try JSONSerialization.data(withJSONObject: [
            "schema_version": 2,
            "export_manifest": [
                "server_contract_completeness": "complete_as_of_schema_version_2",
                "known_omissions": []
            ],
            "media_references": []
        ])
        remote.enforcementData = try JSONSerialization.data(withJSONObject: [
            "enforcement_decisions": [["action_kind": "warning"]],
            "appeals": [["status": "pending", "statement": "Please review this context."]]
        ])
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            fileManager: .default,
            session: .shared
        )

        let package = try await service.prepareExport()
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }
        let journal = try Data(contentsOf: package.shareURLs[0])
        let journalText = try #require(String(data: journal, encoding: .utf8))
        let object = try #require(
            JSONSerialization.jsonObject(with: journal) as? [String: Any]
        )
        let outbox = try #require(
            object["local_pending_submission_outbox"] as? [[String: Any]]
        )
        let manifest = try #require(
            object["pending_outbox_media_manifest"] as? [[String: Any]]
        )
        let enforcement = try #require(
            object["enforcement_and_appeals"] as? [String: Any]
        )

        #expect(package.completeness == .complete)
        #expect(package.packagedMediaCount == 1)
        #expect(outbox.first?["localPhotoNames"] == nil)
        #expect(outbox.first?["localPhotoCount"] as? Int == 1)
        #expect(
            manifest.first?["files"] as? [String]
                == ["Pending-MugShots/\(pending.id.uuidString.lowercased())/photo-001.jpg"]
        )
        #expect(!journalText.contains(resources.directory.path))
        #expect((enforcement["appeals"] as? [[String: Any]])?.count == 1)
    }

    @Test func missingEnforcementSupplementMakesV2ExportExplicitlyPartial() async throws {
        let resources = try makePendingResources(named: "EnforcementExportFallback")
        defer { resources.cleanup() }
        let remote = OwnerExportTransportStub(userID: UUID())
        remote.v2Data = try JSONSerialization.data(withJSONObject: [
            "schema_version": 2,
            "export_manifest": [
                "server_contract_completeness": "complete_as_of_schema_version_2",
                "known_omissions": []
            ],
            "media_references": []
        ])
        remote.enforcementError = PostgrestError(
            code: "PGRST202",
            message: "function is unavailable"
        )
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            fileManager: .default,
            session: .shared
        )

        let package = try await service.prepareExport()
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }

        #expect(package.sourceSchemaVersion == 2)
        #expect(package.completeness == .partial)
        #expect(
            package.omittedCollections.contains(
                "enforcement decisions and appeal statements"
            )
        )
    }

    @Test func completeExportIncludesLocalDraftsAndUnconfirmedSafetyReceipts() async throws {
        let resources = try makePendingResources(named: "LocalExportSupplements")
        let defaultsName = "LocalExportSupplements.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            resources.cleanup()
        }
        let ownerID = UUID()
        let draftStore = SipDraftStore(
            baseDirectory: resources.directory.appendingPathComponent(
                "Drafts",
                isDirectory: true
            )
        )
        let draft = SipDraft(
            ownerUserID: ownerID,
            context: .home,
            drinkName: "Private draft",
            socialCaption: "Still deciding",
            visibility: .private
        )
        _ = try draftStore.save(
            draft,
            images: [image(.cyan)],
            in: .user(ownerID)
        )
        let safetyDirectory = resources.directory.appendingPathComponent(
            "SocialSafety",
            isDirectory: true
        )
        let reportStore = SafetyReportReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: safetyDirectory
        )
        let report = try reportStore.prepare(
            accountID: ownerID,
            target: .visit(UUID()),
            reason: .other,
            details: "Unconfirmed report context"
        )
        _ = try reportStore.markFailed(report)
        let appealStore = ModerationAppealReceiptStore(
            defaults: defaults,
            protectedBaseDirectory: safetyDirectory
        )
        _ = try appealStore.prepare(
            accountID: ownerID,
            actionID: UUID(),
            statement: "Please review the missing context."
        )

        let remote = OwnerExportTransportStub(userID: ownerID)
        remote.v2Data = try JSONSerialization.data(withJSONObject: [
            "schema_version": 2,
            "export_manifest": [
                "server_contract_completeness": "complete_as_of_schema_version_2",
                "known_omissions": []
            ],
            "media_references": []
        ])
        remote.enforcementData = Data("{}".utf8)
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            draftStore: draftStore,
            reportStore: reportStore,
            appealStore: appealStore,
            fileManager: .default,
            session: .shared
        )

        let package = try await service.prepareExport()
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }
        let journal = try Data(contentsOf: package.shareURLs[0])
        let object = try #require(
            JSONSerialization.jsonObject(with: journal) as? [String: Any]
        )
        let drafts = try #require(object["local_sip_drafts"] as? [[String: Any]])
        let reports = try #require(
            object["local_unconfirmed_safety_reports"] as? [[String: Any]]
        )
        let appeals = try #require(
            object["local_unconfirmed_moderation_appeals"] as? [[String: Any]]
        )
        let draftManifest = try #require(
            object["draft_media_manifest"] as? [[String: Any]]
        )

        #expect(package.completeness == .complete)
        #expect(package.packagedMediaCount == 1)
        #expect(drafts.count == 1)
        #expect(drafts.first?["localPhotoNames"] == nil)
        #expect(drafts.first?["localPhotoCount"] as? Int == 1)
        #expect(reports.count == 1)
        #expect(appeals.count == 1)
        #expect(draftManifest.count == 1)
    }

    @Test func unreadableLocalRecoveryDataMakesExportPartialWithoutChangingBytes() async throws {
        let resources = try makePendingResources(named: "UnreadableLocalExport")
        defer { resources.cleanup() }
        let ownerID = UUID()
        let pendingBytes = Data("unreadable-pending-outbox".utf8)
        let pendingKey = PendingVisitSubmissionStore.outboxStorageKey(for: ownerID)
        resources.defaults.set(pendingBytes, forKey: pendingKey)

        let draftBase = resources.directory.appendingPathComponent(
            "Drafts",
            isDirectory: true
        )
        let draftStore = SipDraftStore(baseDirectory: draftBase)
        let readableDraft = SipDraft(
            ownerUserID: ownerID,
            context: .home,
            drinkName: "Readable local draft",
            visibility: .private
        )
        _ = try draftStore.save(
            readableDraft,
            images: [],
            in: .user(ownerID)
        )
        let unreadableDraftID = UUID()
        let unreadableDraftDirectory = draftBase
            .appendingPathComponent("v2/users", isDirectory: true)
            .appendingPathComponent(ownerID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(
                unreadableDraftID.uuidString.lowercased(),
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: unreadableDraftDirectory,
            withIntermediateDirectories: true
        )
        let draftBytes = Data("unreadable-draft-metadata".utf8)
        let draftMetadataURL = unreadableDraftDirectory
            .appendingPathComponent("draft.json")
        try draftBytes.write(to: draftMetadataURL, options: .atomic)

        let remote = OwnerExportTransportStub(userID: ownerID)
        remote.v2Data = try JSONSerialization.data(withJSONObject: [
            "schema_version": 2,
            "export_manifest": [
                "server_contract_completeness": "complete_as_of_schema_version_2",
                "known_omissions": []
            ],
            "media_references": []
        ])
        remote.enforcementData = Data("{}".utf8)
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            draftStore: draftStore,
            fileManager: .default,
            session: .shared
        )

        let syncSnapshot = SyncHealthSnapshot(
            userID: ownerID,
            draftStore: draftStore,
            pendingStore: resources.store
        )
        #expect(syncSnapshot.hasLocalReadIssues)
        #expect(syncSnapshot.localReadIssueCount == 2)
        #expect(syncSnapshot.title == "Local journal data needs attention")

        let package = try await service.prepareExport()
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }
        let journal = try Data(contentsOf: package.shareURLs[0])
        let object = try #require(
            JSONSerialization.jsonObject(with: journal) as? [String: Any]
        )
        let localStatus = try #require(
            object["local_data_read_status"] as? [String: Any]
        )
        let pendingStatus = try #require(
            localStatus["pending_submission_outbox"] as? [String: Any]
        )
        let draftStatus = try #require(
            localStatus["sip_drafts"] as? [String: Any]
        )
        let exportedDrafts = try #require(
            object["local_sip_drafts"] as? [[String: Any]]
        )

        #expect(package.completeness == .partial)
        #expect(pendingStatus["status"] as? String == "unavailable_preserved")
        #expect(draftStatus["status"] as? String == "partial_unavailable_preserved")
        #expect(exportedDrafts.count == 1)
        #expect(resources.defaults.data(forKey: pendingKey) == pendingBytes)
        #expect(try Data(contentsOf: draftMetadataURL) == draftBytes)
    }

    @Test func privateMediaReferenceRequiresOwnerPrefixAndUsesSignedHTTPSURL() async throws {
        let resources = try makePendingResources(named: "PrivateReference")
        defer { resources.cleanup() }
        let ownerID = UUID()
        let remote = OwnerExportTransportStub(userID: ownerID)
        remote.signedURLValue = try #require(
            URL(string: "https://storage.example.test/signed/private-image")
        )
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            fileManager: .default,
            session: .shared
        )
        let path = "\(ownerID.uuidString.lowercased())/\(UUID())/photo.jpg"
        let reference = OwnerExportMediaReference(source: .storage(
            bucket: "visit-photos-private",
            path: path,
            access: "private"
        ))

        let url = try await service.resolvedURL(for: reference, ownerID: ownerID)

        #expect(url == remote.signedURLValue)
        #expect(remote.signedRequests == ["visit-photos-private|\(path)|300"])

        let rejected = OwnerDataExportService.mediaReferences(from: [
            "media_references": [
                [
                    "kind": "storage",
                    "bucket": "visit-photos-private",
                    "path": "\(UUID())/visit/photo.jpg"
                ],
                ["kind": "remote_url", "url": "http://example.test/photo.jpg"],
                ["kind": "remote_url", "url": "https://127.0.0.1/photo.jpg"],
                ["kind": "remote_url", "url": "https://192.168.1.12/photo.jpg"],
                ["kind": "remote_url", "url": "https://[::1]/photo.jpg"],
                ["kind": "remote_url", "url": "https://printer.local/photo.jpg"]
            ]
        ], ownerID: ownerID)
        #expect(rejected.isEmpty)

        let unsafePath = OwnerExportMediaReference(source: .storage(
            bucket: "visit-photos-private",
            path: "\(ownerID.uuidString.lowercased())/../photo.jpg",
            access: "private"
        ))
        do {
            _ = try await service.resolvedURL(for: unsafePath, ownerID: ownerID)
            Issue.record("A traversal-like Storage path was signed for export.")
        } catch {
            #expect(error as? OwnerDataExportError == .unsafeMediaReference)
        }
    }

    @Test func exportAccountSwitchRemovesTheInFlightTemporaryPackage() async throws {
        let resources = try makePendingResources(named: "ExportAccountSwitch")
        defer { resources.cleanup() }
        try FileManager.default.createDirectory(
            at: resources.directory,
            withIntermediateDirectories: true
        )
        let ownerID = UUID()
        let path = "\(ownerID.uuidString.lowercased())/\(UUID())/photo.jpg"
        let remote = OwnerExportTransportStub(userID: ownerID)
        remote.v2Data = try JSONSerialization.data(withJSONObject: [
            "schema_version": 2,
            "export_manifest": [
                "server_contract_completeness": "complete_as_of_schema_version_2",
                "known_omissions": []
            ],
            "media_references": [[
                "kind": "storage",
                "bucket": "visit-photos-private",
                "path": path
            ]]
        ])
        remote.enforcementData = Data("{}".utf8)
        remote.signedURLValue = try #require(
            URL(string: "https://storage.example.test/signed/private-image")
        )
        remote.userIDAfterSignedURL = UUID()
        let service = OwnerDataExportService(
            remote: remote,
            pendingStore: resources.store,
            fileManager: .default,
            session: .shared,
            temporaryDirectory: resources.directory
        )

        do {
            _ = try await service.prepareExport()
            Issue.record("An export continued after the authenticated account changed.")
        } catch {
            #expect(error as? OwnerDataExportError == .accountScopeChanged)
        }

        let remaining = try FileManager.default.contentsOfDirectory(
            at: resources.directory,
            includingPropertiesForKeys: nil
        )
        #expect(remaining.isEmpty)
    }

    private var safeCapability: AccountDeletionCapability {
        AccountDeletionCapability(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            destructiveAction: AccountDeletionService.deletionAction,
            requiresExplicitAction: true,
            identityBeforeStorage: true,
            buckets: Array(AccountDeletionService.requiredBuckets),
            cleanupWorkerAction: AccountDeletionService.cleanupWorkerAction,
            cleanupWorkerAuthentication: "service_role_bearer",
            cleanupWorkerInvocation: "scheduled_service_role_batch",
            cleanupDelivery: "durable_scheduled_retry",
            automaticCleanupScheduled: true,
            liveSessionGateConfigured: true
        )
    }

    private func preparePending(
        store: PendingVisitSubmissionStore,
        userID: UUID,
        image selectedImage: UIImage
    ) throws -> PendingVisitSubmissionRecord {
        try store.prepare(
            userId: userID,
            cafe: nil,
            entryContext: .home,
            locationName: "Home",
            drinkType: .coffee,
            customDrinkType: nil,
            drinkSubtype: "Coffee",
            caption: "Pending sip",
            notes: nil,
            visibility: .private,
            ratings: ["Taste": 4],
            overallScore: 4,
            ratingTemplate: RatingTemplate(),
            images: [selectedImage],
            posterPhotoIndex: 0
        )
    }

    private func makePendingResources(named name: String) throws -> (
        store: PendingVisitSubmissionStore,
        defaults: UserDefaults,
        directory: URL,
        cleanup: () -> Void
    ) {
        let defaultsName = "\(name).\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let directory = temporaryDirectory(named: name)
        return (
            PendingVisitSubmissionStore(defaults: defaults, baseDirectory: directory),
            defaults,
            directory,
            {
                defaults.removePersistentDomain(forName: defaultsName)
                try? FileManager.default.removeItem(at: directory)
            }
        )
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(name).\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }

    private func profile(id: UUID, name: String) -> SupabaseUserProfile {
        SupabaseUserProfile(
            id: id,
            displayName: name,
            username: name.lowercased(),
            bio: nil,
            location: nil,
            favoriteDrink: nil,
            instagramHandle: nil,
            avatarURL: nil,
            bannerURL: nil,
            websiteURL: nil
        )
    }
}

private final class DeletionTransportStub: AccountDeletionFunctionTransport {
    let expectedRequestID = UUID()
    let userID = UUID()
    var currentUserID: UUID?
    var capability: AccountDeletionCapability
    var capabilityError: Error?
    var userIDAfterCapabilityFetch: UUID?
    var beginStepUpResponse: AccountDeletionStepUpChallenge?
    var beginStepUpError: Error?
    var authorizationResponse: AccountDeletionStepUpAuthorization?
    var authorizationError: Error?
    var deletionResponse: AccountDeletionV3Response?
    var recoveryResponse: AccountDeletionV3Response?
    var acknowledgementResponse: AccountDeletionAcknowledgementResponse?
    var deletionError: Error?
    private let challengeID = UUID()
    private(set) var events: [String] = []
    private(set) var freshSessionCreated = false
    private(set) var deletionRequestIDs: [UUID] = []
    private(set) var recoveryRequestIDs: [UUID] = []
    private(set) var acknowledgementRequestIDs: [UUID] = []
    private(set) var localAuthClearCount = 0
    private(set) var discardedLocalSessionCount = 0

    init(capability: AccountDeletionCapability) {
        self.capability = capability
        currentUserID = userID
    }

    func fetchCapability() async throws -> AccountDeletionCapability {
        if let capabilityError { throw capabilityError }
        if let userIDAfterCapabilityFetch {
            currentUserID = userIDAfterCapabilityFetch
        }
        return capability
    }

    func freshAuthentication(subjectID: UUID? = nil) -> AuthenticatedUser {
        let authenticatedID = subjectID ?? userID
        currentUserID = authenticatedID
        freshSessionCreated = true
        events.append("fresh_authentication")
        return AuthenticatedUser(id: authenticatedID, email: "test@mugshot.app")
    }

    func beginStepUp(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionStepUpChallenge {
        events.append("begin_step_up")
        guard record.subjectID == currentUserID else {
            throw AccountDeletionError.accountScopeChanged
        }
        if let beginStepUpError { throw beginStepUpError }
        return beginStepUpResponse ?? AccountDeletionStepUpChallenge(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            action: AccountDeletionService.beginStepUpAction,
            requestId: record.requestID,
            subjectId: record.subjectID,
            challengeId: challengeID,
            expiresAt: "2099-01-01T00:00:00Z",
            reauthenticationRequired: true
        )
    }

    func authorizeStepUp(
        record: AccountDeletionRecoveryRecord,
        challengeID: UUID
    ) async throws -> AccountDeletionStepUpAuthorization {
        events.append("authorize_step_up")
        guard freshSessionCreated,
              record.subjectID == currentUserID else {
            throw AccountDeletionError.accountScopeChanged
        }
        if let authorizationError { throw authorizationError }
        return authorizationResponse ?? AccountDeletionStepUpAuthorization(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            action: AccountDeletionService.authorizeStepUpAction,
            requestId: record.requestID,
            subjectId: record.subjectID,
            challengeId: challengeID,
            authorizationSecret: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG",
            expiresAt: "2099-01-01T00:00:00Z",
            singleUse: true
        )
    }

    func requestDeletion(
        record: AccountDeletionRecoveryRecord,
        authorization: AccountDeletionStepUpAuthorization
    ) async throws -> AccountDeletionV3Response {
        events.append("delete")
        guard record.subjectID == currentUserID else {
            throw AccountDeletionError.accountScopeChanged
        }
        deletionRequestIDs.append(record.requestID)
        if let deletionError { throw deletionError }
        guard let deletionResponse else { throw AccountLifecycleTestError.missingStub }
        return deletionResponse
    }

    func resumeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionV3Response {
        recoveryRequestIDs.append(record.requestID)
        guard let recoveryResponse else { throw AccountLifecycleTestError.missingStub }
        return recoveryResponse
    }

    func acknowledgeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionAcknowledgementResponse {
        acknowledgementRequestIDs.append(record.requestID)
        return acknowledgementResponse ?? AccountDeletionAcknowledgementResponse(
            protocolName: AccountDeletionService.protocolName,
            protocolVersion: AccountDeletionService.protocolVersion,
            action: AccountDeletionService.acknowledgementAction,
            requestId: record.requestID,
            subjectId: record.subjectID,
            acknowledged: true,
            status: "acknowledged",
            finalRetentionDays: AccountDeletionService.completionTombstoneFinalRetentionDays
        )
    }

    func clearLocalAuthSession(expectedUserID: UUID) async {
        guard expectedUserID == currentUserID else { return }
        localAuthClearCount += 1
    }

    func discardCurrentLocalAuthSession() async {
        discardedLocalSessionCount += 1
        currentUserID = nil
    }
}

private final class DeletionRecoveryStoreStub: AccountDeletionRecoveryStore {
    var values: [AccountDeletionRecoveryRecord]

    init(values: [AccountDeletionRecoveryRecord] = []) {
        self.values = values
    }

    func records() throws -> [AccountDeletionRecoveryRecord] { values }

    func save(_ record: AccountDeletionRecoveryRecord) throws {
        values.removeAll { $0.subjectID == record.subjectID }
        values.append(record)
    }

    func remove(subjectID: UUID) throws {
        values.removeAll { $0.subjectID == subjectID }
    }
}

private final class OwnerExportTransportStub: OwnerDataExportRemoteTransport {
    var currentUserID: UUID?
    var v2Data = Data("{}".utf8)
    var v1Data = Data("{}".utf8)
    var enforcementData = Data("{}".utf8)
    var v2Error: Error?
    var v1Error: Error?
    var enforcementError: Error?
    var signedURLValue: URL?
    var userIDAfterSignedURL: UUID?
    private(set) var signedRequests: [String] = []

    init(userID: UUID?) {
        currentUserID = userID
    }

    func fetchV2Export() async throws -> Data {
        if let v2Error { throw v2Error }
        return v2Data
    }

    func fetchV1Export() async throws -> Data {
        if let v1Error { throw v1Error }
        return v1Data
    }

    func fetchEnforcementExport() async throws -> Data {
        if let enforcementError { throw enforcementError }
        return enforcementData
    }

    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        signedRequests.append("\(bucket)|\(path)|\(expiresIn)")
        if let userIDAfterSignedURL {
            currentUserID = userIDAfterSignedURL
        }
        guard let signedURLValue else { throw AccountLifecycleTestError.missingStub }
        return signedURLValue
    }
}

private enum AccountLifecycleTestError: Error {
    case missingStub
}
