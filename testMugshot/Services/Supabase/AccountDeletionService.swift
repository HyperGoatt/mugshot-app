//
//  AccountDeletionService.swift
//  testMugshot
//

import Foundation
import Security
import Supabase

struct AccountDeletionCapability: Decodable, Equatable {
    let protocolName: String
    let protocolVersion: Int
    let destructiveAction: String
    let requiresExplicitAction: Bool
    let expectedSubjectRequired: Bool?
    let recentSessionRequired: Bool?
    let recentSessionMaximumAgeSeconds: Int?
    let stepUpRequired: Bool?
    let stepUpProtocol: String?
    let beginStepUpAction: String?
    let authorizeStepUpAction: String?
    let stepUpChallengeLifetimeSeconds: Int?
    let stepUpAuthorizationLifetimeSeconds: Int?
    let stepUpSingleUse: Bool?
    let stepUpClientConfigured: Bool?
    let recoveryAction: String?
    let localCleanupAcknowledgementAction: String?
    let recoveryAuthentication: String?
    let recoveryPersistsAfterAuthDeletion: Bool?
    let completionReceiptFreshDays: Int?
    let completionTombstoneRetention: String?
    let completionTombstoneFinalRetentionDays: Int?
    let recoveryCapabilityExpires: Bool?
    let recoveryCapabilityExpiresAfterLocalAcknowledgement: Bool?
    let exactOwnerValidatedStorageManifest: Bool?
    let identityBeforeStorage: Bool
    let buckets: [String]
    let cleanupWorkerAction: String?
    let cleanupWorkerAuthentication: String?
    let cleanupWorkerInvocation: String?
    let cleanupDelivery: String?
    let automaticCleanupScheduled: Bool?
    let liveSessionGateConfigured: Bool?

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion
        case destructiveAction
        case requiresExplicitAction
        case expectedSubjectRequired
        case recentSessionRequired
        case recentSessionMaximumAgeSeconds
        case stepUpRequired
        case stepUpProtocol
        case beginStepUpAction
        case authorizeStepUpAction
        case stepUpChallengeLifetimeSeconds
        case stepUpAuthorizationLifetimeSeconds
        case stepUpSingleUse
        case stepUpClientConfigured
        case recoveryAction
        case localCleanupAcknowledgementAction
        case recoveryAuthentication
        case recoveryPersistsAfterAuthDeletion
        case completionReceiptFreshDays
        case completionTombstoneRetention
        case completionTombstoneFinalRetentionDays
        case recoveryCapabilityExpires
        case recoveryCapabilityExpiresAfterLocalAcknowledgement
        case exactOwnerValidatedStorageManifest
        case identityBeforeStorage
        case buckets
        case cleanupWorkerAction
        case cleanupWorkerAuthentication
        case cleanupWorkerInvocation
        case cleanupDelivery
        case automaticCleanupScheduled
        case liveSessionGateConfigured
    }

    init(
        protocolName: String,
        protocolVersion: Int,
        destructiveAction: String,
        requiresExplicitAction: Bool,
        expectedSubjectRequired: Bool? = true,
        recentSessionRequired: Bool? = true,
        recentSessionMaximumAgeSeconds: Int? = 900,
        stepUpRequired: Bool? = true,
        stepUpProtocol: String? = AccountDeletionService.stepUpProtocol,
        beginStepUpAction: String? = AccountDeletionService.beginStepUpAction,
        authorizeStepUpAction: String? = AccountDeletionService.authorizeStepUpAction,
        stepUpChallengeLifetimeSeconds: Int? = AccountDeletionService.stepUpChallengeLifetimeSeconds,
        stepUpAuthorizationLifetimeSeconds: Int? = AccountDeletionService.stepUpAuthorizationLifetimeSeconds,
        stepUpSingleUse: Bool? = true,
        stepUpClientConfigured: Bool? = true,
        recoveryAction: String? = AccountDeletionService.recoveryAction,
        localCleanupAcknowledgementAction: String? = AccountDeletionService.acknowledgementAction,
        recoveryAuthentication: String? = "sha256_capability",
        recoveryPersistsAfterAuthDeletion: Bool? = true,
        completionReceiptFreshDays: Int? = AccountDeletionService.completionReceiptFreshDays,
        completionTombstoneRetention: String? = AccountDeletionService.completionTombstoneRetention,
        completionTombstoneFinalRetentionDays: Int? = AccountDeletionService.completionTombstoneFinalRetentionDays,
        recoveryCapabilityExpires: Bool? = false,
        recoveryCapabilityExpiresAfterLocalAcknowledgement: Bool? = true,
        exactOwnerValidatedStorageManifest: Bool? = true,
        identityBeforeStorage: Bool,
        buckets: [String],
        cleanupWorkerAction: String? = nil,
        cleanupWorkerAuthentication: String? = nil,
        cleanupWorkerInvocation: String? = nil,
        cleanupDelivery: String? = nil,
        automaticCleanupScheduled: Bool? = nil,
        liveSessionGateConfigured: Bool? = nil
    ) {
        self.protocolName = protocolName
        self.protocolVersion = protocolVersion
        self.destructiveAction = destructiveAction
        self.requiresExplicitAction = requiresExplicitAction
        self.expectedSubjectRequired = expectedSubjectRequired
        self.recentSessionRequired = recentSessionRequired
        self.recentSessionMaximumAgeSeconds = recentSessionMaximumAgeSeconds
        self.stepUpRequired = stepUpRequired
        self.stepUpProtocol = stepUpProtocol
        self.beginStepUpAction = beginStepUpAction
        self.authorizeStepUpAction = authorizeStepUpAction
        self.stepUpChallengeLifetimeSeconds = stepUpChallengeLifetimeSeconds
        self.stepUpAuthorizationLifetimeSeconds = stepUpAuthorizationLifetimeSeconds
        self.stepUpSingleUse = stepUpSingleUse
        self.stepUpClientConfigured = stepUpClientConfigured
        self.recoveryAction = recoveryAction
        self.localCleanupAcknowledgementAction = localCleanupAcknowledgementAction
        self.recoveryAuthentication = recoveryAuthentication
        self.recoveryPersistsAfterAuthDeletion = recoveryPersistsAfterAuthDeletion
        self.completionReceiptFreshDays = completionReceiptFreshDays
        self.completionTombstoneRetention = completionTombstoneRetention
        self.completionTombstoneFinalRetentionDays = completionTombstoneFinalRetentionDays
        self.recoveryCapabilityExpires = recoveryCapabilityExpires
        self.recoveryCapabilityExpiresAfterLocalAcknowledgement = recoveryCapabilityExpiresAfterLocalAcknowledgement
        self.exactOwnerValidatedStorageManifest = exactOwnerValidatedStorageManifest
        self.identityBeforeStorage = identityBeforeStorage
        self.buckets = buckets
        self.cleanupWorkerAction = cleanupWorkerAction
        self.cleanupWorkerAuthentication = cleanupWorkerAuthentication
        self.cleanupWorkerInvocation = cleanupWorkerInvocation
        self.cleanupDelivery = cleanupDelivery
        self.automaticCleanupScheduled = automaticCleanupScheduled
        self.liveSessionGateConfigured = liveSessionGateConfigured
    }

    var advertisesRecoveryV3: Bool {
        protocolName == AccountDeletionService.protocolName
            && protocolVersion == AccountDeletionService.protocolVersion
            && recoveryAction == AccountDeletionService.recoveryAction
            && localCleanupAcknowledgementAction == AccountDeletionService.acknowledgementAction
            && recoveryAuthentication == "sha256_capability"
            && recoveryPersistsAfterAuthDeletion == true
            && completionReceiptFreshDays == AccountDeletionService.completionReceiptFreshDays
            && completionTombstoneRetention == AccountDeletionService.completionTombstoneRetention
            && completionTombstoneFinalRetentionDays
                == AccountDeletionService.completionTombstoneFinalRetentionDays
            && recoveryCapabilityExpires == false
            && recoveryCapabilityExpiresAfterLocalAcknowledgement == true
            && exactOwnerValidatedStorageManifest == true
    }

    var advertisesSafeV3: Bool {
        advertisesRecoveryV3
            && destructiveAction == AccountDeletionService.deletionAction
            && requiresExplicitAction
            && expectedSubjectRequired == true
            && recentSessionRequired == true
            && recentSessionMaximumAgeSeconds == 900
            && stepUpRequired == true
            && stepUpProtocol == AccountDeletionService.stepUpProtocol
            && beginStepUpAction == AccountDeletionService.beginStepUpAction
            && authorizeStepUpAction == AccountDeletionService.authorizeStepUpAction
            && stepUpChallengeLifetimeSeconds == AccountDeletionService.stepUpChallengeLifetimeSeconds
            && stepUpAuthorizationLifetimeSeconds == AccountDeletionService.stepUpAuthorizationLifetimeSeconds
            && stepUpSingleUse == true
            && stepUpClientConfigured == true
            && identityBeforeStorage
            && Set(buckets).isSuperset(of: AccountDeletionService.requiredBuckets)
            && cleanupWorkerAction == AccountDeletionService.cleanupWorkerAction
            && cleanupWorkerAuthentication == "service_role_bearer"
            && cleanupWorkerInvocation == "scheduled_service_role_batch"
            && cleanupDelivery == "durable_scheduled_retry"
            && automaticCleanupScheduled == true
            && liveSessionGateConfigured == true
    }
}

