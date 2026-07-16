import SwiftUI

// MARK: - Value model

enum SipDetailPresentationMode: Equatable {
    case pushed
    case postSave

    var dismissIcon: String {
        switch self {
        case .pushed: "chevron.left"
        case .postSave: "xmark"
        }
    }

    var dismissLabel: String {
        switch self {
        case .pushed: "Back"
        case .postSave: "Close sip"
        }
    }
}

enum SipDetailPhotoSource: Identifiable, Equatable {
    case local(String)
    case remote(String)

    var id: String {
        switch self {
        case .local(let path): "local-\(path)"
        case .remote(let url): "remote-\(url)"
        }
    }
}

struct SipDetailPhotoViewerPresentation: Identifiable, Equatable {
    let id = UUID()
    let photos: [SipDetailPhotoSource]
    let initialIndex: Int

    static func == (lhs: SipDetailPhotoViewerPresentation, rhs: SipDetailPhotoViewerPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

struct SipDetailRatingItem: Identifiable, Equatable {
    let name: String
    let score: Double

    var id: String { name }
}

struct SipDetailVisitFact: Identifiable, Equatable {
    let label: String
    let value: String
    let systemImage: String?

    init(label: String, value: String, systemImage: String? = nil) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    var id: String { "\(label)-\(value)" }
}

struct SipDetailReactionSummary: Identifiable, Equatable {
    let title: String
    let systemImage: String
    let count: Int

    var id: String { title }
}

struct SipDetailCommentModel: Identifiable, Equatable {
    let id: UUID
    let authorName: String
    let username: String
    let text: String
    let timestamp: String
    let canReply: Bool
}

struct SipDetailMentionSuggestion: Identifiable, Equatable {
    let id: UUID
    let username: String
}

enum SipDetailSection: String, CaseIterable, Equatable {
    case note
    case actions
    case friendsNoticed
    case taste
    case visitDetails
    case privateNote
    case conversation
}

enum SipDetailAction: String, CaseIterable, Identifiable, Equatable {
    case like
    case comment
    case saveCafe
    case share
    case recommend
    case more
    case edit
    case correctDrink
    case repeatSip
    case delete
    case report
    case block

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: "Like"
        case .comment: "Comment"
        case .saveCafe: "Save cafe"
        case .share: "Share"
        case .recommend: "Recommend"
        case .more: "More"
        case .edit: "Edit Sip"
        case .correctDrink: "Correct Drink Details"
        case .repeatSip: "Repeat Sip"
        case .delete: "Delete Sip"
        case .report: "Report Sip"
        case .block: "Block User"
        }
    }

    var systemImage: String {
        switch self {
        case .like: "heart"
        case .comment: "bubble.right"
        case .saveCafe: "bookmark"
        case .share: "square.and.arrow.up"
        case .recommend: "paperplane"
        case .more: "ellipsis"
        case .edit: "pencil"
        case .correctDrink: "slider.horizontal.3"
        case .repeatSip: "plus.square.on.square"
        case .delete: "trash"
        case .report: "exclamationmark.bubble"
        case .block: "hand.raised"
        }
    }
}

struct SipDetailCapabilities: Equatable {
    let isOwner: Bool
    let dockActions: [SipDetailAction]
    let menuActions: [SipDetailAction]
    let canComment: Bool

    static func owner(
        hasCafe: Bool,
        canComment: Bool,
        canRepeat: Bool,
        canCorrectDrink: Bool = true
    ) -> SipDetailCapabilities {
        var dock: [SipDetailAction] = [.comment]
        if hasCafe { dock.append(.saveCafe) }
        dock.append(.share)
        dock.append(.more)

        var menu: [SipDetailAction] = [.edit]
        if canCorrectDrink { menu.append(.correctDrink) }
        if canRepeat { menu.append(.repeatSip) }
        menu.append(.delete)

        return SipDetailCapabilities(
            isOwner: true,
            dockActions: Array(dock.prefix(4)),
            menuActions: menu,
            canComment: canComment
        )
    }

    static func friend(
        hasCafe: Bool,
        canComment: Bool,
        canRecommend: Bool
    ) -> SipDetailCapabilities {
        var dock: [SipDetailAction] = [.like, .comment]
        if hasCafe { dock.append(.saveCafe) }
        dock.append(canRecommend ? .recommend : .share)

        return SipDetailCapabilities(
            isOwner: false,
            dockActions: Array(dock.prefix(4)),
            menuActions: [.report, .block],
            canComment: canComment
        )
    }
}

struct SipDetailContentModel: Identifiable, Equatable {
    let id: UUID
    let authorName: String
    let authorUsername: String
    let authorAvatarURL: String?
    let timestamp: String
    let visibility: String
    let drinkName: String
    let locationName: String
    let locationSubtitle: String?
    let score: Double
    let caption: String?
    let privateNote: String?
    let photos: [SipDetailPhotoSource]
    let ratings: [SipDetailRatingItem]
    let visitFacts: [SipDetailVisitFact]
    let reactions: [SipDetailReactionSummary]
    let comments: [SipDetailCommentModel]
    let isLiked: Bool
    let likeCount: Int
    let isCafeSaved: Bool
    let replyingToUsername: String?
    let sharePayload: SipShareCardPayload

