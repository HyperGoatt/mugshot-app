import AVFoundation
import CoreLocation
import MapKit
import SwiftUI
import Supabase
import UIKit

struct LogVisitView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe? = nil
    private let explicitLaunchDraft: SipDraft?

    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(SipComposerExperience.storageKey) private var composerExperienceRaw = SipComposerExperience.defaultExperience.rawValue
    @AppStorage(RoadmapFeatureFlags.cafeSessionsAndPulse) private var cafeSessionsAndPulse = true

    @StateObject private var composerModel: SipComposerModel
    @State private var photoImages: [UIImage] = []
    @State private var didRestoreDraft = false
    @State private var suppressContextDefaults = false
    @State private var showTastingLens2 = false
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showCameraPermissionRecovery = false
    @State private var showTextOnlyConfirmation = false
    @State private var showDiscardPendingConfirmation = false
    @State private var confirmedTextOnlyEveryone = false
    @State private var isSaving = false
    @State private var showSavedConfirmation = false
    @State private var completionSummary: SipCompletionSummary?
    @State private var v3CompletionSummary: LogASipV3PassportSummary?
    @State private var completedRemoteVisit: RemoteVisitSummary?
    @State private var completedLocalVisit: Visit?
    @State private var publishedCompletionRecord: V3PublishedCompletionRecord?
    @State private var isLoadingPublishedVisit = false
    @State private var completionStatusMessage: String?
    @State private var showPublishedMugshot = false
    @State private var completedCafeSession: CafeSessionDraft?
    @State private var completedSessionCafe: Cafe?
    @State private var activeContinuationSession: CafeSessionDraft?
    @State private var errorMessage: String?
    @State private var pendingSubmission: PendingVisitSubmissionRecord?
    @State private var conflictingPendingSubmission: PendingVisitSubmissionRecord?
    @State private var pendingRecoveryNeedsPhotoRepair = false
    @State private var uploadRecoveryMessage: String?
    @State private var servingVolumeUnit: ServingVolumeUnit = .preferredForCurrentLocale
    @State private var isAddingCustomTag = false
    @State private var customTagText = ""
    @State private var peoplePickerMode: SipPeoplePickerMode?
    @State private var showPhotoOrganizer = false
    @State private var photoOrganizerOriginalImages: [UIImage]?
    @State private var photoOrganizerOriginalPosterIndex: Int?
    @State private var remoteCafeSessionsAvailable = false
    @State private var cafeLearningSignals: [CafePreferenceSignal] = []
    @State private var v3Step: SipV3ComposerStep
    @State private var analyticsStartedAt = Date()
    @State private var analyticsIsDraftResume: Bool
    @State private var analyticsDidCaptureOpen = false
    @State private var analyticsDidCaptureRecovery = false
    @State private var analyticsDidCaptureDeduplication = false
    @State private var analyticsPublishWasRecovery = false

    @StateObject private var searchService = MapSearchService()
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var isCafeSearchActive = false
    @State private var cafeSearchRegion = Self.defaultSearchRegion

    private static let defaultSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    /// Local `Visit` predates non-cafe contexts and still requires an ID. This
    /// sentinel deliberately has no matching `Cafe`, so Home and Elsewhere
    /// memories never manufacture cafes or affect cafe stats.
    private static let localNonCafeContextID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000003"
    )!

    private var composerExperience: SipComposerExperience {
#if DEBUG
        SipComposerExperience(rawValue: composerExperienceRaw) ?? .defaultExperience
#else
        .guided
#endif
    }

    private var draft: SipDraft {
        get { composerModel.draft }
        nonmutating set { composerModel.draft = newValue }
    }

    private var tastingLensUserID: UUID? {
        draft.ownerUserID ?? authModel.authenticatedUser?.id ?? dataManager.appData.currentUser?.id
    }

    private var localAccountScope: LocalAccountScope {
        .forUserID(
            authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        )
    }

    private var analyticsSnapshot: MugshotSipAnalyticsSnapshot {
        MugshotSipAnalyticsSnapshot(
            draft: draft,
            photoCount: photoImages.count,
            isDraftResume: analyticsIsDraftResume
        )
    }

    private var analyticsDurationSeconds: Int {
        Int(Date().timeIntervalSince(analyticsStartedAt).rounded())
    }

    private var tastingLensHistory: [SipSensorySnapshot] {
        guard let userID = tastingLensUserID else { return [] }
        return dataManager.appData.visits
            .filter { $0.userId == userID }
            .compactMap(\.sensorySnapshot)
    }

    private var cafeSessionsEnabled: Bool {
        guard cafeSessionsAndPulse else { return false }
        return authModel.authenticatedUser == nil || remoteCafeSessionsAvailable
    }

    private var shouldOfferCafePulse: Bool {
        cafeSessionsEnabled &&
            draft.context == .cafe &&
            draft.cafe != nil &&
            draft.launchContext.source != .addAnotherSip
    }

    /// Required product state drives the vessel. Optional photos and notes add
    /// texture to the memory but never make the mug look incomplete.
    private var logMotionProgress: CGFloat {
        if showSavedConfirmation { return 1 }
        var progress: CGFloat = 0.08
        if hasCompletedContext { progress += 0.22 }
        if draft.drinkName.remoteTrimmedNonEmpty != nil { progress += 0.28 }
        if draft.resolvedOverallScore >= 0.5 { progress += 0.28 }
        if draft.resolvedGuidedStep == .audience { progress += 0.10 }
        if isSaving { progress = max(progress, 0.94) }
        return MugshotMotion.normalized(progress)
    }

    private var primaryContext: Binding<JournalEntryContext> {
        Binding(
            get: { draft.context == .cafe ? .cafe : .home },
            set: { draft.context = $0 }
        )
    }

    private var homeUsesRecipe: Binding<Bool> {
        Binding(
            get: { draft.context == .recipe },
            set: { draft.context = $0 ? .recipe : .home }
        )
    }

    init(
        dataManager: DataManager,
        preselectedCafe: Cafe? = nil,
        initialDraft: SipDraft? = nil
    ) {
        self.dataManager = dataManager
        self.preselectedCafe = preselectedCafe
        self.explicitLaunchDraft = initialDraft
        let restoredImages = initialDraft.flatMap {
            SipDraftStore.shared.load(
                id: $0.id,
                in: .forUserID($0.ownerUserID)
            )?.images
        } ?? []
        _photoImages = State(initialValue: restoredImages)
        _showPhotoSourceDialog = State(initialValue: initialDraft?.launchContext.source == .camera)
        _v3Step = State(initialValue: initialDraft?.v3Step ?? .setup)
        _analyticsIsDraftResume = State(initialValue: initialDraft != nil)
        _composerModel = StateObject(wrappedValue: SipComposerModel(
            draft: initialDraft ?? Self.initialDraft(
                dataManager: dataManager,
                preselectedCafe: preselectedCafe,
                ownerUserID: dataManager.appData.currentUser?.id
            )
        ))
    }

    private static func initialDraft(
        dataManager: DataManager,
        preselectedCafe: Cafe?,
        ownerUserID: UUID? = nil
    ) -> SipDraft {
        let draft = SipDraft(
            ownerUserID: ownerUserID,
            launchContext: SipComposerLaunchContext(
                source: preselectedCafe == nil ? .centralAdd : .cafeDetail,
                preselectedCafe: preselectedCafe
            ),
            cafe: preselectedCafe,
            visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility
        )
        return draft
    }

    var body: some View {
        observedComposer
            .background(Color.creamWhite.ignoresSafeArea())
    }

    private var navigationComposer: some View {
        composerBodyContent
    }

    private var presentedComposer: some View {
        navigationComposer
            .fullScreenCover(isPresented: $showTastingLens2) {
                TastingLens2ComposerContainer(
                    analysis: draft.drinkAnalysis,
                    rawDrinkName: draft.drinkName,
                    userID: tastingLensUserID,
                    remoteSyncEnabled: authModel.authenticatedUser?.id == tastingLensUserID,
                    history: tastingLensHistory,
                    existingSnapshot: draft.sensorySnapshot,
                    existingSession: draft.sensorySessionDraft,
                    onComplete: { snapshot in
                        draft.sensorySnapshot = snapshot
                        draft.sensorySessionDraft = nil
                        draft.overallScore = snapshot.personalEnjoyment?.value ?? draft.overallScore
                        draft.captureMode = .addDetails
                        showTastingLens2 = false
                        MugshotHaptic.softImpact.play()
                    },
                    onCancel: {
                        if draft.sensorySnapshot == nil {
                            draft.captureMode = .quickSip
                        }
                        showTastingLens2 = false
                    },
                    onSessionUpdate: { session in
                        draft.sensorySessionDraft = session
                    }
                )
            }
            .sheet(item: $peoplePickerMode) { mode in
                SipCompanionPicker(
                    mode: mode,
                    selected: draft.taggedCompanions ?? [],
                    onSave: { companions in
                        draft.taggedCompanions = companions
                        draft.companions = companions.map(\.displayName)
                    }
                )
            }
            .sheet(isPresented: $isCafeSearchActive) {
                CafeSearchSheet(
                    searchText: $searchText,
                    searchService: searchService,
                    dataManager: dataManager,
                    selectedCafe: $composerModel.draft.cafe,
                    region: $cafeSearchRegion,
                    searchAreaDescription: searchAreaDescription,
                    locationActionTitle: locationActionTitle,
                    onLocationAction: useCurrentLocation
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView(
                    image: Binding(
                        get: { nil },
                        set: { image in
                            if let image { appendPhotos([image]) }
                        }
                    ),
                    isPresented: $showCamera
                )
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoLibraryPickerView(
                    images: Binding(
                        get: { [] },
                        set: { appendPhotos($0) }
                    ),
                    isPresented: $showPhotoLibrary,
                    maximumSelectionCount: max(1, 10 - photoImages.count)
                )
            }
            .sheet(isPresented: $showPhotoOrganizer, onDismiss: finishOrganizingPhotos) {
                SipPhotoOrganizer(
                    images: $photoImages,
                    posterPhotoIndex: $composerModel.draft.posterPhotoIndex,
                    localPhotoNames: $composerModel.draft.localPhotoNames
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showPublishedMugshot, onDismiss: {
                finishSuccessfulSave()
            }) {
                if let completedRemoteVisit {
                    RemoteVisitDetailView(
                        visitId: completedRemoteVisit.id,
                        initialSummary: completedRemoteVisit,
                        currentUserId: authModel.authenticatedUser?.id,
                        dataManager: dataManager,
                        justPosted: true,
                        presentationMode: .postSave
                    )
                } else if let completedLocalVisit {
                    VisitDetailView(
                        visit: completedLocalVisit,
                        dataManager: dataManager,
                        presentationMode: .postSave
                    )
                }
            }
    }

    private var alertedComposer: some View {
        presentedComposer
            .confirmationDialog(
                "Add a photo",
                isPresented: $showPhotoSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Take Photo") { requestCamera() }
                Button("Choose from Library") { showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos are optional for Private and Friends sips.")
            }
            .alert("Camera access is off", isPresented: $showCameraPermissionRecovery) {
                Button("Choose from Library") { showPhotoLibrary = true }
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow Camera access in Settings, or choose a photo from your library.")
            }
            .alert("Publish without a photo?", isPresented: $showTextOnlyConfirmation) {
                Button("Publish Text Only") {
                    confirmedTextOnlyEveryone = true
                    saveSip()
                }
                Button("Add Photo") { showPhotoSourceDialog = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everyone posts usually include a photo. Confirm that you want this tasting note to be text only.")
            }
            .confirmationDialog(
                "Discard the earlier interrupted save?",
                isPresented: $showDiscardPendingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Earlier Save", role: .destructive) {
                    Task { await discardConflictingPendingSubmission() }
                }
                Button("Keep It", role: .cancel) {}
            } message: {
                Text("Mugshot verifies any remote save before removing its protected retry copy. If verification is unavailable, the save stays protected.")
            }
    }

    private var observedComposer: some View {
        alertedComposer
            .onAppear {
                activateLocalState()
                restoreDraftIfNeeded()
                captureComposerOpenedIfNeeded()
            }
            .task(id: authModel.authenticatedUser?.id) {
                await refreshCafeSessionsCapability()
            }
            .onChange(of: draft) { _, _ in persistDraft() }
            .onChange(of: draft.drinkName) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: draft.brewDetails.servingVolumeMilliliters) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: draft.brewDetails.espressoShotCount) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: composerExperienceRaw) { _, _ in
                draft.composerExperience = composerExperience
                persistDraft()
            }
            .onChange(of: draft.context) { oldContext, newContext in
                guard oldContext != newContext, !suppressContextDefaults else { return }
                draft.applyContextDefaults(using: .shared)
                confirmedTextOnlyEveryone = false
                MugshotAnalytics.shared.capture(
                    .sipContextSelected(analyticsSnapshot)
                )
            }
            .onChange(of: draft.visibility) { _, _ in
                confirmedTextOnlyEveryone = false
                constrainRawNoteVisibility()
                if draft.cafeSessionDraft != nil {
                    draft.cafeSessionDraft?.visibility = draft.visibility
                }
            }
            .onChange(of: draft.cafe?.id) { oldCafeID, newCafeID in
                guard oldCafeID != newCafeID else { return }
                resetCafeSessionForSelectedCafe()
            }
            .onChange(of: v3Step) { _, step in
                if draft.v3Step != step { draft.v3Step = step }
                MugshotAnalytics.shared.capture(
                    .sipStepViewed(analyticsSnapshot)
                )
            }
            .onChange(of: draft.ratingCriteria) { _, criteria in
                PinnedCriterionStore.shared.synchronize(criteria, scope: pinnedSipScope)
            }
            .onChange(of: draft.contextRatingCriteria) { _, criteria in
                PinnedCriterionStore.shared.synchronize(criteria, scope: pinnedContextScope)
            }
            .onChange(of: locationManager.location) { _, location in
                if let location { updateSearchRegion(for: location) }
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, userID in
                activateLocalState(scope: .forUserID(userID))
                guard let userID else {
                    pendingSubmission = nil
                    conflictingPendingSubmission = nil
                    return
                }
                if explicitLaunchDraft == nil,
                   !showSavedConfirmation,
                   restorePublishedV3CompletionIfNeeded() {
                    return
                }
                if draft.ownerUserID == nil { draft.ownerUserID = userID }
                if draft.cafeSessionDraft != nil {
                    draft.cafeSessionDraft?.ownerUserID = userID
                }
                reconcilePendingSubmission(for: userID)
            }
    }

    @ViewBuilder
    private var composerBodyContent: some View {
        activeComposer
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var activeComposer: some View {
        LogASipV3ProductionView(
            draft: $composerModel.draft,
            photoImages: $photoImages,
            step: $v3Step,
            isSaving: isSaving,
            isRecoveryLocked: pendingSubmission != nil || isSaving,
            statusMessage: errorMessage ?? uploadRecoveryMessage,
            isOpeningPublishedMugshot: isLoadingPublishedVisit,
            completionStatusMessage: completionStatusMessage,
            completion: showSavedConfirmation ? v3CompletionSummary : nil,
            canUseLastSipSetup: !RecentCriterionSetupStore.shared
                .names(scope: pinnedSipScope).isEmpty,
            canUseLastContextSetup: !RecentCriterionSetupStore.shared
                .names(scope: pinnedContextScope).isEmpty,
            onCancel: cancelComposer,
            onAddPhoto: { showPhotoSourceDialog = true },
            onOrganizePhotos: beginOrganizingPhotos,
            onChooseCafe: {
                initializeLocationIfAvailable()
                isCafeSearchActive = true
            },
            onTagPeople: { peoplePickerMode = .tag },
            onRepairProtectedSave: pendingRecoveryNeedsPhotoRepair
                ? { showPhotoSourceDialog = true }
                : nil,
            onDiscardProtectedSave: pendingRecoveryNeedsPhotoRepair
                || conflictingPendingSubmission != nil
                ? prepareProtectedSaveForDiscard
                : nil,
            onUseLastSipSetup: useLastSipCriteriaSetup,
            onUseLastContextSetup: useLastContextCriteriaSetup,
            onPublish: saveSip,
            onViewPublishedMugshot: viewPublishedMugshot,
            onViewPassport: viewPassportAfterCompletion,
            onFinish: finishSuccessfulSave,
            onStartAnother: completedCafeSession == nil ? nil : addAnotherSipToCompletedSession
        )
    }

    private var longFormComposer: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    composerHeader
                    contextCard
                    locationCard
                    drinkCard
                    overallRatingCard
                    if shouldOfferCafePulse {
                        cafePulseEditor(presentation: .compact)
                            .id("long-form-cafe-pulse")
                    }
                    addToMemoryCard

                    if draft.isMemoryExpanded {
                        memoryCard
                        detailContent
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        visibilityCard
                    }

                    recoveryAndValidationContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .containerRelativeFrame(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: currentCafePulseStepID) { oldStepID, newStepID in
                guard shouldOfferCafePulse, oldStepID != newStepID else { return }
                withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                    proxy.scrollTo("long-form-cafe-pulse", anchor: .top)
                }
            }
        }
    }

    private var guidedComposer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                guidedHeader
                guidedProgress

                guidedStepContent

                recoveryAndValidationContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .id(guidedScrollIdentity)
    }

    /// The iOS 27 beta runtime can overflow while resolving one generic SwiftUI
    /// type containing every guided branch. Erase only the selected step so the
    /// runtime never has to materialize that combined metadata graph.
    private var guidedStepContent: AnyView {
        switch draft.resolvedGuidedStep {
        case .context:
            AnyView(guidedContextStep)
        case .drink:
            AnyView(guidedDrinkStep)
        case .rating:
            AnyView(guidedRatingStep)
        case .cafePulse:
            AnyView(guidedCafePulseStep)
        case .audience:
            AnyView(guidedAudienceStep)
        }
    }

    private var guidedContextStep: some View {
        Group {
            contextCard
            locationCard
        }
    }

    @ViewBuilder
    private var guidedDrinkStep: some View {
        drinkCard
        if draft.drinkName.remoteTrimmedNonEmpty != nil {
            memoryCard
            if draft.context == .cafe {
                guidedCafeContextCard
            }
        }
    }

    @ViewBuilder
    private var guidedRatingStep: some View {
        if draft.launchContext.source == .repeatSip || draft.launchContext.source == .brewAgain {
            repeatedSipContext
        }
        overallRatingCard
    }

    private var guidedCafePulseStep: some View {
        Group {
            cafePulseEditor(presentation: .guided)
            Button {
                draft.cafeSessionDraft?.experienceDraft = nil
                draft.cafeSessionDraft?.returnIntention = nil
                draft.cafeSessionDraft?.repeatComparison = nil
                draft.cafeSessionDraft?.shareProjection = CafeExperienceShareProjection()
                draft.sipReorderIntention = nil
                moveToGuidedStep(.audience)
            } label: {
                Text("Save just the sip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("Keeps this as a cafe visit without adding a Cafe Pulse rating")
        }
    }

    @ViewBuilder
    private var guidedAudienceStep: some View {
        visibilityCard
        Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                draft.memoryDetailsExpanded = !draft.isMemoryExpanded
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "note.text.badge.plus")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Serving details or a private note")
                        .font(.system(size: 14, weight: .bold))
                    Text("Optional and never required to publish")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Image(systemName: draft.isMemoryExpanded ? "chevron.up" : "chevron.down")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SecondaryButtonStyle())

        if draft.isMemoryExpanded {
            guidedDetailContent
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        }
    }

    private var repeatedSipContext: some View {
        HStack(spacing: 12) {
            Image(systemName: draft.launchContext.source == .brewAgain
                ? "arrow.clockwise.circle.fill"
                : "plus.square.on.square")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.mugshotSage)
                .frame(width: 36, height: 36)
                .background(Color.mugshotMint.opacity(0.6), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.launchContext.source == .brewAgain ? "Brewing again" : "Repeating this sip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
                Text(draft.drinkName.remoteTrimmedNonEmpty ?? "Saved sip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                Text(draft.context == .cafe ? draft.cafe?.name ?? "Cafe" : draft.locationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var recoveryAndValidationContent: some View {
        if let uploadRecoveryMessage {
            recoveryCard(uploadRecoveryMessage)
        }
        if let errorMessage {
            ValidationErrorCard(errors: [errorMessage])
        }
    }

    private var composerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Remember this sip.")
                    .mugshotDisplay(size: 36)
                    .foregroundColor(.espressoBrown)

                Text("Capture what you drank, where it happened, and what stood out.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            MugshotSipProgressMug(
                progress: logMotionProgress,
                drinkName: draft.drinkName,
                rating: draft.resolvedOverallScore,
                isSaving: isSaving
            )
            .frame(width: 78, height: 90)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var guidedHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(guidedTitle)
                    .mugshotDisplay(size: 35)
                    .foregroundColor(.espressoBrown)

                Text(guidedSubtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            MugshotSipProgressMug(
                progress: logMotionProgress,
                drinkName: draft.drinkName,
                rating: draft.resolvedOverallScore,
                isSaving: isSaving
            )
            .frame(width: 82, height: 94)
            .animation(MugshotMotion.response, value: logMotionProgress)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var guidedProgress: some View {
        HStack(spacing: 7) {
            ForEach(guidedSteps, id: \.self) { step in
                Capsule()
                    .fill(
                        (guidedSteps.firstIndex(of: step) ?? 0) <= guidedCurrentStepIndex
                            ? Color.mugshotSage
                            : Color.sandBeige
                    )
                    .frame(height: 6)
                    .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: draft.resolvedGuidedStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(guidedCurrentStepIndex + 1) of \(guidedSteps.count)")
        .accessibilityRespondsToUserInteraction(false)
    }

    private var contextCard: some View {
        SipComposerCard(step: "01", title: "Where are you sipping?", subtitle: contextSubtitle) {
            MugshotSegmentedControl(
                options: [.cafe, .home],
                selection: primaryContext,
                title: { $0.rawValue },
                icon: { $0.systemImage }
            )

            if draft.context != .cafe {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you brewing?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    MugshotSegmentedControl(
                        options: [false, true],
                        selection: homeUsesRecipe,
                        title: { $0 ? "Recipe" : "One-time brew" },
                        icon: { $0 ? "book.pages.fill" : "clock.arrow.circlepath" }
                    )
                }

                contextExplainer(
                    icon: draft.context == .recipe ? "book.pages.fill" : "clock.arrow.circlepath",
                    title: draft.context == .recipe ? "Recipe is a reusable blueprint" : "Home is an attempt",
                    text: draft.context == .recipe
                        ? "Save this sip with a named version you can brew again later."
                        : "Keep this brew independent so you can compare it with every other try."
                )
            }
        }
    }

    @ViewBuilder
    private var locationCard: some View {
        if draft.context == .cafe {
            CafeLocationSection(
                selectedCafe: $composerModel.draft.cafe,
                searchText: $searchText,
                isSearchActive: $isCafeSearchActive,
                searchService: searchService,
                dataManager: dataManager,
                searchRegion: cafeSearchRegion,
                searchAreaDescription: searchAreaDescription,
                locationActionTitle: locationActionTitle,
                onLocationAction: useCurrentLocation
            )
        } else {
            SipComposerCard(step: nil, title: "Brew context", subtitle: "Home is remembered, but you can rename this setup.") {
                TextField("Home", text: $composerModel.draft.locationName)
                    .textInputAutocapitalization(.words)
                    .mugshotFormField()
            }
        }
    }

    private var drinkCard: some View {
        SipComposerCard(step: "02", title: "What did you drink?", subtitle: "Say it naturally. Mugshot organizes the details for your journal.") {
            TextField(
                "Iced cinnamon and orange cortado",
                text: $composerModel.draft.drinkName,
                axis: .vertical
            )
                .textInputAutocapitalization(.sentences)
                .submitLabel(.continue)
                .lineLimit(1...3)
                .accessibilityIdentifier("sipComposer.drinkName")
                .mugshotFormField()

            Text("Try the full order name—temperature, milk, flavor, preparation, or shot count can all live here.")
                .font(.system(size: 12))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overallRatingCard: some View {
        SipComposerCard(step: "03", title: "How was the sip?", subtitle: ratingSubtitle) {
            ratingModeControl

            if draft.captureMode == .quickSip {
                HalfStepStarRating(value: $composerModel.draft.overallScore, label: "Overall sip rating")
                    .accessibilityIdentifier("sipComposer.overallRating")

                HStack {
                    Text(draft.overallScore > 0 ? scoreLabel : "Tap a half or whole star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Spacer()
                    Text(draft.overallScore > 0 ? String(format: "%.1f", draft.overallScore) : "—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.espressoBrown)
                }
            } else {
                personalRatingContent
            }
        }
    }

    private func cafePulseEditor(
        presentation: CafePulsePresentationStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !cafeLearningSignals.isEmpty {
                cafeLearningContext
            }
            CafePulseCaptureView(
                draft: cafeExperienceDraftBinding,
                returnIntention: cafeReturnIntentionBinding,
                sipReorderIntention: $composerModel.draft.sipReorderIntention,
                repeatComparison: cafeRepeatComparisonBinding,
                shareProjection: cafeShareProjectionBinding,
                presentation: presentation,
                showsRepeatComparison: true
            )
        }
    }

    private var cafeLearningContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What Mugshot is learning", systemImage: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.espressoBrown)

            ForEach(cafeLearningSignals.prefix(2)) { signal in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: signal.direction == .lifted
                        ? "arrow.up.right.circle.fill"
                        : "arrow.down.right.circle.fill")
                        .foregroundColor(.mugshotSage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(signal.title) \(signal.direction == .lifted ? "often lifts your visits" : "has detracted before")")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text("\(signal.strength == .established ? "Established" : "Emerging") · \(signal.supportSessionCount) visits across \(signal.distinctCafeCount) cafes")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                }
            }

            Text("Only explicit Lifted or Detracted observations count. Low stars, private notes, staff, people, and demographics are never inferred.")
                .font(.system(size: 10))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.mugshotMint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }

    private var cafeExperienceDraftBinding: Binding<CafeExperienceDraft> {
        Binding(
            get: {
                draft.cafeSessionDraft?.experienceDraft ?? CafeExperienceDraft()
            },
            set: { value in
                ensureCafeSessionDraft()
                draft.cafeSessionDraft?.experienceDraft = value
            }
        )
    }

    private var cafeReturnIntentionBinding: Binding<CafeReturnIntention?> {
        Binding(
            get: { draft.cafeSessionDraft?.returnIntention },
            set: { value in
                ensureCafeSessionDraft()
                draft.cafeSessionDraft?.returnIntention = value
            }
        )
    }

    private var cafeRepeatComparisonBinding: Binding<CafeRepeatComparison?> {
        Binding(
            get: { draft.cafeSessionDraft?.repeatComparison },
            set: { value in
                ensureCafeSessionDraft()
                draft.cafeSessionDraft?.repeatComparison = value
            }
        )
    }

    private var cafeShareProjectionBinding: Binding<CafeExperienceShareProjection> {
        Binding(
            get: {
                draft.cafeSessionDraft?.shareProjection
                    ?? CafeExperienceShareProjection()
            },
            set: { value in
                ensureCafeSessionDraft()
                draft.cafeSessionDraft?.shareProjection = value
            }
        )
    }

    @ViewBuilder
    private var ratingModeControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ratingModeButtons
            }
        } else {
            HStack(spacing: 8) {
                ratingModeButtons
            }
        }
    }

    @ViewBuilder
    private var ratingModeButtons: some View {
        Group {
            ratingModeButton(
                title: "Quick rating",
                subtitle: "One score",
                systemImage: "star.fill",
                mode: .quickSip
            )
            ratingModeButton(
                title: "Use my tasting lens",
                subtitle: draft.sensorySessionDraft == nil ? "What matters to you" : "Resume saved Lens",
                systemImage: "sparkles",
                mode: .addDetails
            )
        }
    }

    private func ratingModeButton(
        title: String,
        subtitle: String,
        systemImage: String,
        mode: SipCaptureMode
    ) -> some View {
        let selected = draft.captureMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                draft.captureMode = mode
            }
            if mode == .addDetails {
                showTastingLens2 = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? Color.foamWhite.opacity(0.78) : Color.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .padding(.horizontal, 12)
            .foregroundColor(selected ? .foamWhite : .espressoBrown)
            .background(selected ? Color.mugshotSage : Color.sandBeige.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("sipComposer.ratingMode.\(mode == .quickSip ? "quick" : "lens")")
    }

    private var personalRatingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = draft.sensorySnapshot {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your \(snapshot.depth.title.lowercased()) tasting is captured")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text(tastingLensSnapshotPreview(snapshot))
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    if let enjoyment = snapshot.personalEnjoyment {
                        Text(String(format: "%.1f", enjoyment.value))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .monospacedDigit()
                            .accessibilityLabel("Personal rating \(String(format: "%.1f", enjoyment.value)) out of 5")
                    }
                }

                Button {
                    showTastingLens2 = true
                } label: {
                    Label("Review or refine this tasting", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("sipComposer.openTastingLens2")
            } else {
                Label("Describe first. Rate enjoyment separately.", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mugshotSage)

                Text("Start in your own words, explore a broad-to-specific flavor web, then let Mugsy guide only the questions that fit this drink.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showTastingLens2 = true
                } label: {
                    Label("Open Tasting Lens 2.0", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("sipComposer.openTastingLens2")
            }

            Text("Your observations never calculate your stars. High intensity is not automatically better.")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tastingLensSnapshotPreview(_ snapshot: SipSensorySnapshot) -> String {
        if let ownWords = snapshot.ownWords.remoteTrimmedNonEmpty {
            return "“\(ownWords)”"
        }
        let descriptors = snapshot.responses
            .flatMap(\.descriptors)
            .map(\.displayedTitle)
        if !descriptors.isEmpty {
            return Array(descriptors.prefix(3)).joined(separator: " · ")
        }
        return "A versioned sensory snapshot is ready for your journal."
    }

    private var addToMemoryCard: some View {
        Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                draft.memoryDetailsExpanded = !draft.isMemoryExpanded
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 42, height: 42)
                    .background(Color.mugshotMint.opacity(0.25))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add to the memory")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text("Photo, thought, tasting context, and private notes")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: draft.isMemoryExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.mugshotSage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.mugshotLine))
        }
        .buttonStyle(.plain)
    }

    private var memoryCard: some View {
        SipComposerCard(step: nil, title: "Make it memorable", subtitle: "A photo and one-line thought are optional.") {
            HStack(alignment: .top, spacing: 12) {
                Button { showPhotoSourceDialog = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: photoImages.isEmpty ? "camera.fill" : "photo.stack.fill")
                        Text(photoImages.isEmpty ? "Add photo" : "\(photoImages.count) photo\(photoImages.count == 1 ? "" : "s")")
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(Color.sandBeige.opacity(0.72))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canEditPhotos)
                .opacity(canEditPhotos ? 1 : 0.55)
                .accessibilityHint(
                    canEditPhotos
                        ? "Adds another photo to this sip"
                        : "Finish retrying the uploaded sip before changing photos"
                )

                TextField("One-line thought", text: $composerModel.draft.socialCaption, axis: .vertical)
                    .lineLimit(1...2)
                    .fixedSize(horizontal: false, vertical: true)
                    .mugshotFormField()
                    .accessibilityIdentifier("sipComposer.socialCaption")
            }

            if !photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoImages.indices, id: \.self) { index in
                            Image(uiImage: photoImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .bottomLeading) {
                                    if index == draft.posterPhotoIndex {
                                        Text("Cover")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.foamWhite)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color.espressoBrown.opacity(0.82))
                                            .clipShape(Capsule())
                                            .padding(5)
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            index == draft.posterPhotoIndex ? Color.mugshotSage : Color.clear,
                                            lineWidth: 2
                                        )
                                }
                                .overlay(alignment: .topTrailing) {
                                    Button { removePhoto(at: index) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color.foamWhite, Color.espressoBrown.opacity(0.72))
                                    }
                                    .offset(x: 5, y: -5)
                                    .accessibilityLabel("Remove photo \(index + 1)")
                                    .disabled(!canEditPhotos)
                                }
                        }
                    }
                    .padding(.top, 4)
                }

                if photoImages.count > 1 {
                    Button {
                        beginOrganizingPhotos()
                    } label: {
                        Label("Choose cover and reorder", systemImage: "rectangle.2.swap")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.mugshotSage)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canEditPhotos)
                    .opacity(canEditPhotos ? 1 : 0.55)
                    .accessibilityHint("Opens photo order and cover controls")
                }
            }
        }
    }

    private var canEditPhotos: Bool {
        guard !isSaving else { return false }
        guard let pendingSubmission else { return true }
        return pendingSubmission.canResume(
            with: draft,
            authenticatedUserID: pendingSubmission.userId
        ) && pendingSubmission.phase < .photosUploaded
    }

    private var guidedCafeContextCard: some View {
        SipComposerCard(
            step: nil,
            title: "Tags and company",
            subtitle: "Optional context that makes your journal easier to revisit."
        ) {
            tagsAndCompanyContent
        }
    }

    private var semanticTagSuggestions: [String] {
        let existing = Set(draft.tags.map { $0.localizedLowercase })
        return SemanticSipTagEngine.suggestions(
            drinkName: draft.drinkName,
            analysis: draft.drinkAnalysis,
            context: draft.context
        ).filter { !existing.contains($0.localizedLowercase) }
    }

    private var tagsAndCompanyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Helpful tags", systemImage: "tag.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Spacer()
                    Text("Optional")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                }

                if !semanticTagSuggestions.isEmpty {
                    Text("Suggested from the order—not invented tasting notes")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(semanticTagSuggestions, id: \.self) { suggestion in
                                Button {
                                    addTag(suggestion)
                                } label: {
                                    Label(suggestion, systemImage: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                        .padding(.horizontal, 11)
                                        .frame(minHeight: 38)
                                        .background(Color.mugshotMint.opacity(0.42), in: Capsule())
                                        .overlay(Capsule().stroke(Color.mugshotSage.opacity(0.24), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Adds this optional journal tag")
                            }
                        }
                    }
                }

                if !draft.tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(draft.tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Button {
                                    draft.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(tag) tag")
                            }
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .background(Color.sandBeige.opacity(0.58), in: Capsule())
                        }
                    }
                }

                if isAddingCustomTag {
                    HStack(spacing: 8) {
                        TextField("Add a helpful tag", text: $customTagText)
                            .textInputAutocapitalization(.sentences)
                            .mugshotFormField()
                            .onSubmit { commitCustomTag() }
                        Button("Add") { commitCustomTag() }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.mugshotSage)
                            .disabled(customTagText.remoteTrimmedNonEmpty == nil)
                    }
                } else {
                    Button {
                        isAddingCustomTag = true
                    } label: {
                        Label("Add your own tag", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.mugshotSage)
                }
            }

            Divider().overlay(Color.mugshotLine)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("People tagged", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Spacer()
                    Button {
                        peoplePickerMode = .tag
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 36, height: 36)
                            .foregroundColor(.mugshotSage)
                            .background(Color.mugshotMint.opacity(0.42), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag people in this Mugshot")
                }

                if let companions = draft.taggedCompanions, !companions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(companions) { companion in
                                HStack(spacing: 7) {
                                    MugshotAvatar(
                                        name: companion.displayName,
                                        size: 28,
                                        imageURL: companion.avatarURL
                                    )
                                    Text(companion.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                    Button {
                                        removeCompanion(companion)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(companion.displayName)")
                                }
                                .foregroundColor(.espressoBrown)
                                .padding(.leading, 5)
                                .padding(.trailing, 9)
                                .frame(minHeight: 40)
                                .background(Color.sandBeige.opacity(0.56), in: Capsule())
                            }
                        }
                    }
                } else {
                    Text("Search any Mugshot account. Tags add attribution, not shared ownership.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
            }

        }
    }

    @ViewBuilder
    private var guidedDetailContent: some View {
        servingDetailsCard
        privateNotesCard
    }

    @ViewBuilder
    private var detailContent: some View {
        servingDetailsCard

        switch draft.context {
        case .cafe:
            cafeDetailsCard
        case .home, .elsewhere:
            homeDetailsCard(includeRecipe: false)
        case .recipe:
            homeDetailsCard(includeRecipe: true)
        }

        privateNotesCard
    }

    private var servingDetailsCard: some View {
        SipComposerCard(
            step: nil,
            title: "Serving details",
            subtitle: "Optional size and espresso-base details for your journal."
        ) {
            HStack(spacing: 10) {
                TextField("Serving size", text: servingVolumeBinding)
                    .keyboardType(.decimalPad)
                    .mugshotFormField()

                Picker("Serving unit", selection: $servingVolumeUnit) {
                    ForEach(ServingVolumeUnit.allCases) { unit in
                        Text(unit.shortTitle).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 112)
            }

            if draft.drinkAnalysis?.preparation.isEspressoBased == true {
                Picker("Espresso base", selection: espressoShotCountBinding) {
                    Text("Not specified").tag(nil as Int?)
                    Text("Single shot").tag(1 as Int?)
                    Text("Double shot").tag(2 as Int?)
                    Text("Triple shot").tag(3 as Int?)
                    Text("Quad shot").tag(4 as Int?)
                }
                .pickerStyle(.menu)
                .tint(.mugshotSage)
            } else {
                Text("This preparation uses serving size rather than espresso shot count.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private var cafeDetailsCard: some View {
        SipComposerCard(step: nil, title: "Tags and company", subtitle: "Optional context that makes your journal easier to revisit.") {
            tagsAndCompanyContent
        }
    }

    private func homeDetailsCard(includeRecipe: Bool) -> some View {
        SipComposerCard(
            step: nil,
            title: includeRecipe ? "Recipe blueprint" : "Brew details",
            subtitle: includeRecipe
                ? "Save this version without overwriting the brews that came before it."
                : "Record only the variables that help your next attempt."
        ) {
            if includeRecipe {
                HStack(spacing: 10) {
                    TextField("Recipe name", text: optionalText(\.recipeName))
                        .mugshotFormField()
                    TextField("Version", text: optionalText(\.recipeVersion))
                        .frame(maxWidth: 105)
                        .mugshotFormField()
                }
            }

            TextField("Beans", text: optionalText(\.beans))
                .mugshotFormField()

            HStack(spacing: 10) {
                TextField("Dose (g)", text: optionalDouble(\.doseGrams))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
                TextField("Yield (g)", text: optionalDouble(\.yieldGrams))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
                TextField("Time (s)", text: optionalInt(\.brewTimeSeconds))
                    .keyboardType(.numberPad)
                    .mugshotFormField()
            }

            HStack(spacing: 10) {
                TextField("Origin", text: optionalText(\.beanOrigin))
                    .mugshotFormField()
                TextField("Roast", text: optionalText(\.roastLevel))
                    .mugshotFormField()
            }

            HStack(spacing: 10) {
                TextField("Grind", text: optionalText(\.grindSetting))
                    .mugshotFormField()
                TextField("Water °C", text: optionalDouble(\.waterTemperatureCelsius))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
            }

            TextField("Brew method", text: $composerModel.draft.brewMethod)
                .mugshotFormField()
            TextField("Equipment", text: $composerModel.draft.equipment)
                .mugshotFormField()
            TextField("Water notes", text: optionalText(\.waterNotes))
                .mugshotFormField()
            TextField("Additions", text: optionalText(\.additions))
                .mugshotFormField()

            if includeRecipe {
                recipeSteps
            }
        }
    }

    private var recipeSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reusable steps")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Button {
                    var steps = draft.brewDetails.steps ?? []
                    steps.append(BrewRecipeStep())
                    draft.brewDetails.steps = steps
                } label: {
                    Label("Add step", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.mugshotSage)
            }

            ForEach(Array((draft.brewDetails.steps ?? []).enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .frame(width: 26, height: 26)
                        .background(Color.mugshotSage)
                        .clipShape(Circle())

                    TextField("Step instruction", text: recipeStepBinding(step.id), axis: .vertical)
                        .lineLimit(1...3)
                        .mugshotFormField()
                }
            }

            Label("Brew this again will create a new Home draft from this exact version.", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var privateNotesCard: some View {
        SipComposerCard(
            step: nil,
            title: "Private notes",
            subtitle: "Owner-only journal space. This is stored separately and can never appear in Feed or sharing."
        ) {
            TextField("What do you want only yourself to remember?", text: $composerModel.draft.privateNotes, axis: .vertical)
                .lineLimit(3...7)
                .mugshotFormField()
                .accessibilityIdentifier("sipComposer.privateNotes")

            Label("Only you", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.mugshotSage)
        }
    }

    private var visibilityCard: some View {
        SipComposerCard(step: nil, title: "Who can see this sip?", subtitle: visibilitySubtitle) {
            MugshotSegmentedControl(
                options: [VisitVisibility.private, .friends, .everyone],
                selection: $composerModel.draft.visibility,
                title: { $0.rawValue },
                icon: { visibilityIcon($0) }
            )

            if draft.visibility == .everyone && photoImages.isEmpty {
                Label("Text-only Everyone posts ask for confirmation before publishing.", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saveFooter: some View {
        VStack(spacing: 7) {
            Button { saveSip() } label: {
                HStack(spacing: 9) {
                    if isSaving {
                        ProgressView().tint(.foamWhite)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text(saveButtonTitle)
                    Spacer()
                    Text(draft.visibility.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.foamWhite.opacity(0.14))
                        .clipShape(Capsule())
                }
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)

            Text("Context, drink, and one rating path are all you need.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Color.mugshotLine) }
    }

    private var savedConfirmation: some View {
        let summary = completionSummary
        let facts = [
            summary.map {
                MugshotCompletionFact(
                    icon: $0.contextIcon,
                    label: $0.contextLabel,
                    value: $0.locationName
                )
            },
            summary.map {
                MugshotCompletionFact(
                    icon: "star.fill",
                    label: "The Sip",
                    value: String(format: "%.1f", $0.score)
                )
            },
            summary?.isCafeSession == true ? summary.map {
                MugshotCompletionFact(
                    icon: "storefront.fill",
                    label: "The Cafe",
                    value: $0.cafeRating.map { String(format: "%.1f", $0) } ?? "Not rated"
                )
            } : nil,
            summary?.isCafeSession == true ? summary.map {
                MugshotCompletionFact(
                    icon: "arrow.triangle.branch",
                    label: "Next move",
                    value: $0.nextMove.title
                )
            } : nil,
            summary?.isDetailedMemory == true ? summary.map {
                MugshotCompletionFact(
                    icon: $0.visibilityIcon,
                    label: "Saved for",
                    value: $0.visibility.rawValue
                )
            } : nil,
            summary?.detailHighlights.isEmpty == false ? summary.map {
                MugshotCompletionFact(
                    icon: "sparkles",
                    label: "Includes",
                    value: $0.detailHighlights.joined(separator: " · ")
                )
            } : nil
        ].compactMap { $0 }

        return VStack(spacing: 12) {
            MugshotCompletionCard(
                mugsyConfiguration: MugsyModelConfiguration(
                    expression: .delighted,
                    gaze: .topTrailing,
                    liquid: MugsyLiquidState(
                        appearance: .infer(from: summary?.drinkName ?? ""),
                        fillProgress: 0.94,
                        steamIntensity: min(1, CGFloat((summary?.score ?? 4) / 5))
                    )
                ),
                mugsyAction: .celebrating,
                eyebrow: summary?.isCafeSession == true ? "Cafe visit saved" : (summary?.isDetailedMemory == true ? "Memory saved" : "Sip saved"),
                title: summary?.isCafeSession == true ? "Your Mugshot" : (summary?.drinkName ?? "Sip remembered"),
                message: summary?.isCafeSession == true
                    ? "The sip and the cafe remain two independent truths. Your Next Move comes only from what you said you would do again."
                    : summary?.completionMessage
                    ?? "Your rating is saved in Journal and ready whenever you want to add more.",
                facts: facts,
                celebrates: true
            )

            if summary?.isCafeSession == true, completedCafeSession != nil {
                Button(action: addAnotherSipToCompletedSession) {
                    Label("Add another sip", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Finish in Journal", action: finishSuccessfulSave)
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Closes the composer and opens your saved cafe visit")
            } else {
                Button("View in Journal", action: finishSuccessfulSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Closes the composer and opens your saved coffee memories")
            }
        }
        .padding(28)
    }

    private func recoveryCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.mugshotSage)
            VStack(alignment: .leading, spacing: 7) {
                Text("Your sip is safe")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                if conflictingPendingSubmission != nil {
                    Button("Discard earlier save") {
                        showDiscardPendingConfirmation = true
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sandBeige.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contextExplainer(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.mugshotSage)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.sandBeige.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var contextSubtitle: String {
        switch draft.context {
        case .cafe: return "Attach the real place so Map and discovery stay useful."
        case .home: return "A single brew attempt, kept independent in your history."
        case .elsewhere: return "Name the setting without sharing an exact location."
        case .recipe: return "A sip plus a versioned blueprint you can brew again."
        }
    }

    private var guidedTitle: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Where did this happen?"
        case .drink: return "Name the sip."
        case .rating: return "Rate the sip."
        case .cafePulse: return "How was the cafe?"
        case .audience: return "Who should see this sip?"
        }
    }

    private var guidedSubtitle: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Start with Cafe or Home. Recipes live inside Home when you need one."
        case .drink: return "Use the order name you will recognize later."
        case .rating: return "Choose one quick score or open your personal tasting lens."
        case .cafePulse: return "Keep the place experience independent from the drink."
        case .audience: return "Choose the journal audience. Private notes stay private in every setting."
        }
    }

    private var ratingSubtitle: String {
        draft.captureMode == .quickSip
            ? "One honest score in half-star steps."
            : "Describe what you noticed, then rate personal enjoyment at the end."
    }

    private var visibilitySubtitle: String {
        switch draft.context {
        case .cafe: return "Cafe sips remember your last audience choice."
        case .home, .elsewhere, .recipe: return "Personal contexts begin Private every time."
        }
    }

    private var scoreLabel: String {
        PersonalEnjoymentRating(value: draft.overallScore)?.anchor ?? "Choose a personal rating"
    }

    private var saveButtonTitle: String {
        if isSaving { return photoImages.isEmpty ? "Saving sip…" : "Saving photos…" }
        if conflictingPendingSubmission != nil { return "Earlier sip protected" }
        if pendingSubmission != nil { return "Retry same sip" }
        if uploadRecoveryMessage != nil { return "Retry save" }
        return "Save sip"
    }

    @ViewBuilder
    private var composerFooter: some View {
        if composerExperience == .guided {
            guidedFooter
        } else {
            saveFooter
        }
    }

    private var guidedFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if draft.resolvedGuidedStep != .context {
                    Button(action: moveToPreviousGuidedStep) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Previous step")
                }

                Button(action: performGuidedPrimaryAction) {
                    HStack(spacing: 9) {
                        if isSaving {
                            ProgressView().tint(.foamWhite)
                        } else {
                            Image(systemName: guidedPrimaryIcon)
                        }
                        Text(guidedPrimaryTitle)
                        Spacer()
                        if draft.resolvedGuidedStep == .audience {
                            Text(guidedSaveVisibility.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.foamWhite.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || !canPerformGuidedPrimaryAction)
                .accessibilityIdentifier("sipComposer.primaryAction")
            }

            Text(guidedFooterHint)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Color.mugshotLine) }
    }

    private func visibilityIcon(_ visibility: VisitVisibility) -> String {
        switch visibility {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .everyone: return "globe.americas.fill"
        }
    }

    private func restoreDraftIfNeeded() {
        guard !didRestoreDraft else { return }
        didRestoreDraft = true

        if explicitLaunchDraft == nil, restorePublishedV3CompletionIfNeeded() {
            return
        }

        if explicitLaunchDraft == nil,
           let stored = SipDraftStore.shared.load(in: localAccountScope),
           shouldResume(stored.draft) {
            analyticsIsDraftResume = true
            suppressContextDefaults = true
            draft = stored.draft
            photoImages = stored.images
            v3Step = stored.draft.v3Step ?? .setup
            DispatchQueue.main.async { suppressContextDefaults = false }
        } else {
            draft.ownerUserID = authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        }
#if DEBUG
        if MugshotLaunchEnvironment.shouldSeedUITestPhoto, photoImages.isEmpty {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96))
            let fixturePhoto = renderer.image { context in
                UIColor(red: 0.36, green: 0.49, blue: 0.40, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: CGSize(width: 96, height: 96)))
            }
            photoImages = [fixturePhoto]
        }
#endif
        if draft.uploadState == .failed, uploadRecoveryMessage == nil {
            uploadRecoveryMessage = "Your last save was interrupted. Retry continues the same sip and photos."
        }

        if let userID = authModel.authenticatedUser?.id {
            reconcilePendingSubmission(for: userID)
        }

        // Restore the durable Cafe Session handoff before adding guided-flow
        // scaffold state. A fresh `.context` step is not user-entered content
        // and must not prevent the completion handoff from reopening.
        restoreCafeSessionContinuationIfNeeded()
        guard !showSavedConfirmation else { return }
        draft.composerExperience = composerExperience
        draft.v3Step = v3Step
        if draft.guidedStep == nil { draft.guidedStep = .context }
        applyPinnedCriteria()
        refreshDrinkAnalysis()
        initializeLocationIfAvailable()
        persistDraft()
    }

    private func activateLocalState(scope: LocalAccountScope? = nil) {
        let resolvedScope = scope ?? localAccountScope
        SipDraftStore.shared.activate(scope: resolvedScope)
        CafeVisibilityPreferenceStore.shared.activate(scope: resolvedScope)
        try? PhotoCache.shared.activate(
            scope: resolvedScope,
            migratingKnownKeys: knownLegacyPhotoKeys(for: resolvedScope)
        )
        searchService.activate(scope: resolvedScope)
    }

    private func knownLegacyPhotoKeys(for scope: LocalAccountScope) -> Set<String> {
        guard let userID = scope.userID else { return [] }
        return Set(
            dataManager.appData.visits
                .filter { $0.userId == userID }
                .flatMap(\.photos)
        )
    }

    @discardableResult
    private func restorePublishedV3CompletionIfNeeded() -> Bool {
        let ownerUserID = authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        guard let record = V3PublishedCompletionStore.shared.load(
            ownerUserID: ownerUserID,
            onExpired: { expiredRecord in
                if let storedDraft = SipDraftStore.shared.load(
                    id: expiredRecord.visitID,
                    in: .forUserID(expiredRecord.ownerUserID)
                ) {
                    SipDraftStore.shared.remove(
                        storedDraft.draft,
                        in: .forUserID(expiredRecord.ownerUserID)
                    )
                }
            }
        ) else {
            return false
        }
        analyticsIsDraftResume = true
        if record.isRemote,
           let recordOwnerUserID = record.ownerUserID,
           let pending = PendingVisitSubmissionStore.shared.load(
               visitId: record.visitID,
               userId: recordOwnerUserID
           ),
           !pending.isPostPublicationSetupComplete {
            return false
        }
        let recordScope = LocalAccountScope.forUserID(record.ownerUserID)
        guard let stored = SipDraftStore.shared.load(id: record.visitID, in: recordScope),
              stored.draft.ownerUserID == nil
                || stored.draft.ownerUserID == record.ownerUserID else {
            V3PublishedCompletionStore.shared.remove(ownerUserID: ownerUserID)
            return false
        }

        suppressContextDefaults = true
        draft = stored.draft
        photoImages = stored.images
        v3Step = .publish
        publishedCompletionRecord = record
        completionStatusMessage = nil
        completedRemoteVisit = nil
        completedLocalVisit = record.isRemote ? nil : dataManager.getVisit(id: record.visitID)

        if let continuation = CafeSessionContinuationStore.shared.load(
            ownerUserID: ownerUserID
        ), continuation.stage == .completion {
            completedCafeSession = continuation.session
            completedSessionCafe = continuation.cafe
            completionSummary = SipCompletionSummary(snapshot: continuation.summary)
        } else {
            completedCafeSession = nil
            completedSessionCafe = nil
            completionSummary = makeCompletionSummary(
                from: stored.draft,
                session: nil
            )
        }

        let coverImage = stored.images.isEmpty
            ? nil
            : stored.images[min(
                max(stored.draft.posterPhotoIndex, 0),
                stored.images.count - 1
            )]
        v3CompletionSummary = makeV3PassportSummary(
            from: stored.draft,
            visitID: record.visitID,
            isRemote: record.isRemote,
            photoImages: stored.images,
            coverImage: coverImage,
            knownMemoryCount: record.isRemote
                ? nil
                : knownLocalMemoryCount(for: stored.draft)
        )
        showSavedConfirmation = true
        pendingSubmission = nil
        conflictingPendingSubmission = nil
        uploadRecoveryMessage = nil

        if let ownerUserID,
           let pending = PendingVisitSubmissionStore.shared.load(
               visitId: record.visitID,
               userId: ownerUserID
           ), pending.isPostPublicationSetupComplete {
            PendingVisitSubmissionStore.shared.remove(pending)
        }

        DispatchQueue.main.async { suppressContextDefaults = false }
        if record.isRemote, let ownerUserID {
            Task {
                await loadPublishedRemoteVisit(
                    record: record,
                    ownerUserID: ownerUserID,
                    openAfterLoad: false
                )
            }
        }
        return true
    }

    private func restoreCafeSessionContinuationIfNeeded() {
        let ownerUserID = draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        guard var continuation = CafeSessionContinuationStore.shared.load(
            ownerUserID: ownerUserID
        ) else {
            return
        }

        if continuation.stage == .activeAdditionalSip,
           continuation.activeDraftID == draft.id,
           draft.cafeSessionID == continuation.session.id {
            activeContinuationSession = continuation.session
            return
        }

        guard explicitLaunchDraft == nil,
              preselectedCafe == nil,
              pendingSubmission == nil,
              conflictingPendingSubmission == nil,
              !draft.hasDraftWorthyUserContent,
              photoImages.isEmpty else {
            return
        }

        if let abandonedDraftID = continuation.activeDraftID {
            continuation.session.sipDraftIDs.removeAll { $0 == abandonedDraftID }
            continuation.session.updatedAt = .now
        }
        continuation.stage = .completion
        continuation.activeDraftID = nil
        continuation.updatedAt = .now
        try? CafeSessionContinuationStore.shared.save(continuation)
        completedCafeSession = continuation.session
        completedSessionCafe = continuation.cafe
        completionSummary = SipCompletionSummary(snapshot: continuation.summary)
        showSavedConfirmation = true
    }

    private func reconcilePendingSubmission(for userID: UUID) {
        let pendingStore = PendingVisitSubmissionStore.shared
        let exactPending = pendingStore.load(visitId: draft.id, userId: userID)
        let mayAdoptOldestPending = explicitLaunchDraft == nil
            && preselectedCafe == nil
            && !draft.hasDraftWorthyUserContent
            && photoImages.isEmpty
        let pending = exactPending
            ?? (mayAdoptOldestPending ? pendingStore.load(userId: userID) : nil)

        guard let pending else {
            pendingSubmission = nil
            conflictingPendingSubmission = nil
            pendingRecoveryNeedsPhotoRepair = false
            uploadRecoveryMessage = nil
            return
        }

        if pending.isRemoteFinalized {
            let recovered = SipDraftStore.shared.load(
                id: pending.id,
                in: .user(userID)
            ).map { ($0.draft, $0.images) }
                ?? reconstructDraft(
                    from: pending,
                    authenticatedUserID: userID
                ).map { ($0, []) }
            guard let recovered else {
                pendingSubmission = pending
                conflictingPendingSubmission = nil
                uploadRecoveryMessage = "Your Mugshot is published. Reconnect to finish its local handoff."
                return
            }
            routeToPendingSubmission(
                pending,
                recoveredDraft: recovered.0,
                fallbackImages: recovered.1,
                userID: userID
            )
            uploadRecoveryMessage = "Your Mugshot is published. Finish the local handoff without publishing it again."
            return
        }

        guard pending.hasValidRetryPayload else {
            pendingSubmission = nil
            conflictingPendingSubmission = pending
            pendingRecoveryNeedsPhotoRepair = false
            uploadRecoveryMessage = pending.retryPayloadIssue?.localizedDescription
                ?? "An earlier save needs to be discarded before this draft can publish."
            return
        }

        if pending.canResume(with: draft, authenticatedUserID: userID) {
            if let reconstructedDraft = reconstructDraft(
                from: pending,
                authenticatedUserID: userID
            ) {
                routeToPendingSubmission(
                    pending,
                    recoveredDraft: reconstructedDraft,
                    fallbackImages: photoImages,
                    userID: userID
                )
            } else if pendingHasMissingLocalPhotos(pending) {
                bindPendingSubmission(pending, fallbackImages: [])
                pendingRecoveryNeedsPhotoRepair = true
                v3Step = .publish
                draft.v3Step = .publish
                uploadRecoveryMessage = "One protected photo is missing. Replace the photos, or discard this interrupted save and keep editing the journal entry."
            } else {
                pendingSubmission = nil
                conflictingPendingSubmission = pending
                pendingRecoveryNeedsPhotoRepair = false
                uploadRecoveryMessage = "An earlier save is protected, but its retry copy could not be restored. Discard it before publishing this draft."
            }
            return
        }

        if let matchingStoredDraft = SipDraftStore.shared.load(
            id: pending.id,
            in: .user(userID)
        ),
           pending.canResume(
               with: matchingStoredDraft.draft,
               authenticatedUserID: userID
           ) {
            if pendingHasMissingLocalPhotos(pending) {
                routeToPendingSubmission(
                    pending,
                    recoveredDraft: matchingStoredDraft.draft,
                    fallbackImages: [],
                    userID: userID
                )
                pendingRecoveryNeedsPhotoRepair = true
                uploadRecoveryMessage = "One protected photo is missing. Replace the photos, or discard this interrupted save and keep editing the journal entry."
                return
            }
            routeToPendingSubmission(
                pending,
                recoveredDraft: matchingStoredDraft.draft,
                fallbackImages: matchingStoredDraft.images,
                userID: userID
            )
            return
        }

        if let reconstructedDraft = reconstructDraft(
            from: pending,
            authenticatedUserID: userID
        ) {
            routeToPendingSubmission(
                pending,
                recoveredDraft: reconstructedDraft,
                fallbackImages: [],
                userID: userID
            )
            return
        }

        pendingSubmission = nil
        conflictingPendingSubmission = pending
        pendingRecoveryNeedsPhotoRepair = false
        uploadRecoveryMessage = "An earlier save is protected, but its retry copy could not be restored. Keep it, or discard it before saving this draft."
    }

    private func pendingHasMissingLocalPhotos(
        _ pending: PendingVisitSubmissionRecord
    ) -> Bool {
        guard SipRemoteRecoveryPlanner.requiresLocalPhotosForRecovery(pending) else {
            return false
        }
        return (try? PendingVisitSubmissionStore.shared.loadImages(for: pending).count)
            != pending.localPhotoNames.count
    }

    private func routeToPendingSubmission(
        _ pending: PendingVisitSubmissionRecord,
        recoveredDraft: SipDraft,
        fallbackImages: [UIImage],
        userID: UUID
    ) {
        if draft.id != pending.id,
           draft.hasDraftWorthyUserContent || !photoImages.isEmpty {
            _ = try? SipDraftStore.shared.save(
                draft,
                images: photoImages,
                in: .user(userID)
            )
        }

        suppressContextDefaults = true
        draft = recoveredDraft
        draft.ownerUserID = userID
        draft.v3Step = .publish
        v3Step = .publish
        bindPendingSubmission(pending, fallbackImages: fallbackImages)
        DispatchQueue.main.async { suppressContextDefaults = false }
        persistDraft()
    }

    private func reconstructDraft(
        from pending: PendingVisitSubmissionRecord,
        authenticatedUserID: UUID
    ) -> SipDraft? {
        guard pending.userId == authenticatedUserID else { return nil }
        if pending.resolvedEntryContext == .cafe, pending.cafe == nil {
            return nil
        }
        if pending.phase < .photosUploaded,
           !pending.localPhotoNames.isEmpty,
           (try? PendingVisitSubmissionStore.shared.loadImages(for: pending).count)
            != pending.localPhotoNames.count {
            return nil
        }

        let ratingCriteria = pending.ratingTemplate.categories.enumerated().map {
            index,
            category in
            SipRatingCriterionSnapshot(
                id: category.id,
                name: category.name,
                score: pending.ratings[category.name] ?? 0,
                weight: category.weight,
                sortOrder: index
            )
        }
        let possibleSessionState = reconstructedCafeSessionState(
            from: pending,
            authenticatedUserID: authenticatedUserID
        )
        let sessionState: (
            draft: CafeSessionDraft?,
            reference: CafeSessionReference?
        )
        if pending.cafeSession != nil {
            guard let possibleSessionState else { return nil }
            sessionState = possibleSessionState
        } else {
            sessionState = (nil, nil)
        }
        let details = pending.resolvedBrewDetails

        return SipDraft(
            id: pending.id,
            ownerUserID: authenticatedUserID,
            createdAt: pending.createdAt,
            updatedAt: .now,
            captureMode: pending.sensorySnapshot == nil ? .quickSip : .addDetails,
            launchContext: SipComposerLaunchContext(
                source: pending.cafeSession?.sipRole == .secondary
                    ? .addAnotherSip
                    : .centralAdd,
                preselectedCafe: pending.cafe
            ),
            context: pending.resolvedEntryContext,
            cafe: pending.cafe,
            locationName: pending.locationName?.remoteTrimmedNonEmpty
                ?? pending.cafe?.consumerDisplayName
                ?? pending.resolvedEntryContext.locationFallback,
            drinkType: pending.drinkType,
            customDrinkType: pending.customDrinkType ?? "",
            drinkName: pending.drinkSubtype,
            overallScore: pending.resolvedOverallScore,
            socialCaption: pending.caption,
            privateNotes: pending.notes ?? "",
            visibility: pending.visibility,
            ratingCriteria: ratingCriteria,
            orderNotes: details.orderNotes ?? "",
            tags: details.tags ?? [],
            companions: details.companions ?? [],
            taggedCompanions: pending.taggedCompanions,
            recipePublication: pending.resolvedRecipePublication,
            brewMethod: pending.brewMethod ?? "",
            equipment: pending.equipment ?? "",
            brewDetails: details,
            localPhotoNames: [],
            posterPhotoIndex: pending.posterPhotoIndex,
            uploadState: pending.isRemoteFinalized ? .local : .failed,
            composerExperience: composerExperience,
            guidedStep: .audience,
            memoryDetailsExpanded: true,
            sensorySnapshot: pending.sensorySnapshot,
            cafeSessionDraft: sessionState.draft,
            cafeSessionReference: sessionState.reference,
            cafeSessionSipOrder: pending.cafeSession?.sipOrder,
            cafeSessionSipRole: pending.cafeSession?.sipRole,
            sipReorderIntention: pending.cafeSession?.reorderIntention,
            v3Step: .publish,
            contextNotes: pending.v3Reflection?.contextRawNote ?? "",
            rawNoteVisibility: pending.v3Reflection?.rawNoteVisibility ?? .private,
            contextScore: pending.v3Reflection?.contextScore,
            contextRatingCriteria: pending.v3Reflection?.contextCriteria ?? [],
            photoFallback: pending.v3Reflection?.photoFallback,
            homeMakeAgain: pending.v3Reflection?.homeMakeAgain
        )
    }

    private func reconstructedCafeSessionState(
        from pending: PendingVisitSubmissionRecord,
        authenticatedUserID: UUID
    ) -> (draft: CafeSessionDraft?, reference: CafeSessionReference?)? {
        guard let link = pending.cafeSession else {
            return (nil, nil)
        }
        guard pending.resolvedEntryContext == .cafe,
              let cafe = pending.cafe else {
            return nil
        }

        switch link.sipRole {
        case .primary:
            let experienceDraft = link.experienceSnapshot.map { snapshot in
                CafeExperienceDraft(
                    schemaVersion: snapshot.schemaVersion,
                    depth: snapshot.depth,
                    ownWords: snapshot.ownWords ?? "",
                    cafeRating: snapshot.cafeRating,
                    visitContext: snapshot.visitContext,
                    observations: snapshot.observations,
                    privateNotes: snapshot.privateNotes ?? "",
                    updatedAt: snapshot.createdAt
                )
            }
            return (
                CafeSessionDraft(
                    id: link.sessionID,
                    ownerUserID: authenticatedUserID,
                    cafeID: cafe.id,
                    startedAt: link.startedAt,
                    status: .active,
                    visibility: pending.visibility,
                    primarySipDraftID: pending.id,
                    returnIntention: link.returnIntention,
                    repeatComparison: link.repeatComparison,
                    experienceDraft: experienceDraft,
                    shareProjection: link.shareProjection
                ),
                nil
            )
        case .secondary:
            return (
                nil,
                CafeSessionReference(
                    id: link.sessionID,
                    ownerUserID: authenticatedUserID,
                    cafeID: cafe.id,
                    startedAt: link.startedAt,
                    visibility: pending.visibility,
                    primaryVisitID: nil,
                    returnIntention: link.returnIntention
                )
            )
        }
    }

    private func bindPendingSubmission(
        _ pending: PendingVisitSubmissionRecord,
        fallbackImages: [UIImage]? = nil
    ) {
        analyticsIsDraftResume = true
        if draft.ownerUserID == nil {
            draft.ownerUserID = pending.userId
        }
        pendingSubmission = pending
        conflictingPendingSubmission = nil
        pendingRecoveryNeedsPhotoRepair = false
        if let frozenImages = try? PendingVisitSubmissionStore.shared.loadImages(for: pending) {
            photoImages = frozenImages
            draft.localPhotoNames = []
            draft.posterPhotoIndex = pending.posterPhotoIndex
        } else if let fallbackImages {
            photoImages = fallbackImages
        }
        uploadRecoveryMessage = "An earlier save was interrupted. Retry continues the same sip without making a duplicate."
        if !analyticsDidCaptureRecovery {
            analyticsDidCaptureRecovery = true
            MugshotAnalytics.shared.capture(
                .sipRecoveryResumed(analyticsSnapshot)
            )
        }
    }

    @MainActor
    private func discardConflictingPendingSubmission() async {
        guard let conflictingPendingSubmission else { return }

        switch SipRemoteRecoveryPlanner.discardPolicy(
            for: conflictingPendingSubmission
        ) {
        case .preservePublished:
            pendingSubmission = conflictingPendingSubmission
            self.conflictingPendingSubmission = nil
            routeToPublishedRecovery(conflictingPendingSubmission)
            errorMessage = nil
        case .removeLocalOnly:
            removeConfirmedDiscard(conflictingPendingSubmission)
        case .verifyRemoteThenDelete:
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = VisitService(client: client)
                let remoteState = try await service.fetchOwnedVisitUploadState(
                    visitId: conflictingPendingSubmission.id,
                    userId: conflictingPendingSubmission.userId
                )
                if remoteState == .complete {
                    try protectReconciledPublication(conflictingPendingSubmission)
                    return
                }
                if remoteState != nil {
                    try await service.deleteOwnedIncompleteVisit(
                        visitId: conflictingPendingSubmission.id,
                        userId: conflictingPendingSubmission.userId
                    )
                }
                let stateAfterDelete = try await service.fetchOwnedVisitUploadState(
                    visitId: conflictingPendingSubmission.id,
                    userId: conflictingPendingSubmission.userId
                )
                switch stateAfterDelete {
                case nil:
                    removeConfirmedDiscard(conflictingPendingSubmission)
                case .complete:
                    try protectReconciledPublication(conflictingPendingSubmission)
                case .uploading?, .failed?:
                    uploadRecoveryMessage = "Mugshot could not confirm the interrupted remote save was removed. It remains protected; reconnect and try again."
                    errorMessage = uploadRecoveryMessage
                }
            } catch {
                uploadRecoveryMessage = "Mugshot could not verify the remote save. It remains protected; reconnect and try again."
                errorMessage = uploadRecoveryMessage
            }
        }
    }

    private func protectReconciledPublication(
        _ record: PendingVisitSubmissionRecord
    ) throws {
        var finalized = record
        finalized.remoteFinalizedAt = finalized.remoteFinalizedAt ?? .now
        let store = PendingVisitSubmissionStore.shared
        try store.save(finalized)
        finalized = store.load(visitId: finalized.id, userId: finalized.userId)
            ?? finalized
        pendingSubmission = finalized
        conflictingPendingSubmission = nil
        routeToPublishedRecovery(finalized)
        errorMessage = nil
    }

    private func routeToPublishedRecovery(
        _ record: PendingVisitSubmissionRecord
    ) {
        if let recoveredDraft = reconstructDraft(
            from: record,
            authenticatedUserID: record.userId
        ) {
            routeToPendingSubmission(
                record,
                recoveredDraft: recoveredDraft,
                fallbackImages: [],
                userID: record.userId
            )
            v3Step = .publish
        }
        uploadRecoveryMessage = "Your MugShot is already published. Retry finishes its remaining setup without publishing it again."
    }

    private func removeConfirmedDiscard(
        _ record: PendingVisitSubmissionRecord
    ) {
        PendingVisitSubmissionStore.shared.remove(record)
        scheduleObsoletePhotoCleanup(record.objectPaths, userID: record.userId)
        conflictingPendingSubmission = nil
        pendingSubmission = nil
        pendingRecoveryNeedsPhotoRepair = false
        uploadRecoveryMessage = nil
        errorMessage = nil
    }

    private func prepareProtectedSaveForDiscard() {
        if let pendingSubmission,
           SipRemoteRecoveryPlanner.discardPolicy(for: pendingSubmission) == .preservePublished {
            uploadRecoveryMessage = "Your MugShot is already published. Retry finishes its remaining setup without publishing it again."
            return
        }
        if conflictingPendingSubmission == nil, let pendingSubmission {
            conflictingPendingSubmission = pendingSubmission
            self.pendingSubmission = nil
        }
        pendingRecoveryNeedsPhotoRepair = false
        showDiscardPendingConfirmation = conflictingPendingSubmission != nil
    }

    @MainActor
    private func refreshCafeSessionsCapability() async {
        guard cafeSessionsAndPulse else {
            remoteCafeSessionsAvailable = false
            if draft.resolvedGuidedStep == .cafePulse {
                draft.guidedStep = .audience
            }
            return
        }
        guard authModel.authenticatedUser != nil else {
            remoteCafeSessionsAvailable = false
            if let userID = dataManager.appData.currentUser?.id {
                cafeLearningSignals = CafeExperienceLearningEngine().learnedSignals(
                    userID: userID,
                    snapshots: dataManager.appData.cafeSessions.compactMap(\.experienceSnapshot)
                )
            }
            ensureCafeSessionDraft()
            return
        }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeSessionService(client: client)
            _ = try await service.capability()
            remoteCafeSessionsAvailable = true
            ensureCafeSessionDraft()
            if let userID = authModel.authenticatedUser?.id,
               let snapshots = try? await service.fetchOwnSnapshots(userID: userID) {
                cafeLearningSignals = CafeExperienceLearningEngine().learnedSignals(
                    userID: userID,
                    snapshots: snapshots
                )
            }
        } catch {
            // Capability gating is deliberately quiet: an older backend keeps
            // the proven sip-only composer instead of exposing an unsavable
            // Cafe Pulse journey.
            remoteCafeSessionsAvailable = false
            cafeLearningSignals = []
            if draft.resolvedGuidedStep == .cafePulse {
                draft.guidedStep = .audience
            }
        }
    }

    private func resetCafeSessionForSelectedCafe() {
        guard draft.context == .cafe, draft.launchContext.source != .addAnotherSip else {
            return
        }
        draft.clearCafeSession()
        ensureCafeSessionDraft()
    }

    private func ensureCafeSessionDraft() {
        guard shouldOfferCafePulse, let cafe = draft.cafe else { return }
        if draft.cafeSessionDraft?.cafeID != cafe.id {
            draft.cafeSessionDraft = CafeSessionDraft(
                ownerUserID: draft.ownerUserID
                    ?? authModel.authenticatedUser?.id
                    ?? dataManager.appData.currentUser?.id,
                cafeID: cafe.id,
                startedAt: draft.createdAt,
                visibility: draft.visibility,
                primarySipDraftID: draft.id
            )
        }
        draft.cafeSessionDraft?.ownerUserID = draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        draft.cafeSessionDraft?.visibility = draft.visibility
        draft.cafeSessionSipOrder = 0
        draft.cafeSessionSipRole = .primary
    }

    private var pinnedOwnerScope: String {
        (draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id)?.uuidString.lowercased()
            ?? "anonymous"
    }

    private var pinnedSipScope: String { "\(pinnedOwnerScope).sip" }

    private var pinnedContextScope: String {
        "\(pinnedOwnerScope).context.\(draft.context.rawValue.lowercased())"
    }

    private func applyPinnedCriteria() {
        var sipCriteria = draft.ratingCriteria
        PinnedCriterionStore.shared.applyPins(to: &sipCriteria, scope: pinnedSipScope)
        draft.ratingCriteria = sipCriteria

        var contextCriteria = draft.contextRatingCriteria
        PinnedCriterionStore.shared.applyPins(to: &contextCriteria, scope: pinnedContextScope)
        draft.contextRatingCriteria = contextCriteria
    }

    private func useLastSipCriteriaSetup() {
        var criteria = draft.ratingCriteria
        RecentCriterionSetupStore.shared.apply(to: &criteria, scope: pinnedSipScope)
        PinnedCriterionStore.shared.applyPins(to: &criteria, scope: pinnedSipScope)
        draft.ratingCriteria = criteria
        MugshotHaptic.softImpact.play()
    }

    private func useLastContextCriteriaSetup() {
        var criteria = draft.contextRatingCriteria
        RecentCriterionSetupStore.shared.apply(to: &criteria, scope: pinnedContextScope)
        PinnedCriterionStore.shared.applyPins(to: &criteria, scope: pinnedContextScope)
        draft.contextRatingCriteria = criteria
        MugshotHaptic.softImpact.play()
    }

    private func constrainRawNoteVisibility() {
        guard visibilityRank(draft.rawNoteVisibility) > visibilityRank(draft.visibility) else { return }
        draft.rawNoteVisibility = draft.visibility
    }

    private func visibilityRank(_ visibility: VisitVisibility) -> Int {
        switch visibility {
        case .private: return 0
        case .friends: return 1
        case .everyone: return 2
        }
    }

    private func synchronizeV3CafeExperience() {
        guard draft.context == .cafe else { return }
        ensureCafeSessionDraft()
        guard draft.cafeSessionDraft != nil else { return }
        if draft.cafeSessionDraft?.experienceDraft == nil {
            draft.cafeSessionDraft?.experienceDraft = CafeExperienceDraft()
        }
        draft.cafeSessionDraft?.experienceDraft?.depth = .quick
        draft.cafeSessionDraft?.experienceDraft?.cafeRating = draft.contextScore
            .flatMap { CafeExperienceRating(value: $0) }
        draft.cafeSessionDraft?.experienceDraft?.ratingCriteria = draft.contextRatingCriteria
        draft.cafeSessionDraft?.experienceDraft?.privateNotes = draft.contextNotes
        draft.cafeSessionDraft?.experienceDraft?.updatedAt = .now
        draft.cafeSessionDraft?.shareProjection.includesCafeRating = draft.contextScore != nil
    }

    private func shouldResume(_ storedDraft: SipDraft) -> Bool {
        guard explicitLaunchDraft == nil else { return false }
        guard let preselectedCafe else { return true }
        guard storedDraft.context == .cafe, let storedCafe = storedDraft.cafe else { return false }
        if storedCafe.id == preselectedCafe.id { return true }
        if let storedRemoteID = storedCafe.remoteCafeId,
           let selectedRemoteID = preselectedCafe.remoteCafeId,
           storedRemoteID == selectedRemoteID {
            return true
        }
        return false
    }

    private func persistDraft() {
        guard didRestoreDraft, draft.hasDraftWorthyUserContent || !photoImages.isEmpty else { return }
        do {
            let stored = try SipDraftStore.shared.save(
                draft,
                images: photoImages,
                in: localAccountScope
            )
            if draft.localPhotoNames != stored.localPhotoNames {
                draft.localPhotoNames = stored.localPhotoNames
                draft.posterPhotoIndex = stored.posterPhotoIndex
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func captureComposerOpenedIfNeeded() {
        guard !analyticsDidCaptureOpen, !showSavedConfirmation else { return }
        analyticsDidCaptureOpen = true
        MugshotAnalytics.shared.capture(
            .sipComposerOpened(analyticsSnapshot)
        )
        MugshotAnalytics.shared.capture(
            .sipStepViewed(analyticsSnapshot)
        )
    }

    private func capturePublicationDeduplicationIfNeeded() {
        guard !analyticsDidCaptureDeduplication else { return }
        analyticsDidCaptureDeduplication = true
        MugshotAnalytics.shared.capture(
            .sipPublicationDeduplicated(analyticsSnapshot)
        )
    }

    private func cancelComposer() {
        if draft.hasDraftWorthyUserContent || !photoImages.isEmpty {
            MugshotAnalytics.shared.capture(
                .sipDraftSaved(
                    analyticsSnapshot,
                    durationSeconds: analyticsDurationSeconds
                )
            )
        }
        persistDraft()
        tabCoordinator.returnFromComposer()
        dismiss()
    }

    private func saveSip() {
        guard !isSaving else { return }
        analyticsPublishWasRecovery = pendingSubmission != nil
            || conflictingPendingSubmission != nil
            || draft.uploadState == .failed
        MugshotAnalytics.shared.capture(
            .sipPublishAttempted(
                analyticsSnapshot,
                isRecovery: analyticsPublishWasRecovery
            )
        )
        synchronizeV3CafeExperience()
        if shouldOfferCafePulse {
            ensureCafeSessionDraft()
        }
        SipSaveDiagnostics.record(.requested, draftID: draft.id, visitID: pendingSubmission?.id)
        if conflictingPendingSubmission != nil {
            errorMessage = PendingVisitSubmissionStoreError
                .submissionIdentityMismatch
                .localizedDescription
            SipSaveDiagnostics.record(
                .validationBlocked,
                draftID: draft.id,
                visitID: conflictingPendingSubmission?.id
            )
            MugshotAnalytics.shared.capture(
                .sipPublishBlocked(
                    analyticsSnapshot,
                    reason: .pendingConflict
                )
            )
            return
        }
        errorMessage = validationMessage
        guard errorMessage == nil else {
            SipSaveDiagnostics.record(.validationBlocked, draftID: draft.id, visitID: pendingSubmission?.id)
            MugshotAnalytics.shared.capture(
                .sipPublishBlocked(
                    analyticsSnapshot,
                    reason: analyticsBlockReason(for: errorMessage)
                )
            )
            return
        }

        if SipPublicationPolicy.requirement(
            visibility: draft.visibility,
            photoCount: publicationVisualCount,
            socialCaption: draft.socialCaption,
            confirmedTextOnlyEveryone: confirmedTextOnlyEveryone
        ) == .needsTextOnlyConfirmation {
            SipSaveDiagnostics.record(.awaitingTextOnlyConfirmation, draftID: draft.id, visitID: pendingSubmission?.id)
            MugshotAnalytics.shared.capture(
                .sipPublishBlocked(
                    analyticsSnapshot,
                    reason: .textOnlyConfirmation
                )
            )
            showTextOnlyConfirmation = true
            return
        }

#if DEBUG
        if MugshotLaunchEnvironment.consumeAuthenticationInterruption() {
            persistDraft()
            errorMessage = "Sign back in to save. Your draft will stay here."
            MugshotAnalytics.shared.capture(
                .sipPublishFailed(
                    analyticsSnapshot,
                    errorCode: .authentication,
                    recoveryState: .localDraft
                )
            )
            return
        }
        if MugshotLaunchEnvironment.consumeForcedSaveFailure() {
            draft.uploadState = .failed
            persistDraft()
            uploadRecoveryMessage = "The network interrupted this save. Retry continues the same sip and photos."
            errorMessage = "We couldn’t finish this save. Your sip is safe—try again."
            MugshotAnalytics.shared.capture(
                .sipPublishFailed(
                    analyticsSnapshot,
                    errorCode: .network,
                    recoveryState: .localDraft
                )
            )
            return
        }
#endif

        if draft.context == .cafe {
            CafeVisibilityPreferenceStore.shared.rememberCafeVisibility(
                draft.visibility,
                in: localAccountScope
            )
        }

        isSaving = true
        if let authenticatedUser = authModel.authenticatedUser {
            Task { await saveRemote(authenticatedUser: authenticatedUser) }
        } else {
            saveLocal()
        }
    }

    private var validationMessage: String? {
        if let ownerUserID = draft.ownerUserID,
           let authenticatedUserID = authModel.authenticatedUser?.id,
           ownerUserID != authenticatedUserID {
            return "This draft belongs to the account that started it. Sign back into that account to save it."
        }
        if draft.context == .cafe && draft.cafe == nil {
            return "Choose a cafe before saving this sip."
        }
        if draft.context != .cafe && draft.locationName.remoteTrimmedNonEmpty == nil {
            return draft.context == .elsewhere
                ? "Name this setting before saving."
                : "Name this home context before saving."
        }
        if draft.drinkName.remoteTrimmedNonEmpty == nil {
            return "Add the drink you want to remember."
        }
        if photoImages.isEmpty, draft.photoFallback == nil {
            return "Add a photo, or deliberately choose I missed the photo."
        }
        if let captionError = SipCaptionPolicy.validationError(for: draft.socialCaption) {
            return captionError.localizedDescription
        }
        if draft.privateNotes.v3DatabaseCharacterCount
            > V3VisitReflection.rawNoteCharacterLimit {
            return "Keep your sip journal note to 10,000 characters or fewer."
        }
        if draft.contextNotes.v3DatabaseCharacterCount
            > V3VisitReflection.rawNoteCharacterLimit {
            return "Keep your context journal note to 10,000 characters or fewer."
        }
        if draft.captureMode == .addDetails && draft.sensorySnapshot == nil {
            return "Finish or switch from Tasting Lens before saving this sip."
        }
        if draft.resolvedOverallScore < 0.5 || draft.resolvedOverallScore > 5 {
            return "Add your personal How was it? rating."
        }
        if draft.context == .cafe,
           !(1...5).contains(draft.contextScore ?? 0) {
            return "Add your cafe score before publishing this Mugshot."
        }
        switch draft.recipePublicationRequirement {
        case .ready:
            break
        case .needsImmutableSource:
            return "This adapted recipe needs its exact Mugshot source before it can publish."
        case .sourceCannotBePublic:
            return "Purchased and external recipes cannot share instructions with Everyone."
        case .needsRedistributionPermission:
            return "Confirm that people may save and adapt this recipe before sharing it with Everyone."
        case .needsPublicReuseAcknowledgment:
            return "Acknowledge public recipe reuse before sharing these instructions with Everyone."
        }
        if SipPublicationPolicy.requirement(
            visibility: draft.visibility,
            photoCount: publicationVisualCount,
            socialCaption: draft.socialCaption,
            confirmedTextOnlyEveryone: confirmedTextOnlyEveryone
        ) == .needsTextOrPhoto {
            return "Add a one-line thought or photo before sharing this sip with Everyone."
        }
        if authModel.authenticatedUser == nil && dataManager.appData.currentUser == nil {
            return "Sign back in to save. Your draft will stay here."
        }
        return nil
    }

    private func analyticsBlockReason(
        for message: String?
    ) -> MugshotSipPublishBlockReason {
        guard let message else { return .unknown }
        if message.hasPrefix("This draft belongs") { return .accountMismatch }
        if message.hasPrefix("Choose a cafe") { return .cafeRequired }
        if message.hasPrefix("Name this setting")
            || message.hasPrefix("Name this home") {
            return .contextNameRequired
        }
        if message.hasPrefix("Add the drink") { return .drinkNameRequired }
        if message.hasPrefix("Add a photo") { return .visualRequired }
        if message.hasPrefix("Write the caption") { return .captionRequired }
        if message.hasPrefix("Keep the caption") { return .captionTooLong }
        if message.hasPrefix("Keep your sip journal") { return .privateNoteTooLong }
        if message.hasPrefix("Keep your context journal") { return .contextNoteTooLong }
        if message.hasPrefix("Finish or switch from Tasting Lens") {
            return .tastingLensIncomplete
        }
        if message.hasPrefix("Add your personal") { return .sipScoreRequired }
        if message.hasPrefix("Add your cafe score") { return .contextScoreRequired }
        if message.hasPrefix("This adapted recipe needs") {
            return .recipeSourceRequired
        }
        if message.contains("recipe")
            || message.contains("instructions with Everyone") {
            return .recipeAudienceBlocked
        }
        if message.hasPrefix("Choose Friends or Everyone") {
            return .sharedAudienceRequired
        }
        if message.hasPrefix("Invite people from the primary") {
            return .sharedPrimaryRequired
        }
        if message.hasPrefix("Add a one-line thought") {
            return .publicContentRequired
        }
        if message.hasPrefix("Sign back in") { return .authenticationRequired }
        return .unknown
    }

    private var publicationVisualCount: Int {
        if !photoImages.isEmpty { return photoImages.count }
        return draft.photoFallback == nil ? 0 : 1
    }

    private func saveLocal() {
        guard let userID = dataManager.appData.currentUser?.id else { return }
        isSaving = true
        SipSaveDiagnostics.record(.localSaveStarted, draftID: draft.id)
        let cafeSessionLink = makePendingCafeSessionLink(userID: userID)

        do {
            let normalizedCaption = try SipCaptionPolicy.validateAndNormalize(draft.socialCaption)
            let cafe = draft.context == .cafe
                ? draft.cafe ?? dataManager.findOrCreateCafe(named: "Cafe")
                : nil
            let photoPaths = try photoImages.enumerated().map { index, image in
                let path = "photo_\(draft.id.uuidString.lowercased())_\(index)"
                try PhotoCache.shared.storeDurably(image, forKey: path)
                return path
            }
            let visit = Visit(
                id: draft.id,
                cafeId: cafe?.id ?? Self.localNonCafeContextID,
                userId: userID,
                drinkType: draft.drinkType,
                customDrinkType: draft.drinkType == .other ? draft.customDrinkType : nil,
                caption: normalizedCaption,
                notes: draft.privateNotes.remoteTrimmedNonEmpty,
                context: draft.context,
                locationName: draft.context == .cafe ? draft.cafe?.name : draft.locationName,
                brewMethod: draft.brewMethod.remoteTrimmedNonEmpty,
                equipment: draft.equipment.remoteTrimmedNonEmpty,
                brewDetails: submissionBrewDetails,
                drinkAnalysis: draft.drinkAnalysis,
                sensorySnapshot: draft.captureMode == .addDetails ? draft.sensorySnapshot : nil,
                photos: photoPaths,
                posterPhotoIndex: draft.posterPhotoIndex,
                ratings: draft.ratingsDictionary,
                ratingCriteria: draft.ratingCriteria,
                overallScore: draft.resolvedOverallScore,
                cafeSessionID: cafeSessionLink?.sessionID,
                cafeSessionSipOrder: cafeSessionLink?.sipOrder,
                cafeSessionSipRole: cafeSessionLink?.sipRole,
                sipReorderIntention: cafeSessionLink?.reorderIntention,
                v3Reflection: V3VisitReflection.make(visitID: draft.id, from: draft),
                visibility: draft.visibility,
                mentions: MentionParser.parseMentions(from: normalizedCaption)
            )
            dataManager.upsertVisit(visit)
            if let cafeSessionLink, let cafe {
                persistLocalCafeSession(
                    cafeSessionLink,
                    visitID: visit.id,
                    cafeID: cafe.id,
                    userID: userID
                )
            }
            try completeSuccessfulSave(visitID: visit.id, localVisit: visit)
        } catch {
            isSaving = false
            draft.uploadState = .failed
            persistDraft()
            uploadRecoveryMessage = "Your journal entry is safe. Retry finishes this same Mugshot without making a duplicate."
            errorMessage = MugshotUserFacingError.message(
                for: error,
                context: .sipSave
            )
            SipSaveDiagnostics.record(.failed, draftID: draft.id, visitID: draft.id)
            MugshotAnalytics.shared.capture(
                .sipPublishFailed(
                    analyticsSnapshot,
                    errorCode: MugshotAnalyticsErrorCode(error: error),
                    recoveryState: .localDraft
                )
            )
        }
    }

    @MainActor
    private func saveRemote(authenticatedUser: AuthenticatedUser) async {
        isSaving = true
        errorMessage = nil
        var saveOperation = SipRemoteSaveOperation.preparing
        var canonicalPublicationCommitted = false
        SipSaveDiagnostics.record(.remoteSaveStarted, draftID: draft.id, visitID: pendingSubmission?.id)

        do {
            let normalizedCaption = try SipCaptionPolicy.validateAndNormalize(draft.socialCaption)
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let cafeSessionService = CafeSessionService(client: client)
            let pendingStore = PendingVisitSubmissionStore.shared
            var submission: PendingVisitSubmissionRecord
            var savedVisit: RemoteVisitSummary?

            if let storedPending = pendingStore.load(
                visitId: draft.id,
                userId: authenticatedUser.id
            ) {
                if storedPending.isRemoteFinalized {
                    capturePublicationDeduplicationIfNeeded()
                    guard SipRemoteRecoveryPlanner.action(
                        for: storedPending,
                        authenticatedUserID: authenticatedUser.id
                    ) == .finishLocalCompletion else {
                        throw PendingVisitSubmissionStoreError.submissionIdentityMismatch
                    }
                    if draft.id != storedPending.id {
                        guard let recoveredDraft = reconstructDraft(
                            from: storedPending,
                            authenticatedUserID: authenticatedUser.id
                        ) else {
                            throw PendingVisitSubmissionStoreError.submissionIdentityMismatch
                        }
                        draft = recoveredDraft
                        photoImages = []
                    }
                } else {
                    guard storedPending.canResume(
                        with: draft,
                        authenticatedUserID: authenticatedUser.id
                    ) else {
                        conflictingPendingSubmission = storedPending
                        pendingSubmission = nil
                        throw PendingVisitSubmissionStoreError.submissionIdentityMismatch
                    }
                }
                submission = storedPending
                self.pendingSubmission = storedPending
                conflictingPendingSubmission = nil
            } else {
                self.pendingSubmission = nil
                submission = try pendingStore.prepare(
                    visitId: draft.id,
                    userId: authenticatedUser.id,
                    cafe: draft.context == .cafe ? draft.cafe : nil,
                    entryContext: draft.context,
                    locationName: draft.locationName,
                    drinkType: draft.drinkType,
                    customDrinkType: draft.customDrinkType,
                    drinkSubtype: draft.drinkName,
                    caption: normalizedCaption,
                    notes: draft.privateNotes.remoteTrimmedNonEmpty,
                    brewMethod: draft.brewMethod,
                    equipment: draft.equipment,
                    brewDetails: submissionBrewDetails,
                    visibility: draft.visibility,
                    ratings: draft.ratingsDictionary,
                    overallScore: draft.resolvedOverallScore,
                    ratingTemplate: draft.ratingTemplateSnapshot,
                    sensorySnapshot: draft.captureMode == .addDetails ? draft.sensorySnapshot : nil,
                    v3Reflection: V3VisitReflection.make(visitID: draft.id, from: draft),
                    recipePublication: draft.includesRecipeBlueprint
                        ? draft.recipePublication
                        : nil,
                    taggedCompanions: draft.taggedCompanions,
                    cafeSession: makePendingCafeSessionLink(userID: authenticatedUser.id),
                    images: photoImages,
                    posterPhotoIndex: draft.posterPhotoIndex
                )
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.submissionPrepared, draftID: draft.id, visitID: submission.id)
            }

            // A prior finalization request may have committed even when its
            // response or the following local receipt write was interrupted.
            // Reconcile the owner row before performing any other remote work.
            if submission.hasAmbiguousRemoteFinalization {
                saveOperation = .finalizing
                let remoteState = try await service.fetchOwnedVisitUploadState(
                    visitId: submission.id,
                    userId: submission.userId
                )
                if remoteState == .complete {
                    capturePublicationDeduplicationIfNeeded()
                    canonicalPublicationCommitted = true
                    submission.remoteFinalizedAt = .now
                    self.pendingSubmission = submission
                    try pendingStore.save(submission)
                    submission = pendingStore.load(
                        visitId: submission.id,
                        userId: submission.userId
                    ) ?? submission
                    self.pendingSubmission = submission
                } else if remoteState == nil {
                    // The owner query authoritatively confirmed there is no
                    // remote row. Recreate the same stable visit ID and frozen
                    // payload; the ambiguity marker remains fail-closed.
                    submission.phase = .prepared
                    submission.uploadedPhotoURLs = nil
                    try pendingStore.save(submission)
                    self.pendingSubmission = submission
                }
            }

            if submission.isRemoteFinalized {
                saveOperation = .finishingLocalCompletion
                let postPublicationSetup = await SipPostPublicationSetupWorker(
                    client: client
                ).finish(submission: submission)
                submission = postPublicationSetup.submission
                self.pendingSubmission = submission
                let finalizedVisit = try await service.fetchOwnedVisitSummary(
                    visitId: submission.id,
                    userId: submission.userId
                )
                let completionRecord = V3PublishedCompletionRecord(
                    ownerUserID: submission.userId,
                    visitID: submission.id,
                    isRemote: true,
                    updatedAt: .now
                )
                try V3PublishedCompletionStore.shared.save(completionRecord)
                publishedCompletionRecord = completionRecord
                dataManager.noteJournalMutation()
                let ownerSipCount = try? await service.fetchOwnerSipCount(
                    userId: submission.userId
                )
                try completeSuccessfulSave(
                    visitID: submission.id,
                    remoteVisit: finalizedVisit,
                    knownRemoteMemoryCount: ownerSipCount
                )
                completionStatusMessage = postPublicationSetup.warning
                if submission.isPostPublicationSetupComplete {
                    pendingStore.remove(submission)
                }
                self.pendingSubmission = nil
                conflictingPendingSubmission = nil
                uploadRecoveryMessage = nil
                return
            }

            if submission.phase == .prepared {
                saveOperation = .creatingVisit
                savedVisit = try await service.createVisit(
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
                try pendingStore.save(submission)
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.visitCreated, draftID: draft.id, visitID: submission.id)
            }

            if submission.phase >= .visitCreated,
               let session = submission.cafeSession {
                let visit: RemoteVisitSummary
                if let savedVisit {
                    visit = savedVisit
                } else {
                    visit = try await service.fetchOwnedVisitSummary(
                        visitId: submission.id,
                        userId: submission.userId
                    )
                }
                guard let remoteCafeID = visit.visit.cafeId else {
                    throw CafeSessionServiceError.missingRemoteCafe
                }
                try await cafeSessionService.ensureSession(
                    sessionID: session.sessionID,
                    remoteCafeID: remoteCafeID,
                    startedAt: session.startedAt,
                    context: session.visitContext,
                    visibility: .private
                )
                try await cafeSessionService.attachVisit(
                    sessionID: session.sessionID,
                    visitID: submission.id,
                    order: session.sipOrder,
                    role: session.sipRole
                )
                if session.sipRole == .primary {
                    if let snapshot = session.experienceSnapshot {
                        let reboundSnapshot = snapshot.rebindingCafeID(remoteCafeID)
                        try await cafeSessionService.recordExperience(
                            reboundSnapshot,
                            primaryReorderIntention: session.reorderIntention
                        )
                    } else if session.returnIntention != nil || session.reorderIntention != nil {
                        try await cafeSessionService.recordIntentions(
                            sessionID: session.sessionID,
                            visitID: submission.id,
                            returnIntention: session.returnIntention,
                            reorderIntention: session.reorderIntention
                        )
                    }
                }
            }

            // The immutable private Taste Snapshot belongs to the visit, not to
            // photo publication. Keep this retry-safe block outside the prepared
            // branch so an interrupted save always repairs or verifies it before
            // the visit can be finalized for an audience.
            if submission.phase >= .visitCreated,
               let sensorySnapshot = submission.sensorySnapshot {
                saveOperation = .savingTastingLens
                SipSaveDiagnostics.record(
                    .tastingLensSnapshotStarted,
                    draftID: draft.id,
                    visitID: submission.id
                )
                _ = try await SensorySnapshotService(client: client).insertOnce(
                    visitID: submission.id,
                    userID: submission.userId,
                    snapshot: sensorySnapshot
                )
                SipSaveDiagnostics.record(
                    .tastingLensSnapshotSaved,
                    draftID: draft.id,
                    visitID: submission.id
                )
            }

            if submission.phase < .photosUploaded {
                saveOperation = .uploadingPhotos
                SipSaveDiagnostics.record(
                    .photoUploadStarted,
                    draftID: draft.id,
                    visitID: submission.id
                )
#if DEBUG
                if !submission.objectPaths.isEmpty,
                   MugshotLaunchEnvironment.consumeRemotePhotoUploadFailure() {
                    throw URLError(.networkConnectionLost)
                }
#endif
                let images = try pendingStore.loadImages(for: submission)
                let result = try await VisitPhotoUploadService(client: client).uploadPhotos(
                    userId: submission.userId,
                    visitId: submission.id,
                    images: images,
                    posterPhotoIndex: submission.posterPhotoIndex,
                    plannedObjectPaths: submission.objectPaths,
                    replacingExisting: true
                )
                submission.uploadedPhotoURLs = result.publicURLs
                submission.phase = .photosUploaded
                try pendingStore.save(submission)
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.photosUploaded, draftID: draft.id, visitID: submission.id)
            }

            saveOperation = .finalizing
            SipSaveDiagnostics.record(
                .finalizationStarted,
                draftID: draft.id,
                visitID: submission.id
            )
            let urls = submission.uploadedPhotoURLs ?? []
            let attached = try await service.attachPhotoURLs(
                visitId: submission.id,
                photoURLs: urls,
                posterPhotoIndex: submission.posterPhotoIndex
            )

            // Persist ambiguity protection before the first RPC that can make
            // the visit complete. A timeout from that RPC is never treated as
            // proof that publication failed.
            if submission.finalizationRequestedAt == nil {
                submission.finalizationRequestedAt = .now
                try pendingStore.save(submission)
                self.pendingSubmission = submission
            }

            if let session = submission.cafeSession {
                try await cafeSessionService.finalizeSipUpload(
                    sessionID: session.sessionID,
                    visitID: submission.id
                )
            } else {
                try await service.finalizeVisitPublication(
                    visitId: submission.id,
                    userId: submission.userId,
                    visibility: submission.visibility
                )
            }

            // This is the irreversible boundary. Update the in-memory record
            // before the durable write so even a local persistence error can
            // never enter the failed-upload or destructive-discard path.
            canonicalPublicationCommitted = true
            submission.remoteFinalizedAt = .now
            self.pendingSubmission = submission
            try pendingStore.save(submission)
            submission = pendingStore.load(
                visitId: submission.id,
                userId: submission.userId
            ) ?? submission
            self.pendingSubmission = submission
            SipSaveDiagnostics.record(.visitFinalized, draftID: draft.id, visitID: submission.id)

            let completionRecord = V3PublishedCompletionRecord(
                ownerUserID: submission.userId,
                visitID: submission.id,
                isRemote: true,
                updatedAt: .now
            )
            try V3PublishedCompletionStore.shared.save(completionRecord)
            publishedCompletionRecord = completionRecord

            let postPublicationSetup = await SipPostPublicationSetupWorker(
                client: client
            ).finish(submission: submission)
            submission = postPublicationSetup.submission
            self.pendingSubmission = submission

            let finalizedVisit = try await service.fetchOwnedVisitSummary(
                visitId: submission.id,
                userId: submission.userId
            )

            DrinkAnalysisRetryStore.shared.enqueue(
                visitId: submission.id,
                userId: submission.userId
            )
            Task {
                await DrinkAnalysisService(client: client).requestAnalysisDurably(
                    visitId: submission.id,
                    userId: submission.userId
                )
            }
            SipSaveDiagnostics.record(.analysisQueued, draftID: draft.id, visitID: submission.id)

            if let cafeID = attached.cafe?.id {
                try? await CafeStateService(client: client).clearWantToTryAfterVisit(
                    userId: submission.userId,
                    cafeId: cafeID
                )
            }

            dataManager.noteJournalMutation()
            let ownerSipCount = try? await service.fetchOwnerSipCount(
                userId: submission.userId
            )
            try completeSuccessfulSave(
                visitID: submission.id,
                remoteVisit: finalizedVisit,
                knownRemoteMemoryCount: ownerSipCount
            )
            completionStatusMessage = postPublicationSetup.warning
            if submission.isPostPublicationSetupComplete {
                pendingStore.remove(submission)
            }
            self.pendingSubmission = nil
            conflictingPendingSubmission = nil
            uploadRecoveryMessage = nil
        } catch {
            isSaving = false
            SipSaveDiagnostics.record(.failed, draftID: draft.id, visitID: pendingSubmission?.id)
            let analyticsRecoveryState: MugshotSipRecoveryState
            if canonicalPublicationCommitted
                || pendingSubmission?.isRemotePublicationProtected == true {
                analyticsRecoveryState = .publicationProtected
            } else if pendingSubmission != nil {
                analyticsRecoveryState = .protectedRetry
            } else {
                analyticsRecoveryState = .localDraft
            }
            MugshotAnalytics.shared.capture(
                .sipPublishFailed(
                    analyticsSnapshot,
                    errorCode: MugshotAnalyticsErrorCode(error: error),
                    recoveryState: analyticsRecoveryState
                )
            )
            if canonicalPublicationCommitted
                || pendingSubmission?.isRemotePublicationProtected == true {
                let publicationWasRecorded = pendingSubmission?.isRemoteFinalized == true
                uploadRecoveryMessage = publicationWasRecorded
                    ? SipRemoteSaveOperation.finishingLocalCompletion.recoveryMessage
                    : "Mugshot could not verify the publication response. Your protected save was kept so Retry can check the server without creating a duplicate."
                completionStatusMessage = publicationWasRecorded
                    ? "Your MugShot is safely published. Mugshot will finish its remaining setup when you retry."
                    : nil
                errorMessage = completionStatusMessage
                    ?? uploadRecoveryMessage
                return
            }
            draft.uploadState = .failed
            persistDraft()
            if let pendingSubmission {
                let client = try? SupabaseClientProvider.shared.client()
                if let client, pendingSubmission.phase >= .visitCreated {
                    try? await VisitService(client: client).markVisitUploadFailed(
                        visitId: pendingSubmission.id,
                        userId: pendingSubmission.userId
                    )
                }
                uploadRecoveryMessage = saveOperation.recoveryMessage
                if let frozenDraft = reconstructDraft(
                    from: pendingSubmission,
                    authenticatedUserID: pendingSubmission.userId
                ) {
                    routeToPendingSubmission(
                        pendingSubmission,
                        recoveredDraft: frozenDraft,
                        fallbackImages: photoImages,
                        userID: pendingSubmission.userId
                    )
                    v3Step = .publish
                }
            }
            errorMessage = MugshotUserFacingError.message(
                for: error,
                context: saveOperation.errorContext
            )
        }
    }

    private func completeSuccessfulSave(
        visitID: UUID,
        remoteVisit: RemoteVisitSummary? = nil,
        localVisit: Visit? = nil,
        knownRemoteMemoryCount: Int? = nil
    ) throws {
        SipSaveDiagnostics.record(.completed, draftID: draft.id, visitID: visitID)
        MugshotAnalytics.shared.capture(
            .sipPublished(
                analyticsSnapshot,
                durationSeconds: analyticsDurationSeconds,
                isRemote: remoteVisit != nil,
                wasRecovery: analyticsPublishWasRecovery
            )
        )
        let completedDraft = draft
        let selectedCoverImage = photoImages.isEmpty
            ? nil
            : photoImages[min(max(draft.posterPhotoIndex, 0), photoImages.count - 1)]
        let continuationOwnerUserID = draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        if draft.context == .cafe {
            CafeVisibilityPreferenceStore.shared.rememberCafeVisibility(
                draft.visibility,
                in: .forUserID(continuationOwnerUserID)
            )
        }
        var sessionForContinuation = draft.cafeSessionDraft
        if sessionForContinuation == nil,
           activeContinuationSession?.id == draft.cafeSessionID {
            sessionForContinuation = activeContinuationSession
        }
        if var sessionForContinuation {
            if sessionForContinuation.primaryVisitID == nil {
                sessionForContinuation.primaryVisitID = visitID
            }
            sessionForContinuation.status = .complete
            sessionForContinuation.updatedAt = .now
            completedCafeSession = sessionForContinuation
            completedSessionCafe = draft.cafe
        } else {
            completedCafeSession = nil
            completedSessionCafe = nil
        }
        activeContinuationSession = nil

        let completedSummary = makeCompletionSummary(
            from: draft,
            session: sessionForContinuation
        )
        RecentCriterionSetupStore.shared.remember(
            completedDraft.ratingCriteria,
            scope: pinnedSipScope
        )
        RecentCriterionSetupStore.shared.remember(
            completedDraft.contextRatingCriteria,
            scope: pinnedContextScope
        )
        completionSummary = completedSummary
        v3CompletionSummary = makeV3PassportSummary(
            from: completedDraft,
            visitID: visitID,
            isRemote: remoteVisit != nil,
            photoImages: photoImages,
            coverImage: selectedCoverImage,
            knownMemoryCount: localVisit != nil
                ? knownLocalMemoryCount(for: completedDraft)
                : knownRemoteMemoryCount
        )
        completedRemoteVisit = remoteVisit
        completedLocalVisit = localVisit
        if let sessionForContinuation,
           let completedSessionCafe {
            try? CafeSessionContinuationStore.shared.save(
                CafeSessionContinuationRecord(
                    ownerUserID: continuationOwnerUserID,
                    session: sessionForContinuation,
                    cafe: completedSessionCafe,
                    summary: completedSummary.snapshot,
                    stage: .completion,
                    activeDraftID: nil,
                    updatedAt: .now
                )
            )
        } else {
            CafeSessionContinuationStore.shared.remove(
                ownerUserID: continuationOwnerUserID
            )
        }
        let durableCompletedDraft = try SipDraftStore.shared.save(
            completedDraft,
            images: photoImages,
            in: .forUserID(continuationOwnerUserID)
        )
        composerModel.draft = durableCompletedDraft
        let completionRecord = V3PublishedCompletionRecord(
            ownerUserID: continuationOwnerUserID,
            visitID: visitID,
            isRemote: remoteVisit != nil,
            updatedAt: .now
        )
        try V3PublishedCompletionStore.shared.save(completionRecord)
        publishedCompletionRecord = completionRecord
        searchText = ""
        isCafeSearchActive = false
        confirmedTextOnlyEveryone = false
        showTextOnlyConfirmation = false
        pendingSubmission = nil
        conflictingPendingSubmission = nil
        uploadRecoveryMessage = nil
        completionStatusMessage = nil
        showSavedConfirmation = true
        v3Step = .publish
        isSaving = false
    }

    private func addAnotherSipToCompletedSession() {
        guard var session = completedCafeSession,
              let cafe = completedSessionCafe
                ?? dataManager.getCafe(id: session.cafeID)
                ?? explicitLaunchDraft?.cafe
                ?? preselectedCafe else {
            finishSuccessfulSave()
            return
        }
        let priorCompletionSummary = completionSummary
        clearPublishedCompletionHandoff()
        let nextDraft = SipDraft.additionalSip(
            in: &session,
            cafe: cafe,
            ownerUserID: authModel.authenticatedUser?.id
                ?? dataManager.appData.currentUser?.id
        )
        var configuredDraft = nextDraft
        configuredDraft.composerExperience = composerExperience
        configuredDraft.guidedStep = .drink
        activeContinuationSession = session
        completedCafeSession = nil
        completedSessionCafe = nil
        completionSummary = nil
        v3CompletionSummary = nil
        completedRemoteVisit = nil
        completedLocalVisit = nil
        isLoadingPublishedVisit = false
        completionStatusMessage = nil
        configuredDraft.v3Step = .setup
        composerModel.draft = configuredDraft
        photoImages.removeAll()
        searchText = ""
        isCafeSearchActive = false
        confirmedTextOnlyEveryone = false
        showSavedConfirmation = false
        v3Step = .setup
        analyticsStartedAt = .now
        analyticsIsDraftResume = false
        analyticsDidCaptureOpen = false
        analyticsDidCaptureRecovery = false
        analyticsDidCaptureDeduplication = false
        analyticsPublishWasRecovery = false
        persistDraft()
        captureComposerOpenedIfNeeded()
        let ownerUserID = configuredDraft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        if let priorCompletionSummary {
            try? CafeSessionContinuationStore.shared.save(
                CafeSessionContinuationRecord(
                    ownerUserID: ownerUserID,
                    session: session,
                    cafe: cafe,
                    summary: priorCompletionSummary.snapshot,
                    stage: .activeAdditionalSip,
                    activeDraftID: configuredDraft.id,
                    updatedAt: .now
                )
            )
        }
        MugshotHaptic.softImpact.play()
    }

    private func finishSuccessfulSave() {
        let ownerUserID = draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        clearPublishedCompletionHandoff(ownerUserID: ownerUserID)
        CafeSessionContinuationStore.shared.remove(ownerUserID: ownerUserID)
        tabCoordinator.selectedTab = 4
        dismiss()
    }

    private func viewPassportAfterCompletion() {
        JournalPassportRouter.shared.requestPassport()
        finishSuccessfulSave()
    }

    private func clearPublishedCompletionHandoff(ownerUserID explicitOwnerUserID: UUID? = nil) {
        let ownerUserID = explicitOwnerUserID
            ?? publishedCompletionRecord?.ownerUserID
            ?? draft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        let record = publishedCompletionRecord
            ?? V3PublishedCompletionStore.shared.load(ownerUserID: ownerUserID)
        if let record,
           let storedDraft = SipDraftStore.shared.load(
               id: record.visitID,
               in: .forUserID(record.ownerUserID)
           ) {
            SipDraftStore.shared.remove(
                storedDraft.draft,
                in: .forUserID(record.ownerUserID)
            )
        }
        V3PublishedCompletionStore.shared.remove(ownerUserID: ownerUserID)
        publishedCompletionRecord = nil
    }

    private func viewPublishedMugshot() {
        guard completedRemoteVisit != nil || completedLocalVisit != nil else {
            guard let record = publishedCompletionRecord,
                  record.isRemote,
                  let ownerUserID = record.ownerUserID
                    ?? authModel.authenticatedUser?.id else {
                completionStatusMessage = "Your Mugshot is safely published. Open it from Journal."
                return
            }
            Task {
                await loadPublishedRemoteVisit(
                    record: record,
                    ownerUserID: ownerUserID,
                    openAfterLoad: true
                )
            }
            return
        }
        showPublishedMugshot = true
    }

    @MainActor
    private func loadPublishedRemoteVisit(
        record: V3PublishedCompletionRecord,
        ownerUserID: UUID,
        openAfterLoad: Bool
    ) async {
        guard !isLoadingPublishedVisit else { return }
        isLoadingPublishedVisit = true
        completionStatusMessage = nil
        defer { isLoadingPublishedVisit = false }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            async let visitRequest = service.fetchOwnedVisitSummary(
                visitId: record.visitID,
                userId: ownerUserID
            )
            async let countRequest = try? service.fetchOwnerSipCount(userId: ownerUserID)
            let visit = try await visitRequest
            let memoryCount = await countRequest
            guard publishedCompletionRecord?.visitID == record.visitID,
                  showSavedConfirmation else {
                return
            }
            completedRemoteVisit = visit
            if let stored = SipDraftStore.shared.load(
                id: record.visitID,
                in: .forUserID(record.ownerUserID)
            ) {
                let coverImage = stored.images.isEmpty
                    ? nil
                    : stored.images[min(
                        max(stored.draft.posterPhotoIndex, 0),
                        stored.images.count - 1
                    )]
                v3CompletionSummary = makeV3PassportSummary(
                    from: stored.draft,
                    visitID: record.visitID,
                    isRemote: record.isRemote,
                    photoImages: stored.images,
                    coverImage: coverImage,
                    knownMemoryCount: memoryCount
                )
            }
            if openAfterLoad {
                showPublishedMugshot = true
            }
        } catch {
            guard publishedCompletionRecord?.visitID == record.visitID else { return }
            completionStatusMessage = "Your Mugshot is safely published. Reconnect to open it here."
        }
    }

    private func makeCompletionSummary(
        from completedDraft: SipDraft,
        session: CafeSessionDraft?
    ) -> SipCompletionSummary {
        SipCompletionSummary(
            drinkName: completedDraft.drinkName.remoteTrimmedNonEmpty ?? "Saved sip",
            locationName: completedDraft.context == .cafe
                ? completedDraft.cafe?.consumerDisplayName ?? "Cafe"
                : completedDraft.locationName.remoteTrimmedNonEmpty
                    ?? completedDraft.context.locationFallback,
            context: completedDraft.context,
            score: completedDraft.resolvedOverallScore,
            visibility: completedDraft.visibility,
            usedTastingLens: completedDraft.captureMode == .addDetails,
            hasPhoto: !photoImages.isEmpty,
            hasThought: completedDraft.socialCaption.remoteTrimmedNonEmpty != nil,
            hasPrivateNote: completedDraft.privateNotes.remoteTrimmedNonEmpty != nil,
            hasBrewDetails: completedDraft.brewMethod.remoteTrimmedNonEmpty != nil
                || completedDraft.equipment.remoteTrimmedNonEmpty != nil
                || !completedDraft.tags.isEmpty
                || !completedDraft.companions.isEmpty
                || completedDraft.orderNotes.remoteTrimmedNonEmpty != nil,
            isCafeSession: completedDraft.cafeSessionID != nil,
            cafeRating: session?.experienceDraft?.cafeRating?.value,
            nextMove: completedDraft.cafeNextMove.kind
        )
    }

    private func makeV3PassportSummary(
        from completedDraft: SipDraft,
        visitID: UUID,
        isRemote: Bool,
        photoImages: [UIImage],
        coverImage: UIImage?,
        knownMemoryCount: Int?
    ) -> LogASipV3PassportSummary {
        let isHome = completedDraft.context == .home || completedDraft.context == .recipe
        let contextScore = isHome ? nil : completedDraft.contextScore
        let sipScore = completedDraft.resolvedOverallScore
        let mugshotScore = V3VisitReflection.deriveMugshotScore(
            sipScore: sipScore,
            contextScore: contextScore
        )
        let contextName: String
        switch completedDraft.context {
        case .cafe:
            contextName = completedDraft.cafe?.consumerDisplayName ?? "Cafe"
        case .home, .recipe:
            contextName = completedDraft.locationName.remoteTrimmedNonEmpty ?? "Home"
        case .elsewhere:
            contextName = completedDraft.locationName.remoteTrimmedNonEmpty ?? "Elsewhere"
        }

        var seenCriteria = Set<String>()
        let criteria = (completedDraft.ratingCriteria + completedDraft.contextRatingCriteria)
            .filter { $0.score > 0 }
            .compactMap { criterion -> String? in
                let normalized = criterion.name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard !normalized.isEmpty, seenCriteria.insert(normalized).inserted else {
                    return nil
                }
                return criterion.name
            }

        let contextLabel = completedDraft.context == .cafe ? "Cafe" : "Setting"
        let scoreEvidence: String
        if let contextScore {
            scoreEvidence = String(
                format: "Sip %.1f and %@ %.1f blend to a %.1f Mugshot.",
                sipScore,
                contextLabel,
                contextScore,
                mugshotScore
            )
        } else {
            scoreEvidence = String(
                format: "Sip %.1f is this memory’s Mugshot score; no second score was required.",
                sipScore
            )
        }

        let evidence = [
            LogASipV3PassportEvidence(
                id: "latest-memory",
                title: "A new memory",
                detail: "\(completedDraft.drinkName) at \(contextName)",
                systemImage: "camera.fill"
            ),
            LogASipV3PassportEvidence(
                id: "score-evidence",
                title: "Your scoring evidence",
                detail: scoreEvidence,
                systemImage: "star.bubble.fill"
            )
        ]

        let identityDetail = criteria.isEmpty
            ? "This memory adds one honest data point. Mugshot waits for repeated evidence before calling anything a pattern."
            : "\(criteria.prefix(2).joined(separator: " and ")) shaped this memory. Mugshot will wait for repetition before turning that into a taste pattern."

        return LogASipV3PassportSummary(
            visitID: visitID,
            visibility: completedDraft.visibility,
            isOwner: true,
            isRemote: isRemote,
            displayName: dataManager.appData.currentUser?.displayNameOrUsername ?? "You",
            drinkName: completedDraft.drinkName,
            contextName: contextName,
            createdAt: completedDraft.createdAt,
            sipScore: sipScore,
            contextScore: contextScore,
            mugshotScore: mugshotScore,
            identityTitle: "Your Mugshot Passport is forming",
            identityDetail: identityDetail,
            memoryCount: knownMemoryCount ?? 0,
            criteria: Array(criteria.prefix(8)),
            evidence: evidence,
            publicCaption: completedDraft.socialCaption.remoteTrimmedNonEmpty,
            photoImages: photoImages,
            coverImage: coverImage
        )
    }

    private func knownLocalMemoryCount(for completedDraft: SipDraft) -> Int {
        let userID = completedDraft.ownerUserID
            ?? authModel.authenticatedUser?.id
            ?? dataManager.appData.currentUser?.id
        let localMemories = dataManager.appData.visits.filter { visit in
            userID == nil || visit.userId == userID
        }
        return localMemories.contains(where: { $0.id == completedDraft.id })
            ? localMemories.count
            : localMemories.count + 1
    }

    private func makePendingCafeSessionLink(userID: UUID) -> PendingCafeSessionLink? {
        guard draft.context == .cafe,
              let sessionID = draft.cafeSessionID,
              let role = draft.cafeSessionSipRole,
              let order = draft.cafeSessionSipOrder else {
            return nil
        }

        if var session = draft.cafeSessionDraft {
            session.ownerUserID = userID
            session.visibility = draft.visibility
            return PendingCafeSessionLink(
                sessionID: session.id,
                startedAt: session.startedAt,
                sipOrder: order,
                sipRole: role,
                visitContext: session.experienceDraft?.visitContext ?? CafeVisitContext(),
                returnIntention: session.returnIntention,
                reorderIntention: draft.sipReorderIntention,
                repeatComparison: session.repeatComparison,
                experienceSnapshot: session.makeSnapshot(),
                shareProjection: session.shareProjection
            )
        }

        guard let reference = draft.cafeSessionReference,
              reference.id == sessionID else {
            return nil
        }
        return PendingCafeSessionLink(
            sessionID: reference.id,
            startedAt: reference.startedAt,
            sipOrder: order,
            sipRole: role,
            visitContext: CafeVisitContext(),
            returnIntention: reference.returnIntention,
            reorderIntention: draft.sipReorderIntention,
            repeatComparison: nil,
            experienceSnapshot: nil,
            shareProjection: CafeExperienceShareProjection()
        )
    }

    private func persistLocalCafeSession(
        _ link: PendingCafeSessionLink,
        visitID: UUID,
        cafeID: UUID,
        userID: UUID
    ) {
        if var existing = dataManager.getCafeSession(id: link.sessionID) {
            if !existing.visitIDs.contains(visitID) {
                existing.visitIDs.append(visitID)
            }
            if link.sipRole == .primary {
                existing.primaryVisitID = visitID
            }
            existing.status = .complete
            existing.endedAt = .now
            existing.visibility = draft.visibility
            existing.returnIntention = link.returnIntention ?? existing.returnIntention
            existing.experienceSnapshot = link.experienceSnapshot ?? existing.experienceSnapshot
            dataManager.upsertCafeSession(existing)
            return
        }

        dataManager.upsertCafeSession(CafeSession(
            id: link.sessionID,
            ownerUserID: userID,
            cafeID: cafeID,
            startedAt: link.startedAt,
            endedAt: .now,
            status: .complete,
            visibility: draft.visibility,
            primaryVisitID: link.sipRole == .primary ? visitID : nil,
            visitIDs: [visitID],
            returnIntention: link.returnIntention,
            experienceSnapshot: link.experienceSnapshot
        ))
    }

    private var submissionBrewDetails: BrewDetails {
        var details = draft.brewDetails
        details.orderNotes = draft.orderNotes.remoteTrimmedNonEmpty
        details.tags = draft.tags.isEmpty ? nil : draft.tags
        details.companions = draft.companions.isEmpty ? nil : draft.companions
        if draft.context == .recipe {
            if details.recipeIdentityID == nil { details.recipeIdentityID = UUID() }
        }
        return details
    }

    private func refreshDrinkAnalysis() {
        composerModel.refreshDrinkAnalysis()
    }

    private func moveToPreviousGuidedStep() {
        let prior: SipGuidedStep
        switch draft.resolvedGuidedStep {
        case .context: return
        case .drink: prior = .context
        case .rating: prior = .drink
        case .cafePulse:
            if moveToPriorCafePulseStep() { return }
            prior = .rating
        case .audience: prior = guidedSteps.contains(.cafePulse) ? .cafePulse : .rating
        }
        moveToGuidedStep(prior)
    }

    private func performGuidedPrimaryAction() {
        switch draft.resolvedGuidedStep {
        case .context:
            guard hasCompletedContext else { return }
            moveToGuidedStep(.drink)
        case .drink:
            guard draft.drinkName.remoteTrimmedNonEmpty != nil else { return }
            moveToGuidedStep(.rating)
        case .rating:
            moveToGuidedStep(guidedSteps.contains(.cafePulse) ? .cafePulse : .audience)
        case .cafePulse:
            if moveToNextCafePulseStep() { return }
            moveToGuidedStep(.audience)
        case .audience:
            saveSip()
        }
    }

    private func moveToGuidedStep(_ step: SipGuidedStep) {
        errorMessage = nil
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            draft.guidedStep = step
        }
        MugshotHaptic.softImpact.play()
    }

    private var hasCompletedContext: Bool {
        draft.context == .cafe ? draft.cafe != nil : draft.locationName.remoteTrimmedNonEmpty != nil
    }

    private var canPerformGuidedPrimaryAction: Bool {
        switch draft.resolvedGuidedStep {
        case .context: return hasCompletedContext
        case .drink: return draft.drinkName.remoteTrimmedNonEmpty != nil
        case .rating:
            return draft.resolvedOverallScore >= 0.5 && draft.resolvedOverallScore <= 5
                && (draft.captureMode == .quickSip || draft.sensorySnapshot != nil)
        case .cafePulse: return true
        case .audience: return draft.hasRequiredCore
        }
    }

    private var guidedPrimaryTitle: String {
        switch draft.resolvedGuidedStep {
        case .context, .drink: return "Continue"
        case .rating: return guidedSteps.contains(.cafePulse) ? "Reflect on the cafe" : "Choose audience"
        case .cafePulse:
            return cafePulseJourneyPlan.isLastStep(currentCafePulseStepID)
                ? "Choose audience"
                : "Continue"
        case .audience: return saveButtonTitle
        }
    }

    private var guidedPrimaryIcon: String {
        switch draft.resolvedGuidedStep {
        case .context, .drink: return "arrow.right"
        case .rating: return guidedSteps.contains(.cafePulse) ? "building.2.fill" : "person.2.fill"
        case .cafePulse:
            return cafePulseJourneyPlan.isLastStep(currentCafePulseStepID)
                ? "person.2.fill"
                : "arrow.right"
        case .audience: return "checkmark"
        }
    }

    private var guidedSaveVisibility: VisitVisibility {
        draft.visibility
    }

    private var guidedFooterHint: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Your draft is saved as you go."
        case .drink: return "Mugshot will organize this in the background."
        case .rating:
            return draft.captureMode == .addDetails
                ? "Your observations and personal stars are separate."
                : "Your sip score is ready."
        case .cafePulse:
            let index = cafePulseJourneyPlan.resolvedIndex(for: currentCafePulseStepID)
            return "Cafe Pulse step \(index + 1) of \(cafePulseJourneyPlan.steps.count) · Cafe stars never change sip stars."
        case .audience: return "Serving details and private notes are optional."
        }
    }

    private var cafePulseJourneyPlan: CafePulseJourneyPlan {
        let experience = draft.cafeSessionDraft?.experienceDraft ?? CafeExperienceDraft()
        return CafePulseJourneyPlan.make(
            depth: experience.depth,
            context: experience.visitContext,
            showsRepeatComparison: true
        )
    }

    private var currentCafePulseStepID: String? {
        draft.cafeSessionDraft?.experienceDraft?.journeyStepID
    }

    @discardableResult
    private func moveToNextCafePulseStep() -> Bool {
        guard let next = cafePulseJourneyPlan.step(after: currentCafePulseStepID) else {
            return false
        }
        setCafePulseJourneyStep(next.id)
        return true
    }

    @discardableResult
    private func moveToPriorCafePulseStep() -> Bool {
        guard let prior = cafePulseJourneyPlan.step(before: currentCafePulseStepID) else {
            return false
        }
        setCafePulseJourneyStep(prior.id)
        return true
    }

    private func setCafePulseJourneyStep(_ stepID: String) {
        ensureCafeSessionDraft()
        if draft.cafeSessionDraft?.experienceDraft == nil {
            draft.cafeSessionDraft?.experienceDraft = CafeExperienceDraft()
        }
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            draft.cafeSessionDraft?.experienceDraft?.journeyStepID = stepID
            draft.cafeSessionDraft?.experienceDraft?.updatedAt = .now
        }
        MugshotHaptic.softImpact.play()
    }

    private var guidedSteps: [SipGuidedStep] {
        if shouldOfferCafePulse {
            return [.context, .drink, .rating, .cafePulse, .audience]
        }
        return [.context, .drink, .rating, .audience]
    }

    private var guidedScrollIdentity: String {
        if draft.resolvedGuidedStep == .cafePulse {
            return "\(SipGuidedStep.cafePulse.rawValue)-\(currentCafePulseStepID ?? "start")"
        }
        return draft.resolvedGuidedStep.rawValue
    }

    private var guidedCurrentStepIndex: Int {
        guidedSteps.firstIndex(of: draft.resolvedGuidedStep)
            ?? max(guidedSteps.count - 1, 0)
    }

    private func addTag(_ rawTag: String) {
        guard let tag = rawTag.remoteTrimmedNonEmpty,
              !draft.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            return
        }
        draft.tags.append(tag)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func commitCustomTag() {
        guard let tag = customTagText.remoteTrimmedNonEmpty else { return }
        addTag(tag)
        customTagText = ""
        isAddingCustomTag = false
    }

    private func removeCompanion(_ companion: SipCompanion) {
        draft.taggedCompanions?.removeAll { $0.userID == companion.userID }
        draft.companions = draft.taggedCompanions?.map(\.displayName) ?? []
    }

    private func appendPhotos(_ images: [UIImage]) {
        guard canEditPhotos else {
            errorMessage = PendingVisitSubmissionStoreError
                .mediaAlreadyUploaded
                .localizedDescription
            return
        }
        let previousImages = photoImages
        let previousLocalNames = draft.localPhotoNames
        let previousPosterPhotoIndex = draft.posterPhotoIndex
        let previousPhotoFallback = draft.photoFallback
        let remaining = max(0, 10 - photoImages.count)
        photoImages.append(contentsOf: images.prefix(remaining))
        if !images.isEmpty { draft.photoFallback = nil }
        guard commitPendingPhotoPlanIfNeeded() else {
            photoImages = previousImages
            draft.localPhotoNames = previousLocalNames
            draft.posterPhotoIndex = previousPosterPhotoIndex
            draft.photoFallback = previousPhotoFallback
            return
        }
        confirmedTextOnlyEveryone = false
        persistDraft()
    }

    private func removePhoto(at index: Int) {
        guard canEditPhotos, photoImages.indices.contains(index) else {
            if !canEditPhotos {
                errorMessage = PendingVisitSubmissionStoreError
                    .mediaAlreadyUploaded
                    .localizedDescription
            }
            return
        }
        let previousImages = photoImages
        let previousLocalNames = draft.localPhotoNames
        let previousPosterPhotoIndex = draft.posterPhotoIndex
        let removedPoster = draft.posterPhotoIndex == index
        photoImages.remove(at: index)
        if draft.localPhotoNames.indices.contains(index) {
            draft.localPhotoNames.remove(at: index)
        }
        if removedPoster {
            draft.posterPhotoIndex = min(index, max(photoImages.count - 1, 0))
        } else if index < draft.posterPhotoIndex {
            draft.posterPhotoIndex -= 1
        } else {
            draft.posterPhotoIndex = min(draft.posterPhotoIndex, max(photoImages.count - 1, 0))
        }
        guard commitPendingPhotoPlanIfNeeded() else {
            photoImages = previousImages
            draft.localPhotoNames = previousLocalNames
            draft.posterPhotoIndex = previousPosterPhotoIndex
            return
        }
        confirmedTextOnlyEveryone = false
        persistDraft()
    }

    private func finishOrganizingPhotos() {
        let imagesChanged = photoOrganizerOriginalImages.map { original in
            original.count != photoImages.count
                || !zip(original, photoImages).allSatisfy { pair in
                    pair.0 === pair.1
                }
        } ?? false
        let posterChanged = photoOrganizerOriginalPosterIndex.map {
            $0 != draft.posterPhotoIndex
        } ?? false
        photoOrganizerOriginalImages = nil
        photoOrganizerOriginalPosterIndex = nil

        guard imagesChanged || posterChanged else {
            persistDraft()
            return
        }
        guard commitPendingPhotoPlanIfNeeded() else {
            restoreFrozenPendingPhotos()
            return
        }
        persistDraft()
    }

    private func beginOrganizingPhotos() {
        guard canEditPhotos else {
            errorMessage = PendingVisitSubmissionStoreError
                .mediaAlreadyUploaded
                .localizedDescription
            return
        }
        photoOrganizerOriginalImages = photoImages
        photoOrganizerOriginalPosterIndex = draft.posterPhotoIndex
        showPhotoOrganizer = true
    }

    @discardableResult
    private func commitPendingPhotoPlanIfNeeded() -> Bool {
        guard let pendingSubmission else { return true }
        guard pendingSubmission.canResume(
            with: draft,
            authenticatedUserID: pendingSubmission.userId
        ) else {
            conflictingPendingSubmission = pendingSubmission
            self.pendingSubmission = nil
            errorMessage = PendingVisitSubmissionStoreError
                .submissionIdentityMismatch
                .localizedDescription
            return false
        }

        do {
            let replacement = try PendingVisitSubmissionStore.shared.replaceImages(
                for: pendingSubmission,
                images: photoImages,
                posterPhotoIndex: draft.posterPhotoIndex
            )
            self.pendingSubmission = replacement.record
            pendingRecoveryNeedsPhotoRepair = false
            scheduleObsoletePhotoCleanup(
                replacement.obsoleteObjectPaths,
                userID: replacement.record.userId
            )
            uploadRecoveryMessage = "Your photo changes are ready. Retry continues this same sip without making a duplicate."
            errorMessage = nil
            return true
        } catch {
            errorMessage = MugshotUserFacingError.message(
                for: error,
                context: .photoUpload
            )
            return false
        }
    }

    private func restoreFrozenPendingPhotos() {
        guard let pendingSubmission,
              let images = try? PendingVisitSubmissionStore.shared.loadImages(
                for: pendingSubmission
              ) else {
            return
        }
        photoImages = images
        draft.localPhotoNames = []
        draft.posterPhotoIndex = pendingSubmission.posterPhotoIndex
        persistDraft()
    }

    private func scheduleObsoletePhotoCleanup(_ paths: [String], userID: UUID) {
        guard !paths.isEmpty else { return }
        let cleanupStore = VisitMediaCleanupStore.shared
        cleanupStore.enqueue(paths, userId: userID)
        Task {
            guard let client = try? SupabaseClientProvider.shared.client() else { return }
            do {
                try await VisitPhotoUploadService(client: client).deletePhotos(at: paths)
                cleanupStore.remove(paths, userId: userID)
            } catch {
                // Durable cleanup remains queued for the existing launch retry.
            }
        }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                    else { showCameraPermissionRecovery = true }
                }
            }
        case .denied, .restricted:
            showCameraPermissionRecovery = true
        @unknown default:
            showCameraPermissionRecovery = true
        }
    }

    private var searchAreaDescription: String {
        if locationManager.location != nil { return "Searching around your current location" }
        switch locationManager.authorizationStatus {
        case .denied, .restricted: return "Location is off — search by cafe or neighborhood"
        case .notDetermined: return "Search nearby or type a cafe name"
        default: return "Finding your current location…"
        }
    }

    private var locationActionTitle: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted: return "Settings"
        case .authorizedAlways, .authorizedWhenInUse: return locationManager.location == nil ? "Find me" : "Near me"
        case .notDetermined: return "Near me"
        @unknown default: return "Near me"
        }
    }

    private func initializeLocationIfAvailable() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        locationManager.startUpdatingLocation()
        if let location = locationManager.location { updateSearchRegion(for: location) }
    }

    private func useCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestCurrentLocation()
            if let location = locationManager.location { updateSearchRegion(for: location) }
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        @unknown default:
            break
        }
    }

    private func updateSearchRegion(for location: CLLocation) {
        cafeSearchRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        if !searchText.isEmpty { searchService.search(query: searchText, region: cafeSearchRegion) }
    }

    private func optionalText(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = $0 }
        )
    }

    private func optionalDouble(_ keyPath: WritableKeyPath<BrewDetails, Double?>) -> Binding<String> {
        Binding(
            get: {
                guard let value = draft.brewDetails[keyPath: keyPath] else { return "" }
                return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            },
            set: { draft.brewDetails[keyPath: keyPath] = Double($0.replacingOccurrences(of: ",", with: ".")) }
        )
    }

    private func optionalInt(_ keyPath: WritableKeyPath<BrewDetails, Int?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath].map(String.init) ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = Int($0) }
        )
    }

    private var servingVolumeBinding: Binding<String> {
        Binding(
            get: {
                guard let milliliters = draft.brewDetails.servingVolumeMilliliters else { return "" }
                let value = servingVolumeUnit.displayValue(fromMilliliters: milliliters)
                return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            },
            set: { value in
                guard let number = Double(value.replacingOccurrences(of: ",", with: ".")), number > 0 else {
                    draft.brewDetails.servingVolumeMilliliters = nil
                    return
                }
                draft.brewDetails.servingVolumeMilliliters = servingVolumeUnit.milliliters(fromDisplayValue: number)
            }
        )
    }

    private var espressoShotCountBinding: Binding<Int?> {
        Binding(
            get: { draft.brewDetails.espressoShotCount },
            set: { draft.brewDetails.espressoShotCount = $0 }
        )
    }

    private func arrayBinding(_ keyPath: WritableKeyPath<SipDraft, [String]>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].joined(separator: ", ") },
            set: { value in
                draft[keyPath: keyPath] = value
                    .split(separator: ",")
                    .compactMap { String($0).remoteTrimmedNonEmpty }
            }
        )
    }

    private func recipeStepBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { draft.brewDetails.steps?.first(where: { $0.id == id })?.instruction ?? "" },
            set: { value in
                guard let index = draft.brewDetails.steps?.firstIndex(where: { $0.id == id }) else { return }
                draft.brewDetails.steps?[index].instruction = value
            }
        )
    }
}

