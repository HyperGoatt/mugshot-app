import Combine
import Foundation
import Network
import Supabase

enum AutomaticSipRecoveryState: Equatable {
    case idle
    case pending(Int)
    case waitingForNetwork(Int)
    case recovering(Int)
    case failed(count: Int, published: Bool, message: String)
    case localDataUnavailable(message: String)

    var pendingCount: Int {
        switch self {
        case .idle: 0
        case .pending(let count),
             .waitingForNetwork(let count),
             .recovering(let count),
             .failed(let count, _, _): count
        case .localDataUnavailable: 0
        }
    }
}

struct AutomaticSipRecoveryCandidate {
    let record: PendingVisitSubmissionRecord
    let reconciledRemoteState: Bool
}

struct AutomaticSipRecoveryDependencies {
    var loadRecords: (_ accountID: UUID) throws -> [PendingVisitSubmissionRecord]
    var reconcile: (
        _ record: PendingVisitSubmissionRecord
    ) async throws -> PendingVisitSubmissionRecord
    var recover: (_ candidate: AutomaticSipRecoveryCandidate) async throws -> UUID

    static let live = AutomaticSipRecoveryDependencies(
        loadRecords: { try PendingVisitSubmissionStore.shared.loadAll(userId: $0) },
        reconcile: { record in
            try await PendingVisitPublicationWorker().reconcile(record)
        },
        recover: { candidate in
            try await PendingVisitPublicationWorker().recover(candidate)
        }
    )
}

/// Account-scoped app-lifecycle driver for the frozen visit outbox. It never
/// opens, replaces, or resumes a composer draft; every operation receives the
/// exact durable record selected FIFO for the active authenticated account.
@MainActor
final class AutomaticSipRecoveryCoordinator: ObservableObject {
    @Published private(set) var state: AutomaticSipRecoveryState = .idle
    @Published private(set) var completionRevision = 0

    private let dependencies: AutomaticSipRecoveryDependencies
    private let networkObserver: SipRecoveryNetworkObserver?
    private var activeAccountID: UUID?
    private var isAppActive = false
    private var isNetworkAvailable = false
    private var suppressAutomaticRetry = false
    private var recoveryTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init(
        dependencies: AutomaticSipRecoveryDependencies = .live,
        observesNetwork: Bool = true
    ) {
        self.dependencies = dependencies
        self.networkObserver = observesNetwork ? SipRecoveryNetworkObserver() : nil
        networkObserver?.start { [weak self] isAvailable in
            Task { @MainActor [weak self] in
                self?.setNetworkAvailable(isAvailable)
            }
        }
    }

    func activate(accountID: UUID?) {
        guard activeAccountID != accountID else {
            refreshState()
            scheduleIfEligible()
            return
        }

        activeAccountID = accountID
        suppressAutomaticRetry = false
        if recoveryTask != nil {
            recoveryTask?.cancel()
        }
        refreshState()
        scheduleIfEligible()
    }

    func setAppActive(_ isActive: Bool) {
        let becameActive = isActive && !isAppActive
        isAppActive = isActive
        if becameActive { suppressAutomaticRetry = false }
        refreshState()
        scheduleIfEligible()
    }

    func setNetworkAvailable(_ isAvailable: Bool) {
        let reconnected = isAvailable && !isNetworkAvailable
        isNetworkAvailable = isAvailable
        if reconnected { suppressAutomaticRetry = false }
        refreshState()
        scheduleIfEligible()
    }

    func retryNow() {
        suppressAutomaticRetry = false
        refreshState()
        scheduleIfEligible()
    }

    private func refreshState() {
        guard let accountID = activeAccountID else {
            state = .idle
            return
        }
        let count: Int
        do {
            count = try dependencies.loadRecords(accountID).count
        } catch {
            recordLocalReadFailure()
            return
        }
        guard count > 0 else {
            state = .idle
            return
        }
        if recoveryTask != nil {
            state = .recovering(count)
        } else if !isNetworkAvailable {
            state = .waitingForNetwork(count)
        } else if !isAppActive {
            state = .pending(count)
        } else if case .failed = state, suppressAutomaticRetry {
            return
        } else {
            state = .pending(count)
        }
    }

    private func scheduleIfEligible() {
        guard recoveryTask == nil,
              !suppressAutomaticRetry,
              isAppActive,
              isNetworkAvailable,
              let accountID = activeAccountID else {
            return
        }

        let records: [PendingVisitSubmissionRecord]
        do {
            records = try dependencies.loadRecords(accountID)
        } catch {
            recordLocalReadFailure()
            return
        }
        guard !records.isEmpty else { return }

        let runID = UUID()
        activeRunID = runID
        state = .recovering(records.count)
        recoveryTask = Task { [weak self] in
            await self?.drain(accountID: accountID, runID: runID)
        }
    }

