import SwiftUI

/// A private Home attempt rendered by the same post-detail surface as a cafe sip.
/// The workspace remains its source of truth until an optional publication exists.
struct HomeAttemptCanonicalDetailView: View {
    let attemptID: UUID
    var receipt: MugshotSaveReceipt? = nil
    let saveError: String?
    let onShare: () -> Void
    let onMakeAgain: () -> Void
    let onDone: () -> Void
    var onHistory: (() -> Void)? = nil
    var onLogServing: (() -> Void)? = nil
    var onChangeNextBrew: ((HomeBrewPlanChange) -> Void)? = nil
    @State private var originalScope: LocalAccountScope

    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var toolbarProgress: CGFloat = 0
    @State private var viewer: SipDetailPhotoViewerPresentation?
    @State private var assistance: CoffeeAssistancePresentation?
    @State private var editingDraft: HomeAttemptRecord?
    @State private var confirmsDelete = false
    @State private var isDeleting = false
    @State private var deletionError: String?
    @State private var showsRepeatPlan = false
    @FocusState private var commentFocused: Bool

    init(attemptID: UUID, receipt: MugshotSaveReceipt? = nil, saveError: String? = nil,
         onShare: @escaping () -> Void, onMakeAgain: @escaping () -> Void, onDone: @escaping () -> Void,
         onHistory: (() -> Void)? = nil, onLogServing: (() -> Void)? = nil,
         onChangeNextBrew: ((HomeBrewPlanChange) -> Void)? = nil) {
        self.attemptID = attemptID; self.receipt = receipt; self.saveError = saveError
        self.onShare = onShare; self.onMakeAgain = onMakeAgain; self.onDone = onDone
        self.onHistory = onHistory; self.onLogServing = onLogServing
        self.onChangeNextBrew = onChangeNextBrew
        _originalScope = State(initialValue: HomeRecipeWorkspaceStore.shared.scope)
    }

    private var isCurrentOwner: Bool {
        store.scope == originalScope && originalScope == .forUserID(authModel.authenticatedUser?.id)
    }
    private var attempt: HomeAttemptRecord? {
        guard isCurrentOwner else { return nil }
        return store.workspace.attempts.first { $0.id == attemptID }
    }

    private func comparison(for attempt: HomeAttemptRecord) -> HomeAttemptComparison {
        HomeAttemptComparison(attempt, history: store.workspace.attempts,
                           resolveLinked: { store.workspace.version($0)?.content })
    }

    private func repeatPlan(_ comparison: HomeAttemptComparison) {
        guard isCurrentOwner, !isDeleting else { return }
        if onChangeNextBrew != nil && !comparison.changes.isEmpty { showsRepeatPlan = true }
        else { onMakeAgain() }
    }

