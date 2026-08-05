//
//  RemoteVisitDetailView.swift
//  testMugshot
//

import SwiftUI
import UIKit

private func consumerDetailCaption(_ caption: String) -> String? {
    let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let lowercased = trimmed.lowercased()
    let internalMarkers = [
        "smoke",
        "photo-required",
        "ui pass",
        "polish pass"
    ]

    guard !internalMarkers.contains(where: lowercased.contains) else {
        return nil
    }

    return trimmed
}

struct RemoteVisitDetailView: View {
    let visitId: UUID
    let initialSummary: RemoteVisitSummary
    let currentUserId: UUID?
    @ObservedObject var dataManager: DataManager
    let justPosted: Bool
    let onRepeat: ((RemoteVisitDetail) -> Void)?
    let onComposeDraft: ((SipDraft) -> Void)?
    let presentationMode: SipDetailPresentationMode
    let onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)?

    init(
        visitId: UUID,
        initialSummary: RemoteVisitSummary,
        currentUserId: UUID?,
        dataManager: DataManager,
        justPosted: Bool = false,
        onRepeat: ((RemoteVisitDetail) -> Void)? = nil,
        onComposeDraft: ((SipDraft) -> Void)? = nil,
        presentationMode: SipDetailPresentationMode = .pushed,
        onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    ) {
        self.visitId = visitId
        self.initialSummary = initialSummary
        self.currentUserId = currentUserId
        self.dataManager = dataManager
        self.justPosted = justPosted
        self.onRepeat = onRepeat
        self.onComposeDraft = onComposeDraft
        self.presentationMode = presentationMode
        self.onAuthenticationRequired = onAuthenticationRequired
    }

    @Environment(\.dismiss) private var dismiss
    @State private var detail: RemoteVisitDetail?
    @State private var selectedPhotoIndex = 0
    @State private var photoViewerPresentation: SipDetailPhotoViewerPresentation?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var socialError: String?
    @State private var socialStatus: String?
    @State private var isSavingSocialAction = false
    @State private var commentText = ""
    @State private var replyingTo: RemoteVisitComment?
    @State private var mentionSuggestions: [PeopleSearchResult] = []
    @State private var mentionedUserIDs: Set<UUID> = []
    @State private var reportTarget: SocialSafetyTarget?
    @State private var reportDetailsRequest: SafetyReportDetailsRequest?
    @State private var queuedReportDetailsRequest: SafetyReportDetailsRequest?
    @State private var reportConfirmationRequest: SafetyReportConfirmationRequest?
    @State private var queuedReportConfirmationRequest: SafetyReportConfirmationRequest?
    @State private var failedReportReceipt: SafetyReportReceipt?
    @State private var showBlockConfirmation = false
    @State private var editingComment: RemoteVisitComment?
    @State private var editCommentError: String?
    @State private var commentPendingRemoval: RemoteVisitComment?
    @State private var editSipSeed: SipPostEditSeed?
    @State private var isShowingDrinkInterpretation = false
    @State private var isDeletingVisit = false
    @State private var showDeleteConfirmation = false
    @State private var reactions: [SipReactionRecord] = []
    @State private var isShowingRecommendation = false
    @State private var toolbarProgress: CGFloat = 0
    @State private var showMoreActions = false
    @State private var recipeAdaptationRequest: SipDetailRecipeModel?
    @State private var selectedTaggedProfile: PeopleProfileRoute?
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true
    @FocusState private var isCommentFocused: Bool

    private var displayedSummary: RemoteVisitSummary {
        detail?.summary ?? initialSummary
    }

    private var heroHeight: CGFloat { 500 }

    @ViewBuilder
    var body: some View {
        if presentationMode == .postSave {
            NavigationStack { detailScene }
        } else {
            detailScene
        }
    }

    private var detailScene: some View {
        safetyDialogsScene
    }

    @ViewBuilder
    private var detailContentScene: some View {
        Group {
            if let detail {
                SipDetailScreen(
                    presentation: sharedPresentation(for: detail),
                    selectedPhotoIndex: $selectedPhotoIndex,
                    commentText: $commentText,
                    toolbarProgress: $toolbarProgress,
                    commentFocus: $isCommentFocused,
                    isWorking: isSavingSocialAction || isDeletingVisit,
                    statusMessage: socialError ?? socialStatus,
                    mentionSuggestions: mentionSuggestions.map {
                        SipDetailMentionSuggestion(id: $0.id, username: $0.username)
                    },
                    onAction: perform,
                    onSubmitComment: { Task { await postComment() } },
                    onReply: beginReply,
                    onCommentAction: handleCommentAction,
                    onCancelReply: { replyingTo = nil },
                    onSelectMention: selectMention,
                    onPhotoTap: { index in
                        photoViewerPresentation = SipDetailPhotoViewerPresentation(
                            photos: detail.photoURLs.map(SipDetailPhotoSource.remote),
                            initialIndex: index,
                            drinkName: detail.summary.visit.drinkDisplayName,
                            locationName: detail.summary.locationTitle
                        )
                    },
                    onRecipeAction: performRecipeAction,
                    onTaggedAccount: openTaggedProfile,
                    onRemoveOwnTag: { Task { await removeOwnTag() } }
                )
            } else if isLoading {
                SipDetailLoadingView()
            } else if let loadError {
                SipDetailErrorView(
                    message: loadError,
                    onRetry: { Task { await loadDetail() } },
                    onClose: { dismiss() }
                )
            } else {
                SipDetailLoadingView()
            }
        }
    }

    private var configuredDetailScene: some View {
        detailContentScene
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .mugshotBottomNavHidden()
        .toolbar { detailToolbar }
        .toolbarBackground(Color.creamWhite, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            MugshotAnalytics.shared.capture(
                .screenViewed(
                    .sipDetail,
                    source: justPosted ? .postPublish : .navigation
                )
            )
        }
        .task(id: visitId) { await loadDetail() }
        .task(id: commentText) { await updateMentionSuggestions() }
        .navigationDestination(item: $selectedTaggedProfile) { route in
            PublicProfileView(
                route: route,
                dataManager: dataManager,
                onRelationshipChanged: { await loadDetail() }
            )
        }
    }

    private var editorSheetsScene: some View {
        configuredDetailScene
        .sheet(item: $editSipSeed) { seed in
            EditSipView(seed: seed, onSave: saveVisitEdits)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingDrinkInterpretation) {
            if let currentUserId {
                DrinkInterpretationEditor(
                    visitID: visitId,
                    rawDrinkName: displayedSummary.visit.drinkDisplayName,
                    currentUserID: currentUserId
                )
            }
        }
        .sheet(isPresented: $isShowingRecommendation) {
            RecommendToFriendView(
                kind: recommendationKind,
                targetID: recommendationTargetID,
                title: displayedSummary.visit.drinkDisplayName
            )
        }
        .sheet(item: $recipeAdaptationRequest) { recipe in
            SipRecipeAdaptationSheet(recipe: recipe) { name in
                try await saveRecipeAdaptation(recipe, name: name)
            }
        }
    }

    private var safetySheetsScene: some View {
        editorSheetsScene
        .sheet(item: $reportDetailsRequest, onDismiss: presentQueuedReportStep) { request in
            SafetyReportDetailsSheet(targetLabel: request.target.reportLabel) { details in
                queuedReportConfirmationRequest = SafetyReportConfirmationRequest(
                    target: request.target,
                    reason: .other,
                    details: details
                )
                reportDetailsRequest = nil
            }
        }
        .sheet(item: $editingComment) { comment in
            EditCommentSheet(
                initialText: comment.comment.text,
                isSaving: isSavingSocialAction,
                errorMessage: editCommentError,
                onSave: { text in
                    Task { await updateComment(comment, text: text) }
                }
            )
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            SipDeleteConfirmationSheet(
                isDeleting: isDeletingVisit,
                errorMessage: socialError,
                onDelete: { Task { await deleteVisit() } }
            )
            .presentationDetents([.height(socialError == nil ? 340 : 390)])
            .presentationDragIndicator(.visible)
        }
    }

    private var mediaPresentedScene: some View {
        safetySheetsScene
        .fullScreenCover(item: $photoViewerPresentation) { presentation in
            SipDetailPhotoViewer(presentation: presentation)
        }
    }

    private var safetyDialogsScene: some View {
        mediaPresentedScene
        .confirmationDialog("Sip actions", isPresented: $showMoreActions, titleVisibility: .visible) {
            if let detail {
                ForEach(sharedPresentation(for: detail).capabilities.menuActions) { action in
                    Button(action.title, role: action == .delete ? .destructive : nil) {
                        perform(action)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Why are you reporting this?",
            isPresented: Binding(
                get: { reportTarget != nil },
                set: { if !$0 { reportTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.title) {
                    selectReportReason(reason)
                }
            }
            Button("Cancel", role: .cancel) { reportTarget = nil }
        } message: {
            Text("Choose the concern that best describes what you saw.")
        }
        .onChange(of: reportTarget) { _, target in
            guard target == nil else { return }
            Task { @MainActor in
                await Task.yield()
                presentQueuedReportStep()
            }
        }
        .alert(
            "Report this item?",
            isPresented: Binding(
                get: { reportConfirmationRequest != nil },
                set: { if !$0 { reportConfirmationRequest = nil } }
            ),
            presenting: reportConfirmationRequest
        ) { request in
            Button("Report", role: .destructive) {
                reportConfirmationRequest = nil
                Task {
                    await submitReport(
                        target: request.target,
                        reason: request.reason,
                        details: request.details
                    )
                }
            }
            Button("Cancel", role: .cancel) { reportConfirmationRequest = nil }
        } message: { request in
            Text("Send a \(request.reason.title.lowercased()) report about this \(request.target.reportLabel)?")
        }
        .alert("Block @\(displayedSummary.authorUsername)?", isPresented: $showBlockConfirmation) {
            Button("Block · Keep Recipe Copies", role: .destructive) {
                Task { await blockVisitAuthor(removeSavedRecipeCopies: false) }
            }
            Button("Block · Remove Recipe Copies", role: .destructive) {
                Task { await blockVisitAuthor(removeSavedRecipeCopies: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(SocialSafetyCopy.blockConsequences)
        }
        .alert(
            "Remove this comment?",
            isPresented: Binding(
                get: { commentPendingRemoval != nil },
                set: { if !$0 { commentPendingRemoval = nil } }
            ),
            presenting: commentPendingRemoval
        ) { comment in
            Button("Remove", role: .destructive) {
                Task { await removeComment(comment) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { comment in
            Text(commentRemovalMessage(comment))
        }
        .alert(
            "Report not confirmed",
            isPresented: Binding(
                get: { failedReportReceipt != nil },
                set: { if !$0 { failedReportReceipt = nil } }
            ),
            presenting: failedReportReceipt
        ) { receipt in
            Button("Retry") { Task { await submitPreparedReport(receipt) } }
            Button("Not now", role: .cancel) {}
        } message: { _ in
            Text(SocialSafetyCopy.reportFailed)
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: {
                Image(systemName: presentationMode.dismissIcon)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(presentationMode.dismissLabel)
        }

        ToolbarItem(placement: .principal) {
            SipDetailToolbarTitle(
                drinkName: displayedSummary.visit.drinkDisplayName,
                progress: toolbarProgress
            )
        }

        ToolbarItem(placement: .topBarTrailing) {
            if let detail {
                Menu {
                    ForEach(sharedPresentation(for: detail).capabilities.menuActions) { action in
                        Button(role: action == .delete ? .destructive : nil) {
                            perform(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .disabled(isDeletingVisit)
                .accessibilityLabel("Sip actions")
            }
        }
    }

    private func sharedPresentation(for detail: RemoteVisitDetail) -> SipDetailPresentation {
        SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: currentUserId,
            reactions: reactions,
            isCafeSaved: isCafeFavorite(detail),
            canRecommend: phase4LightweightFriends && canRecommend(detail),
            canRepeat: onRepeat != nil,
            replyingToUsername: replyingTo.map { "@\($0.authorUsername)" }
        )
    }

    private func beginReply(to commentID: UUID) {
        guard !requestAuthenticationIfNeeded(for: .comment) else { return }
        guard let comment = detail?.comments.first(where: { $0.id == commentID }) else { return }
        replyingTo = comment
    }

    private func selectMention(id: UUID) {
        guard let person = mentionSuggestions.first(where: { $0.id == id }) else { return }
        selectMention(person)
    }

    private func perform(_ action: SipDetailAction) {
        guard let detail else { return }
        guard !requestAuthenticationIfNeeded(for: action) else { return }
        socialError = nil
        socialStatus = nil
        switch action {
        case .like:
            Task { await toggleLike() }
        case .comment, .share:
            break
        case .saveCafe:
            setCafeStateFromVisit(detail, isFavorite: !isCafeFavorite(detail), wantToTry: nil)
        case .recommend:
            isShowingRecommendation = true
        case .more:
            showMoreActions = true
        case .edit:
            beginEditing(detail)
        case .correctDrink:
            isShowingDrinkInterpretation = true
        case .repeatSip:
            repeatCurrentSip(detail)
        case .delete:
            showDeleteConfirmation = true
        case .report:
            reportTarget = .visit(visitId)
        case .block:
            showBlockConfirmation = true
        }
    }

    private func performRecipeAction(_ action: SipDetailRecipeAction) {
        guard let detail,
              let recipe = sharedPresentation(for: detail).content.recipe else {
            return
        }
        socialError = nil
        socialStatus = nil
        switch action {
        case .brewAgain:
            guard recipe.canBrewAgain else { return }
            repeatCurrentSip(detail)
        case .saveAndAdapt:
            guard recipe.canSaveAndAdapt,
                  currentUserId != nil else {
                onAuthenticationRequired?(
                    "Save this recipe",
                    "Sign in to keep an attributed private adaptation in Mugshot."
                )
                return
            }
            recipeAdaptationRequest = recipe
        }
    }

    private func openTaggedProfile(_ userID: UUID) {
        guard let tag = detail?.taggedAccounts.first(where: { $0.userID == userID }) else {
            return
        }
        selectedTaggedProfile = PeopleProfileRoute(
            id: tag.userID,
            displayName: tag.personLabel,
            username: tag.username,
            state: tag.userID == currentUserId ? .self : .none
        )
    }

    @MainActor
    private func removeOwnTag() async {
        guard let currentUserId,
              detail?.taggedAccounts.contains(where: { $0.userID == currentUserId }) == true,
              !isSavingSocialAction else {
            return
        }
        isSavingSocialAction = true
        socialError = nil
        socialStatus = nil
        defer { isSavingSocialAction = false }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let removed = try await ActivityService(client: client).removeTag(
                visitID: visitId,
                accountID: currentUserId
            )
            guard removed else {
                socialError = "That tag is no longer available. Refreshing this MugShot will show its latest tags."
                replaceDetailTags(detail?.taggedAccounts.filter { $0.userID != currentUserId } ?? [])
                return
            }

            do {
                detail = try await VisitService(client: client).fetchVisitDetail(
                    visitId: visitId,
                    currentUserId: currentUserId
                )
                socialStatus = "Your tag was removed. This MugShot’s audience did not change."
            } catch {
                replaceDetailTags(detail?.taggedAccounts.filter { $0.userID != currentUserId } ?? [])
                socialStatus = "Your tag was removed. Refresh when you’re online to confirm the latest post details."
            }
        } catch {
            socialError = "Mugshot couldn’t remove your tag. This post and its audience are unchanged—please try again."
        }
    }

    @MainActor
    private func saveRecipeAdaptation(
        _ recipe: SipDetailRecipeModel,
        name: String
    ) async throws {
        guard let currentUserId,
              let sourceVersionID = recipe.recipeVersionID,
              recipe.canSaveAndAdapt,
              let detail else {
            throw SocialDiscoveryServiceError.recipeProjectionUnavailable
        }

        isSavingSocialAction = true
        defer { isSavingSocialAction = false }
        let client = try SupabaseClientProvider.shared.client()
        let savedVersionID = try await SocialDiscoveryService(client: client)
            .saveRecipeAdaptation(
                sourceRecipeVersionID: sourceVersionID,
                name: name
            )

        dataManager.noteJournalMutation()
        guard let onComposeDraft else {
            socialStatus = "Saved a private adaptation with source credit."
            return
        }

        let savedProjection = try? await VisitService(client: client)
            .fetchRecipeProjection(recipeVersionId: savedVersionID)
        guard let savedProjection else {
            socialStatus = "Your private adaptation was saved, but Mugshot couldn’t open its Home draft yet."
            return
        }

        let draft = SipDraft.brewAgain(
            from: detail.summary,
            recipeProjection: savedProjection,
            ownerUserID: currentUserId
        )
        socialStatus = "Saved privately. Opening a Home draft…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onComposeDraft(draft)
        }
    }

    private func handleCommentAction(
        commentID: UUID,
        action: SipDetailCommentAction
    ) {
        guard let comment = detail?.comments.first(where: { $0.id == commentID }) else {
            return
        }
        socialError = nil
        socialStatus = nil
        switch action.id {
        case "edit":
            guard comment.comment.userId == currentUserId else { return }
            editCommentError = nil
            editingComment = comment
        case "remove":
            guard currentUserId == comment.comment.userId
                    || currentUserId == detail?.summary.visit.userId else { return }
            commentPendingRemoval = comment
        case "report":
            guard !requestAuthenticationIfNeeded(for: .report) else { return }
            reportTarget = .comment(commentID)
        default:
            break
        }
    }

    @discardableResult
    private func requestAuthenticationIfNeeded(for action: SipDetailAction) -> Bool {
        guard SipDetailInteractionGate.requiresAuthentication(
            for: action,
            currentUserID: currentUserId
        ) else {
            return false
        }

        let title: String
        let message: String
        switch action {
        case .comment:
            title = "Join the conversation"
            message = "Sign in to comment or reply. You can keep exploring public Mugshots as a guest."
        case .saveCafe:
            title = "Keep this cafe"
            message = "Sign in to sync this cafe with your saved places."
        case .report, .block:
            title = "Help keep Mugshot safe"
            message = "Sign in to report content or block an account."
        default:
            title = "Make this social"
            message = "Sign in to like, recommend, and connect with people on Mugshot."
        }
        if let onAuthenticationRequired {
            onAuthenticationRequired(title, message)
        } else {
            socialError = message
        }
        return true
    }

    @ViewBuilder
    private var content: some View {
        if let detail {
            detailContent(detail)
        } else if isLoading {
            loadingContent
        } else if let loadError {
            errorContent(loadError)
        } else {
            loadingContent
        }
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            SipTopBarButton(systemImage: "xmark") {
                dismiss()
            }
            .accessibilityLabel("Close sip")

            Spacer()

            if let detail,
               isOwnVisit(detail) {
                Menu {
                    Button {
                        beginEditing(detail)
                    } label: {
                        Label("Edit Sip", systemImage: "pencil")
                    }

                    Button {
                        isShowingDrinkInterpretation = true
                    } label: {
                        Label("Correct Drink Details", systemImage: "slider.horizontal.3")
                    }

                    if onRepeat != nil {
                        Button {
                            repeatCurrentSip(detail)
                        } label: {
                            Label(
                                detail.summary.visit.journalContext == .recipe ? "Brew Again" : "Repeat Sip",
                                systemImage: detail.summary.visit.journalContext == .recipe
                                    ? "arrow.clockwise.circle.fill"
                                    : "plus.square.on.square"
                            )
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Sip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.foamWhite.opacity(0.72), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                }
                .disabled(isDeletingVisit)
                .accessibilityLabel("Sip actions")
            } else if detail != nil {
                Menu {
                    Button(role: .destructive) {
                        reportTarget = .visit(visitId)
                    } label: {
                        Label("Report Sip", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) {
                        guard !requestAuthenticationIfNeeded(for: .block) else { return }
                        showBlockConfirmation = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Safety actions")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func repeatCurrentSip(_ detail: RemoteVisitDetail) {
        guard let onRepeat else { return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onRepeat(detail)
        }
    }

    private func detailContent(_ detail: RemoteVisitDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection(detail)

                VStack(alignment: .leading, spacing: 18) {
                    memoryPanel(detail)
                    actionShelf(detail)
                    if phase4LightweightFriends {
                        reactionShelf
                    }
                    SipRatingBreakdownPanel(
                        score: detail.summary.visit.overallScore,
                        ratings: detail.summary.visit.ratings,
                        orderedRatings: detail.summary.visit.orderedRatingScores,
                        title: "Flavor map",
                        subtitle: isOwnVisit(detail) ? "Your saved taste breakdown" : "\(detail.summary.authorDisplayName)'s taste breakdown"
                    )
                    SipStructuredEntryDetailsPanel(
                        context: detail.summary.visit.journalContext,
                        brewMethod: detail.recipeProjection?.brewMethod
                            ?? (detail.summary.visit.recipeVersionID == nil
                                ? detail.summary.visit.brewMethod
                                : nil),
                        equipment: detail.recipeProjection?.equipment
                            ?? (detail.summary.visit.recipeVersionID == nil
                                ? detail.summary.visit.equipment
                                : nil),
                        details: detail.recipeProjection?.resolvedBrewDetails
                            ?? (detail.summary.visit.recipeVersionID == nil
                                ? detail.summary.visit.structuredBrewDetails
                                : .empty)
                    )
                    ownerNotesSection(detail)
                    commentsSection(detail)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .background(Color.clear)
    }

    private func heroSection(_ detail: RemoteVisitDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            remotePhotoPager(detail)

            LinearGradient(
                colors: [
                    .black.opacity(0.02),
                    .black.opacity(0.18),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            SipMemoryHeroOverlay(
                authorTitle: isOwnVisit(detail) ? "Your sip" : detail.summary.authorDisplayName,
                avatarName: detail.summary.authorDisplayName,
                username: "@\(detail.summary.authorUsername)",
                timestamp: SipDetailFormat.relative(detail.summary.visit.createdAtDate),
                drinkName: detail.summary.visit.drinkDisplayName,
                locationTitle: detail.summary.locationTitle,
                locationSubtitle: detail.summary.locationSubtitle,
                score: detail.summary.visit.overallScore,
                visibilityLabel: audienceLabel(for: detail),
                isOwnSip: isOwnVisit(detail)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(detail.summary.visit.drinkDisplayName) at \(detail.summary.locationTitle), rated \(String(format: "%.1f", detail.summary.visit.overallScore))")
    }

    @ViewBuilder
    private func remotePhotoPager(_ detail: RemoteVisitDetail) -> some View {
        if detail.photoURLs.isEmpty {
            LinearGradient(
                colors: [
                    Color.darkRoast,
                    Color.roastBrown,
                    Color.mugshotSage.opacity(0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .overlay {
                    MugsyModelView(
                        configuration: MugsySceneResolver.scene(
                            for: detail.summary.usesMugsyPhotoFallback ? .missedSipPhoto : .communitySip,
                            stableID: detail.summary.id.uuidString
                        ).configuration
                    )
                        .frame(width: 172, height: 172)
                        .offset(y: -44)
                        .accessibilityHidden(true)
                }
        } else {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(detail.photoURLs.enumerated()), id: \.offset) { index, urlString in
                    RemotePhotoImageView(
                        urlString: urlString,
                        placeholderSystemName: "photo.on.rectangle"
                    )
                    .tag(index)
                    .overlay(alignment: .topTrailing) {
                        if detail.photoURLs.count > 1 {
                            SipPhotoCountBadge(
                                current: selectedPhotoIndex + 1,
                                total: detail.photoURLs.count
                            )
                            .padding(.top, 64)
                            .padding(.trailing, 18)
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: detail.photoURLs.count > 1 ? .automatic : .never))
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    photoViewerPresentation = SipDetailPhotoViewerPresentation(
                        photos: detail.photoURLs.map(SipDetailPhotoSource.remote),
                        initialIndex: selectedPhotoIndex,
                        drinkName: detail.summary.visit.drinkDisplayName,
                        locationName: detail.summary.locationTitle
                    )
                }
            )
            .accessibilityAction(named: "Open photo full screen") {
                photoViewerPresentation = SipDetailPhotoViewerPresentation(
                    photos: detail.photoURLs.map(SipDetailPhotoSource.remote),
                    initialIndex: selectedPhotoIndex,
                    drinkName: detail.summary.visit.drinkDisplayName,
                    locationName: detail.summary.locationTitle
                )
            }
        }
    }

    private func memoryPanel(_ detail: RemoteVisitDetail) -> some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    MugshotAvatar(name: detail.summary.authorDisplayName, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            isOwnVisit(detail)
                                ? (justPosted ? "Saved to your journal" : "Your journal entry")
                                : "Posted by \(detail.summary.authorDisplayName)"
                        )
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)

                        Text(SipDetailFormat.timestamp(detail.summary.visit.createdAtDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }

                if let caption = consumerDetailCaption(detail.summary.visit.caption) {
                    Text(caption)
                        .font(.system(size: 17))
                        .foregroundColor(.espressoBrown.opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(isOwnVisit(detail) ? "No public tasting note yet." : "No tasting note was shared with this sip.")
                        .font(.system(size: 15))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SipTagGrid(tags: tags(for: detail))
            }
        }
    }

    @ViewBuilder
    private func ownerNotesSection(_ detail: RemoteVisitDetail) -> some View {
        if isOwnVisit(detail), detail.v3Reflection == nil,
           let notes = detail.privateNote?.remoteTrimmedNonEmpty {
            SipPrivateNotePanel(text: notes)
        }
    }

    private func actionShelf(_ detail: RemoteVisitDetail) -> some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Sip actions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SipActionButton(
                        title: detail.currentUserHasLiked ? "Liked" : "Like",
                        value: "\(detail.likeCount)",
                        systemImage: detail.currentUserHasLiked ? "heart.fill" : "heart",
                        isActive: detail.currentUserHasLiked,
                        isEnabled: currentUserId != nil && !isSavingSocialAction
                    ) {
                        Task {
                            await toggleLike()
                        }
                    }

                        SipActionButton(
                        title: "Comment",
                        value: "\(detail.commentCount)",
                        systemImage: "bubble.right",
                        isActive: isCommentFocused,
                        isEnabled: currentUserId != nil
                    ) {
                        isCommentFocused = true
                    }

                        if detail.summary.cafe != nil {
                            SipActionButton(
                            title: isCafeFavorite(detail) ? "Saved" : "Save",
                            value: nil,
                            systemImage: isCafeFavorite(detail) ? "bookmark.fill" : "bookmark",
                            isActive: isCafeFavorite(detail),
                            isEnabled: currentUserId != nil
                        ) {
                            setCafeStateFromVisit(
                                detail,
                                isFavorite: !isCafeFavorite(detail),
                                wantToTry: nil
                            )
                        }

                        }

                        SipShareButton(
                        payload: SipShareCardPayload(
                            visitID: detail.summary.visit.id,
                            visibility: .supabaseValue(detail.summary.visit.visibility),
                            isOwner: currentUserId == detail.summary.visit.userId,
                            isRemote: true,
                            authorName: detail.summary.authorDisplayName,
                            drinkName: detail.summary.visit.drinkDisplayName,
                            cafeName: detail.summary.locationTitle,
                            rating: detail.summary.visit.overallScore,
                            date: detail.summary.visit.createdAtDate,
                            publicCaption: detail.summary.visit.caption.remoteTrimmedNonEmpty,
                            remotePhotoURL: detail.summary.visit.posterPhotoURL,
                            localPhotoPath: nil
                        )
                    )

                        if phase4LightweightFriends,
                           currentUserId != nil,
                           canRecommend(detail) {
                            SipActionButton(
                            title: "Recommend",
                            value: nil,
                            systemImage: "paperplane",
                            isActive: false,
                            isEnabled: !isSavingSocialAction
                            ) {
                                isShowingRecommendation = true
                            }
                        }
                    }
                }

                if let socialError {
                    Text(socialError)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var recommendationKind: TrustedRecommendationKind {
        displayedSummary.visit.recipeVersionID == nil ? .visit : .recipe
    }

    private var recommendationTargetID: UUID {
        displayedSummary.visit.recipeVersionID ?? visitId
    }

    private func canRecommend(_ detail: RemoteVisitDetail) -> Bool {
        if detail.summary.visit.recipeVersionID != nil && isOwnVisit(detail) {
            return true
        }
        return detail.summary.visit.visibility != VisitVisibility.private.rawValue
    }

    private var reactionShelf: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("What stood out?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(reactionExplanation)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SipReaction.allCases) { reaction in
                            let count = reactions.filter { $0.reaction == reaction }.count
                            let isSelected = reactions.contains {
                                $0.reaction == reaction && $0.userID == currentUserId
                            }
                            Button {
                                Task { await toggleReaction(reaction) }
                            } label: {
                                Label(
                                    count > 0 ? "\(reaction.title) \(count)" : reaction.title,
                                    systemImage: reaction.systemImage
                                )
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isSelected ? .foamWhite : .espressoBrown)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 40)
                                .background(isSelected ? Color.mugshotSage : Color.sandBeige.opacity(0.52))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(currentUserId == nil || isOwnDisplayedVisit || isSavingSocialAction)
                            .accessibilityLabel("\(reaction.title), \(count) reactions")
                        }
                    }
                }
            }
        }
    }

    private var isOwnDisplayedVisit: Bool {
        displayedSummary.visit.userId == currentUserId
    }

    private var reactionExplanation: String {
        if isOwnDisplayedVisit {
            return "These are quick reactions friends left on your sip. They do not change your rating or tasting notes."
        }
        return "Choose the coffee detail that stood out to you in this sip. It is your quick reaction to their post, not part of their rating."
    }

    private func commentsSection(_ detail: RemoteVisitDetail) -> some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Conversation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Spacer()

                    Text("\(detail.commentCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.espressoBrown.opacity(0.66))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.sandBeige.opacity(0.50))
                        .clipShape(Capsule())
                }

                if detail.comments.isEmpty {
                    Text("No comments yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiaryText)
                        .padding(.vertical, 2)
                } else {
                    VStack(spacing: 10) {
                        ForEach(detail.comments) { comment in
                            RemoteCommentRow(
                                comment: comment,
                                onReply: comment.comment.parentCommentId == nil ? {
                                    replyingTo = comment
                                    isCommentFocused = true
                                } : nil,
                                onReport: { reportTarget = .comment(comment.id) }
                            )
                                .padding(.leading, comment.comment.parentCommentId == nil ? 0 : 18)
                        }
                    }
                }

                if currentUserId != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let replyingTo {
                            HStack {
                                Text("Replying to @\(replyingTo.authorUsername)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.mugshotSage)
                                Spacer()
                                Button("Cancel") { self.replyingTo = nil }
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }

                        if !mentionSuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mentionSuggestions) { person in
                                        Button("@\(person.username)") { selectMention(person) }
                                            .font(.system(size: 12, weight: .semibold))
                                            .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }

                        HStack(alignment: .bottom, spacing: 10) {
                            TextField("Add a thought", text: $commentText, axis: .vertical)
                                .lineLimit(1...4)
                                .mugshotFormField()
                                .focused($isCommentFocused)
                                .submitLabel(.send)

                            Button {
                                Task { await postComment() }
                            } label: {
                                Image(systemName: isSavingSocialAction ? "hourglass" : "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(commentText.remoteTrimmedNonEmpty == nil || isSavingSocialAction)
                            .accessibilityLabel("Post comment")
                        }
                    }
                }
            }
        }
        .task(id: commentText) { await updateMentionSuggestions() }
    }

    private var loadingContent: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.sandBeige.opacity(0.62))
                .frame(height: 360)
                .overlay {
                    ProgressView()
                        .tint(.mugshotSage)
                }

            Text(displayedSummary.locationTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.espressoBrown)
                .multilineTextAlignment(.center)

            Text("Loading this sip...")
                .font(.system(size: 13))
                .foregroundColor(.tertiaryText)
        }
        .padding(20)
        .padding(.top, 58)
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.mugshotSage)

            Text("Could not load this sip")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadDetail()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.mugshotSage)
        }
        .padding(22)
        .mugshotGlassSurface(
            radius: 22,
            tint: .foamWhite,
            stroke: Color.foamWhite.opacity(0.62),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6),
            interactive: false
        )
        .padding(24)
        .padding(.top, 90)
    }

    private func isOwnVisit(_ detail: RemoteVisitDetail) -> Bool {
        currentUserId == detail.summary.visit.userId
    }

    private func audienceLabel(for detail: RemoteVisitDetail) -> String {
        if isOwnVisit(detail) {
            return detail.summary.visit.backendVisibilityLabel
        }

        switch detail.summary.visit.backendVisibilityLabel.lowercased() {
        case "friends":
            return "Friend sip"
        case "public":
            return "Public sip"
        default:
            return detail.summary.visit.backendVisibilityLabel
        }
    }

    private func tags(for detail: RemoteVisitDetail) -> [SipTag] {
        var tags: [SipTag] = [
            SipTag(title: detail.summary.visit.backendVisibilityLabel, systemImage: visibilityIcon(for: detail.summary.visit.backendVisibilityLabel), isActive: true),
            SipTag(title: detail.summary.visit.contextDisplayName, systemImage: "cup.and.saucer.fill", isActive: false)
        ]

        if let category = detail.summary.visit.drinkCategoryDisplayName,
           category != detail.summary.visit.drinkDisplayName {
            tags.append(SipTag(title: category, systemImage: "tag.fill", isActive: false))
        }

        let visibleBrewMethod = detail.recipeProjection?.brewMethod
            ?? (detail.summary.visit.recipeVersionID == nil
                ? detail.summary.visit.brewMethod
                : nil)
        if let brewMethod = visibleBrewMethod?.remoteTrimmedNonEmpty {
            tags.append(SipTag(title: brewMethod, systemImage: "drop.fill", isActive: false))
        }

        tags.append(SipTag(title: SipDetailFormat.relative(detail.summary.visit.createdAtDate), systemImage: "clock.fill", isActive: false))

        return tags
    }

    private func visibilityIcon(for label: String) -> String {
        switch label.lowercased() {
        case "private":
            return "lock.fill"
        case "friends", "friend sip":
            return "person.2.fill"
        default:
            return "globe"
        }
    }

    private func cafeState(_ detail: RemoteVisitDetail) -> (isFavorite: Bool, wantToTry: Bool) {
        guard let remoteCafeId = detail.summary.cafe?.id,
              let cafe = dataManager.appData.cafes.first(where: {
                  $0.remoteCafeId == remoteCafeId || $0.id == remoteCafeId
              }) else {
            return (false, false)
        }

        return (cafe.isFavorite, cafe.wantToTry)
    }

    private func isCafeFavorite(_ detail: RemoteVisitDetail) -> Bool {
        cafeState(detail).isFavorite
    }

    private func isCafeWantToTry(_ detail: RemoteVisitDetail) -> Bool {
        cafeState(detail).wantToTry
    }

    private func setCafeStateFromVisit(
        _ detail: RemoteVisitDetail,
        isFavorite: Bool?,
        wantToTry: Bool?
    ) {
        guard let currentUserId else {
            socialError = "Sign in to save cafes."
            return
        }

        guard let remoteCafe = detail.summary.cafe else {
            return
        }

        let existing = cafeState(detail)
        let nextFavorite = isFavorite ?? existing.isFavorite
        let nextWantToTry = wantToTry ?? existing.wantToTry
        let localCafe = dataManager.upsertRemoteCafe(
            remoteCafe,
            isFavorite: nextFavorite,
            wantToTry: nextWantToTry
        )

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = CafeStateService(client: client)
                let summary = try await service.setCafeState(
                    userId: currentUserId,
                    cafe: localCafe,
                    isFavorite: nextFavorite,
                    wantToTry: nextWantToTry
                )
                dataManager.applyRemoteCafeState(summary)
                if existing.isFavorite != nextFavorite {
                    MugshotAnalytics.shared.capture(
                        .cafeStateChanged(
                            state: .favorite,
                            action: nextFavorite ? .added : .removed,
                            surface: .remoteSipDetail
                        )
                    )
                }
                if existing.wantToTry != nextWantToTry {
                    MugshotAnalytics.shared.capture(
                        .cafeStateChanged(
                            state: .wantToTry,
                            action: nextWantToTry ? .added : .removed,
                            surface: .remoteSipDetail
                        )
                    )
                }
            } catch {
                socialError = "Could not update this cafe."
            }
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            detail = try await service.fetchVisitDetail(
                visitId: visitId,
                currentUserId: currentUserId
            )
            if phase4LightweightFriends {
                reactions = (try? await SocialDiscoveryService(client: client).reactions(for: visitId)) ?? []
            }
            selectedPhotoIndex = 0
            isLoading = false
        } catch {
            detail = nil
            loadError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoading = false
        }
    }

    @MainActor
    private func toggleReaction(_ reaction: SipReaction) async {
        guard !requestAuthenticationIfNeeded(for: .like) else { return }
        isSavingSocialAction = true
        defer { isSavingSocialAction = false }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            _ = try await service.toggleReaction(reaction, visitID: visitId)
            reactions = try await service.reactions(for: visitId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            socialError = nil
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func toggleLike() async {
        guard let currentUserId,
              let detail else {
            return
        }

        let previousDetail = detail
        let optimisticState = RemoteVisitSocialState(
            likeCount: max(0, detail.likeCount + (detail.currentUserHasLiked ? -1 : 1)),
            commentCount: detail.commentCount,
            currentUserHasLiked: !detail.currentUserHasLiked
        )
        applySocialState(optimisticState)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isSavingSocialAction = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let state = try await service.toggleLike(
                visitId: visitId,
                userId: currentUserId,
                currentlyLiked: detail.currentUserHasLiked
            )
            applySocialState(state)
            MugshotAnalytics.shared.capture(
                .sipLiked(
                    action: state.currentUserHasLiked ? .added : .removed,
                    surface: .remoteSipDetail
                )
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isSavingSocialAction = false
        } catch {
            self.detail = previousDetail
            socialError = MugshotUserFacingError.message(for: error, context: .social)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isSavingSocialAction = false
        }
    }

    @MainActor
    private func postComment() async {
        guard !requestAuthenticationIfNeeded(for: .comment) else { return }
        guard let currentUserId,
              let detail,
              commentText.remoteTrimmedNonEmpty != nil else {
            return
        }

        let text = commentText
        isSavingSocialAction = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            _ = try await service.addComment(
                visitId: visitId,
                userId: currentUserId,
                text: text,
                parentCommentId: replyingTo?.id,
                mentionedUserIds: Array(mentionedUserIDs)
            )
            self.detail = try await service.fetchVisitDetail(
                visitId: visitId,
                currentUserId: currentUserId
            )
            MugshotAnalytics.shared.capture(
                .commentAdded(surface: .remoteSipDetail)
            )
            commentText = ""
            replyingTo = nil
            mentionedUserIDs = []
            mentionSuggestions = []
            isCommentFocused = false
            isSavingSocialAction = false
        } catch {
            self.detail = detail
            socialError = MugshotUserFacingError.message(for: error, context: .social)
            isSavingSocialAction = false
        }
    }

    @MainActor
    private func updateMentionSuggestions() async {
        guard let token = commentText.split(whereSeparator: \.isWhitespace).last,
              token.hasPrefix("@"), token.count > 1 else {
            mentionSuggestions = []
            return
        }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled else { return }
        do {
            mentionSuggestions = try await SocialDiscoveryService(
                client: try SupabaseClientProvider.shared.client()
            ).searchPeople(query: String(token.dropFirst()), limit: 6)
        } catch is CancellationError {
        } catch {
            mentionSuggestions = []
        }
    }

    private func selectMention(_ person: PeopleSearchResult) {
        var tokens = commentText.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.last?.hasPrefix("@") == true { tokens.removeLast() }
        tokens.append("@\(person.username)")
        commentText = tokens.joined(separator: " ") + " "
        mentionedUserIDs.insert(person.id)
        mentionSuggestions = []
        isCommentFocused = true
    }

    private func selectReportReason(_ reason: ReportReason) {
        guard let target = reportTarget else { return }
        if reason == .other {
            queuedReportDetailsRequest = SafetyReportDetailsRequest(target: target)
        } else {
            queuedReportConfirmationRequest = SafetyReportConfirmationRequest(
                target: target,
                reason: reason,
                details: nil
            )
        }
        reportTarget = nil
    }

    @MainActor
    private func presentQueuedReportStep() {
        guard reportTarget == nil,
              reportDetailsRequest == nil,
              reportConfirmationRequest == nil else { return }
        if let request = queuedReportDetailsRequest {
            queuedReportDetailsRequest = nil
            reportDetailsRequest = request
        } else if let request = queuedReportConfirmationRequest {
            queuedReportConfirmationRequest = nil
            reportConfirmationRequest = request
        }
    }

    @MainActor
    private func submitReport(
        target: SocialSafetyTarget,
        reason: ReportReason,
        details: String?
    ) async {
        guard !requestAuthenticationIfNeeded(for: .report) else { return }
        guard let currentUserId else { return }
        reportDetailsRequest = nil
        do {
            let service = SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            )
            let receipt = try service.prepareReport(
                accountID: currentUserId,
                target: target,
                reason: reason,
                details: details
            )
            await submitPreparedReport(receipt)
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func submitPreparedReport(_ receipt: SafetyReportReceipt) async {
        guard currentUserId == receipt.accountID else {
            socialStatus = nil
            socialError = "Sign in to the account that started this report before retrying."
            return
        }
        isSavingSocialAction = true
        socialError = nil
        socialStatus = SocialSafetyCopy.reportPending
        failedReportReceipt = nil

        do {
            let outcome = try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).submit(receipt)
            isSavingSocialAction = false
            switch outcome {
            case .submitted:
                socialStatus = SocialSafetyCopy.reportSubmitted
            case .failed(let failedReceipt):
                socialStatus = SocialSafetyCopy.reportFailed
                failedReportReceipt = failedReceipt
            }
        } catch {
            isSavingSocialAction = false
            socialStatus = nil
            socialError = MugshotUserFacingError.message(for: error, context: .social)
            if (error as? SocialSafetyServiceError) != .accountScopeChanged {
                failedReportReceipt = receipt
            }
        }
    }

    @MainActor
    private func blockVisitAuthor(removeSavedRecipeCopies: Bool) async {
        guard !requestAuthenticationIfNeeded(for: .block) else { return }
        guard let expectedAccountID = currentUserId,
              initialSummary.visit.userId != expectedAccountID else { return }
        isSavingSocialAction = true
        defer { isSavingSocialAction = false }
        do {
            _ = try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).block(
                userID: initialSummary.visit.userId,
                expectedAccountID: expectedAccountID,
                removeSavedRecipeCopies: removeSavedRecipeCopies
            )
            dataManager.noteJournalMutation()
            dismiss()
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func updateComment(_ comment: RemoteVisitComment, text: String) async {
        guard comment.comment.userId == currentUserId else { return }
        isSavingSocialAction = true
        editCommentError = nil
        do {
            let service = VisitService(client: try SupabaseClientProvider.shared.client())
            try await service.updateComment(commentID: comment.id, text: text)
            do {
                detail = try await service.fetchVisitDetail(
                    visitId: visitId,
                    currentUserId: currentUserId
                )
                socialError = nil
            } catch {
                applyEditedComment(comment, text: text)
                socialError = "Comment updated, but the conversation couldn’t refresh. Pull to refresh before making another change."
            }
            editingComment = nil
            socialStatus = "Comment updated."
            dataManager.noteJournalMutation()
        } catch {
            editCommentError = MugshotUserFacingError.message(for: error, context: .social)
        }
        isSavingSocialAction = false
    }

    @MainActor
    private func removeComment(_ comment: RemoteVisitComment) async {
        guard currentUserId == comment.comment.userId
                || currentUserId == detail?.summary.visit.userId else { return }
        isSavingSocialAction = true
        socialError = nil
        do {
            let service = VisitService(client: try SupabaseClientProvider.shared.client())
            let reason = currentUserId == comment.comment.userId
                ? "removed_by_author"
                : "removed_by_post_owner"
            try await service.removeComment(commentID: comment.id, reason: reason)
            do {
                detail = try await service.fetchVisitDetail(
                    visitId: visitId,
                    currentUserId: currentUserId
                )
            } catch {
                applyRemovedComment(comment)
                socialError = "Comment removed, but the conversation couldn’t refresh. Pull to refresh before making another change."
            }
            if replyingTo?.id == comment.id {
                replyingTo = nil
            }
            socialStatus = "Comment removed."
            dataManager.noteJournalMutation()
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
        isSavingSocialAction = false
    }

    private func commentRemovalMessage(_ comment: RemoteVisitComment) -> String {
        let ownership = comment.comment.userId == currentUserId
            ? "This removes your comment."
            : "This removes the comment from your post."
        if comment.comment.parentCommentId == nil {
            return "\(ownership) Replies in its thread are removed too."
        }
        return ownership
    }

    private func applyEditedComment(_ comment: RemoteVisitComment, text: String) {
        guard let detail else { return }
        let comments = detail.comments.map { current in
            guard current.id == comment.id else { return current }
            return RemoteVisitComment(
                comment: SupabaseVisitCommentRow(
                    id: current.comment.id,
                    userId: current.comment.userId,
                    visitId: current.comment.visitId,
                    text: text,
                    createdAt: current.comment.createdAt,
                    parentCommentId: current.comment.parentCommentId
                ),
                author: current.author
            )
        }
        replaceDetailComments(comments)
    }

    private func applyRemovedComment(_ comment: RemoteVisitComment) {
        guard let detail else { return }
        replaceDetailComments(detail.comments.filter { current in
            current.id != comment.id
                && current.comment.parentCommentId != comment.id
        })
    }

    private func replaceDetailComments(_ comments: [RemoteVisitComment]) {
        guard let detail else { return }
        self.detail = RemoteVisitDetail(
            summary: detail.summary,
            photos: detail.photos,
            comments: comments,
            likeCount: detail.likeCount,
            currentUserHasLiked: detail.currentUserHasLiked,
            privateNote: detail.privateNote,
            sensorySnapshot: detail.sensorySnapshot,
            cafeSessionSummary: detail.cafeSessionSummary,
            v3Reflection: detail.v3Reflection,
            recipeProjection: detail.recipeProjection,
            recipeIdentityProjection: detail.recipeIdentityProjection,
            taggedAccounts: detail.taggedAccounts
        )
    }

    private func replaceDetailTags(_ tags: [RemoteVisitTag]) {
        guard let detail else { return }
        self.detail = RemoteVisitDetail(
            summary: detail.summary,
            photos: detail.photos,
            comments: detail.comments,
            likeCount: detail.likeCount,
            currentUserHasLiked: detail.currentUserHasLiked,
            privateNote: detail.privateNote,
            sensorySnapshot: detail.sensorySnapshot,
            cafeSessionSummary: detail.cafeSessionSummary,
            v3Reflection: detail.v3Reflection,
            recipeProjection: detail.recipeProjection,
            recipeIdentityProjection: detail.recipeIdentityProjection,
            taggedAccounts: tags
        )
    }

    @MainActor
    private func saveVisitEdits(_ draft: SipPostEditDraft) async -> SipDetailEditSaveResult {
        guard let currentUserId, let detail else {
            return .failure("Sign in again to edit this sip.")
        }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let refreshedDetail = try await VisitEditService(client: client).save(
                detail: detail,
                currentUserID: currentUserId,
                draft: draft
            )
            if let refreshedDetail {
                self.detail = refreshedDetail
            } else {
                Task { await loadDetail() }
            }
            selectedPhotoIndex = 0
            dataManager.noteJournalMutation()
            socialStatus = "Your sip was updated."
            return .success
        } catch {
            socialError = error.localizedDescription
            return .failure(
                MugshotUserFacingError.message(for: error, context: .social)
            )
        }
    }

    private func beginEditing(_ detail: RemoteVisitDetail) {
        guard let currentUserId, detail.summary.visit.userId == currentUserId else { return }
        editSipSeed = SipPostEditSeed(detail: detail, currentUserID: currentUserId)
    }

    @MainActor
    private func deleteVisit() async {
        guard let currentUserId else {
            return
        }

        isDeletingVisit = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            try await VisitDeletionService(client: client).deleteVisit(
                visitId: visitId,
                userId: currentUserId
            )
            dataManager.noteJournalMutation()
            isDeletingVisit = false
            dismiss()
        } catch {
            socialError = "Could not delete sip."
            isDeletingVisit = false
        }
    }

    private func applySocialState(_ state: RemoteVisitSocialState) {
        guard let detail else {
            return
        }

        self.detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(
                visit: detail.summary.visit,
                cafe: detail.summary.cafe,
                author: detail.summary.author,
                socialState: state,
                rankingScore: detail.summary.rankingScore,
                recommendationReason: detail.summary.recommendationReason,
                recommendationReasonType: detail.summary.recommendationReasonType,
                sessionSipCount: detail.summary.sessionSipCount,
                cafePulseProjection: detail.summary.cafePulseProjection,
                v3FeedProjection: detail.summary.v3FeedProjection
            ),
            photos: detail.photos,
            comments: detail.comments,
            likeCount: state.likeCount,
            currentUserHasLiked: state.currentUserHasLiked,
            privateNote: detail.privateNote,
            sensorySnapshot: detail.sensorySnapshot,
            cafeSessionSummary: detail.cafeSessionSummary,
            v3Reflection: detail.v3Reflection,
            recipeProjection: detail.recipeProjection,
            recipeIdentityProjection: detail.recipeIdentityProjection,
            taggedAccounts: detail.taggedAccounts
        )
    }
}

private struct SipRecipeAdaptationSheet: View {
    let recipe: SipDetailRecipeModel
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(
        recipe: SipDetailRecipeModel,
        onSave: @escaping (String) async throws -> Void
    ) {
        self.recipe = recipe
        self.onSave = onSave
        _name = State(initialValue: recipe.suggestedAdaptationName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Save & Adapt", systemImage: "square.and.pencil")
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                        Text("Mugshot saves a private snapshot with credit to \(recipe.creatorUsername). Later changes to the source won’t overwrite your copy.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adaptation name")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.tertiaryText)
                        TextField("Name this adaptation", text: $name)
                            .focused($isNameFocused)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(13)
                            .background(Color.creamWhite)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.mugshotLine, lineWidth: 1)
                            }
                            .onChange(of: name) { _, value in
                                guard value.count > 120 else { return }
                                name = String(value.prefix(120))
                            }
                        Text("\(name.count)/120")
                            .font(.caption2)
                            .foregroundStyle(Color.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let errorMessage {
                        MugshotStatusCard(
                            title: "Adaptation not saved",
                            message: errorMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }

                    Button {
                        save()
                    } label: {
                        Label(
                            isSaving ? "Saving…" : "Save Private Adaptation",
                            systemImage: isSaving ? "hourglass" : "lock.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving || name.remoteTrimmedNonEmpty == nil)
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.medium, .large])
        .onAppear { isNameFocused = true }
    }

    private func save() {
        guard let cleanName = name.remoteTrimmedNonEmpty,
              !isSaving else {
            return
        }
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            do {
                try await onSave(cleanName)
                isSaving = false
                dismiss()
            } catch is CancellationError {
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = MugshotUserFacingError.message(for: error, context: .social)
            }
        }
    }
}

private struct DrinkInterpretationEditor: View {
    let visitID: UUID
    let rawDrinkName: String
    let currentUserID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var analysis: RemoteVisitDrinkAnalysis?
    @State private var preparation = DrinkPreparation.unknown.rawValue
    @State private var temperature = DrinkTemperature.hot.rawValue
    @State private var shotCount = 2
    @State private var servingVolume = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(rawDrinkName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Your original drink name stays unchanged. These corrections only improve Mugshot’s private journal data and recaps.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                } header: {
                    Text("Original sip")
                }

                Section("Preparation") {
                    Picker("Style", selection: $preparation) {
                        ForEach(DrinkPreparation.allCases, id: \.rawValue) { option in
                            Text(option.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(option.rawValue)
                        }
                    }
                    Picker("Temperature", selection: $temperature) {
                        Text("Hot").tag(DrinkTemperature.hot.rawValue)
                        Text("Iced").tag(DrinkTemperature.iced.rawValue)
                        Text("Frozen").tag(DrinkTemperature.frozen.rawValue)
                        Text("Cold brew").tag(DrinkTemperature.coldBrew.rawValue)
                    }
                }

                Section("Serving details") {
                    if selectedPreparation.isEspressoBased {
                        Stepper("\(shotCount) espresso \(shotCount == 1 ? "shot" : "shots")", value: $shotCount, in: 1...8)
                    } else {
                        Text("Shot count does not apply to this preparation. Serving size is enough for Mugshot’s recap estimate.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                    TextField("Serving size in mL", text: $servingVolume)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text("Mugshot recalculates estimated recap data from traditional averages. You never enter caffeine milligrams.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Drink details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isLoading)
                }
            }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        do {
            let client = try SupabaseClientProvider.shared.client()
            let loaded = try await TasteGraphService(client: client).fetchDrinkAnalysis(visitID: visitID)
            analysis = loaded
            preparation = loaded?.preparation ?? DrinkPreparation.unknown.rawValue
            temperature = loaded?.temperature ?? DrinkTemperature.hot.rawValue
            shotCount = loaded?.espressoShotCount ?? 2
            if let volume = loaded?.servingVolumeMilliliters {
                servingVolume = volume.rounded() == volume ? String(format: "%.0f", volume) : String(format: "%.1f", volume)
            }
            isLoading = false
        } catch {
            errorMessage = "Mugshot could not load this interpretation. Please try again."
            isLoading = false
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            try await TasteGraphService(client: client).correctDrinkAnalysis(
                visitID: visitID,
                correction: DrinkAnalysisCorrection(
                    canonicalFamily: nil,
                    preparation: preparation,
                    temperature: temperature,
                    espressoShotCount: selectedPreparation.isEspressoBased ? shotCount : nil,
                    servingVolumeMilliliters: Double(servingVolume)
                ),
                userID: currentUserID
            )
            isSaving = false
            dismiss()
        } catch {
            errorMessage = "That correction did not save. Please try again."
            isSaving = false
        }
    }

    private var selectedPreparation: DrinkPreparation {
        DrinkPreparation(rawValue: preparation) ?? .unknown
    }
}

struct RemotePhotoImageView: View {
    let urlString: String?
    let placeholderSystemName: String
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var didFail = false
    @Environment(\.mugshotImageSizeReporter) private var reportImageSize

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
                    .overlay {
                        if !didFail, hasPhotoReference {
                            ProgressView()
                                .tint(.mugshotSage)
                        }
                    }
            }
        }
        .background(Color.sandBeige.opacity(0.72))
        .clipped()
        .task(id: urlString) {
            image = nil
            didFail = false
            guard let urlString = urlString?.remoteTrimmedNonEmpty else { return }
            do {
                let url = try await VisitPhotoAccessService.shared.resolvedURL(for: urlString)
                let loadedImage = try await RemoteImagePipeline.shared.image(for: url)
                image = loadedImage
                reportImageSize?(loadedImage.size)
            } catch is CancellationError {
                return
            } catch {
                didFail = true
            }
        }
    }

    private var hasPhotoReference: Bool {
        urlString?.remoteTrimmedNonEmpty != nil
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.sandBeige.opacity(0.72))
            .overlay(
                Image(systemName: placeholderSystemName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.roastBrown.opacity(0.42))
            )
    }
}