    func visibleSections(capabilities: SipDetailCapabilities) -> [SipDetailSection] {
        var sections: [SipDetailSection] = []
        if caption != nil { sections.append(.note) }
        if !capabilities.dockActions.isEmpty { sections.append(.actions) }
        if !reactions.isEmpty { sections.append(.friendsNoticed) }
        if score > 0 || !ratings.isEmpty { sections.append(.taste) }
        if !visitFacts.isEmpty { sections.append(.visitDetails) }
        if capabilities.isOwner, privateNote != nil { sections.append(.privateNote) }
        if capabilities.canComment || !comments.isEmpty { sections.append(.conversation) }
        return sections
    }
}

struct SipDetailPresentation: Equatable {
    let content: SipDetailContentModel
    let capabilities: SipDetailCapabilities
}

enum SipDetailPresentationAdapter {
    static func remote(
        detail: RemoteVisitDetail,
        currentUserID: UUID?,
        reactions: [SipReactionRecord],
        isCafeSaved: Bool,
        canRecommend: Bool,
        canRepeat: Bool,
        replyingToUsername: String?
    ) -> SipDetailPresentation {
        let visit = detail.summary.visit
        let isOwner = visit.userId == currentUserID
        let authorName = isOwner ? "Your sip" : detail.summary.authorDisplayName
        let caption = consumerCaption(visit.caption)
        let reactionSummaries = Dictionary(grouping: reactions, by: \SipReactionRecord.reaction)
            .map { reaction, records in
                SipDetailReactionSummary(
                    title: reaction.title,
                    systemImage: reaction.systemImage,
                    count: records.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.title < rhs.title }
                return lhs.count > rhs.count
            }

        let content = SipDetailContentModel(
            id: detail.id,
            authorName: authorName,
            authorUsername: "@\(detail.summary.authorUsername)",
            authorAvatarURL: detail.summary.author?.avatarURL,
            timestamp: SipDetailFormat.timestamp(visit.createdAtDate),
            visibility: audienceLabel(visit.visibility),
            drinkName: visit.drinkDisplayName,
            locationName: detail.summary.locationTitle,
            locationSubtitle: detail.summary.locationSubtitle,
            score: visit.overallScore,
            caption: caption,
            privateNote: isOwner ? detail.privateNote?.remoteTrimmedNonEmpty : nil,
            photos: detail.photoURLs.map(SipDetailPhotoSource.remote),
            ratings: visit.orderedRatingScores.map {
                SipDetailRatingItem(name: $0.name, score: $0.score)
            },
            visitFacts: remoteVisitFacts(detail),
            reactions: reactionSummaries,
            comments: detail.comments.map { comment in
                SipDetailCommentModel(
                    id: comment.id,
                    authorName: comment.authorDisplayName,
                    username: "@\(comment.authorUsername)",
                    text: comment.comment.text,
                    timestamp: SipDetailFormat.relative(comment.comment.createdAtDate),
                    canReply: comment.comment.parentCommentId == nil
                )
            },
            isLiked: detail.currentUserHasLiked,
            likeCount: detail.likeCount,
            isCafeSaved: isCafeSaved,
            replyingToUsername: replyingToUsername,
            sharePayload: SipShareCardPayload(
                authorName: detail.summary.authorDisplayName,
                drinkName: visit.drinkDisplayName,
                cafeName: detail.summary.locationTitle,
                rating: visit.overallScore,
                date: visit.createdAtDate,
                publicCaption: caption,
                remotePhotoURL: detail.photoURLs.first,
                localPhotoPath: nil
            )
        )

        let capabilities = isOwner
            ? SipDetailCapabilities.owner(
                hasCafe: detail.summary.cafe != nil,
                canComment: currentUserID != nil,
                canRepeat: canRepeat
            )
            : SipDetailCapabilities.friend(
                hasCafe: detail.summary.cafe != nil,
                canComment: currentUserID != nil,
                canRecommend: canRecommend
            )

        return SipDetailPresentation(content: content, capabilities: capabilities)
    }

    static func local(
        visit: Visit,
        cafe: Cafe?,
        user: User?,
        comments: [Comment],
        isCafeSaved: Bool
    ) -> SipDetailPresentation {
        let isOwner = user?.id == visit.userId
        let authorDisplayName = user?.displayNameOrUsername ?? "Mugshot User"
        let caption = consumerCaption(visit.caption)
        let orderedPhotos = orderedLocalPhotos(visit)
        let ratings = visit.ratingCriteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.score > 0 }
            .map { SipDetailRatingItem(name: $0.name, score: $0.score) }
        let fallbackRatings = visit.ratings.keys.sorted().compactMap { name -> SipDetailRatingItem? in
            guard let score = visit.ratings[name] else { return nil }
            return SipDetailRatingItem(name: name, score: score)
        }