    private func drain(accountID: UUID, runID: UUID) async {
        var recordAtFailure: PendingVisitSubmissionRecord?
        do {
            while !Task.isCancelled {
                guard activeAccountID == accountID else {
                    throw CancellationError()
                }
                let records = try dependencies.loadRecords(accountID)
                guard let record = records.first else {
                    finish(runID: runID, accountID: accountID, completed: true)
                    return
                }
                guard record.userId == accountID else {
                    throw AutomaticSipRecoveryError.accountMismatch
                }

                state = .recovering(records.count)
                recordAtFailure = record
                // Always probe the owner-bound server row before retrying
                // local media or insert work. Older app versions can leave a
                // complete visit beside an outbox record that predates the
                // finalization marker; treating that record as an upload retry
                // traps an already-published MugShot behind missing local
                // photos forever.
                let reconciled = try await dependencies.reconcile(record)
                try Task.checkCancellation()
                recordAtFailure = reconciled
                let candidate = AutomaticSipRecoveryCandidate(
                    record: reconciled,
                    reconciledRemoteState: true
                )

                let completedVisitID = try await dependencies.recover(candidate)
                try Task.checkCancellation()
                guard completedVisitID == record.id else {
                    throw AutomaticSipRecoveryError.identityMismatch
                }
                let remainingRecords = try dependencies.loadRecords(accountID)
                guard !remainingRecords.contains(where: {
                    $0.id == record.id
                }) else {
                    throw AutomaticSipRecoveryError.noProgress
                }
                completionRevision &+= 1
            }
            throw CancellationError()
        } catch is CancellationError {
            finish(runID: runID, accountID: accountID, completed: false)
        } catch {
            guard activeRunID == runID else { return }
            recoveryTask = nil
            activeRunID = nil
            guard activeAccountID == accountID else {
                refreshState()
                scheduleIfEligible()
                return
            }
            suppressAutomaticRetry = true
            let remainingRecords: [PendingVisitSubmissionRecord]
            do {
                remainingRecords = try dependencies.loadRecords(accountID)
            } catch {
                recordLocalReadFailure()
                return
            }
            let published = recordAtFailure.map { failedRecord in
                let latestRecord = remainingRecords.first {
                    $0.id == failedRecord.id
                }
                return latestRecord?.isRemoteFinalized == true
                    || failedRecord.isRemoteFinalized
            } ?? false
            let count = remainingRecords.count
            state = count == 0
                ? .idle
                : .failed(
                    count: count,
                    published: published,
                    message: AutomaticSipRecoveryError.userMessage(
                        for: error,
                        published: published
                    )
                )
        }
    }

    private func finish(runID: UUID, accountID: UUID, completed: Bool) {
        guard activeRunID == runID else { return }
        recoveryTask = nil
        activeRunID = nil
        guard activeAccountID == accountID else {
            refreshState()
            scheduleIfEligible()
            return
        }
        if completed { suppressAutomaticRetry = false }
        refreshState()
        scheduleIfEligible()
    }

    private func recordLocalReadFailure() {
        suppressAutomaticRetry = true
        state = .localDataUnavailable(
            message: "Mugshot couldn’t check the protected local queue. Its stored data was left unchanged. Retry after reopening the app."
        )
    }
}

private final class SipRecoveryNetworkObserver {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mugshot.sip-recovery-network")

