import SwiftUI

/// Loads the versioned offline bundle and account-scoped learning context,
/// then freezes the completed UI session into an immutable visit snapshot.
struct TastingLens2ComposerContainer: View {
    let analysis: DrinkAnalysis?
    let rawDrinkName: String
    let userID: UUID?
    let remoteSyncEnabled: Bool
    let history: [SipSensorySnapshot]
    let existingSnapshot: SipSensorySnapshot?
    let existingSession: TastingLensSessionDraft?
    let onComplete: (SipSensorySnapshot) -> Void
    let onCancel: () -> Void
    let onSessionUpdate: (TastingLensSessionDraft) -> Void

    @State private var runtime: Runtime?
    @State private var loadError: String?

    private let preferencesStore = TastingLensPreferencesStore()
    private let selectionService = TastingLensSelectionService()
    private let personalizationEngine = TastingLensPersonalizationEngine()

    var body: some View {
        Group {
            if let runtime {
                TastingLens2View(
                    session: runtime.session,
                    bundle: runtime.bundle,
                    selection: runtime.selection,
                    history: runtime.history,
                    preferences: runtime.preferences,
                    learnedPatterns: runtime.patterns,
                    contentState: runtime.contentState,
                    selectionBuilder: { identity, depth, preferences in
                        selectionService.makeSelection(
                            analysis: analysis,
                            confirmedIdentity: identity,
                            depth: depth,
                            bundle: runtime.bundle,
                            preferences: preferences,
                            patterns: runtime.patterns
                        )
                    },
                    onComplete: { session, preferences in
                        finish(session, preferences: preferences, runtime: runtime)
                    },
                    onCancel: onCancel,
                    onUpdatePreferences: persistPreferences,
                    onSessionUpdate: onSessionUpdate,
                    onRetry: { Task { await prepare() } }
                )
            } else if let loadError {
                TastingLensBootstrapError(
                    message: loadError,
                    onRetry: { Task { await prepare() } },
                    onCancel: onCancel
                )
            } else {
                TastingLensBootstrapLoading()
            }
        }
        .task { await prepare() }
    }

    @MainActor
    private func prepare() async {
        do {
            let bundle = try TastingLensKnowledgeStore.shared.loadBundle()
            let preferenceUserID = userID ?? Self.guestPreferenceID
            var preferences: TastingLensUserPreferences
            if let userID {
                preferences = preferencesStore.load(userID: userID)
            } else {
                preferences = TastingLensUserPreferences(userID: preferenceUserID)
            }
            var mergedHistory = history
            var contentState = TastingLensContentState.ready

            if remoteSyncEnabled, let userID {
                do {
                    let remote = try await loadRemoteContext(userID: userID)
                    mergedHistory = Self.mergeSnapshots(local: history, remote: remote.history)
                    preferences = Self.mergePreferences(
                        local: preferences,
                        remote: remote.preferences,
                        remoteCorrections: remote.corrections
                    )
                    try? preferencesStore.save(preferences, for: userID)

                    if let client = try? SupabaseClientProvider.shared.client() {
                        let service = SensorySnapshotService(client: client)
                        if remote.preferences != preferences {
                            _ = try? await service.upsertPreferences(preferences, userID: userID)
                        }
                        let pendingCorrections = Self.pendingCorrections(
                            local: preferences.dismissals,
                            remote: remote.corrections
                        )
                        var correctionSyncFailed = false
                        for correction in pendingCorrections {
                            do {
                                try await service.appendCorrection(correction, userID: userID)
                            } catch {
                                correctionSyncFailed = true
                            }
                        }
                        if correctionSyncFailed {
                            contentState = .offline(
                                message: "Your correction is safe on this device and will sync the next time the Lens connects."
                            )
                        }
                    }
                } catch {
                    contentState = .offline(
                        message: "Your saved on-device Lens is ready. Cross-device history will be checked the next time you open the Lens."
                    )
                }
            }

            let scopedHistory = mergedHistory.filter { snapshot in
                snapshot.identity.userConfirmed
            }
            let patterns = personalizationEngine.learnedPatterns(
                userID: preferenceUserID,
                snapshots: scopedHistory,
                preferences: preferences,
                bundle: bundle
            )

            let sourceSession = existingSnapshot.map(TastingLensSessionDraft.init(restoring:))
                ?? existingSession
            let exactResume = sourceSession.flatMap { session in
                session.bundleID == bundle.bundleID
                    && session.bundleContentVersion == bundle.contentVersion
                    ? session
                    : nil
            }
            let depth = sourceSession?.depth ?? preferences.defaultDepth
            let identity = sourceSession?.identity
                ?? selectionService.identity(from: analysis)
            let selection = selectionService.makeSelection(
                analysis: analysis,
                confirmedIdentity: identity,
                depth: depth,
                bundle: bundle,
                preferences: preferences,
                patterns: patterns
            )
            let migratedSession = sourceSession.flatMap { session in
                exactResume == nil
                    ? Self.migrateSession(session, bundle: bundle, selection: selection)
                    : nil
            }
            var session = exactResume
                ?? migratedSession
                ?? TastingLensSessionDraft(
                    bundleID: bundle.bundleID,
                    bundleContentVersion: bundle.contentVersion,
                    depth: depth,
                    identity: selection.identity,
                    activePackIDs: selection.activePackIDs
                )
            if session.identity.rawName.remoteTrimmedNonEmpty == nil {
                session.identity.rawName = rawDrinkName
            }
            session.activePackIDs = selection.activePackIDs
            if migratedSession != nil, !contentState.showsJourneyBanner {
                contentState = .notice(
                    message: "Mugshot carried forward the answers whose meanings are still compatible. Review them before saving; your first words and personal rating were preserved."
                )
            }

            runtime = Runtime(
                bundle: bundle,
                preferences: preferences,
                patterns: patterns,
                selection: selection,
                session: session,
                history: scopedHistory,
                contentState: contentState
            )
            loadError = nil
        } catch {
            runtime = nil
            loadError = error.localizedDescription
        }
    }