    var body: some View {
        Group {
            if let attempt {
                let brew = comparison(for: attempt)
                let presentation = SipDetailPresentationAdapter.homeAttempt(
                    attempt,
                    authorName: authModel.profile?.displayName ?? "You",
                    username: authModel.profile?.username ?? "you",
                    resolveLinked: { store.workspace.version($0)?.content }
                )
                SipDetailScreen(
                    presentation: presentation,
                    selectedPhotoIndex: $photoIndex,
                    commentText: $comment,
                    toolbarProgress: $toolbarProgress,
                    commentFocus: $commentFocused,
                    isWorking: isDeleting,
                    statusMessage: saveError ?? store.errorMessage
                        ?? (!attempt.pendingKeptIngredientIDs.isEmpty
                            ? "Sip saved · Recipe change pending"
                            : store.workspace.pendingOperationID == nil ? nil : "Saved here · Sync pending"),
                    mentionSuggestions: [],
                    composerMentionTokens: [],
                    onAction: { action in
                        guard isCurrentOwner, !isDeleting else { return }
                        switch action {
                        case .share: onShare()
                        case .repeatSip: repeatPlan(brew)
                        default: break
                        }
                    },
                    onSubmitComment: {},
                    onReply: { _ in },
                    onCommentAction: { _, _ in },
                    onCancelReply: {},
                    onSelectMention: { _ in },
                    onPhotoTap: { index in
                        guard isCurrentOwner, presentation.content.photos.indices.contains(index) else { return }
                        viewer = SipDetailPhotoViewerPresentation(
                            photos: presentation.content.photos,
                            initialIndex: index,
                            drinkName: presentation.content.drinkName,
                            locationName: attempt.journalLocationName
                        )
                    },
                    onRecipeAction: { _ in },
                    onTaggedAccount: { _ in },
                    onCommentMention: { _ in },
                    onRemoveOwnTag: {},
                    privateHomeBrewReview: HomeBrewReviewPresentation(
                        comparison: brew, versionNumber: attempt.recipe.flatMap { store.workspace.version($0)?.number },
                        onMakeAgain: { repeatPlan(brew) }
                    )
                )
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let receipt {
                        VStack(spacing: 6) {
                            MugshotSaveReceiptView(
                                receipt: receipt,
                                detail: !attempt.pendingKeptIngredientIDs.isEmpty
                                    ? "Saved to Journal · Recipe change needs attention"
                                    : "Saved to Journal"
                            )
                            Button("Share sip", systemImage: "square.and.arrow.up", action: onShare)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mugshotSageText)
                                .frame(minHeight: 44)
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("home.sip.share")
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                .toolbar { detailToolbar(attempt, brew: brew) }
            } else {
                ContentUnavailableView("Sip unavailable", systemImage: "cup.and.saucer")
            }
        }
        .background(Color.creamWhite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.creamWhite, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .mugshotBottomNavHidden()
        .fullScreenCover(item: $viewer) { SipDetailPhotoViewer(presentation: $0) }
        .sheet(item: $editingDraft) { draft in
            NavigationStack {
                HomeQuickLogScreen(store: store, initial: draft, onSaved: { _ in
                    editingDraft = nil
                }, onDiscard: {
                    guard isCurrentOwner else { throw HomeRecipeWorkspaceError.invalid("Your account changed. This draft was left in its original account.") }
                    try store.discardAttemptDraft(id: draft.id, expectedScope: originalScope)
                    editingDraft = nil
                }, onKeep: { editingDraft = nil }, startsAtReflection: true)
            }
        }
        .sheet(item: $assistance) { item in
            CoffeeAssistanceReviewSheet(presentation: item)
        }
        .sheet(isPresented: $showsRepeatPlan) {
            if let attempt {
                HomeBrewRepeatSheet(choices: comparison(for: attempt).changes, onSamePlan: {
                    showsRepeatPlan = false
                    if isCurrentOwner { onMakeAgain() }
                }, onChange: { change in
                    showsRepeatPlan = false
                    if isCurrentOwner { onChangeNextBrew?(change) }
                })
            }
        }
        .sheet(isPresented: $confirmsDelete) {
            SipDeleteConfirmationSheet(isDeleting: isDeleting, errorMessage: deletionError,
                message: "This removes your Home sip. Saved recipes and other servings stay. Unshared photo cleanup finishes after syncing.",
                onDelete: deleteAttempt)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(isDeleting)
        }
        .onChange(of: store.scope) { _, scope in
            if scope != originalScope { editingDraft = nil; viewer = nil; assistance = nil; confirmsDelete = false; showsRepeatPlan = false }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in
            if !isCurrentOwner { editingDraft = nil; viewer = nil; assistance = nil; confirmsDelete = false; showsRepeatPlan = false; onDone() }
        }
    }

    @ToolbarContentBuilder
    private func detailToolbar(_ attempt: HomeAttemptRecord, brew: HomeAttemptComparison) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            SipDetailToolbarTitle(drinkName: attempt.name, progress: toolbarProgress)
        }
        SipDetailActionsToolbarItem(isDisabled: isDeleting || !isCurrentOwner) {
            Button("Edit Sip", systemImage: "pencil") { beginEditing(attempt) }
                .disabled(attempt.publicationStatus == .posting)
                .accessibilityIdentifier("home.sip.edit")
            Button("Make Again", systemImage: "arrow.clockwise") { repeatPlan(brew) }
            Button("Share Sip", systemImage: "square.and.arrow.up", action: onShare)
            if let onHistory { Button("History", systemImage: "clock.arrow.circlepath", action: onHistory) }
            if let ownerID = store.scope.userID, ownerID == authModel.authenticatedUser?.id {
                Button("Explore a Next Experiment", systemImage: "sparkles") {
                    assistance = CoffeeAssistancePresentation(ownerID: ownerID, task: .brewExperiment,
                        query: "Explain one recorded difference or offer one small trial. Use only recorded values and feedback. Plans are not actuals; leave unknowns unknown. Never infer espresso extraction from a flavored drink alone.",
                        evidence: brew.assistanceEvidence(for: attempt),
                        image: nil, allowsPhoto: false)
                }
            }
            if !attempt.pendingKeptIngredientIDs.isEmpty {
                Button("Retry Keeping Recipe Changes", systemImage: "arrow.triangle.2.circlepath") {
                    do {
                        try store.applyKeptIngredientChanges(attemptID: attempt.id)
                        store.errorMessage = nil
                        Task { await store.synchronize() }
                    } catch {
                        store.errorMessage = "Your sip is safe. Recipe change needs attention. \(error.localizedDescription)"
                    }
                }
            }
            if attempt.batchID != nil, attempt.batchSourceAttemptID == nil,
               let onLogServing {
                Button("Log a Serving", systemImage: "cup.and.saucer", action: onLogServing)
            }
            Button("Delete Sip", systemImage: "trash", role: .destructive) {
                deletionError = nil
                confirmsDelete = true
            }
            .accessibilityIdentifier("home.sip.delete")
        }
    }

    private func beginEditing(_ source: HomeAttemptRecord) {
        guard isCurrentOwner, !isDeleting,
              let current = store.workspace.attempts.first(where: { $0.id == source.id }),
              current.publicationStatus != .posting else { return }
        if let existing = store.workspace.attemptDrafts.first(where: { $0.editingAttemptID == current.id }) {
            editingDraft = existing
            return
        }
        var draft = current
        draft.id = UUID()
        draft.editingAttemptID = current.id
        draft.savedAt = nil
        draft.publicationDraftID = nil
        draft.publicationStatus = nil
        draft.resumeAtReflection = true
        do {
            try store.saveAttemptDraft(draft)
            store.errorMessage = nil
            editingDraft = draft
        } catch { store.errorMessage = "This sip could not be opened for editing. Your saved entry is safe. \(error.localizedDescription)" }
    }

    private func deleteAttempt() {
        guard isCurrentOwner, !isDeleting else { return }
        isDeleting = true
        do {
            try store.deleteAttempt(id: attemptID, expectedScope: originalScope)
            confirmsDelete = false; isDeleting = false; onDone()
            Task { if store.scope == originalScope { await store.synchronize() } }
        } catch {
            deletionError = error.localizedDescription; isDeleting = false
        }
    }
}