struct AccountDeletionRecoveryRecord: Codable, Equatable, Sendable {
    let subjectID: UUID
    let requestID: UUID
    let recoverySecret: String
    let createdAt: Date
    let attributableLegacyPhotoKeys: [String]?

    init(
        subjectID: UUID,
        requestID: UUID,
        recoverySecret: String,
        createdAt: Date,
        attributableLegacyPhotoKeys: [String]? = nil
    ) {
        self.subjectID = subjectID
        self.requestID = requestID
        self.recoverySecret = recoverySecret
        self.createdAt = createdAt
        self.attributableLegacyPhotoKeys = attributableLegacyPhotoKeys
    }

    var capturedLegacyPhotoKeys: Set<String> {
        Set(attributableLegacyPhotoKeys ?? [])
    }
}

protocol AccountDeletionRecoveryStore: AnyObject {
    func records() throws -> [AccountDeletionRecoveryRecord]
    func save(_ record: AccountDeletionRecoveryRecord) throws
    func remove(subjectID: UUID) throws
}

private final class VolatileAccountDeletionRecoveryStore: AccountDeletionRecoveryStore {
    private var values: [AccountDeletionRecoveryRecord] = []

    func records() throws -> [AccountDeletionRecoveryRecord] { values }
    func save(_ record: AccountDeletionRecoveryRecord) throws {
        values.removeAll { $0.subjectID == record.subjectID }
        values.append(record)
    }
    func remove(subjectID: UUID) throws {
        values.removeAll { $0.subjectID == subjectID }
    }
}