private struct SipCompletionSummary {
    let drinkName: String
    let locationName: String
    let context: JournalEntryContext
    let score: Double
    let visibility: VisitVisibility
    let usedTastingLens: Bool
    let hasPhoto: Bool
    let hasThought: Bool
    let hasPrivateNote: Bool
    let hasBrewDetails: Bool
    let isCafeSession: Bool
    let cafeRating: Double?
    let nextMove: CafeNextMoveKind

    init(
        drinkName: String,
        locationName: String,
        context: JournalEntryContext,
        score: Double,
        visibility: VisitVisibility,
        usedTastingLens: Bool,
        hasPhoto: Bool,
        hasThought: Bool,
        hasPrivateNote: Bool,
        hasBrewDetails: Bool,
        isCafeSession: Bool,
        cafeRating: Double?,
        nextMove: CafeNextMoveKind
    ) {
        self.drinkName = drinkName
        self.locationName = locationName
        self.context = context
        self.score = score
        self.visibility = visibility
        self.usedTastingLens = usedTastingLens
        self.hasPhoto = hasPhoto
        self.hasThought = hasThought
        self.hasPrivateNote = hasPrivateNote
        self.hasBrewDetails = hasBrewDetails
        self.isCafeSession = isCafeSession
        self.cafeRating = cafeRating
        self.nextMove = nextMove
    }