struct RemoteCommentRow: View {
    let comment: RemoteVisitComment
    var onReply: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: comment.authorDisplayName, size: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(comment.authorDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)

                    Text("@\(comment.authorUsername)")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.55))
                        .lineLimit(1)
                }

                Text(comment.comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Text(SipDetailFormat.relative(comment.comment.createdAtDate))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.55))

                HStack(spacing: 14) {
                    if let onReply {
                        Button("Reply", action: onReply)
                    }
                    if let onReport {
                        Button("Report", role: .destructive, action: onReport)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.sandBeige.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
    }
}

struct SipDetailBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.creamWhite,
                Color.sandBeige.opacity(0.52),
                Color.mugshotMint.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SipTopBarButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.foamWhite.opacity(0.72), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct SipMemoryHeroOverlay: View {
    let authorTitle: String
    let avatarName: String
    let username: String
    let timestamp: String
    let drinkName: String
    let locationTitle: String
    let locationSubtitle: String?
    let score: Double
    let visibilityLabel: String
    let isOwnSip: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                MugshotAvatar(name: avatarName, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(authorTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.creamWhite)
                        .lineLimit(1)

                    Text("\(username) · \(timestamp)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.creamWhite.opacity(0.76))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MugshotRatingBadge(score: score, onPhoto: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(drinkName)
                    .mugshotDisplay(size: 42)
                    .foregroundColor(.creamWhite)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Label(locationTitle, systemImage: "mappin.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.creamWhite)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let locationSubtitle {
                        Text(locationSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.creamWhite.opacity(0.74))
                            .lineLimit(2)
                    }
                }
            }

            HStack(spacing: 8) {
                SipMetaChip(
                    title: visibilityLabel,
                    systemImage: isOwnSip ? "person.crop.circle.fill" : "sparkles",
                    isActive: true,
                    onPhoto: true
                )
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 6)
    }
}