private final class KeychainAccountDeletionRecoveryStore: AccountDeletionRecoveryStore {
    private let service = "co.mugshot.account-deletion-recovery.v3"
    private let account = "pending-deletions"

    func records() throws -> [AccountDeletionRecoveryRecord] {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
        do {
            return try JSONDecoder().decode([AccountDeletionRecoveryRecord].self, from: data)
        } catch {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
    }

    func save(_ record: AccountDeletionRecoveryRecord) throws {
        var current = try records().filter { $0.subjectID != record.subjectID }
        current.append(record)
        try write(current.sorted { $0.createdAt < $1.createdAt })
    }

    func remove(subjectID: UUID) throws {
        let remaining = try records().filter { $0.subjectID != subjectID }
        if remaining.isEmpty {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AccountDeletionError.recoveryPersistenceUnavailable
            }
        } else {
            try write(remaining)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    private func write(_ records: [AccountDeletionRecoveryRecord]) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(records)
        } catch {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
        var insert = baseQuery
        insert[kSecValueData] = data
        insert[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
    }
}

private struct AccountDeletionBeginStepUpRequest: Encodable {
    let action = AccountDeletionService.beginStepUpAction
    let protocolVersion = AccountDeletionService.protocolVersion
    let requestId: UUID
    let expectedSubjectId: UUID
    let recoverySecret: String
}

private struct AccountDeletionAuthorizeStepUpRequest: Encodable {
    let action = AccountDeletionService.authorizeStepUpAction
    let protocolVersion = AccountDeletionService.protocolVersion
    let requestId: UUID
    let expectedSubjectId: UUID
    let recoverySecret: String
    let challengeId: UUID
}

private struct AccountDeletionRequest: Encodable {
    let action = AccountDeletionService.deletionAction
    let protocolVersion = AccountDeletionService.protocolVersion
    let requestId: UUID
    let expectedSubjectId: UUID
    let recoverySecret: String
    let challengeId: UUID
    let authorizationSecret: String
}

private struct AccountDeletionRecoveryRequest: Encodable {
    let action = AccountDeletionService.recoveryAction
    let protocolVersion = AccountDeletionService.protocolVersion
    let requestId: UUID
    let expectedSubjectId: UUID
    let recoverySecret: String
}

private struct AccountDeletionAcknowledgementRequest: Encodable {
    let action = AccountDeletionService.acknowledgementAction
    let protocolVersion = AccountDeletionService.protocolVersion
    let requestId: UUID
    let expectedSubjectId: UUID
    let recoverySecret: String
}

struct AccountDeletionStepUpChallenge: Decodable, Equatable {
    let protocolName: String
    let protocolVersion: Int
    let action: String
    let requestId: UUID
    let subjectId: UUID
    let challengeId: UUID
    let expiresAt: String
    let reauthenticationRequired: Bool

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion
        case action
        case requestId
        case subjectId
        case challengeId
        case expiresAt
        case reauthenticationRequired
    }
}

struct AccountDeletionStepUpAuthorization: Decodable, Equatable {
    let protocolName: String
    let protocolVersion: Int
    let action: String
    let requestId: UUID
    let subjectId: UUID
    let challengeId: UUID
    let authorizationSecret: String
    let expiresAt: String
    let singleUse: Bool

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion
        case action
        case requestId
        case subjectId
        case challengeId
        case authorizationSecret
        case expiresAt
        case singleUse
    }
}