    func start(_ handler: @escaping (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            handler(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

struct PublishedSipDraftCleaner {
    var draftStore: SipDraftStore = .shared

    @discardableResult
    func removeDraft(
        matching submission: PendingVisitSubmissionRecord
    ) -> Bool {
        guard submission.isRemoteFinalized else { return false }
        // Remove only the exact draft that created this stable visit ID. An
        // unrelated active draft for the same account is never loaded or
        // replaced by automatic recovery.
        let scope = LocalAccountScope.user(submission.userId)
        guard let storedDraft = draftStore.load(id: submission.id, in: scope),
              storedDraft.draft.id == submission.id,
              storedDraft.draft.ownerUserID == submission.userId else {
            return false
        }
        draftStore.remove(storedDraft.draft, in: scope)
        return true
    }
}

private struct PendingVisitPublicationWorker {
    var pendingStore: PendingVisitSubmissionStore = .shared
    var draftStore: SipDraftStore = .shared

    func reconcile(
        _ record: PendingVisitSubmissionRecord
    ) async throws -> PendingVisitSubmissionRecord {
        guard let latest = pendingStore.load(
            visitId: record.id,
            userId: record.userId
        ), latest.id == record.id, latest.userId == record.userId else {
            throw AutomaticSipRecoveryError.identityMismatch
        }

        let client = try SupabaseClientProvider.shared.client()
        let remoteState = try await VisitService(client: client)
            .fetchOwnedVisitUploadState(
                visitId: latest.id,
                userId: latest.userId
            )
        var reconciled = latest
        if remoteState == .complete {
            if reconciled.remoteFinalizedAt == nil {
                reconciled.remoteFinalizedAt = .now
            }
        } else if remoteState == nil,
                  latest.hasAmbiguousRemoteFinalization {
            // The owner-bound read proved there is no visit row. Recreate the
            // same stable ID and frozen payload; the ambiguity marker remains
            // as evidence that reconciliation was required.
            reconciled.phase = .prepared
            reconciled.uploadedPhotoURLs = nil
        }
        guard reconciled != latest else { return latest }
        try pendingStore.save(reconciled)
        return pendingStore.load(
            visitId: reconciled.id,
            userId: reconciled.userId
        ) ?? reconciled
    }

    func recover(_ candidate: AutomaticSipRecoveryCandidate) async throws -> UUID {
        var submission = candidate.record
        guard let latest = pendingStore.load(
            visitId: submission.id,
            userId: submission.userId
        ), latest.id == submission.id, latest.userId == submission.userId else {
            throw AutomaticSipRecoveryError.identityMismatch
        }
        submission = latest
        if submission.hasAmbiguousRemoteFinalization,
           !candidate.reconciledRemoteState {
            throw AutomaticSipRecoveryError.reconciliationRequired
        }
        guard submission.isRemoteFinalized || submission.hasValidRetryPayload else {
            throw submission.retryPayloadIssue
                ?? AutomaticSipRecoveryError.invalidPayload
        }

        let client = try SupabaseClientProvider.shared.client()
        let visits = VisitService(client: client)
        let cafeSessions = CafeSessionService(client: client)
        var savedVisit: RemoteVisitSummary?

        if !submission.isRemoteFinalized {
            if submission.phase == .prepared {
                savedVisit = try await visits.createVisit(
                    visitId: submission.id,
                    userId: submission.userId,
                    cafe: submission.cafe,
                    entryContext: submission.resolvedEntryContext,
                    locationName: submission.locationName,
                    drinkType: submission.drinkType,
                    customDrinkType: submission.customDrinkType,
                    drinkSubtype: submission.drinkSubtype,
                    brewMethod: submission.brewMethod,
                    equipment: submission.equipment,
                    homeCoffeeBagID: submission.homeCoffeeBagID,
                    brewDetails: submission.resolvedBrewDetails,
                    caption: submission.caption,
                    notes: submission.notes,
                    visibility: .private,
                    ratings: submission.ratings,
                    overallScore: submission.resolvedOverallScore,
                    ratingTemplate: submission.ratingTemplate,
                    uploadState: .uploading
                )
                submission.phase = .visitCreated
                try saveAndReload(&submission)
            }

            if submission.phase >= .visitCreated,
               let session = submission.cafeSession {
                let visit: RemoteVisitSummary
                if let savedVisit {
                    visit = savedVisit
                } else {
                    visit = try await visits.fetchOwnedVisitSummary(
                        visitId: submission.id,
                        userId: submission.userId
                    )
                }
                guard let remoteCafeID = visit.visit.cafeId else {
                    throw CafeSessionServiceError.missingRemoteCafe
                }
                try await cafeSessions.ensureSession(
                    sessionID: session.sessionID,
                    remoteCafeID: remoteCafeID,
                    startedAt: session.startedAt,
                    context: session.visitContext,
                    visibility: .private
                )
                try await cafeSessions.attachVisit(
                    sessionID: session.sessionID,
                    visitID: submission.id,
                    order: session.sipOrder,
                    role: session.sipRole
                )
                if session.sipRole == .primary {
                    if let snapshot = session.experienceSnapshot {
                        try await cafeSessions.recordExperience(
                            snapshot.rebindingCafeID(remoteCafeID),
                            primaryReorderIntention: session.reorderIntention
                        )
                    } else if session.returnIntention != nil
                                || session.reorderIntention != nil {
                        try await cafeSessions.recordIntentions(
                            sessionID: session.sessionID,
                            visitID: submission.id,
                            returnIntention: session.returnIntention,
                            reorderIntention: session.reorderIntention
                        )
                    }
                }
            }

            if submission.phase >= .visitCreated,
               let sensorySnapshot = submission.sensorySnapshot {
                _ = try await SensorySnapshotService(client: client).insertOnce(
                    visitID: submission.id,
                    userID: submission.userId,
                    snapshot: sensorySnapshot
                )
            }

            if submission.phase < .photosUploaded {
                let images = try pendingStore.loadImages(for: submission)
                let uploaded = try await VisitPhotoUploadService(client: client)
                    .uploadPhotos(
                        userId: submission.userId,
                        visitId: submission.id,
                        images: images,
                        posterPhotoIndex: submission.posterPhotoIndex,
                        plannedObjectPaths: submission.objectPaths,
                        replacingExisting: true
                    )
                submission.uploadedPhotoURLs = uploaded.publicURLs
                submission.phase = .photosUploaded
                try saveAndReload(&submission)
            }

            _ = try await visits.attachPhotoURLs(
                visitId: submission.id,
                photoURLs: submission.uploadedPhotoURLs ?? [],
                posterPhotoIndex: submission.posterPhotoIndex
            )

            if submission.finalizationRequestedAt == nil {
                submission.finalizationRequestedAt = .now
                try saveAndReload(&submission)
            }

            if let session = submission.cafeSession {
                try await cafeSessions.finalizeSipUpload(
                    sessionID: session.sessionID,
                    visitID: submission.id
                )
            } else {
                try await visits.finalizeVisitPublication(
                    visitId: submission.id,
                    userId: submission.userId,
                    visibility: submission.visibility
                )
            }

            // Persist this receipt immediately after the irreversible remote
            // boundary and before any projection or local cleanup.
            submission.remoteFinalizedAt = .now
            try saveAndReload(&submission)
        }

        await DiscoveryInteractionService(client: client)
            .consumeAttributionAndCapture(visitID: submission.id)

        // Once the owner-bound server row proves the canonical post is
        // complete, the composer draft is no longer a draft. Remove it before
        // best-effort projection/setup work so a downstream retry can never
        // leave an already-visible post stuck in Drafts.
        PublishedSipDraftCleaner(draftStore: draftStore)
            .removeDraft(matching: submission)

        let postPublication = await SipPostPublicationSetupWorker(
            client: client,
            pendingStore: pendingStore
        ).finish(submission: submission)
        submission = postPublication.submission
        guard submission.isPostPublicationSetupComplete else {
            throw AutomaticSipRecoveryError.postPublicationPending(
                postPublication.warning
            )
        }

        DrinkAnalysisRetryStore.shared.enqueue(
            visitId: submission.id,
            userId: submission.userId
        )
        let completedID = submission.id
        guard let exactReceipt = pendingStore.load(
            visitId: submission.id,
            userId: submission.userId
        ), exactReceipt.isPostPublicationSetupComplete else {
            throw AutomaticSipRecoveryError.noProgress
        }
        pendingStore.remove(exactReceipt)
        guard pendingStore.load(
            visitId: completedID,
            userId: submission.userId
        ) == nil else {
            throw AutomaticSipRecoveryError.noProgress
        }
        return completedID
    }

    private func saveAndReload(
        _ submission: inout PendingVisitSubmissionRecord
    ) throws {
        try pendingStore.save(submission)
        submission = pendingStore.load(
            visitId: submission.id,
            userId: submission.userId
        ) ?? submission
    }
}

enum AutomaticSipRecoveryError: LocalizedError, Equatable {
    case accountMismatch
    case identityMismatch
    case reconciliationRequired
    case invalidPayload
    case noProgress
    case postPublicationPending(String?)

    var errorDescription: String? {
        switch self {
        case .accountMismatch, .identityMismatch:
            "The saved MugShot belongs to a different account or visit."
        case .reconciliationRequired:
            "Mugshot must verify the earlier publication response before retrying."
        case .invalidPayload:
            "The protected MugShot needs review before it can finish publishing."
        case .noProgress:
            "The protected MugShot was kept because recovery could not confirm completion."
        case .postPublicationPending(let warning):
            warning ?? "The MugShot is published, but some finishing work is still pending."
        }
    }

    static func userMessage(
        for error: Error,
        published: Bool = false
    ) -> String {
        if let recovery = error as? AutomaticSipRecoveryError,
           let description = recovery.errorDescription {
            return description
        }
        if let payload = error as? PendingVisitRetryPayloadIssue,
           let description = payload.errorDescription {
            return "\(description) Open the saved MugShot to review it."
        }
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut]
            .contains(urlError.code) {
            return published
                ? "This MugShot is already published. Mugshot will finish clearing its local recovery copy when the connection is ready."
                : "The protected MugShot will retry when the connection is ready."
        }
        return published
            ? "This MugShot is already published. Mugshot couldn’t finish clearing its local recovery copy."
            : "Mugshot couldn’t finish this protected retry. Try again or review the saved MugShot."
    }
}