struct SipEmptyPhotoBackdrop: View {
    let title: String
    let message: String
    var stableID = "sip-memory"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.darkRoast,
                    Color.roastBrown,
                    Color.mugshotSage.opacity(0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                MugsyModelView(
                    configuration: MugsySceneResolver.scene(
                        for: .sipMemory,
                        stableID: stableID
                    ).configuration
                )
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.creamWhite)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.creamWhite.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 34)
            }
            .padding(.bottom, 80)
        }
    }
}

struct SipPhotoCountBadge: View {
    let current: Int
    let total: Int

    var body: some View {
        Text("\(current)/\(total)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.creamWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.espressoBrown.opacity(0.64))
            .clipShape(Capsule())
            .accessibilityLabel("Photo \(current) of \(total)")
    }
}

struct SipDetailPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.foamWhite.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.foamWhite.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

struct SipTag: Identifiable {
    let title: String
    let systemImage: String
    var isActive = false

    var id: String { "\(title)-\(systemImage)" }
}

struct SipTagGrid: View {
    let tags: [SipTag]

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags) { tag in
                SipMetaChip(
                    title: tag.title,
                    systemImage: tag.systemImage,
                    isActive: tag.isActive
                )
            }
        }
    }
}

struct SipMetaChip: View {
    let title: String
    let systemImage: String
    var isActive = false
    var onPhoto = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundColor(onPhoto ? .creamWhite : .espressoBrown.opacity(0.82))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(stroke, lineWidth: 1))
    }

    private var background: Color {
        if onPhoto {
            return Color.creamWhite.opacity(0.16)
        }
        return isActive ? Color.mugshotMint.opacity(0.38) : Color.sandBeige.opacity(0.52)
    }

    private var stroke: Color {
        if onPhoto {
            return Color.creamWhite.opacity(0.22)
        }
        return isActive ? Color.mugshotSage.opacity(0.38) : Color.clear
    }
}