struct AccountDeletionV3Response: Decodable, Equatable {
    let protocolName: String
    let protocolVersion: Int
    let requestId: UUID
    let jobId: UUID?
    let subjectId: UUID
    let found: Bool?
    let identityDeleted: Bool?
    let cleanupStatus: String?
    let completionProofState: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion
        case requestId
        case jobId
        case subjectId
        case found
        case identityDeleted
        case cleanupStatus
        case completionProofState
        case status
    }

    init(
        protocolName: String,
        protocolVersion: Int,
        requestId: UUID,
        jobId: UUID?,
        subjectId: UUID,
        found: Bool? = nil,
        identityDeleted: Bool?,
        cleanupStatus: String?,
        completionProofState: String? = nil,
        status: String
    ) {
        self.protocolName = protocolName
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.jobId = jobId
        self.subjectId = subjectId
        self.found = found
        self.identityDeleted = identityDeleted
        self.cleanupStatus = cleanupStatus
        self.completionProofState = completionProofState
        self.status = status
    }
}

struct AccountDeletionAcknowledgementResponse: Decodable, Equatable {
    let protocolName: String
    let protocolVersion: Int
    let action: String
    let requestId: UUID
    let subjectId: UUID
    let acknowledged: Bool
    let status: String
    let finalRetentionDays: Int

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case protocolVersion
        case action
        case requestId
        case subjectId
        case acknowledged
        case status
        case finalRetentionDays
    }
}

protocol AccountDeletionFunctionTransport: AnyObject {
    var currentUserID: UUID? { get }
    func fetchCapability() async throws -> AccountDeletionCapability
    func beginStepUp(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionStepUpChallenge
    func authorizeStepUp(
        record: AccountDeletionRecoveryRecord,
        challengeID: UUID
    ) async throws -> AccountDeletionStepUpAuthorization
    func requestDeletion(
        record: AccountDeletionRecoveryRecord,
        authorization: AccountDeletionStepUpAuthorization
    ) async throws -> AccountDeletionV3Response
    func resumeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionV3Response
    func acknowledgeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionAcknowledgementResponse
    func clearLocalAuthSession(expectedUserID: UUID) async
    func discardCurrentLocalAuthSession() async
}

private final class SupabaseAccountDeletionFunctionTransport: AccountDeletionFunctionTransport {
    private let client: SupabaseClient
    private let anonymousAuthorization: String?

    init(client: SupabaseClient) {
        self.client = client
        anonymousAuthorization = try? SupabaseConfiguration.load().publishableKey
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func fetchCapability() async throws -> AccountDeletionCapability {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .get,
                headers: anonymousHeaders
            )
        )
    }