        let content = SipDetailContentModel(
            id: visit.id,
            authorName: isOwner ? "Your sip" : authorDisplayName,
            authorUsername: "@\(user?.username ?? "user")",
            authorAvatarURL: nil,
            timestamp: SipDetailFormat.timestamp(visit.createdAt),
            visibility: visit.visibility == .everyone ? "Public" : visit.visibility.rawValue,
            drinkName: visit.journalDrinkName,
            locationName: visit.context == .cafe
                ? (cafe?.consumerDisplayName ?? "Cafe")
                : (visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback),
            locationSubtitle: cafe?.address.remoteTrimmedNonEmpty,
            score: visit.overallScore,
            caption: caption,
            privateNote: isOwner ? visit.notes?.remoteTrimmedNonEmpty : nil,
            photos: orderedPhotos.map(SipDetailPhotoSource.local),
            ratings: ratings.isEmpty ? fallbackRatings : ratings,
            visitFacts: localVisitFacts(visit: visit, cafe: cafe),
            reactions: [],
            comments: comments.map { comment in
                SipDetailCommentModel(
                    id: comment.id,
                    authorName: comment.userId == user?.id ? authorDisplayName : "Mugshot User",
                    username: comment.userId == user?.id ? "@\(user?.username ?? "user")" : "@user",
                    text: comment.text,
                    timestamp: SipDetailFormat.relative(comment.createdAt),
                    canReply: false
                )
            },
            isLiked: user.map { visit.isLikedBy(userId: $0.id) } ?? false,
            likeCount: visit.likeCount,
            isCafeSaved: isCafeSaved,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                authorName: authorDisplayName,
                drinkName: visit.journalDrinkName,
                cafeName: cafe?.consumerDisplayName ?? visit.locationName ?? "Cafe",
                rating: visit.overallScore,
                date: visit.createdAt,
                publicCaption: caption,
                remotePhotoURL: nil,
                localPhotoPath: orderedPhotos.first
            )
        )

        let capabilities = isOwner
            ? SipDetailCapabilities.owner(
                hasCafe: cafe != nil,
                canComment: user != nil,
                canRepeat: false,
                canCorrectDrink: false
            )
            : SipDetailCapabilities.friend(
                hasCafe: cafe != nil,
                canComment: user != nil,
                canRecommend: false
            )

        return SipDetailPresentation(content: content, capabilities: capabilities)
    }

    private static func consumerCaption(_ caption: String) -> String? {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let internalMarkers = ["smoke", "photo-required", "ui pass", "polish pass"]
        guard !internalMarkers.contains(where: trimmed.lowercased().contains) else { return nil }
        return trimmed
    }

    private static func audienceLabel(_ visibility: String) -> String {
        switch visibility.lowercased() {
        case "everyone": "Public"
        case "friends": "Friends"
        case "private": "Private"
        default: visibility.capitalized
        }
    }

    private static func remoteVisitFacts(_ detail: RemoteVisitDetail) -> [SipDetailVisitFact] {
        let visit = detail.summary.visit
        let structured = visit.structuredBrewDetails
        var facts: [SipDetailVisitFact] = []
        if let companions = structured.companions, !companions.isEmpty {
            facts.append(SipDetailVisitFact(label: "With", value: companions.joined(separator: ", "), systemImage: "person.2"))
        }
        if let subtitle = detail.summary.locationSubtitle?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Address", value: subtitle, systemImage: "mappin"))
        }
        facts.append(SipDetailVisitFact(
            label: "Visited",
            value: visit.createdAtDate.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        ))
        if let order = structured.orderNotes?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Order", value: order, systemImage: "cup.and.saucer"))
        }
        if let additions = structured.additions?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Additions", value: additions, systemImage: "plus.circle"))
        }
        if let brewMethod = visit.brewMethod?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Method", value: brewMethod, systemImage: "drop"))
        }
        if let equipment = visit.equipment?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Equipment", value: equipment, systemImage: "wrench.and.screwdriver"))
        }
        return facts
    }

    private static func localVisitFacts(visit: Visit, cafe: Cafe?) -> [SipDetailVisitFact] {
        var facts: [SipDetailVisitFact] = []
        if let companions = visit.brewDetails.companions, !companions.isEmpty {
            facts.append(SipDetailVisitFact(label: "With", value: companions.joined(separator: ", "), systemImage: "person.2"))
        }
        if let address = cafe?.address.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Address", value: address, systemImage: "mappin"))
        }
        facts.append(SipDetailVisitFact(
            label: "Visited",
            value: visit.createdAt.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        ))
        if let method = visit.brewMethod?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Method", value: method, systemImage: "drop"))
        }
        if let equipment = visit.equipment?.remoteTrimmedNonEmpty {
            facts.append(SipDetailVisitFact(label: "Equipment", value: equipment, systemImage: "wrench.and.screwdriver"))
        }
        return facts
    }

    private static func orderedLocalPhotos(_ visit: Visit) -> [String] {
        guard !visit.photos.isEmpty else { return [] }
        var ordered = visit.photos
        if let poster = visit.posterImagePath,
           let posterIndex = ordered.firstIndex(of: poster) {
            ordered.remove(at: posterIndex)
            ordered.insert(poster, at: 0)
        }
        return ordered
    }
}

// MARK: - Shared Immersive Pour screen

