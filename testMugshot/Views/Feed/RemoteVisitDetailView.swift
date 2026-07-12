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

    init(
        visitId: UUID,
        initialSummary: RemoteVisitSummary,
        currentUserId: UUID?,
        dataManager: DataManager,
        justPosted: Bool = false
    ) {
        self.visitId = visitId
        self.initialSummary = initialSummary
        self.currentUserId = currentUserId
        self.dataManager = dataManager
        self.justPosted = justPosted
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
    @State private var isShowingEditVisit = false
    @State private var isDeletingVisit = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isCommentFocused: Bool

    private var displayedSummary: RemoteVisitSummary {
        detail?.summary ?? initialSummary
    }

    private var heroHeight: CGFloat { 500 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SipDetailBackground()

                content

                topControls
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: visitId) {
                await loadDetail()
            }
            .sheet(isPresented: $isShowingEditVisit) {
                if let detail,
                   let currentUserId {
                    EditRemoteVisitView(
                        detail: detail,
                        currentUserId: currentUserId,
                        onSave: saveVisitEdits
                    )
                }
            }
            .fullScreenCover(item: $photoViewerPresentation) { presentation in
                RemotePhotoViewer(
                    photoURLs: presentation.photoURLs,
                    initialIndex: presentation.initialIndex
                )
            }
            .confirmationDialog(
                "Delete this sip?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Sip", role: .destructive) {
                    Task {
                        await deleteVisit()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the sip from Profile, Feed, and cafe history.")
            }
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func detailContent(_ detail: RemoteVisitDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection(detail)

                VStack(alignment: .leading, spacing: 18) {
                    memoryPanel(detail)
                    actionShelf(detail)
                    SipRatingBreakdownPanel(
                        score: detail.summary.visit.overallScore,
                        ratings: detail.summary.visit.ratings,
                        title: "Flavor map",
                        subtitle: isOwnVisit(detail) ? "Your saved taste breakdown" : "\(detail.summary.authorDisplayName)'s taste breakdown"
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
            Color.sandBeige.opacity(0.64)
                .overlay {
                    MugshotLegacySipHero(
                        title: detail.summary.visit.drinkDisplayName,
                        subtitle: detail.summary.locationTitle,
                        score: detail.summary.visit.overallScore
                    )
                    .padding(20)
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
           let notes = detail.summary.visit.trimmedNotes {
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

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 94), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
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

                        if !isOwnVisit(detail) {
                            SipActionButton(
                                title: isCafeWantToTry(detail) ? "Wanting" : "Want",
                                value: nil,
                                systemImage: isCafeWantToTry(detail) ? "pin.fill" : "pin",
                                isActive: isCafeWantToTry(detail),
                                isEnabled: currentUserId != nil
                            ) {
                                setCafeStateFromVisit(
                                    detail,
                                    isFavorite: nil,
                                    wantToTry: !isCafeWantToTry(detail)
                                )
                            }
                        }
                    }

                    SipShareButton(text: shareText(for: detail))
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
                            RemoteCommentRow(comment: comment)
                                .padding(.leading, comment.comment.parentCommentId == nil ? 0 : 18)
                        }
                    }
                }

                if currentUserId != nil {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Add a thought", text: $commentText, axis: .vertical)
                            .lineLimit(1...4)
                            .mugshotFormField()
                            .focused($isCommentFocused)
                            .submitLabel(.send)

                        Button {
                            Task {
                                await postComment()
                            }
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

    private func shareText(for detail: RemoteVisitDetail) -> String {
        "\(detail.summary.authorDisplayName) rated \(detail.summary.visit.drinkDisplayName) \(String(format: "%.1f", detail.summary.visit.overallScore)) at \(detail.summary.locationTitle) on Mugshot."
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
            selectedPhotoIndex = 0
            isLoading = false
        } catch {
            detail = nil
            loadError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoading = false
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
                text: text
            )
            self.detail = try await service.fetchVisitDetail(
                visitId: visitId,
                currentUserId: currentUserId
            )
            commentText = ""
            isCommentFocused = false
            isSavingSocialAction = false
        } catch {
            self.detail = detail
            socialError = MugshotUserFacingError.message(for: error, context: .social)
            isSavingSocialAction = false
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
                notes: notes,
                visibility: visibility
            )
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let summary = try await service.updateVisit(
                visitId: visitId,
                userId: currentUserId,
                update: update
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
                socialState: state
            ),
            photos: detail.photos,
            comments: detail.comments,
            likeCount: state.likeCount,
            currentUserHasLiked: state.currentUserHasLiked
        )
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

struct RemoteCommentRow: View {
    let comment: RemoteVisitComment

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

    init(
        detail: RemoteVisitDetail,
        currentUserId: UUID,
        onSave: @escaping (String, String, VisitVisibility) async -> Bool
    ) {
        self.detail = detail
        self.currentUserId = currentUserId
        self.onSave = onSave
        _caption = State(initialValue: detail.summary.visit.caption)
        _notes = State(initialValue: detail.summary.visit.trimmedNotes ?? "")
        _visibility = State(initialValue: VisitVisibility.supabaseValue(detail.summary.visit.visibility))
    }

    private var canSave: Bool {
        caption.remoteTrimmedNonEmpty != nil && !isSaving
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
                        Task {
                            await save()
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

                if ratings.isEmpty {
                    Text("No category scores were saved with this sip.")
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 12) {
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

struct SipShareButton: View {
    let text: String

    var body: some View {
        ShareLink(item: text) {
            SipActionLabel(
                title: "Share",
                value: nil,
                systemImage: "square.and.arrow.up",
                isActive: false,
                isEnabled: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share sip")
    }
}

struct SipActionLabel: View {
    let title: String
    let value: String?
    let systemImage: String
    var isActive = false
    var isEnabled = true

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))

            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let value {
                    Text(value)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
            }
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
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