    init(snapshot: SipCompletionSnapshot) {
        self.init(
            drinkName: snapshot.drinkName,
            locationName: snapshot.locationName,
            context: snapshot.context,
            score: snapshot.score,
            visibility: snapshot.visibility,
            usedTastingLens: snapshot.usedTastingLens,
            hasPhoto: snapshot.hasPhoto,
            hasThought: snapshot.hasThought,
            hasPrivateNote: snapshot.hasPrivateNote,
            hasBrewDetails: snapshot.hasBrewDetails,
            isCafeSession: snapshot.isCafeSession,
            cafeRating: snapshot.cafeRating,
            nextMove: snapshot.nextMove
        )
    }

    var snapshot: SipCompletionSnapshot {
        SipCompletionSnapshot(
            drinkName: drinkName,
            locationName: locationName,
            context: context,
            score: score,
            visibility: visibility,
            usedTastingLens: usedTastingLens,
            hasPhoto: hasPhoto,
            hasThought: hasThought,
            hasPrivateNote: hasPrivateNote,
            hasBrewDetails: hasBrewDetails,
            isCafeSession: isCafeSession,
            cafeRating: cafeRating,
            nextMove: nextMove
        )
    }

    var detailHighlights: [String] {
        [
            hasPhoto ? "photo" : nil,
            usedTastingLens ? "tasting lens" : nil,
            hasThought ? "public thought" : nil,
            hasPrivateNote ? "private note" : nil,
            hasBrewDetails ? "brew details" : nil
        ].compactMap { $0 }
    }