struct SipDetailScreen: View {
    let presentation: SipDetailPresentation
    @Binding var selectedPhotoIndex: Int
    @Binding var commentText: String
    @Binding var toolbarProgress: CGFloat
    let commentFocus: FocusState<Bool>.Binding
    let isWorking: Bool
    let mentionSuggestions: [SipDetailMentionSuggestion]
    let onAction: (SipDetailAction) -> Void
    let onSubmitComment: () -> Void
    let onReply: (UUID) -> Void
    let onCancelReply: () -> Void
    let onSelectMention: (UUID) -> Void
    let onPhotoTap: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isTasteExpanded = false
    @State private var isVisitExpanded = false
    @State private var isComposerPresented = false
    @State private var tasteReveal: CGFloat = 0

    private let heroAnchor = "sip-detail-hero"
    private let commentsAnchor = "sip-detail-comments"

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        SipDetailHero(
                            model: presentation.content,
                            selectedPhotoIndex: $selectedPhotoIndex,
                            onPhotoTap: onPhotoTap
                        )
                        .frame(height: heroHeight(for: viewport.size.width))
                        .id(heroAnchor)

                        contentSurface(proxy: proxy)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    let collapseDistance = max(heroHeight(for: viewport.size.width) - 84, 1)
                    toolbarProgress = MugshotMotion.normalized(max(offset, 0) / collapseDistance)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isComposerPresented {
                        SipDetailComposerBar(
                            text: $commentText,
                            replyingToUsername: presentation.content.replyingToUsername,
                            isWorking: isWorking,
                            mentionSuggestions: mentionSuggestions,
                            focus: commentFocus,
                            onCancelReply: onCancelReply,
                            onSelectMention: onSelectMention,
                            onSubmit: onSubmitComment
                        )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(Color.creamWhite)
                .ignoresSafeArea(edges: .top)
            }
        }
        .background(Color.creamWhite)
        .accessibilityIdentifier("sip.detail.screen")
        .accessibilityElement(children: .contain)
        .onChange(of: commentFocus.wrappedValue) { _, isFocused in
            guard !isFocused, commentText.remoteTrimmedNonEmpty == nil else { return }
            withAnimation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion)) {
                isComposerPresented = false
            }
        }
    }

    private func heroHeight(for width: CGFloat) -> CGFloat {
        let base = width / 0.88
        if dynamicTypeSize.isAccessibilitySize {
            return max(base, 680)
        }
        return min(max(base, 390), 472)
    }

    private func contentSurface(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption = presentation.content.caption {
                SipDetailEditorialNote(text: caption)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
            }

            SipDetailActionDock(
                actions: presentation.capabilities.dockActions,
                model: presentation.content,
                isWorking: isWorking,
                onAction: { action in handle(action, proxy: proxy) }
            )
            .padding(.horizontal, 18)
            .padding(.top, presentation.content.caption == nil ? 26 : 22)

            if !presentation.content.reactions.isEmpty {
                SipFriendsNoticedSection(reactions: presentation.content.reactions)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
            }

            if presentation.content.score > 0 || !presentation.content.ratings.isEmpty {
                SipTasteSnapshotSection(
                    score: presentation.content.score,
                    ratings: presentation.content.ratings,
                    isExpanded: $isTasteExpanded,
                    revealProgress: tasteReveal
                )
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .onChange(of: isTasteExpanded) { _, isExpanded in
                    guard isExpanded else { return }
                    revealTaste()
                }
            }

            if !presentation.content.visitFacts.isEmpty {
                SipVisitDetailsSection(
                    facts: presentation.content.visitFacts,
                    isExpanded: $isVisitExpanded
                )
                .padding(.horizontal, 22)
                .padding(.top, 28)
            }

            if presentation.capabilities.isOwner,
               let privateNote = presentation.content.privateNote {
                SipPrivateNoteSection(text: privateNote)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
            }

            if presentation.capabilities.canComment || !presentation.content.comments.isEmpty {
                SipConversationSection(
                    comments: presentation.content.comments,
                    canComment: presentation.capabilities.canComment,
                    onReply: { commentID in
                        onReply(commentID)
                        focusComposer(proxy: proxy)
                    },
                    onCompose: { focusComposer(proxy: proxy) }
                )
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .id(commentsAnchor)
            }
        }
        .padding(.bottom, 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.creamWhite)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 28,
            style: .continuous
        ))
        .offset(y: -18)
        .padding(.bottom, -18)
    }

    private func handle(_ action: SipDetailAction, proxy: ScrollViewProxy) {
        if action == .comment {
            focusComposer(proxy: proxy)
            return
        }
        if action == .like || action == .saveCafe {
            MugshotHaptic.softImpact.play()
        }
        onAction(action)
    }

    private func focusComposer(proxy: ScrollViewProxy) {
        withAnimation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion)) {
            proxy.scrollTo(commentsAnchor, anchor: .bottom)
            isComposerPresented = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 20 : 140))
            commentFocus.wrappedValue = true
            onAction(.comment)
        }
    }

    private func revealTaste() {
        guard tasteReveal == 0 else { return }
        if reduceMotion {
            tasteReveal = 1
        } else {
            withAnimation(.easeOut(duration: 0.64)) {
                tasteReveal = 1
            }
        }
    }
}