struct SipRatingBreakdownPanel: View {
    let score: Double
    let ratings: [String: Double]
    var orderedRatings: [SupabaseVisitCategoryScore] = []
    let title: String
    let subtitle: String

    var body: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.espressoBrown)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text("overall")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.espressoBrown.opacity(0.56))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.mugshotMint.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Overall rating \(String(format: "%.1f", score)) out of 5")
                }

                if orderedRatings.isEmpty && ratings.isEmpty {
                    Text("No category scores were saved with this sip.")
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 12) {
                        if !orderedRatings.isEmpty {
                            ForEach(orderedRatings) { rating in
                                SipRatingRow(title: rating.name, value: rating.score)
                            }
                        } else {
                            ForEach(ratings.keys.sorted(), id: \.self) { category in
                                if let rating = ratings[category] {
                                    SipRatingRow(title: category, value: rating)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SipStructuredEntryDetailsPanel: View {
    let context: JournalEntryContext
    let brewMethod: String?
    let equipment: String?
    let details: BrewDetails

    @ViewBuilder
    var body: some View {
        if details.hasStructuredData || brewMethod?.remoteTrimmedNonEmpty != nil || equipment?.remoteTrimmedNonEmpty != nil {
            SipDetailPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(context == .cafe ? "Visit details" : context == .recipe ? "Recipe blueprint" : "Brew details")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Spacer()
                        Image(systemName: context.systemImage)
                            .foregroundColor(.mugshotSage)
                    }

                    if let recipe = details.recipeDisplayName {
                        detailLine("Recipe", recipe)
                    }
                    if let extraction = details.extractionSummary {
                        detailLine("Extraction", extraction)
                    }
                    if let beans = details.beans?.remoteTrimmedNonEmpty {
                        detailLine("Beans", beans)
                    }
                    if let origin = details.beanOrigin?.remoteTrimmedNonEmpty {
                        detailLine("Origin", origin)
                    }
                    if let roast = details.roastLevel?.remoteTrimmedNonEmpty {
                        detailLine("Roast", roast)
                    }
                    if let brewMethod = brewMethod?.remoteTrimmedNonEmpty {
                        detailLine("Method", brewMethod)
                    }
                    if let equipment = equipment?.remoteTrimmedNonEmpty {
                        detailLine("Equipment", equipment)
                    }
                    if let grind = details.grindSetting?.remoteTrimmedNonEmpty {
                        detailLine("Grind", grind)
                    }
                    if let temperature = details.waterTemperatureCelsius {
                        detailLine("Water", String(format: "%.0f°C", temperature))
                    }
                    if let water = details.waterNotes?.remoteTrimmedNonEmpty {
                        detailLine("Water notes", water)
                    }
                    if let additions = details.additions?.remoteTrimmedNonEmpty {
                        detailLine("Additions", additions)
                    }
                    if let order = details.orderNotes?.remoteTrimmedNonEmpty {
                        detailLine("Order", order)
                    }
                    if let companions = details.companions, !companions.isEmpty {
                        detailLine("With", companions.joined(separator: ", "))
                    }
                    if let tags = details.tags, !tags.isEmpty {
                        detailLine("Tags", tags.joined(separator: " · "))
                    }

                    if let steps = details.steps?.filter({ $0.instruction.remoteTrimmedNonEmpty != nil }), !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Steps")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.tertiaryText)
                            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.foamWhite)
                                        .frame(width: 22, height: 22)
                                        .background(Color.mugshotSage)
                                        .clipShape(Circle())
                                    Text(step.instruction)
                                        .font(.system(size: 13))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tertiaryText)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct SipRatingRow: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer()

                Text(String(format: "%.1f", value))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
            }

            ProgressView(value: value, total: 5)
                .tint(.mugshotSage)
                .accessibilityLabel("\(title) rating \(String(format: "%.1f", value)) out of 5")
        }
    }
}