    func beginStepUp(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionStepUpChallenge {
        guard currentUserID == record.subjectID else {
            throw AccountDeletionError.accountScopeChanged
        }
        return try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                body: AccountDeletionBeginStepUpRequest(
                    requestId: record.requestID,
                    expectedSubjectId: record.subjectID,
                    recoverySecret: record.recoverySecret
                )
            )
        )
    }

    func authorizeStepUp(
        record: AccountDeletionRecoveryRecord,
        challengeID: UUID
    ) async throws -> AccountDeletionStepUpAuthorization {
        guard currentUserID == record.subjectID else {
            throw AccountDeletionError.accountScopeChanged
        }
        return try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                body: AccountDeletionAuthorizeStepUpRequest(
                    requestId: record.requestID,
                    expectedSubjectId: record.subjectID,
                    recoverySecret: record.recoverySecret,
                    challengeId: challengeID
                )
            )
        )
    }

    func requestDeletion(
        record: AccountDeletionRecoveryRecord,
        authorization: AccountDeletionStepUpAuthorization
    ) async throws -> AccountDeletionV3Response {
        guard currentUserID == record.subjectID else {
            throw AccountDeletionError.accountScopeChanged
        }
        return try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                body: AccountDeletionRequest(
                    requestId: record.requestID,
                    expectedSubjectId: record.subjectID,
                    recoverySecret: record.recoverySecret,
                    challengeId: authorization.challengeId,
                    authorizationSecret: authorization.authorizationSecret
                )
            )
        )
    }

    func resumeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionV3Response {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                headers: anonymousHeaders,
                body: AccountDeletionRecoveryRequest(
                    requestId: record.requestID,
                    expectedSubjectId: record.subjectID,
                    recoverySecret: record.recoverySecret
                )
            )
        )
    }

    func acknowledgeDeletion(
        record: AccountDeletionRecoveryRecord
    ) async throws -> AccountDeletionAcknowledgementResponse {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                headers: anonymousHeaders,
                body: AccountDeletionAcknowledgementRequest(
                    requestId: record.requestID,
                    expectedSubjectId: record.subjectID,
                    recoverySecret: record.recoverySecret
                )
            )
        )
    }

    func clearLocalAuthSession(expectedUserID: UUID) async {
        guard currentUserID == expectedUserID else { return }
        try? await client.auth.signOut(scope: .local)
    }

    func discardCurrentLocalAuthSession() async {
        try? await client.auth.signOut(scope: .local)
    }

    private var anonymousHeaders: [String: String] {
        guard let anonymousAuthorization else { return [:] }
        return ["Authorization": "Bearer \(anonymousAuthorization)"]
    }
}

enum AccountDeletionCleanupState: Equatable {
    case completed
    case pending(jobID: UUID)
}

enum AccountDeletionSupportReason: Equatable {
    case upgradeRequired
    case capabilityUnavailable
    case identityDeletionPending(jobID: UUID)

    var userMessage: String {
        switch self {
        case .upgradeRequired:
            return "Safe account deletion is not fully configured yet. Nothing was deleted. Contact support and try again after the service upgrade."
        case .capabilityUnavailable:
            return "Mugshot couldn’t verify the safe deletion service. Nothing was deleted. Check your connection or contact support before trying again."
        case .identityDeletionPending(let jobID):
            return "Mugshot is still confirming account deletion. Your local data remains on this device. Reference \(jobID.uuidString.lowercased()) if you contact support."
        }
    }
}

enum AccountDeletionOutcome: Equatable {
    case identityDeleted(cleanup: AccountDeletionCleanupState)
    case supportRequired(AccountDeletionSupportReason)
}

enum AccountDeletionRecoveryResolution: Equatable {
    case none
    case resolved(subjectID: UUID, outcome: AccountDeletionOutcome)
}

final class AccountDeletionService {
    static let protocolName = "mugshot-account-deletion"
    static let protocolVersion = 3
    static let deletionAction = "delete_v3"
    static let stepUpProtocol = "fresh_amr_new_session_challenge_v3"
    static let beginStepUpAction = "begin_delete_step_up_v3"
    static let authorizeStepUpAction = "authorize_delete_step_up_v3"
    static let stepUpChallengeLifetimeSeconds = 300
    static let stepUpAuthorizationLifetimeSeconds = 120
    static let recoveryAction = "resume_delete_v3"
    static let acknowledgementAction = "acknowledge_delete_v3"
    static let completionReceiptFreshDays = 400
    static let completionTombstoneRetention = "until_local_cleanup_ack_plus_30_days"
    static let completionTombstoneFinalRetentionDays = 30
    static let cleanupWorkerAction = "drain_deletions_v3"
    static let requiredBuckets: Set<String> = [
        "visit-photos",
        "visit-photos-private",
        "profile-media"
    ]

    private let transport: AccountDeletionFunctionTransport
    private let recoveryStore: AccountDeletionRecoveryStore