// MARK: - Hero

private struct SipDetailHero: View {
    let model: SipDetailContentModel
    @Binding var selectedPhotoIndex: Int
    let onPhotoTap: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SipDetailPhotoPager(
                photos: model.photos,
                selectedIndex: $selectedPhotoIndex,
                onTap: onPhotoTap
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    MugshotAvatar(
                        name: model.authorName,
                        size: 42,
                        imageURL: model.authorAvatarURL
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.authorName)
                            .font(.system(.subheadline, design: .default, weight: .bold))
                        Text("\(model.authorUsername)  ·  \(model.timestamp)  ·  \(model.visibility)")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                    }
                }

                Text(model.drinkName)
                    .font(.system(.largeTitle, design: .serif, weight: .regular))
                    .tracking(-0.7)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 12) {
                    Label(model.locationName, systemImage: "mappin.circle.fill")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    MugshotRatingBadge(score: model.score, onPhoto: false)
                        .background(Color.mugshotMint.opacity(0.76), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.bottom, 38)
            .shadow(color: .black.opacity(0.36), radius: 16, x: 0, y: 8)
            .allowsHitTesting(false)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.drinkName) at \(model.locationName), rated \(String(format: "%.1f", model.score))")
    }
}

private struct SipDetailPhotoPager: View {
    let photos: [SipDetailPhotoSource]
    @Binding var selectedIndex: Int
    let onTap: (Int) -> Void

    var body: some View {
        Group {
            if photos.isEmpty {
                SipDetailNoPhotoSurface()
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, source in
                        SipDetailPhoto(source: source)
                            .tag(index)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(index) }
                            .overlay(alignment: .topTrailing) {
                                if photos.count > 1 {
                                    Text("\(selectedIndex + 1)/\(photos.count)")
                                        .font(.system(.caption, design: .default, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.black.opacity(0.54), in: Capsule())
                                        .padding(.top, 96)
                                        .padding(.trailing, 18)
                                }
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            }
        }
        .accessibilityAction(named: "Open photo full screen") {
            guard !photos.isEmpty else { return }
            onTap(selectedIndex)
        }
    }
}

private struct SipDetailPhoto: View {
    let source: SipDetailPhotoSource

    var body: some View {
        switch source {
        case .local(let path):
            PhotoImageView(photoPath: path)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        case .remote(let url):
            RemotePhotoImageView(urlString: url, placeholderSystemName: "photo.on.rectangle")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }
}

struct SipDetailPhotoViewer: View {
    let presentation: SipDetailPhotoViewerPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(presentation: SipDetailPhotoViewerPresentation) {
        self.presentation = presentation
        _selectedIndex = State(initialValue: presentation.initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(presentation.photos.enumerated()), id: \.element.id) { index, source in
                    SipDetailPhoto(source: source)
                        .tag(index)
                        .scaledToFit()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: presentation.photos.count > 1 ? .automatic : .never))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(.body, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            .accessibilityLabel("Close photo viewer")
        }
    }
}

private struct SipDetailNoPhotoSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.darkRoast, Color.roastBrown, Color.mugshotSage.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 54, weight: .light))
                Text("No photo added")
                    .font(.system(.callout, design: .default, weight: .semibold))
            }
            .foregroundStyle(Color.creamWhite.opacity(0.72))
            .padding(.bottom, 90)
        }
    }
}

// MARK: - Content sections

private struct SipDetailEditorialNote: View {
    let text: String

    var body: some View {
        Text("“\(text)”")
            .font(.system(.title2, design: .serif, weight: .regular))
            .foregroundStyle(Color.espressoBrown)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Tasting note: \(text)")
    }
}

private struct SipDetailActionDock: View {
    let actions: [SipDetailAction]
    let model: SipDetailContentModel
    let isWorking: Bool
    let onAction: (SipDetailAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : max(min(actions.count, 4), 1)
        return Array(repeating: GridItem(.flexible(), spacing: 0), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(actions) { action in
                if action == .share {
                    SipShareButton(payload: model.sharePayload, layout: .dock)
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 76 : 70)
                } else {
                    Button {
                        onAction(action)
                    } label: {
                        SipDetailDockLabel(
                            action: action,
                            isActive: isActive(action),
                            value: action == .like && model.likeCount > 0 ? "\(model.likeCount)" : nil
                        )
                    }
                    .buttonStyle(SipDetailPressButtonStyle())
                    .disabled(isWorking)
                    .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 76 : 70)
                    .accessibilityLabel(accessibilityLabel(action))
                }
            }
        }
        .background(Color.creamWhite)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func isActive(_ action: SipDetailAction) -> Bool {
        switch action {
        case .like: model.isLiked
        case .saveCafe: model.isCafeSaved
        default: false
        }
    }

    private func accessibilityLabel(_ action: SipDetailAction) -> String {
        switch action {
        case .like where model.isLiked: "Unlike sip, \(model.likeCount) likes"
        case .like: "Like sip, \(model.likeCount) likes"
        case .saveCafe where model.isCafeSaved: "Cafe saved"
        default: action.title
        }
    }
}