    var isDetailedMemory: Bool { !detailHighlights.isEmpty }

    var completionMessage: String {
        if detailHighlights.isEmpty {
            return "Your rating is saved in Journal and ready whenever you want to add more."
        }
        return "This memory reflects the details you added. Everything is waiting in Journal."
    }

    var contextIcon: String { context.systemImage }

    var contextLabel: String {
        switch context {
        case .cafe: return "Cafe"
        case .home: return "Brewed at"
        case .elsewhere: return "Setting"
        case .recipe: return "Recipe"
        }
    }

    var visibilityIcon: String {
        switch visibility {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .everyone: return "globe.americas.fill"
        }
    }
}

private struct SipPhotoOrganizer: View {
    @Binding var images: [UIImage]
    @Binding var posterPhotoIndex: Int
    @Binding var localPhotoNames: [String]
    @Environment(\.dismiss) private var dismiss

    private var safePosterIndex: Int {
        min(max(posterPhotoIndex, 0), max(images.count - 1, 0))
    }

    private var coverImage: UIImage? {
        guard images.indices.contains(safePosterIndex) else { return nil }
        return images[safePosterIndex]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let cover = coverImage {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Label("Feed cover", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.foamWhite)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.espressoBrown.opacity(0.82))
                                    .clipShape(Capsule())
                                    .padding(10)
                            }
                    }
                } footer: {
                    Text("The cover appears first in Feed and Journal. Drag the rows to change the swipe order.")
                }

                Section("Photo order") {
                    ForEach(images.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Photo \(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                                Text(index == safePosterIndex ? "Cover photo" : "Swipe position \(index + 1)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondaryText)
                            }

                            Spacer()

                            Button {
                                posterPhotoIndex = index
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: index == safePosterIndex ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.mugshotSage)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(index == safePosterIndex ? "Current cover photo" : "Make photo \(index + 1) the cover")
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: movePhotos)
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Organize photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func movePhotos(from source: IndexSet, to destination: Int) {
        let previousCoverImage = coverImage
        images.move(fromOffsets: source, toOffset: destination)
        if localPhotoNames.count == images.count {
            localPhotoNames.move(fromOffsets: source, toOffset: destination)
        } else {
            // The draft store will create a fresh ordered set on dismiss.
            localPhotoNames = []
        }
        if let previousCoverImage,
           let updatedIndex = images.firstIndex(where: { $0 === previousCoverImage }) {
            posterPhotoIndex = updatedIndex
        } else {
            posterPhotoIndex = min(safePosterIndex, max(images.count - 1, 0))
        }
    }
}

private struct SipComposerCard<Content: View>: View {
    let step: String?
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(step: String?, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                if let step {
                    Text(step)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 30, height: 30)
                        .background(Color.mugshotMint.opacity(0.35))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 12, x: 0, y: 5)
    }
}