    init(client: SupabaseClient) {
        transport = SupabaseAccountDeletionFunctionTransport(client: client)
        recoveryStore = KeychainAccountDeletionRecoveryStore()
    }

    init(
        transport: AccountDeletionFunctionTransport,
        recoveryStore: AccountDeletionRecoveryStore = VolatileAccountDeletionRecoveryStore()
    ) {
        self.transport = transport
        self.recoveryStore = recoveryStore
    }

    var hasPendingRecovery: Bool {
        (try? recoveryStore.records().isEmpty == false) ?? true
    }

    func deleteCurrentAccount(
        expectedUserID: UUID,
        requestID: UUID? = nil,
        attributableLegacyPhotoKeys: Set<String> = [],
        authenticateFreshSession: () async throws -> AuthenticatedUser
    ) async throws -> AccountDeletionOutcome {
        guard transport.currentUserID == expectedUserID else {
            throw AccountDeletionError.accountScopeChanged
        }
        let capability: AccountDeletionCapability
        do {
            capability = try await transport.fetchCapability()
        } catch {
            return .supportRequired(Self.supportReason(for: error))
        }
        guard capability.advertisesSafeV3 else {
            return .supportRequired(.upgradeRequired)
        }
        guard transport.currentUserID == expectedUserID else {
            throw AccountDeletionError.accountScopeChanged
        }

        if var existing = try recoveryStore.records().first(where: {
            $0.subjectID == expectedUserID
        }) {
            let mergedPhotoKeys = existing.capturedLegacyPhotoKeys
                .union(attributableLegacyPhotoKeys)
            if mergedPhotoKeys != existing.capturedLegacyPhotoKeys {
                existing = AccountDeletionRecoveryRecord(
                    subjectID: existing.subjectID,
                    requestID: existing.requestID,
                    recoverySecret: existing.recoverySecret,
                    createdAt: existing.createdAt,
                    attributableLegacyPhotoKeys: mergedPhotoKeys.sorted()
                )
                try recoveryStore.save(existing)
            }
            do {
                let recovered = try await transport.resumeDeletion(record: existing)
                guard recovered.protocolName == Self.protocolName,
                      recovered.protocolVersion == Self.protocolVersion,
                      recovered.requestId == existing.requestID,
                      recovered.subjectId == existing.subjectID else {
                    throw AccountDeletionError.invalidV3Response
                }
                if recovered.found != false || recovered.status != "not_found" {
                    return try await validatedOutcome(
                        recovered,
                        record: existing,
                        clearsAuth: true
                    )
                }
                // The server authoritatively proved the earlier POST never
                // prepared a job. Only now may a fresh destructive request be
                // bound to the current, recently authenticated session.
                try recoveryStore.remove(subjectID: expectedUserID)
            } catch let error as AccountDeletionError {
                throw error
            } catch {
                throw AccountDeletionError.deletionCouldNotBeConfirmed
            }
        }

        let recoverySecret = try Self.makeRecoverySecret()
        let record = AccountDeletionRecoveryRecord(
            subjectID: expectedUserID,
            requestID: requestID ?? UUID(),
            recoverySecret: recoverySecret,
            createdAt: Date(),
            attributableLegacyPhotoKeys: attributableLegacyPhotoKeys.sorted()
        )
        // The recovery capability exists before the first challenge request so
        // every ambiguous destructive network response can be reconciled after
        // a relaunch. It is removed below while no delete POST has been made.
        try recoveryStore.save(record)

        let challenge: AccountDeletionStepUpChallenge
        do {
            challenge = try await transport.beginStepUp(record: record)
            try Self.validate(challenge, record: record)
        } catch {
            try? recoveryStore.remove(subjectID: expectedUserID)
            if let deletionError = error as? AccountDeletionError {
                throw deletionError
            }
            throw AccountDeletionError.stepUpCouldNotBeStarted
        }

        do {
            let freshUser = try await authenticateFreshSession()
            guard freshUser.id == expectedUserID,
                  transport.currentUserID == expectedUserID else {
                throw AccountDeletionError.accountScopeChanged
            }
        } catch {
            if transport.currentUserID != expectedUserID {
                await transport.discardCurrentLocalAuthSession()
                try? recoveryStore.remove(subjectID: expectedUserID)
                throw AccountDeletionError.accountScopeChanged
            }
            try? recoveryStore.remove(subjectID: expectedUserID)
            throw error
        }

        let authorization: AccountDeletionStepUpAuthorization
        do {
            authorization = try await transport.authorizeStepUp(
                record: record,
                challengeID: challenge.challengeId
            )
            try Self.validate(
                authorization,
                challenge: challenge,
                record: record
            )
        } catch {
            try? recoveryStore.remove(subjectID: expectedUserID)
            if Self.isStepUpAuthenticationError(error) {
                throw AccountDeletionError.stepUpAuthenticationExpired
            }
            if let deletionError = error as? AccountDeletionError {
                throw deletionError
            }
            throw AccountDeletionError.stepUpAuthorizationFailed
        }

        let response: AccountDeletionV3Response
        do {
            // From this point forward, retain the Keychain recovery record for
            // every ambiguous response: the single-use authorization may have
            // prepared a durable deletion job before the connection failed.
            response = try await transport.requestDeletion(
                record: record,
                authorization: authorization
            )
        } catch {
            if Self.isStepUpAuthenticationError(error) {
                try? recoveryStore.remove(subjectID: expectedUserID)
                throw AccountDeletionError.stepUpAuthenticationExpired
            }
            throw AccountDeletionError.deletionCouldNotBeConfirmed
        }
        return try await validatedOutcome(
            response,
            record: record,
            clearsAuth: true
        )
    }