struct SipDetailDockLabel: View {
    let action: SipDetailAction
    let isActive: Bool
    let value: String?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: activeSystemImage)
                .font(.system(size: 21, weight: .semibold))
                .symbolEffect(.bounce, value: isActive)
            HStack(spacing: 3) {
                Text(action.title)
                if let value { Text(value) }
            }
                .font(.system(.caption, design: .default, weight: .semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(isActive ? Color.mugshotSage : Color.espressoBrown)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var activeSystemImage: String {
        guard isActive else { return action.systemImage }
        switch action {
        case .like: return "heart.fill"
        case .saveCafe: return "bookmark.fill"
        default: return action.systemImage
        }
    }
}

private struct SipDetailPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .background(configuration.isPressed ? Color.mugshotMint.opacity(0.16) : .clear)
            .animation(MugshotMotion.animation(MugshotMotion.response, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct SipFriendsNoticedSection: View {
    let reactions: [SipDetailReactionSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Friends noticed")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                HStack(spacing: -7) {
                    ForEach(Array(reactions.prefix(3).enumerated()), id: \.offset) { _, reaction in
                        Circle()
                            .fill(Color.mugshotMint)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: reaction.systemImage)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.espressoBrown)
                            )
                            .overlay(Circle().stroke(Color.creamWhite, lineWidth: 2))
                    }
                }
                .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { reactionContent }
                VStack(alignment: .leading, spacing: 8) { reactionContent }
            }
        }
        .foregroundStyle(Color.espressoBrown)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }

    @ViewBuilder
    private var reactionContent: some View {
        ForEach(reactions) { reaction in
            Label("\(reaction.title) \(reaction.count)", systemImage: reaction.systemImage)
                .font(.system(.footnote, design: .default, weight: .semibold))
                .foregroundStyle(Color.roastBrown)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.sandBeige.opacity(0.64), in: Capsule())
        }
    }
}

private struct SipTasteSnapshotSection: View {
    let score: Double
    let ratings: [SipDetailRatingItem]
    @Binding var isExpanded: Bool
    let revealProgress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Taste snapshot")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                Text(String(format: "%.1f overall", score))
                    .font(.system(.callout, design: .default, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.mugshotMint.opacity(0.28), in: Capsule())
            }

            if isExpanded {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(ratings) { rating in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(rating.name)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(String(format: "%.1f", rating.score))
                                    .monospacedDigit()
                            }
                            .font(.system(.footnote, design: .default, weight: .semibold))

                            GeometryReader { geometry in
                                Capsule().fill(Color.mugshotLine)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.mugshotSage)
                                            .frame(width: geometry.size.width * CGFloat(rating.score / 5) * revealProgress)
                                    }
                            }
                            .frame(height: 5)
                        }
                    }
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !ratings.isEmpty {
                Button {
                    withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(isExpanded ? "Hide details" : "View breakdown", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.footnote, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, isExpanded ? 14 : 6)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            }
        }
        .foregroundStyle(Color.espressoBrown)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }
}

private struct SipVisitDetailsSection: View {
    let facts: [SipDetailVisitFact]
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleFacts: ArraySlice<SipDetailVisitFact> {
        facts.prefix(isExpanded ? facts.count : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Visit details")
                    .font(.system(.title3, design: .default, weight: .bold))
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.mugshotSage)
            }

            ForEach(Array(visibleFacts)) { fact in
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        if let systemImage = fact.systemImage {
                            Label(fact.label, systemImage: systemImage)
                                .font(.system(.footnote, design: .default, weight: .medium))
                                .foregroundStyle(Color.mugshotSage)
                        } else {
                            Text(fact.label)
                                .font(.system(.footnote, design: .default, weight: .medium))
                                .foregroundStyle(Color.tertiaryText)
                        }
                        Text(fact.value)
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        if let systemImage = fact.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(Color.mugshotSage)
                                .frame(width: 18)
                        }
                        Text(fact.label)
                            .font(.system(.footnote, design: .default, weight: .medium))
                            .foregroundStyle(Color.tertiaryText)
                            .frame(width: 68, alignment: .leading)
                        Text(fact.value)
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            if facts.count > 3 {
                Button(isExpanded ? "Show less" : "Show \(facts.count - 3) more") {
                    withAnimation(MugshotMotion.animation(MugshotMotion.reveal, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                }
                .font(.system(.footnote, design: .default, weight: .semibold))
                .foregroundStyle(Color.mugshotSage)
                .frame(minHeight: 44)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.mugshotLine) }
    }
}

