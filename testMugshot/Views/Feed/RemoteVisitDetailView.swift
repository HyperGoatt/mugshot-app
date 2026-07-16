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
    let presentationMode: SipDetailPresentationMode

    init(
        visitId: UUID,
        initialSummary: RemoteVisitSummary,
        currentUserId: UUID?,
        dataManager: DataManager,
        justPosted: Bool = false,
        onRepeat: ((RemoteVisitDetail) -> Void)? = nil,
        presentationMode: SipDetailPresentationMode = .pushed
    ) {
        self.visitId = visitId
        self.initialSummary = initialSummary
        self.currentUserId = currentUserId
        self.dataManager = dataManager
        self.justPosted = justPosted
        self.onRepeat = onRepeat
        self.presentationMode = presentationMode
    }

    @Environment(\.dismiss) private var dismiss
    @State private var detail: RemoteVisitDetail?
    @State private var selectedPhotoIndex = 0
    @State private var photoViewerPresentation: RemotePhotoViewerPresentation?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var socialError: String?
    @State private var isSavingSocialAction = false
    @State private var commentText = ""
    @State private var replyingTo: RemoteVisitComment?
    @State private var mentionSuggestions: [PeopleSearchResult] = []
    @State private var mentionedUserIDs: Set<UUID> = []
    @State private var reportTarget: SocialReportTarget?
    @State private var isShowingEditVisit = false
    @State private var isShowingDrinkInterpretation = false
    @State private var isDeletingVisit = false
    @State private var showDeleteConfirmation = false
    @State private var reactions: [SipReactionRecord] = []
    @State private var isShowingRecommendation = false
    @State private var toolbarProgress: CGFloat = 0
    @State private var showMoreActions = false
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
        Group {
            if let detail {
                SipDetailScreen(
                    presentation: sharedPresentation(for: detail),
                    selectedPhotoIndex: $selectedPhotoIndex,
                    commentText: $commentText,
                    toolbarProgress: $toolbarProgress,
                    commentFocus: $isCommentFocused,
                    isWorking: isSavingSocialAction || isDeletingVisit,
                    mentionSuggestions: mentionSuggestions.map {
                        SipDetailMentionSuggestion(id: $0.id, username: $0.username)
                    },
                    onAction: perform,
                    onSubmitComment: { Task { await postComment() } },
                    onReply: beginReply,
                    onCancelReply: { replyingTo = nil },
                    onSelectMention: selectMention,
                    onPhotoTap: { index in
                        photoViewerPresentation = RemotePhotoViewerPresentation(
                            photoURLs: detail.photoURLs,
                            initialIndex: index
                        )
                    }
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .mugshotBottomNavHidden()
        .toolbar { detailToolbar }
        .toolbarBackground(toolbarProgress > 0.82 ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task(id: visitId) { await loadDetail() }
        .task(id: commentText) { await updateMentionSuggestions() }
        .sheet(isPresented: $isShowingEditVisit) {
            if let detail {
                SipDetailEditForm(
                    summary: sharedPresentation(for: detail).content,
                    initialVisibility: VisitVisibility.supabaseValue(detail.summary.visit.visibility),
                    onSave: saveVisitEdits
                )
            }
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
        .sheet(isPresented: $showDeleteConfirmation) {
            SipDeleteConfirmationSheet(
                isDeleting: isDeletingVisit,
                onDelete: { Task { await deleteVisit() } }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $photoViewerPresentation) { presentation in
            RemotePhotoViewer(
                photoURLs: presentation.photoURLs,
                initialIndex: presentation.initialIndex
            )
        }
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
                Button(reason.title, role: .destructive) {
                    Task { await submitReport(reason: reason) }
                }
            }
            Button("Cancel", role: .cancel) { reportTarget = nil }
        } message: {
            Text("Reports are reviewed and do not automatically remove content.")
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
            Text(displayedSummary.visit.drinkDisplayName)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .opacity(toolbarProgress)
                .accessibilityHidden(toolbarProgress < 0.82)
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
        guard let comment = detail?.comments.first(where: { $0.id == commentID }) else { return }
        replyingTo = comment
    }

    private func selectMention(id: UUID) {
        guard let person = mentionSuggestions.first(where: { $0.id == id }) else { return }
        selectMention(person)
    }

    private func perform(_ action: SipDetailAction) {
        guard let detail else { return }
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
            isShowingEditVisit = true
        case .correctDrink:
            isShowingDrinkInterpretation = true
        case .repeatSip:
            repeatCurrentSip(detail)
        case .delete:
            showDeleteConfirmation = true
        case .report:
            reportTarget = .visit(visitId)
        case .block:
            Task { await blockVisitAuthor() }
        }
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
                        isShowingEditVisit = true
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
                        Task { await blockVisitAuthor() }
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
                        brewMethod: detail.summary.visit.brewMethod,
                        equipment: detail.summary.visit.equipment,
                        details: detail.summary.visit.structuredBrewDetails
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
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 76, weight: .semibold))
                        .foregroundColor(.creamWhite.opacity(0.12))
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
                    photoViewerPresentation = RemotePhotoViewerPresentation(
                        photoURLs: detail.photoURLs,
                        initialIndex: selectedPhotoIndex
                    )
                }
            )
            .accessibilityAction(named: "Open photo full screen") {
                photoViewerPresentation = RemotePhotoViewerPresentation(
                    photoURLs: detail.photoURLs,
                    initialIndex: selectedPhotoIndex
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
        if isOwnVisit(detail),
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

        if let brewMethod = detail.summary.visit.brewMethod?.remoteTrimmedNonEmpty {
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
        guard currentUserId != nil else { return }
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

    @MainActor
    private func submitReport(reason: ReportReason) async {
        guard let target = reportTarget else { return }
        defer { reportTarget = nil }
        do {
            let service = SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
            switch target {
            case .visit(let id):
                try await service.report(reason: reason, details: nil, visitID: id)
            case .comment(let id):
                try await service.report(reason: reason, details: nil, commentID: id)
            }
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func blockVisitAuthor() async {
        guard initialSummary.visit.userId != currentUserId else { return }
        do {
            try await SocialDiscoveryService(client: try SupabaseClientProvider.shared.client())
                .block(userID: initialSummary.visit.userId)
            dismiss()
        } catch {
            socialError = MugshotUserFacingError.message(for: error, context: .social)
        }
    }

    @MainActor
    private func saveVisitEdits(
        caption: String,
        notes: String,
        visibility: VisitVisibility
    ) async -> Bool {
        guard let currentUserId else {
            return false
        }

        do {
            let update = try SupabaseVisitUpdate.make(
                caption: caption,
                visibility: visibility
            )
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let summary = try await service.updateVisit(
                visitId: visitId,
                userId: currentUserId,
                update: update
            )
            try await service.updatePrivateNote(
                visitId: visitId,
                userId: currentUserId,
                note: notes
            )
            self.detail = try await service.fetchVisitDetail(
                visitId: summary.id,
                currentUserId: currentUserId
            )
            dataManager.noteJournalMutation()
            return true
        } catch {
            socialError = error.localizedDescription
            return false
        }
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
                recommendationReasonType: detail.summary.recommendationReasonType
            ),
            photos: detail.photos,
            comments: detail.comments,
            likeCount: state.likeCount,
            currentUserHasLiked: state.currentUserHasLiked,
            privateNote: detail.privateNote
        )
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

private struct RemotePhotoViewerPresentation: Identifiable {
    let id = UUID()
    let photoURLs: [String]
    let initialIndex: Int
}

private struct RemotePhotoViewer: View {
    let photoURLs: [String]
    @State private var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(photoURLs: [String], initialIndex: Int) {
        self.photoURLs = photoURLs
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(photoURLs.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, urlString in
                    RemotePhotoImageView(
                        urlString: urlString,
                        placeholderSystemName: "photo.on.rectangle",
                        contentMode: .fit
                    )
                    .tag(index)
                    .padding(.vertical, 56)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photoURLs.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.52), in: Circle())
                    }
                    .accessibilityLabel("Close photo viewer")
                }
                Spacer()
                if photoURLs.count > 1 {
                    Text("\(selectedIndex + 1) of \(photoURLs.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.56), in: Capsule())
                        .accessibilityLabel("Photo \(selectedIndex + 1) of \(photoURLs.count)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .statusBarHidden(true)
    }
}

struct RemotePhotoImageView: View {
    let urlString: String?
    let placeholderSystemName: String
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
                    .overlay {
                        if !didFail, url != nil {
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
            guard let url else { return }
            do {
                image = try await RemoteImagePipeline.shared.image(for: url)
            } catch is CancellationError {
                return
            } catch {
                didFail = true
            }
        }
    }

    private var url: URL? {
        urlString.flatMap(URL.init(string:))
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

private enum SocialReportTarget: Equatable {
    case visit(UUID)
    case comment(UUID)
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

struct EditRemoteVisitView: View {
    let detail: RemoteVisitDetail
    let currentUserId: UUID
    let onSave: (String, String, VisitVisibility) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    @State private var notes: String
    @State private var visibility: VisitVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showTextOnlyConfirmation = false
    @State private var confirmedTextOnlyEveryone = false

    init(
        detail: RemoteVisitDetail,
        currentUserId: UUID,
        onSave: @escaping (String, String, VisitVisibility) async -> Bool
    ) {
        self.detail = detail
        self.currentUserId = currentUserId
        self.onSave = onSave
        _caption = State(initialValue: detail.summary.visit.caption)
        _notes = State(initialValue: detail.privateNote ?? "")
        _visibility = State(initialValue: VisitVisibility.supabaseValue(detail.summary.visit.visibility))
    }

    private var canSave: Bool {
        !isSaving && !(
            visibility == .everyone &&
            detail.photoURLs.isEmpty &&
            caption.remoteTrimmedNonEmpty == nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MugshotSectionTitle(
                        title: "Edit sip",
                        subtitle: "Update the public note, private note, and audience."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        MugshotSectionTitle(title: "Public note")

                        TextField("What should people remember?", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .remoteVisitEditField()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MugshotSectionTitle(title: "Private note")

                        TextField("Only visible to you", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .remoteVisitEditField()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        MugshotSectionTitle(title: "Audience")

                        MugshotSegmentedControl(
                            options: [VisitVisibility.private, .friends, .everyone],
                            selection: $visibility,
                            title: { $0.rawValue },
                            icon: { visibilityIcon(for: $0.rawValue) }
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        if visibility == .everyone,
                           detail.photoURLs.isEmpty,
                           !confirmedTextOnlyEveryone {
                            showTextOnlyConfirmation = true
                        } else {
                            Task { await save() }
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.foamWhite)
                            }
                            Text("Save sip")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.62)
                }
                .padding(DesignSystem.largePadding)
                .cardStyle(radius: DesignSystem.Radius.heroCard)
                .padding()
            }
            .background(Color.creamWhite)
            .navigationTitle("Edit sip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Publish without a photo?", isPresented: $showTextOnlyConfirmation) {
                Button("Publish Text Only") {
                    confirmedTextOnlyEveryone = true
                    Task { await save() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Confirm that you want this tasting note to be visible to Everyone without a photo.")
            }
            .onChange(of: visibility) { _, _ in confirmedTextOnlyEveryone = false }
            .onChange(of: caption) { _, _ in confirmedTextOnlyEveryone = false }
        }
    }

    @MainActor
    private func save() async {
        guard canSave else {
            return
        }

        isSaving = true
        errorMessage = nil
        let didSave = await onSave(caption, notes, visibility)
        isSaving = false

        if didSave {
            dismiss()
        } else {
            errorMessage = "Could not save sip edits."
        }
    }

    private func visibilityIcon(for label: String) -> String {
        switch label.lowercased() {
        case "private":
            return "lock.fill"
        case "friends":
            return "person.2.fill"
        default:
            return "globe"
        }
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
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.creamWhite.opacity(0.54))

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
    let authorName: String
    let drinkName: String
    let cafeName: String
    let rating: Double
    let date: Date
    let publicCaption: String?
    let remotePhotoURL: String?
    let localPhotoPath: String?

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
    @State private var presentation: RichSharePresentation?
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
            ActivityShareView(items: presentation.items)
        }
    }

    @MainActor
    private func prepareShare() async {
        isPreparing = true
        defer { isPreparing = false }
        let photo = await sharePhoto()
        let artwork = MugshotSipShareCard(payload: payload, photo: photo)
            .frame(width: 540, height: 675)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 2
        var items: [Any] = [payload.shareText]
        if let image = renderer.uiImage {
            items.insert(image, at: 0)
        }
        presentation = RichSharePresentation(items: items)
    }

    private func sharePhoto() async -> UIImage? {
        if let localPhotoPath = payload.localPhotoPath {
            return await PhotoCache.shared.image(forKey: localPhotoPath)
        }
        guard let remotePhotoURL = payload.remotePhotoURL,
              let url = URL(string: remotePhotoURL),
              let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct MugshotSipShareCard: View {
    let payload: SipShareCardPayload
    let photo: UIImage?

    var body: some View {
        ZStack {
            Color.creamWhite

            VStack(spacing: 0) {
                photoSurface
                    .frame(height: 356)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("MUGSHOT")
                            .font(.system(size: 13, weight: .black))
                            .tracking(2.2)
                            .foregroundColor(.mugshotSage)
                        Spacer()
                        Text(payload.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondaryText)
                    }

                    Text(payload.drinkName)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .center, spacing: 12) {
                        Label(payload.cafeName, systemImage: "mappin.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        MugshotRatingBadge(score: payload.rating)
                    }

                    if let caption = payload.publicCaption?.remoteTrimmedNonEmpty {
                        Text("“\(caption)”")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(.roastBrown)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text("Remembered by \(payload.authorName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                }
                .padding(28)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var photoSurface: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, Color.espressoBrown.opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.mugshotMint.opacity(0.64), Color.sandBeige],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                MugsyModelView(configuration: MugsyPlacement.camera.configuration)
                    .padding(46)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct RichSharePresentation: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

private extension View {
    func remoteVisitEditField() -> some View {
        mugshotFormField()
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