    private func finish(
        _ session: TastingLensSessionDraft,
        preferences currentPreferences: TastingLensUserPreferences,
        runtime: Runtime
    ) {
        guard session.personalEnjoyment != nil else {
            loadError = "Add your personal enjoyment stars before finishing the Lens."
            return
        }

        let currentSelection = selectionService.makeSelection(
            analysis: analysis,
            confirmedIdentity: session.identity,
            depth: session.depth,
            bundle: runtime.bundle,
            preferences: currentPreferences,
            patterns: runtime.patterns
        )
        let snapshot = TastingLensSnapshotFactory().makeSnapshot(
            session: session,
            selection: currentSelection,
            bundle: runtime.bundle
        )

        if let userID {
            var preferences = currentPreferences
            preferences.updatedAt = .now
            try? preferencesStore.save(preferences, for: userID)
            syncPreferencesRemotely(preferences, userID: userID)
        }
        onComplete(snapshot)
    }

    private func persistPreferences(_ preferences: TastingLensUserPreferences) {
        guard let userID, preferences.userID == userID else { return }
        try? preferencesStore.save(preferences, for: userID)
        syncPreferencesRemotely(preferences, userID: userID)
        syncCorrectionsRemotely(preferences.dismissals, userID: userID)
    }

    private func syncPreferencesRemotely(
        _ preferences: TastingLensUserPreferences,
        userID: UUID
    ) {
        guard remoteSyncEnabled else { return }
        Task {
            guard let client = try? SupabaseClientProvider.shared.client() else { return }
            _ = try? await SensorySnapshotService(client: client).upsertPreferences(
                preferences,
                userID: userID
            )
        }
    }

    private func syncCorrectionsRemotely(
        _ dismissals: [SensorySuggestionDismissal],
        userID: UUID
    ) {
        guard remoteSyncEnabled else { return }
        let corrections = dismissals.filter { $0.snapshotID != nil }
        guard !corrections.isEmpty else { return }
        Task {
            guard let client = try? SupabaseClientProvider.shared.client() else { return }
            let service = SensorySnapshotService(client: client)
            for correction in corrections {
                try? await service.appendCorrection(correction, userID: userID)
            }
        }
    }

    private func loadRemoteContext(userID: UUID) async throws -> RemoteContext {
        let client = try SupabaseClientProvider.shared.client()
        let service = SensorySnapshotService(client: client)
        return try await withThrowingTaskGroup(of: RemoteContext.self) { group in
            group.addTask {
                async let history = service.fetchOwnHistory(userID: userID)
                async let preferences = service.fetchPreferences(userID: userID)
                async let corrections = service.fetchCorrections(userID: userID)
                return try await RemoteContext(
                    history: history,
                    preferences: preferences,
                    corrections: corrections
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 2_500_000_000)
                throw RemoteContextError.timedOut
            }
            guard let first = try await group.next() else {
                throw RemoteContextError.unavailable
            }
            group.cancelAll()
            return first
        }
    }