private struct SipPrivateNoteSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Private note", systemImage: "lock.fill")
                .font(.system(.caption2, design: .default, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.mugshotSage)
            Text(text)
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(Color.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sandBeige.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct SipConversationSection: View {
    let comments: [SipDetailCommentModel]
    let canComment: Bool
    let onReply: (UUID) -> Void
    let onCompose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Conversation")
                    .font(.system(.title2, design: .default, weight: .bold))
                Spacer()
                Text("\(comments.count)")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.sandBeige.opacity(0.58), in: Capsule())
            }

            if comments.isEmpty {
                Text("No comments yet.")
                    .font(.body)
                    .foregroundStyle(Color.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(comments) { comment in
                        SipDetailCommentRow(comment: comment, onReply: onReply)
                        if comment.id != comments.last?.id {
                            Divider().foregroundStyle(Color.mugshotLine)
                        }
                    }
                }
            }

            if canComment {
                Button(action: onCompose) {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.right")
                        Text("Add a thought")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.mugshotSage)
                    }
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(Color.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SipDetailCommentRow: View {
    let comment: SipDetailCommentModel
    let onReply: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: comment.authorName, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.authorName)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                    Text(comment.timestamp)
                        .font(.caption2)
                        .foregroundStyle(Color.tertiaryText)
                }
                Text(comment.text)
                    .font(.body)
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                if comment.canReply {
                    Button("Reply") { onReply(comment.id) }
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(minHeight: 36)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

private struct SipDetailComposerBar: View {
    @Binding var text: String
    let replyingToUsername: String?
    let isWorking: Bool
    let mentionSuggestions: [SipDetailMentionSuggestion]
    let focus: FocusState<Bool>.Binding
    let onCancelReply: () -> Void
    let onSelectMention: (UUID) -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyingToUsername {
                HStack {
                    Text("Replying to \(replyingToUsername)")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                    Spacer()
                    Button("Cancel", action: onCancelReply)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                }
            }

            if !mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionSuggestions) { suggestion in
                            Button("@\(suggestion.username)") {
                                onSelectMention(suggestion.id)
                            }
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(Color.mugshotSage)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 36)
                            .background(Color.creamWhite, in: Capsule())
                            .overlay(Capsule().stroke(Color.mugshotLine, lineWidth: 1))
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a thought", text: $text, axis: .vertical)
                    .focused(focus)
                    .lineLimit(1...4)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    Image(systemName: isWorking ? "hourglass" : "arrow.up")
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(Color.creamWhite)
                        .frame(width: 46, height: 46)
                        .background(Color.mugshotSage, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(text.remoteTrimmedNonEmpty == nil || isWorking)
                .opacity(text.remoteTrimmedNonEmpty == nil ? 0.45 : 1)
                .accessibilityLabel("Post comment")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Loading, error, edit, and delete surfaces

struct SipDetailLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.sandBeige.opacity(0.72))
                .frame(height: 420)
                .overlay(shimmer)

            VStack(alignment: .leading, spacing: 12) {
                skeleton(width: 0.82, height: 28)
                skeleton(width: 0.64, height: 28)
                skeleton(width: 0.48, height: 16)
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.sandBeige.opacity(0.7))
                            .frame(height: 66)
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color.creamWhite)
        .ignoresSafeArea(edges: .top)
        .accessibilityLabel("Loading sip")
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }

    private var shimmer: some View {
        LinearGradient(
            colors: [.clear, Color.mugshotMint.opacity(0.28), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset * 360)
        .clipped()
    }

    private func skeleton(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sandBeige.opacity(0.72))
                .frame(width: geometry.size.width * width, height: height)
        }
        .frame(height: height)
    }
}

struct SipDetailErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.red.opacity(0.78))
            Text("Couldn’t load this sip")
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Try again", action: onRetry)
                .buttonStyle(PrimaryButtonStyle())
                .frame(minHeight: 50)
            Button("Close", action: onClose)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(Color.mugshotSage)
                .frame(minHeight: 44)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamWhite)
    }
}

struct SipDeleteConfirmationSheet: View {
    let isDeleting: Bool
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(width: 46, height: 46)
                .background(Color.red.opacity(0.10), in: Circle())
            Text("Delete this sip?")
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            Text("This permanently removes the sip, photos, comments, and reactions. This cannot be undone.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive, action: onDelete) {
                HStack {
                    if isDeleting { ProgressView().tint(.white) }
                    Text("Delete Sip")
                        .frame(maxWidth: .infinity)
                }
                .font(.system(.body, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .frame(height: 50)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isDeleting)
            Button("Cancel") { dismiss() }
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.creamWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(Color.creamWhite)
    }
}

struct SipDetailEditForm: View {
    let summary: SipDetailContentModel
    @State private var publicNote: String
    @State private var privateNote: String
    @State private var visibility: VisitVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (String, String, VisitVisibility) async -> Bool

    @Environment(\.dismiss) private var dismiss

    init(
        summary: SipDetailContentModel,
        initialVisibility: VisitVisibility,
        onSave: @escaping (String, String, VisitVisibility) async -> Bool
    ) {
        self.summary = summary
        self.onSave = onSave
        _publicNote = State(initialValue: summary.caption ?? "")
        _privateNote = State(initialValue: summary.privateNote ?? "")
        _visibility = State(initialValue: initialVisibility)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SipEditSummaryRow(summary: summary)
                        .padding(.bottom, 22)

                    editSection(
                        title: "Public note",
                        helper: "Visible with this sip",
                        placeholder: "What should people remember?",
                        text: $publicNote
                    )

                    Divider().padding(.vertical, 20)

                    editSection(
                        title: "Private note",
                        helper: "Only visible to you",
                        placeholder: "Only visible to you",
                        text: $privateNote
                    )

                    Divider().padding(.vertical, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audience")
                            .font(.system(.caption, design: .default, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Color.mugshotSage)
                        MugshotSegmentedControl(
                            options: [VisitVisibility.private, .friends, .everyone],
                            selection: $visibility,
                            title: { $0.rawValue }
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .padding(.top, 16)
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Save sip").frame(maxWidth: .infinity)
                        }
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(height: 52)
                        .background(Color.mugshotSage, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .padding(.top, 28)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite)
            .navigationTitle("Edit sip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save", action: save)
                        .disabled(isSaving)
                }
            }
        }
    }