    func resumePendingDeletion() async throws -> AccountDeletionRecoveryResolution {
        guard let record = try recoveryStore.records().sorted(by: {
            $0.createdAt < $1.createdAt
        }).first else { return .none }

        let capability = try await transport.fetchCapability()
        guard capability.advertisesRecoveryV3 else {
            throw AccountDeletionError.recoveryServiceUnavailable
        }
        let response = try await transport.resumeDeletion(record: record)
        guard response.protocolName == Self.protocolName,
              response.protocolVersion == Self.protocolVersion,
              response.requestId == record.requestID,
              response.subjectId == record.subjectID else {
            throw AccountDeletionError.invalidV3Response
        }
        if response.found == false, response.status == "not_found" {
            try recoveryStore.remove(subjectID: record.subjectID)
            return .none
        }
        let outcome = try await validatedOutcome(
            response,
            record: record,
            clearsAuth: true
        )
        return .resolved(subjectID: record.subjectID, outcome: outcome)
    }

    func acknowledgeLocalDeletion(subjectID: UUID) async throws {
        guard let record = try recoveryStore.records().first(where: {
            $0.subjectID == subjectID
        }) else { return }
        let response = try await transport.acknowledgeDeletion(record: record)
        guard response.protocolName == Self.protocolName,
              response.protocolVersion == Self.protocolVersion,
              response.action == Self.acknowledgementAction,
              response.requestId == record.requestID,
              response.subjectId == record.subjectID,
              response.finalRetentionDays == Self.completionTombstoneFinalRetentionDays,
              (response.acknowledged && response.status == "acknowledged")
                || (!response.acknowledged && response.status == "not_found") else {
            throw AccountDeletionError.invalidV3Response
        }
        try recoveryStore.remove(subjectID: subjectID)
    }

    func pendingLocalPurgePhotoKeys(subjectID: UUID) -> Set<String> {
        guard let records = try? recoveryStore.records(),
              let record = records.first(where: { $0.subjectID == subjectID }) else {
            return []
        }
        return record.capturedLegacyPhotoKeys
    }

    private func validatedOutcome(
        _ response: AccountDeletionV3Response,
        record: AccountDeletionRecoveryRecord,
        clearsAuth: Bool
    ) async throws -> AccountDeletionOutcome {
        guard response.protocolName == Self.protocolName,
              response.protocolVersion == Self.protocolVersion,
              response.requestId == record.requestID,
              response.subjectId == record.subjectID,
              let jobID = response.jobId,
              let identityDeleted = response.identityDeleted,
              let cleanupStatus = response.cleanupStatus else {
            throw AccountDeletionError.invalidV3Response
        }
        guard identityDeleted else {
            guard response.status == "identity_deletion_pending",
                  cleanupStatus == "not_started" else {
                throw AccountDeletionError.invalidV3Response
            }
            if clearsAuth {
                await transport.clearLocalAuthSession(expectedUserID: record.subjectID)
            }
            return .supportRequired(.identityDeletionPending(jobID: jobID))
        }

        let cleanup: AccountDeletionCleanupState
        switch cleanupStatus {
        case "completed" where response.status == "completed"
            && ["completed", "expired_completed"].contains(response.completionProofState):
            cleanup = .completed
        case "pending" where response.status == "cleanup_pending"
            || response.status == "collaboration_pending":
            cleanup = .pending(jobID: jobID)
        default:
            throw AccountDeletionError.invalidV3Response
        }
        if clearsAuth {
            await transport.clearLocalAuthSession(expectedUserID: record.subjectID)
        }
        return .identityDeleted(cleanup: cleanup)
    }