struct HalfStepStarRating: View {
    @Binding var value: Double
    let label: String
    @AppStorage("MugshotSettings.haptics.v1") private var ratingHaptics = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                GeometryReader { proxy in
                    Image(systemName: symbol(for: index))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(value >= Double(index) - 0.5 ? .mugshotSage : .espressoBrown.opacity(0.18))
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { gesture in
                                    value = Self.ratingValue(
                                        starIndex: index,
                                        tapX: gesture.location.x,
                                        starWidth: proxy.size.width
                                    )
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 42)
        .sensoryFeedback(.selection, trigger: value) { _, _ in ratingHaptics }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value > 0 ? "\(String(format: "%.1f", value)) out of 5" : "Not rated")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = value <= 0 ? 1 : min(5, value + 0.5)
            case .decrement: value = max(1, value - 0.5)
            @unknown default: break
            }
        }
    }

    private func symbol(for index: Int) -> String {
        let threshold = Double(index)
        if value >= threshold { return "star.fill" }
        if value >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    static func ratingValue(starIndex: Int, tapX: CGFloat, starWidth: CGFloat) -> Double {
        let clampedIndex = min(max(starIndex, 1), 5)
        let isLeadingHalf = tapX < max(starWidth, 1) / 2
        return max(1, Double(clampedIndex) - (isLeadingHalf ? 0.5 : 0))
    }
}