struct SipPrivateNotePanel: View {
    let text: String

    var body: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Private note", systemImage: "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)

                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.espressoBrown.opacity(0.76))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SipActionButton: View {
    let title: String
    let value: String?
    let systemImage: String
    var isActive = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SipActionLabel(
                title: title,
                value: value,
                systemImage: systemImage,
                isActive: isActive,
                isEnabled: isEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let value {
            return "\(title), \(value)"
        }
        return title
    }
}

struct SipShareCardPayload: Equatable {
    let visitID: UUID
    let visibility: VisitVisibility
    let isOwner: Bool
    let isRemote: Bool
    let authorName: String
    let drinkName: String
    let cafeName: String
    let rating: Double
    let date: Date
    let publicCaption: String?
    let remotePhotoURL: String?
    let localPhotoPath: String?

    init(
        visitID: UUID = UUID(),
        visibility: VisitVisibility = .private,
        isOwner: Bool = true,
        isRemote: Bool = false,
        authorName: String,
        drinkName: String,
        cafeName: String,
        rating: Double,
        date: Date,
        publicCaption: String?,
        remotePhotoURL: String?,
        localPhotoPath: String?
    ) {
        self.visitID = visitID
        self.visibility = visibility
        self.isOwner = isOwner
        self.isRemote = isRemote
        self.authorName = authorName
        self.drinkName = drinkName
        self.cafeName = cafeName
        self.rating = rating
        self.date = date
        self.publicCaption = publicCaption
        self.remotePhotoURL = remotePhotoURL
        self.localPhotoPath = localPhotoPath
    }