    private static func makeRecoverySecret() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AccountDeletionError.recoveryPersistenceUnavailable
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func validate(
        _ challenge: AccountDeletionStepUpChallenge,
        record: AccountDeletionRecoveryRecord
    ) throws {
        guard challenge.protocolName == protocolName,
              challenge.protocolVersion == protocolVersion,
              challenge.action == beginStepUpAction,
              challenge.requestId == record.requestID,
              challenge.subjectId == record.subjectID,
              challenge.reauthenticationRequired,
              isServerTimestamp(challenge.expiresAt) else {
            throw AccountDeletionError.invalidV3Response
        }
    }

    private static func validate(
        _ authorization: AccountDeletionStepUpAuthorization,
        challenge: AccountDeletionStepUpChallenge,
        record: AccountDeletionRecoveryRecord
    ) throws {
        guard authorization.protocolName == protocolName,
              authorization.protocolVersion == protocolVersion,
              authorization.action == authorizeStepUpAction,
              authorization.requestId == record.requestID,
              authorization.subjectId == record.subjectID,
              authorization.challengeId == challenge.challengeId,
              authorization.singleUse,
              isCapabilitySecret(authorization.authorizationSecret),
              isServerTimestamp(authorization.expiresAt) else {
            throw AccountDeletionError.invalidV3Response
        }
    }

    private static func isCapabilitySecret(_ value: String) -> Bool {
        value.count == 43
            && value.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0)
                    || $0 == "-"
                    || $0 == "_"
            }
    }

    private static func isServerTimestamp(_ value: String) -> Bool {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        if fractional.date(from: value) != nil { return true }
        return ISO8601DateFormatter().date(from: value) != nil
    }

    private static func supportReason(for error: Error) -> AccountDeletionSupportReason {
        if case let FunctionsError.httpError(code, _) = error,
           code == 404 || code == 405 {
            return .upgradeRequired
        }
        return .capabilityUnavailable
    }

    private static func isStepUpAuthenticationError(_ error: Error) -> Bool {
        guard case let FunctionsError.httpError(code, data) = error, code == 403 else {
            return false
        }
        let response = String(data: data, encoding: .utf8) ?? ""
        return response.contains("step_up_reauthentication_required")
            || response.contains("step_up_authorization_required")
            || response.contains("recent_authentication_required")
    }
}

enum AccountDeletionError: LocalizedError, Equatable {
    case accountScopeChanged
    case deletionCouldNotBeConfirmed
    case invalidV3Response
    case recoveryPersistenceUnavailable
    case recoveryServiceUnavailable
    case stepUpAuthenticationExpired
    case stepUpAuthorizationFailed
    case stepUpCouldNotBeStarted

    var errorDescription: String? {
        switch self {
        case .accountScopeChanged:
            return "The signed-in account changed before deletion could be confirmed. Nothing was deleted for the newly signed-in account."
        case .deletionCouldNotBeConfirmed:
            return "Mugshot couldn’t confirm account deletion. Your recovery reference is saved securely on this device, and your local data was not cleared. Try again or contact support."
        case .invalidV3Response:
            return "Mugshot received an invalid deletion receipt. Your local data was not cleared. Contact support before trying again."
        case .recoveryPersistenceUnavailable:
            return "Mugshot couldn’t securely save a deletion recovery reference. Nothing was deleted. Unlock this device and try again."
        case .recoveryServiceUnavailable:
            return "Mugshot couldn’t safely resume the pending deletion. Your local data remains on this device. Check your connection or contact support."
        case .stepUpAuthenticationExpired:
            return "That security check expired or was already used. Nothing new was deleted. Start again to create a fresh verification."
        case .stepUpAuthorizationFailed:
            return "Mugshot couldn’t verify that fresh sign-in. Nothing was deleted. Check your connection and try again."
        case .stepUpCouldNotBeStarted:
            return "Mugshot couldn’t start the security check. Nothing was deleted. Check your connection and try again."
        }
    }
}