    static func mergePreferences(
        local: TastingLensUserPreferences,
        remote: TastingLensUserPreferences?,
        remoteCorrections: [SensorySuggestionDismissal]
    ) -> TastingLensUserPreferences {
        guard remote?.userID == nil || remote?.userID == local.userID else { return local }
        var merged = if let remote, remote.updatedAt > local.updatedAt {
            remote
        } else {
            local
        }
        var dismissalsByID: [UUID: SensorySuggestionDismissal] = [:]
        for dismissal in local.dismissals { dismissalsByID[dismissal.id] = dismissal }
        for dismissal in remote?.dismissals ?? [] { dismissalsByID[dismissal.id] = dismissal }
        for correction in remoteCorrections { dismissalsByID[correction.id] = correction }
        merged.dismissals = dismissalsByID.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        merged.updatedAt = ([local.updatedAt, remote?.updatedAt ?? .distantPast]
            + merged.dismissals.map(\.createdAt)).max() ?? merged.updatedAt
        return merged
    }

    static func pendingCorrections(
        local: [SensorySuggestionDismissal],
        remote: [SensorySuggestionDismissal]
    ) -> [SensorySuggestionDismissal] {
        let remoteIDs = Set(remote.map(\.id))
        return local
            .filter { $0.snapshotID != nil && !remoteIDs.contains($0.id) }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    static func migrateSession(
        _ source: TastingLensSessionDraft,
        bundle: SensoryKnowledgeBundle,
        selection: TastingLensSelection,
        now: Date = .now
    ) -> TastingLensSessionDraft {
        let preserveStructuredResponses = source.bundleID == bundle.bundleID
        let rankedByID = Dictionary(
            uniqueKeysWithValues: selection.orderedCriteria.map { ($0.id, $0) }
        )
        let allowedDescriptorIDs = Set(selection.descriptors.map(\.id))
        let migratedResponses: [SensoryResponseDraft]
        if preserveStructuredResponses {
            migratedResponses = source.responses.compactMap { original in
                guard let ranked = rankedByID[original.criterionID] else { return nil }
                let criterion = ranked.criterion
                var response = original
                let allowedChoiceIDs = Set(criterion.options.map(\.id))
                response.choiceIDs = response.choiceIDs.filter(allowedChoiceIDs.contains)
                if criterion.options.isEmpty {
                    response.descriptorIDs = response.descriptorIDs.filter(allowedDescriptorIDs.contains)
                } else {
                    var seenDescriptorIDs = Set<String>()
                    response.descriptorIDs = criterion.options
                        .filter { response.choiceIDs.contains($0.id) }
                        .compactMap(\.descriptorID)
                        .filter { seenDescriptorIDs.insert($0).inserted }
                }
                if criterion.measure != .intensity { response.intensity = nil }
                if criterion.measure != .duration { response.duration = nil }
                if criterion.measure != .qualityImpression { response.qualityImpression = nil }
                response.sourcePackIDs = ranked.sourcePackIDs
                response.suggestionOrigin = ranked.origin
                response.displayedOrder = criterion.order
                response.aiProvenance = nil
                let hasPayload = !response.descriptorIDs.isEmpty
                    || !response.choiceIDs.isEmpty
                    || response.customText?.remoteTrimmedNonEmpty != nil
                    || response.intensity != nil
                    || response.duration != nil
                    || response.preference != nil
                    || response.qualityImpression != nil
                    || response.confidence != nil
                if response.state == .observed && !hasPayload {
                    response.state = .notAsked
                    response.userConfirmed = false
                }
                return response
            }
        } else {
            migratedResponses = []
        }

        return TastingLensSessionDraft(
            id: source.id,
            bundleID: bundle.bundleID,
            bundleContentVersion: bundle.contentVersion,
            depth: source.depth,
            identity: source.identity,
            ownWords: source.ownWords,
            responses: migratedResponses,
            personalEnjoyment: source.personalEnjoyment,
            activePackIDs: selection.activePackIDs,
            startedAt: source.startedAt,
            updatedAt: now
        )
    }

    private static func mergeSnapshots(
        local: [SipSensorySnapshot],
        remote: [SipSensorySnapshot]
    ) -> [SipSensorySnapshot] {
        var byID = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        for snapshot in local { byID[snapshot.id] = snapshot }
        return byID.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    private static let guestPreferenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private struct Runtime {
        let bundle: SensoryKnowledgeBundle
        let preferences: TastingLensUserPreferences
        let patterns: [LearnedSensoryPattern]
        let selection: TastingLensSelection
        let session: TastingLensSessionDraft
        let history: [SipSensorySnapshot]
        let contentState: TastingLensContentState
    }

    private struct RemoteContext {
        let history: [SipSensorySnapshot]
        let preferences: TastingLensUserPreferences?
        let corrections: [SensorySuggestionDismissal]
    }

    private enum RemoteContextError: Error {
        case timedOut
        case unavailable
    }
}

private struct TastingLensBootstrapLoading: View {
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.mugshotSage)
                Text("Preparing your Tasting Lens…")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct TastingLensBootstrapError: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("The Lens needs a moment")
                        .font(.system(.largeTitle, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                    Button("Try again", action: onRetry)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Return to rating", action: onCancel)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }
}