    var shareText: String {
        "\(authorName) remembered \(drinkName) at \(cafeName) on Mugshot."
    }
}

enum SipShareButtonLayout: Equatable {
    case pill
    case dock
}

struct SipShareButton: View {
    let payload: SipShareCardPayload
    var layout: SipShareButtonLayout = .pill
    @State private var presentation: MugshotDetailSharePresentation?
    @State private var isPreparing = false

    var body: some View {
        Button {
            Task { await prepareShare() }
        } label: {
            if layout == .dock {
                SipDetailDockLabel(
                    action: .share,
                    isActive: false,
                    value: nil
                )
            } else {
                SipActionLabel(
                    title: "Share",
                    value: nil,
                    systemImage: isPreparing ? "hourglass" : "square.and.arrow.up",
                    isActive: false,
                    isEnabled: !isPreparing
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
        .accessibilityLabel("Share sip")
        .sheet(item: $presentation) { presentation in
            MugshotShareHubView(
                summary: presentation.summary,
                isOpeningMugshot: false,
                statusMessage: nil,
                onViewMugshot: {},
                onViewPassport: {},
                onFinish: { self.presentation = nil },
                onStartAnother: nil,
                isPostPublish: false
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @MainActor
    private func prepareShare() async {
        isPreparing = true
        defer { isPreparing = false }
        let photo = await sharePhoto()
        let photos = photo.map { [$0] } ?? []
        presentation = MugshotDetailSharePresentation(
            summary: LogASipV3PassportSummary(
                visitID: payload.visitID,
                visibility: payload.visibility,
                isOwner: payload.isOwner,
                isRemote: payload.isRemote,
                displayName: payload.authorName,
                drinkName: payload.drinkName,
                contextName: payload.cafeName,
                createdAt: payload.date,
                sipScore: payload.rating,
                contextScore: nil,
                mugshotScore: payload.rating,
                identityTitle: "Your Mugshot Passport",
                identityDetail: "This memory is already part of the story your Passport is learning.",
                memoryCount: 0,
                criteria: [],
                evidence: [],
                publicCaption: payload.publicCaption,
                photoImages: photos,
                coverImage: photo
            )
        )
    }

    private func sharePhoto() async -> UIImage? {
        if let localPhotoPath = payload.localPhotoPath {
            return await PhotoCache.shared.image(forKey: localPhotoPath)
        }
        guard let remotePhotoURL = payload.remotePhotoURL,
              let url = try? await VisitPhotoAccessService.shared.resolvedURL(
                for: remotePhotoURL
              ) else {
            return nil
        }
        return try? await RemoteImagePipeline.shared.image(
            for: url,
            maxPixelSize: 2_000
        )
    }
}

private struct MugshotDetailSharePresentation: Identifiable {
    let id = UUID()
    let summary: LogASipV3PassportSummary
}

struct SipActionLabel: View {
    let title: String
    let value: String?
    let systemImage: String
    var isActive = false
    var isEnabled = true

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)

            if let value {
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 12)
        .frame(minWidth: 78, minHeight: 44)
        .background(background)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? Color.mugshotSage.opacity(0.58) : Color.clear, lineWidth: 1.3)
        )
        .opacity(isEnabled ? 1 : 0.48)
    }

    private var foreground: Color {
        isActive ? .espressoBrown : .roastBrown.opacity(0.82)
    }

    private var background: Color {
        isActive ? Color.mugshotMint.opacity(0.38) : Color.sandBeige.opacity(0.48)
    }
}

enum SipDetailFormat {
    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension VisitVisibility {
    static func supabaseValue(_ value: String) -> VisitVisibility {
        switch value.lowercased() {
        case "private":
            return .private
        case "friends":
            return .friends
        default:
            return .everyone
        }
    }
}