enum SipPeoplePickerMode: String, Identifiable {
    case tag

    var id: String { rawValue }

    var title: String { "Tag people" }

    var searchPlaceholder: String { "Search Mugshot accounts" }
}

struct SipCompanionPicker: View {
    let mode: SipPeoplePickerMode
    let onSave: ([SipCompanion]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [SipCompanion]
    @State private var suggestions: [SipCompanionSuggestion] = []
    @State private var friends: [SocialConnection] = []
    @State private var accountMatches: [SipCompanion] = []
    @State private var query = ""
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var errorMessage: String?

    init(
        mode: SipPeoplePickerMode,
        selected: [SipCompanion],
        onSave: @escaping ([SipCompanion]) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        _selected = State(initialValue: selected)
    }

    private var allFriends: [SipCompanion] {
        var result = suggestions.map(\.companion)
        let existing = Set(result.map(\.userID))
        result.append(contentsOf: friends.compactMap { friend in
            guard !existing.contains(friend.userID) else { return nil }
            return SipCompanion(
                userID: friend.userID,
                displayName: friend.displayName,
                username: friend.username,
                avatarURL: friend.avatarURL
            )
        })
        let knownIDs = Set(result.map(\.userID))
        result.append(contentsOf: selected.filter { !knownIDs.contains($0.userID) })
        return result
    }

    private var visiblePeople: [SipCompanion] {
        guard query.remoteTrimmedNonEmpty != nil else {
            return allFriends
        }
        return accountMatches
    }

    private var recommended: [SipCompanion] {
        let learned = suggestions.filter { $0.sharedSipCount > 0 }.map(\.companion)
        return Array((learned.isEmpty ? allFriends : learned).prefix(3))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.mugshotSage)
                        TextField(mode.searchPlaceholder, text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if query.isEmpty, !recommended.isEmpty {
                    Section("Quick add") {
                        ForEach(recommended) { companion in
                            companionRow(companion)
                        }
                    }
                }

                Section(query.isEmpty ? "People you know" : "Matches") {
                    if isLoading || isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(isSearching ? "Searching Mugshot…" : "Opening your people…")
                                .foregroundColor(.secondaryText)
                        }
                    } else if visiblePeople.isEmpty {
                        Text(emptyMessage)
                            .foregroundColor(.secondaryText)
                    } else {
                        ForEach(visiblePeople) { companion in
                            companionRow(companion)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(selected)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .task { await load() }
            .task(id: query) { await searchAccountsIfNeeded() }
        }
    }

    private var emptyMessage: String {
        if query.remoteTrimmedNonEmpty != nil {
            return "No Mugshot accounts match that search."
        }
        return "Search for any Mugshot account to tag them."
    }

    private func companionRow(_ companion: SipCompanion) -> some View {
        let isSelected = selected.contains { $0.userID == companion.userID }
        return Button {
            if isSelected {
                selected.removeAll { $0.userID == companion.userID }
            } else if selected.count < 12 {
                selected.append(companion)
            }
        } label: {
            HStack(spacing: 12) {
                MugshotAvatar(name: companion.displayName, size: 38, imageURL: companion.avatarURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(companion.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("@\(companion.username)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .mugshotSage : .tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            async let loadedFriends = service.connections(kind: "friends")
            friends = try await loadedFriends
            suggestions = (try? await service.tagSuggestions()) ?? []
            errorMessage = nil
        } catch {
            errorMessage = "Mugshot couldn’t open your friends just now."
        }
    }

    @MainActor
    private func searchAccountsIfNeeded() async {
        guard let trimmedQuery = query.remoteTrimmedNonEmpty else {
            accountMatches = []
            isSearching = false
            return
        }

        isSearching = true
        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            try Task.checkCancellation()
            let people = try await SocialDiscoveryService(
                client: try SupabaseClientProvider.shared.client()
            ).searchPeople(query: trimmedQuery)
            try Task.checkCancellation()
            accountMatches = people.compactMap { person in
                guard person.friendshipState != .blocked,
                      person.friendshipState != .self else {
                    return nil
                }
                return SipCompanion(
                    userID: person.id,
                    displayName: person.displayName,
                    username: person.username,
                    avatarURL: person.avatarURL
                )
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            accountMatches = []
            errorMessage = "Mugshot couldn’t search accounts just now."
        }
        isSearching = false
    }
}