    private func editSection(
        title: String,
        helper: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(.caption, design: .default, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.mugshotSage)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
                .padding(14)
                .background(Color.creamWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )
            Text(helper)
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
    }

    private func save() {
        guard !isSaving else { return }
        Task { @MainActor in
            isSaving = true
            errorMessage = nil
            let didSave = await onSave(publicNote, privateNote, visibility)
            isSaving = false
            if didSave {
                dismiss()
            } else {
                errorMessage = "Could not save sip edits."
            }
        }
    }
}

private struct SipEditSummaryRow: View {
    let summary: SipDetailContentModel

    var body: some View {
        HStack(spacing: 14) {
            if let source = summary.photos.first {
                SipDetailPhoto(source: source)
                    .frame(width: 64, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.sandBeige)
                    .frame(width: 64, height: 82)
                    .overlay(Image(systemName: "cup.and.saucer").foregroundStyle(Color.mugshotSage))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(summary.drinkName)
                    .font(.system(.title2, design: .serif, weight: .regular))
                    .foregroundStyle(Color.espressoBrown)
                    .lineLimit(3)
                Text(summary.locationName)
                    .font(.system(.callout, design: .default, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Deterministic previews

#if DEBUG
private extension SipDetailPresentation {
    static var previewOwner: SipDetailPresentation {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let content = SipDetailContentModel(
            id: id,
            authorName: "Your sip",
            authorUsername: "@joe",
            authorAvatarURL: nil,
            timestamp: "Jul 14, 2026",
            visibility: "Public",
            drinkName: "Iced Quad Shot Carmel Macchiato",
            locationName: "Babas on Cannon",
            locationSubtitle: "11 Cannon St, Charleston, SC",
            score: 3,
            caption: "Strong coffee and strong friends!",
            privateNote: "Order it with an extra shot next time.",
            photos: [],
            ratings: [
                SipDetailRatingItem(name: "Presentation", score: 3.5),
                SipDetailRatingItem(name: "Value", score: 1.5),
                SipDetailRatingItem(name: "Taste", score: 3),
                SipDetailRatingItem(name: "Ambiance", score: 4)
            ],
            visitFacts: [
                SipDetailVisitFact(label: "With", value: "Amanda", systemImage: "person.2"),
                SipDetailVisitFact(label: "Address", value: "11 Cannon St", systemImage: "mappin"),
                SipDetailVisitFact(label: "Visited", value: "Jul 14, 2026", systemImage: "calendar")
            ],
            reactions: [],
            comments: [],
            isLiked: false,
            likeCount: 0,
            isCafeSaved: true,
            replyingToUsername: nil,
            sharePayload: SipShareCardPayload(
                authorName: "Joe",
                drinkName: "Iced Quad Shot Carmel Macchiato",
                cafeName: "Babas on Cannon",
                rating: 3,
                date: Date(timeIntervalSince1970: 1_768_000_000),
                publicCaption: "Strong coffee and strong friends!",
                remotePhotoURL: nil,
                localPhotoPath: nil
            )
        )
        return SipDetailPresentation(
            content: content,
            capabilities: .owner(hasCafe: true, canComment: true, canRepeat: true)
        )
    }
}

private struct SipDetailPreviewHost: View {
    let presentation: SipDetailPresentation
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var progress: CGFloat = 0
    @FocusState private var commentFocus: Bool

    var body: some View {
        NavigationStack {
            SipDetailScreen(
                presentation: presentation,
                selectedPhotoIndex: $photoIndex,
                commentText: $comment,
                toolbarProgress: $progress,
                commentFocus: $commentFocus,
                isWorking: false,
                mentionSuggestions: [],
                onAction: { _ in },
                onSubmitComment: {},
                onReply: { _ in },
                onCancelReply: {},
                onSelectMention: { _ in },
                onPhotoTap: { _ in }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left")
                }
                ToolbarItem(placement: .principal) {
                    Text(presentation.content.drinkName)
                        .lineLimit(1)
                        .opacity(progress)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

#Preview("Immersive Pour — Owner") {
    SipDetailPreviewHost(presentation: .previewOwner)
}

#Preview("Immersive Pour — No Photo, AX5") {
    SipDetailPreviewHost(presentation: .previewOwner)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Immersive Pour — Loading") {
    SipDetailLoadingView()
}

#Preview("Immersive Pour — Failure") {
    SipDetailErrorView(message: "Check your connection and try again.", onRetry: {}, onClose: {})
}
#endif
