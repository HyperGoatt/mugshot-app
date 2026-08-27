//
//  FeedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit

enum FeedPostRoute: Identifiable, Hashable {
    case local(Visit)
    case remote(RemoteVisitSummary)

    var visitID: UUID {
        switch self {
        case .local(let visit): return visit.id
        case .remote(let visit): return visit.id
        }
    }

    var id: String {
        switch self {
        case .local: return "local:\(visitID.uuidString)"
        case .remote: return "remote:\(visitID.uuidString)"
        }
    }

    static func == (lhs: FeedPostRoute, rhs: FeedPostRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Helper view to display the poster image for a visit
struct PosterImageView: View {
    let visit: Visit
    
    var body: some View {
        if let posterPath = visit.posterImagePath {
            PhotoImageView(photoPath: posterPath)
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(Color.sandBeige.opacity(0.72))
                .overlay(
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.roastBrown.opacity(0.42))
                )
        }
    }
}

@MainActor
private final class RemoteFeedMemoryCache {
    struct Entry {
        let visits: [RemoteVisitSummary]
        let hasMore: Bool
        let updatedAt: Date

        var isFresh: Bool { Date().timeIntervalSince(updatedAt) < 30 }
    }

    static let shared = RemoteFeedMemoryCache()
    private var entries: [String: Entry] = [:]

    func entry(for key: String) -> Entry? { entries[key] }

    func store(_ visits: [RemoteVisitSummary], hasMore: Bool, for key: String) {
        entries[key] = Entry(visits: visits, hasMore: hasMore, updatedAt: Date())
    }
}

struct FeedTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var activityStore: ActivityCenterStore
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onComposeDraft: ((SipDraft) -> Void)? = nil
    var onActivityRequested: (() -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @StateObject private var locationManager = LocationManager()
    @State private var selectedScope: FeedScope = .ranked
    @State private var selectedPostRoute: FeedPostRoute?
    @State private var selectedProfileRoute: PeopleProfileRoute?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var canonicalSipCount = 0
    @State private var isLoadingRemoteVisits = false
    @State private var isLoadingMoreRemoteVisits = false
    @State private var hasMoreRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var pendingSocialVisitIDs: Set<UUID> = []
    @State private var socialRecoveryMessage: String?
    @State private var activeFeedRequestID: UUID?
    @State private var feedSearchQuery = ""
    @State private var isFeedSearchPresented = false
    @State private var isPeopleHubPresented = false
    @State private var refreshPullProgress: CGFloat = 0
    @State private var isRefreshingFeed = false
    @State private var didArmRefresh = false
    @AppStorage("mugshot.your-mix-education.v1.dismissed") private var hasDismissedYourMixEducation = false
    @AppStorage(RoadmapFeatureFlags.phase3ExplainableTasteGraph) private var phase3ExplainableTasteGraph = true
    @FocusState private var isFeedSearchFocused: Bool

    private let feedPageSize = 12

    private var feedTaskID: String {
        "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(selectedScope.displayName)-\(dataManager.journalRevision)"
    }

    private var feedSubtitle: String {
        switch selectedScope {
        case .ranked:
            return "Friends, flavors, and\ncafes matched to you"
        case .friends:
            return "Sips from friends"
        case .everyone:
            return "Fresh public sips"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MugshotScreenHeader(
                    "Feed",
                    subtitle: feedSubtitle,
                    subtitleLineLimit: 2,
                    subtitleMinimumScaleFactor: 0.86
                ) {
                    HStack(spacing: 8) {
                        ActivityBellButton(unreadCount: activityStore.unreadCount) {
                            onActivityRequested?()
                        }
                        MugshotIconButton(systemName: "person.2.fill", size: 36) {
                            isPeopleHubPresented = true
                        }
                        .accessibilityLabel("People, requests, and friends")
                        MugsySipCountPill(value: canonicalSipCount)
                        MugshotIconButton(
                            systemName: "magnifyingglass",
                            size: 36,
                            isActive: isFeedSearchPresented
                        ) {
                            withAnimation(DesignSystem.Motion.fast) {
                                isFeedSearchPresented.toggle()
                            }
                            if isFeedSearchPresented {
                                Task { @MainActor in
                                    await Task.yield()
                                    isFeedSearchFocused = true
                                }
                            } else {
                                feedSearchQuery = ""
                            }
                        }
                        .accessibilityLabel("Search feed")
                    }
                }

                if isFeedSearchPresented {
                    feedSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                MugshotSegmentedControl(
                    options: FeedScope.allCases,
                    selection: $selectedScope,
                    title: { $0.displayName },
                    icon: { scopeIcon(for: $0) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                if selectedScope == .ranked && !hasDismissedYourMixEducation {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.mugshotSage)
                            .padding(.top, 1)

                        Text("Your Mix blends friend activity, recent sips, your taste, and nearby cafes.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            withAnimation(DesignSystem.Motion.fast) {
                                hasDismissedYourMixEducation = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondaryText)
                                .frame(width: 28, height: 28)
                                .background(Color.foamWhite.opacity(0.72), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss Your Mix explanation")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.mugshotMint.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        MugshotPullProgressReader(coordinateSpace: "feed.refresh", restingOffset: 8)
                        feedContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 116)
                }
                .coordinateSpace(name: "feed.refresh")
                .background(Color.creamWhite)
                .overlay(alignment: .top) {
                    MugshotPullRefreshIndicator(
                        progress: refreshPullProgress,
                        isRefreshing: isRefreshingFeed
                    )
                    .offset(y: 6)
                    .allowsHitTesting(false)
                }
                .onPreferenceChange(MugshotPullDistancePreferenceKey.self) { distance in
                    refreshPullProgress = MugshotMotion.normalized(distance / 82)
                    if refreshPullProgress >= 1, !didArmRefresh {
                        didArmRefresh = true
                        MugshotHaptic.refreshArmed.play()
                    } else if refreshPullProgress < 0.35 {
                        didArmRefresh = false
                    }
                }
                .refreshable {
                    isRefreshingFeed = true
                    await loadRemoteFeedIfNeeded(forceRefresh: true)
                    isRefreshingFeed = false
                }
            }
            .background(Color.creamWhite)
            .navigationDestination(item: $selectedPostRoute) { route in
                Group {
                    switch route {
                    case .local(let visit):
                        VisitDetailView(visit: visit, dataManager: dataManager)
                    case .remote(let visit):
                    RemoteVisitDetailView(
                        visitId: visit.id,
                        initialSummary: visit,
                        currentUserId: authModel.authenticatedUser?.id,
                        dataManager: dataManager,
                        onComposeDraft: { draft in
                            selectedPostRoute = nil
                            onComposeDraft?(draft)
                        }
                    )
                    .onDisappear {
                        Task { await loadRemoteFeedIfNeeded(forceRefresh: true) }
                    }
                    }
                }
                .id(route.id)
                .accessibilityIdentifier("feed.destination.\(route.visitID.uuidString)")
            }
            .navigationDestination(item: $selectedProfileRoute) { route in
                PublicProfileView(
                    route: route,
                    dataManager: dataManager,
                    onRelationshipChanged: {
                        await loadRemoteFeedIfNeeded(forceRefresh: true)
                    }
                )
            }
        }
        .sheet(isPresented: $isPeopleHubPresented) {
            PeopleHubView(dataManager: dataManager)
        }
        .task(id: feedTaskID) {
            await loadRemoteFeedIfNeeded()
        }
    }
    
    private var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else {
            return []
        }
        return dataManager.getFeedVisits(scope: selectedScope, currentUserId: currentUserId)
    }

    private var feedSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)

            TextField("Search drinks, cafes, captions, or people", text: $feedSearchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFeedSearchFocused)
                .accessibilityLabel("Search sips")

            if !feedSearchQuery.isEmpty {
                Button {
                    feedSearchQuery = ""
                    isFeedSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear feed search")
            }

            Button("Cancel") {
                feedSearchQuery = ""
                isFeedSearchFocused = false
                withAnimation(DesignSystem.Motion.fast) {
                    isFeedSearchPresented = false
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.espressoBrown)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var feedContent: some View {
        if authModel.authenticatedUser != nil {
            remoteFeedContent
        } else {
            localFeedContent
        }
    }

    @ViewBuilder
    private var remoteFeedContent: some View {
        if isLoadingRemoteVisits {
            MugshotLoadingState(layout: .feed, count: 3)
        } else if let remoteVisitError {
            MugshotRecoveryCard(
                title: "Couldn’t load your feed",
                message: remoteVisitError,
                actionTitle: "Retry"
            ) {
                Task { await loadRemoteFeedIfNeeded() }
            }
        } else if remoteVisits.isEmpty {
            MugsyEmptyStateView(
                placement: selectedScope == .friends ? .friendsEmpty : .feedEmpty,
                title: selectedScope == .friends ? "No friend-visible visits yet" : "No public visits yet",
                message: selectedScope == .friends ? "Sips from friends will appear here as your circle grows." : "Public sips will appear here as people log them.",
                primaryAction: logSipEmptyAction,
                secondaryAction: selectedScope == .friends ? findPeopleEmptyAction : exploreMapEmptyAction
            )
        } else if filteredRemoteVisits.isEmpty {
            MugsyEmptyStateView(
                placement: .feedFiltered,
                title: "No matching sips",
                message: "Try another drink, cafe, caption, or username.",
                primaryAction: clearSearchEmptyAction,
                secondaryAction: exploreMapEmptyAction
            )
        } else {
            ForEach(filteredRemoteVisits) { visit in
                RemoteFeedVisitCard(
                    visit: visit,
                    isCafeSaved: isCafeSaved(for: visit),
                    isSocialActionInFlight: pendingSocialVisitIDs.contains(visit.id),
                    showsRecommendationReason: phase3ExplainableTasteGraph && selectedScope == .ranked,
                    onOpen: {
                        selectedPostRoute = .remote(visit)
                    },
                    onAuthorTap: {
                        openAuthorProfile(for: visit)
                    },
                    onLike: {
                        toggleRemoteLike(for: visit)
                    },
                    onReaction: { reaction in
                        setRemoteReaction(for: visit, reaction: reaction)
                    },
                    onSaveCafe: {
                        saveCafe(from: visit)
                    },
                    onComment: {
                        selectedPostRoute = .remote(visit)
                    }
                )
            }

            if hasMoreRemoteVisits && feedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading more sips…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .task(id: remoteVisits.last?.id) {
                    await loadNextRemoteFeedPage()
                }
            }

            if let socialRecoveryMessage {
                Text(socialRecoveryMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.sandBeige.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var localFeedContent: some View {
        if visits.isEmpty {
            MugsyEmptyStateView(
                placement: .feedEmpty,
                title: "Your feed starts with a sip",
                message: "Log a cafe or Home sip and your memories will begin gathering here.",
                primaryAction: logSipEmptyAction,
                secondaryAction: exploreMapEmptyAction
            )
        } else if filteredLocalVisits.isEmpty {
            MugsyEmptyStateView(
                placement: .feedFiltered,
                title: "No matching sips",
                message: "Try another drink, cafe, or note.",
                primaryAction: clearSearchEmptyAction,
                secondaryAction: exploreMapEmptyAction
            )
        } else {
            ForEach(filteredLocalVisits) { visit in
                VisitCard(
                    visit: visit,
                    dataManager: dataManager,
                    onOpen: {
                        selectedPostRoute = .local(visit)
                    }
                )
            }
        }
    }

    private var filteredRemoteVisits: [RemoteVisitSummary] {
        remoteVisits.filter { $0.matchesFeedSearch(feedSearchQuery) }
    }

    private var filteredLocalVisits: [Visit] {
        let query = feedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return visits }

        return visits.filter { visit in
            let cafeName = dataManager.getCafe(id: visit.cafeId)?.name ?? ""
            let searchableText = [visit.journalDrinkName, visit.caption, cafeName]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let tokens = query
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: \.isWhitespace)
            return tokens.allSatisfy { searchableText.contains(String($0)) }
        }
    }

    private var logSipEmptyAction: MugsyEmptyStateAction {
        MugsyEmptyStateAction(
            "Log a Sip",
            systemImage: "plus.circle.fill",
            accessibilityHint: "Opens the guided sip composer"
        ) {
            withAnimation(DesignSystem.Motion.base) {
                tabCoordinator.selectedTab = .add
            }
        }
    }

    private var exploreMapEmptyAction: MugsyEmptyStateAction {
        MugsyEmptyStateAction(
            "Explore Map",
            systemImage: "map.fill",
            accessibilityHint: "Switches to Map to discover cafes"
        ) {
            withAnimation(DesignSystem.Motion.base) {
                tabCoordinator.selectedTab = .map
            }
        }
    }

    private var findPeopleEmptyAction: MugsyEmptyStateAction {
        MugsyEmptyStateAction(
            "Find people",
            systemImage: "person.2.fill",
            accessibilityHint: "Opens people search and friend requests"
        ) {
            isPeopleHubPresented = true
        }
    }

    private var clearSearchEmptyAction: MugsyEmptyStateAction {
        MugsyEmptyStateAction(
            "Clear search",
            systemImage: "xmark.circle.fill",
            accessibilityHint: "Clears the search and shows all available sips"
        ) {
            feedSearchQuery = ""
            isFeedSearchFocused = false
        }
    }

    private func loadRemoteFeedIfNeeded(forceRefresh: Bool = false) async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteVisits = []
            canonicalSipCount = dataManager.appData.visits.count
            remoteVisitError = nil
            isLoadingRemoteVisits = false
            return
        }

        let scope = selectedScope
        let cacheKey = feedTaskID
        if !forceRefresh, let cached = RemoteFeedMemoryCache.shared.entry(for: cacheKey) {
            remoteVisits = cached.visits
            hasMoreRemoteVisits = cached.hasMore
            isLoadingRemoteVisits = false
            if cached.isFresh {
                await refreshCanonicalSipCount(userID: userId)
                return
            }
        }

        let requestID = UUID()
        activeFeedRequestID = requestID
        isLoadingRemoteVisits = remoteVisits.isEmpty
        remoteVisitError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let visits = try await PerformanceMonitor.measure("Feed initial page") {
                try await service.fetchFeedVisits(
                    scope: scope,
                    currentUserId: userId,
                    limit: feedPageSize,
                    location: locationManager.location
                )
            }
            guard scope == selectedScope, activeFeedRequestID == requestID else { return }
            remoteVisits = visits
            hasMoreRemoteVisits = visits.count == feedPageSize
            RemoteFeedMemoryCache.shared.store(visits, hasMore: hasMoreRemoteVisits, for: cacheKey)
            isLoadingRemoteVisits = false
            await refreshCanonicalSipCount(userID: userId, service: service)
        } catch {
            guard scope == selectedScope, activeFeedRequestID == requestID else { return }
            guard !Task.isCancelled else { return }
            let message = MugshotUserFacingError.message(for: error, context: .loading)
            if remoteVisits.isEmpty {
                remoteVisitError = message
            } else {
                socialRecoveryMessage = "Couldn’t refresh just now. Your recent feed is still here."
            }
            isLoadingRemoteVisits = false
        }
    }

    @MainActor
    private func refreshCanonicalSipCount(
        userID: UUID,
        service: VisitService? = nil
    ) async {
        do {
            let resolvedService: VisitService
            if let service {
                resolvedService = service
            } else {
                resolvedService = VisitService(client: try SupabaseClientProvider.shared.client())
            }
            canonicalSipCount = try await resolvedService.fetchOwnerSipCount(userId: userID)
        } catch {
            // A count failure should never replace an otherwise healthy feed.
            canonicalSipCount = max(canonicalSipCount, dataManager.appData.visits.count)
        }
    }

    private func loadNextRemoteFeedPage() async {
        guard !isLoadingMoreRemoteVisits,
              hasMoreRemoteVisits,
              let userId = authModel.authenticatedUser?.id,
              let lastVisit = remoteVisits.last else {
            return
        }

        let scope = selectedScope
        let cacheKey = feedTaskID
        isLoadingMoreRemoteVisits = true
        defer { isLoadingMoreRemoteVisits = false }

        do {
            let client = try SupabaseClientProvider.shared.client()
            let nextPage = try await PerformanceMonitor.measure("Feed next page") {
                try await VisitService(client: client).fetchFeedVisits(
                    scope: scope,
                    currentUserId: userId,
                    limit: feedPageSize,
                    before: RemoteFeedCursor(lastVisit),
                    location: locationManager.location
                )
            }
            guard scope == selectedScope, !Task.isCancelled else { return }

            let existingIDs = Set(remoteVisits.map(\.id))
            let uniquePage = nextPage.filter { !existingIDs.contains($0.id) }
            remoteVisits.append(contentsOf: uniquePage)
            hasMoreRemoteVisits = nextPage.count == feedPageSize && !uniquePage.isEmpty
            RemoteFeedMemoryCache.shared.store(
                remoteVisits,
                hasMore: hasMoreRemoteVisits,
                for: cacheKey
            )
        } catch {
            guard !Task.isCancelled else { return }
            socialRecoveryMessage = "Couldn’t load more sips. Pull to refresh and try again."
        }
    }

    private func scopeIcon(for scope: FeedScope) -> String {
        switch scope {
        case .ranked:
            return "sparkles"
        case .friends:
            return "person.2.fill"
        case .everyone:
            return "globe"
        }
    }

    private func isCafeSaved(for visit: RemoteVisitSummary) -> Bool {
        guard let remoteCafeId = visit.cafe?.id else {
            return false
        }

        return dataManager.appData.cafes.contains { cafe in
            (cafe.remoteCafeId == remoteCafeId || cafe.id == remoteCafeId) && (cafe.isFavorite || cafe.wantToTry)
        }
    }

    private func toggleRemoteLike(for visit: RemoteVisitSummary) {
        setRemoteReaction(
            for: visit,
            reaction: visit.socialState.viewerReaction == nil ? .like : nil
        )
    }

    private func setRemoteReaction(
        for visit: RemoteVisitSummary,
        reaction: PostReactionKind?
    ) {
        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        guard pendingSocialVisitIDs.insert(visit.id).inserted else { return }
        socialRecoveryMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let optimisticReactionState = visit.socialState.reactionState
            .replacingViewerReaction(with: reaction)
        updateRemoteVisit(
            id: visit.id,
            socialState: RemoteVisitSocialState(
                likeCount: optimisticReactionState.totalCount,
                commentCount: visit.socialState.commentCount,
                currentUserHasLiked: reaction != nil,
                reactionState: optimisticReactionState
            )
        )

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = VisitService(client: client)
                let reactionState = try await service.setReaction(
                    visitId: visit.id,
                    userId: userId,
                    reaction: reaction
                )
                let state = RemoteVisitSocialState(
                    likeCount: reactionState.totalCount,
                    commentCount: visit.socialState.commentCount,
                    currentUserHasLiked: reactionState.viewerReaction != nil,
                    reactionState: reactionState
                )
                updateRemoteVisit(id: visit.id, socialState: state)
                MugshotAnalytics.shared.capture(
                    .sipLiked(
                        action: reaction == nil ? .removed : .added,
                        surface: .feed
                    )
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                updateRemoteVisit(id: visit.id, socialState: visit.socialState)
                socialRecoveryMessage = MugshotUserFacingError.message(for: error, context: .social)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            pendingSocialVisitIDs.remove(visit.id)
        }
    }

    private func openAuthorProfile(for visit: RemoteVisitSummary) {
        guard let author = visit.author else {
            selectedPostRoute = .remote(visit)
            return
        }
        selectedProfileRoute = PeopleProfileRoute(
            id: author.id,
            displayName: visit.authorDisplayName,
            username: visit.authorUsername
        )
    }

    private func saveCafe(from visit: RemoteVisitSummary) {
        guard let remoteCafe = visit.cafe else {
            return
        }

        let existingState = existingCafeState(for: remoteCafe.id)
        let localCafe = dataManager.upsertRemoteCafe(
            remoteCafe,
            isFavorite: true,
            wantToTry: existingState.wantToTry
        )

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        guard pendingSocialVisitIDs.insert(visit.id).inserted else { return }
        socialRecoveryMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = CafeStateService(client: client)
                let state = existingCafeState(for: remoteCafe.id)
                let summary = try await service.setCafeState(
                    userId: userId,
                    cafe: localCafe,
                    isFavorite: true,
                    wantToTry: state.wantToTry
                )
                dataManager.applyRemoteCafeState(summary)
                MugshotAnalytics.shared.capture(
                    .cafeStateChanged(
                        state: .favorite,
                        action: .added,
                        surface: .feed
                    )
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                dataManager.setCafeState(
                    cafeId: localCafe.id,
                    isFavorite: existingState.isFavorite,
                    wantToTry: existingState.wantToTry
                )
                socialRecoveryMessage = MugshotUserFacingError.message(for: error, context: .social)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            pendingSocialVisitIDs.remove(visit.id)
        }
    }

    private func existingCafeState(for remoteCafeId: UUID) -> (isFavorite: Bool, wantToTry: Bool) {
        guard let cafe = dataManager.appData.cafes.first(where: {
            $0.remoteCafeId == remoteCafeId || $0.id == remoteCafeId
        }) else {
            return (false, false)
        }

        return (cafe.isFavorite, cafe.wantToTry)
    }

    private func updateRemoteVisit(id: UUID, socialState: RemoteVisitSocialState) {
        guard let index = remoteVisits.firstIndex(where: { $0.id == id }) else {
            return
        }

        let visit = remoteVisits[index]
        remoteVisits[index] = RemoteVisitSummary(
            visit: visit.visit,
            cafe: visit.cafe,
            author: visit.author,
            socialState: socialState,
            rankingScore: visit.rankingScore,
            recommendationReason: visit.recommendationReason,
            recommendationReasonType: visit.recommendationReasonType,
            sessionSipCount: visit.sessionSipCount,
            cafePulseProjection: visit.cafePulseProjection,
            v3FeedProjection: visit.v3FeedProjection
        )
    }
}

private struct MugsySipCountPill: View {
    let value: Int

    var body: some View {
        HStack(spacing: 5) {
            MugsyModelView()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text("sips")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.foamWhite.opacity(0.86))
                .lineLimit(1)
        }
        .foregroundColor(.foamWhite)
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(Color.mugshotSage)
        .clipShape(Capsule())
        .shadow(
            color: DesignSystem.subtleShadow.color,
            radius: DesignSystem.subtleShadow.radius,
            x: DesignSystem.subtleShadow.x,
            y: DesignSystem.subtleShadow.y
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) total sips")
    }
}

struct RemoteFeedVisitCard: View {
    let visit: RemoteVisitSummary
    let isCafeSaved: Bool
    let isSocialActionInFlight: Bool
    let showsRecommendationReason: Bool
    let onOpen: () -> Void
    var onAuthorTap: (() -> Void)? = nil
    let onLike: () -> Void
    var onReaction: ((PostReactionKind) -> Void)? = nil
    let onSaveCafe: () -> Void
    let onComment: () -> Void

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var displayedScore: Double {
        visit.v3FeedProjection?.mugshotScore ?? visit.visit.overallScore
    }

    private var usesMugsyPhotoFallback: Bool {
        visit.v3FeedProjection?.usesMugsyPhotoFallback == true
    }

    var body: some View {
        MugshotFeedPostCard(
            presentation: MugshotFeedPostPresentation(
                visitID: visit.id,
                mediaSource: feedMediaSource,
                drinkName: visit.visit.drinkDisplayName,
                locationName: visit.locationTitle,
                locationDetail: visit.visit.journalContext == .cafe
                    ? MugshotPostLocationLine.locality(
                        address: visit.cafe?.address,
                        cityState: visit.visit.cityState,
                        city: visit.cafe?.city
                    )
                    : nil,
                score: displayedScore,
                caption: consumerPreviewCaption(visit.visit.caption),
                mentions: [],
                authorName: visit.authorDisplayName,
                username: visit.authorUsername,
                avatarURL: visit.author?.avatarURL,
                timestamp: timeAgoString(from: visit.visit.createdAtDate),
                authorBadge: nil,
                recommendation: showsRecommendationReason
                    ? visit.recommendationReason?.remoteTrimmedNonEmpty
                    : nil,
                recommendationSystemImage: recommendationIcon
            ),
            onOpen: onOpen,
            onAuthorTap: onAuthorTap
        ) {
            footer
        }
        .accessibilityIdentifier("feed.remoteVisitCard.\(visit.id.uuidString)")
    }

    private var feedMediaSource: MugshotPostMediaSource {
        guard let reference = visit.visit.posterPhotoURL?.remoteTrimmedNonEmpty else {
            return .placeholder(
                usesMugsyFallback: usesMugsyPhotoFallback,
                stableID: visit.id.uuidString
            )
        }
#if DEBUG
        if reference.hasPrefix("asset://") {
            return .asset(String(reference.dropFirst("asset://".count)))
        }
#endif
        return .remote(reference)
    }

    private var recommendationIcon: String {
        switch visit.recommendationReasonType {
        case "friend_activity": return "person.2.fill"
        case "taste_match": return "slider.horizontal.3"
        case "saved_cafe": return "bookmark.fill"
        case "journal_evidence": return "book.closed.fill"
        default: return "sparkles"
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(PostReactionKind.allCases) { reaction in
                    Button {
                        onReaction?(reaction)
                    } label: {
                        Label(reaction.title, systemImage: reaction.systemImage)
                    }
                }
            } label: {
                socialActionLabel(
                    value: visit.socialState.likeCount,
                    systemImage: visit.socialState.currentUserHasLiked ? "heart.fill" : "heart",
                    isActive: visit.socialState.currentUserHasLiked
                )
            } primaryAction: {
                onLike()
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)
            .accessibilityLabel(
                visit.socialState.currentUserHasLiked
                    ? "Remove reaction, \(visit.socialState.likeCount) reactions"
                    : "Like, \(visit.socialState.likeCount) reactions"
            )
            .accessibilityHint("Long press to choose Like, Love, Laugh, or Yummy")
            .accessibilityAction(named: Text("React with Like")) { onReaction?(.like) }
            .accessibilityAction(named: Text("React with Love")) { onReaction?(.love) }
            .accessibilityAction(named: Text("React with Laugh")) { onReaction?(.laugh) }
            .accessibilityAction(named: Text("React with Yummy")) { onReaction?(.yummy) }

            Button(action: onComment) {
                socialActionLabel(
                    value: visit.socialState.commentCount,
                    systemImage: "bubble.right",
                    isActive: false
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)
            .accessibilityLabel("Comment, \(visit.socialState.commentCount) comments")
            .accessibilityHint("Opens visit details and the comment field")

            if visit.visit.journalContext == .cafe, visit.cafe != nil {
                Button(action: onSaveCafe) {
                    socialActionLabel(
                        value: nil,
                        systemImage: isCafeSaved ? "bookmark.fill" : "bookmark",
                        isActive: isCafeSaved
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSocialActionInFlight)
                .accessibilityLabel(isCafeSaved ? "Cafe saved" : "Save cafe")
                .accessibilityHint(isCafeSaved ? "This cafe is in Saved" : "Adds this cafe to Saved")
            }

            Spacer(minLength: 0)

            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Text("Open")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(visit.visit.drinkDisplayName) at \(visit.locationTitle)")
            .accessibilityHint("Opens visit details")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private func socialActionLabel(value: Int?, systemImage: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))

            if let value {
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .foregroundColor(isActive ? .mugshotSage : .espressoBrown)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }

    private func timeAgoString(from date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

extension RemoteVisitSummary {
    func matchesFeedSearch(_ rawQuery: String) -> Bool {
        let normalizedQuery = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !normalizedQuery.isEmpty else { return true }

        let searchableText = [
            authorDisplayName,
            authorUsername,
            visit.drinkDisplayName,
            visit.caption,
            locationTitle,
            locationSubtitle ?? "",
            visit.contextDisplayName
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return normalizedQuery
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { searchableText.contains(String($0)) }
    }
}

struct RemoteFeedNoPhotoPoster: View {
    var usesMugsyFallback = false
    var stableID = "feed-no-photo"

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 20)

            MugsyModelView(
                configuration: MugsySceneResolver.scene(
                    for: usesMugsyFallback ? .missedSipPhoto : .sipMemory,
                    stableID: stableID
                ).configuration
            )
            .frame(width: 82, height: 84)
            .accessibilityHidden(true)

            Text(usesMugsyFallback ? "Mugsy kept the memory" : "Taste memory")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondaryText)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sandBeige.opacity(0.72))
    }
}

private func consumerPreviewCaption(_ caption: String) -> String? {
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

struct VisitCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    var onOpen: (() -> Void)? = nil
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        // For now, use current user. Later, fetch by visit.userId
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isCurrentUser: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.userId == currentUserId
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }

    private var localDisplayedScore: Double {
        visit.v3Reflection?.mugshotScore ?? visit.overallScore
    }

    var body: some View {
        MugshotFeedPostCard(
            presentation: MugshotFeedPostPresentation(
                visitID: visit.id,
                mediaSource: visit.posterImagePath.map(MugshotPostMediaSource.local)
                    ?? .placeholder(
                        usesMugsyFallback: visit.v3Reflection?.photoFallback == .mugsyMissedPhoto,
                        stableID: visit.id.uuidString
                    ),
                drinkName: localDrinkDisplayName,
                locationName: localLocationName,
                locationDetail: localLocationDetail,
                score: localDisplayedScore,
                caption: consumerPreviewCaption(visit.caption),
                mentions: visit.mentions,
                authorName: user?.displayNameOrUsername ?? user?.username ?? "Mugshot User",
                username: user?.username ?? "user",
                avatarURL: nil,
                timestamp: timeAgoString(from: visit.createdAt),
                authorBadge: isCurrentUser ? "You" : nil,
                recommendation: nil,
                recommendationSystemImage: "sparkles"
            ),
            onOpen: { onOpen?() }
        ) {
            localFooter
        }
        .accessibilityIdentifier("feed.localVisitCard.\(visit.id.uuidString)")
    }

    private var localLocationName: String {
        visit.context == .cafe
            ? cafe?.consumerDisplayName ?? "Cafe"
            : visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback
    }

    private var localLocationDetail: String? {
        guard visit.context == .cafe else { return nil }
        return MugshotPostLocationLine.locality(from: cafe?.address)
    }

    private var localFooter: some View {
        HStack(spacing: 14) {
            Button(action: {
                if let userId = dataManager.appData.currentUser?.id {
                    let action: MugshotAnalyticsMutationAction = isLiked
                        ? .removed
                        : .added
                    dataManager.toggleVisitLike(visit.id, userId: userId)
                    MugshotAnalytics.shared.capture(
                        .sipLiked(action: action, surface: .feed)
                    )
                }
            }) {
                localSocialLabel(value: visit.likeCount, systemImage: isLiked ? "heart.fill" : "heart", isActive: isLiked)
            }
            .buttonStyle(.plain)

            Button(action: { onOpen?() }) {
                localSocialLabel(value: visit.commentCount, systemImage: "bubble.right", isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comment, \(visit.commentCount) comments")

            Spacer(minLength: 0)

            if let onOpen {
                Button(action: onOpen) {
                    Text("Open")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open sip")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private var localDrinkDisplayName: String {
        visit.journalDrinkName
    }

    private func localSocialLabel(value: Int, systemImage: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(isActive ? .mugshotSage : .espressoBrown)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct VisitDetailView: View {
    @ObservedObject var dataManager: DataManager
    @State private var visit: Visit
    let presentationMode: SipDetailPresentationMode
    let onCafeRequested: ((Cafe) -> Void)?
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var selectedPhotoIndex = 0
    @FocusState private var isCommentFocused: Bool
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var showMoreActions = false
    @State private var toolbarProgress: CGFloat = 0
    @State private var photoViewerPresentation: SipDetailPhotoViewerPresentation?
    @State private var selectedCafeDetail: Cafe?
    
    init(
        visit: Visit,
        dataManager: DataManager,
        presentationMode: SipDetailPresentationMode = .pushed,
        onCafeRequested: ((Cafe) -> Void)? = nil
    ) {
        self._visit = State(initialValue: visit)
        self.dataManager = dataManager
        self.presentationMode = presentationMode
        self.onCafeRequested = onCafeRequested
    }
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }
    
    var comments: [Comment] {
        dataManager.getComments(for: visit.id)
    }
    
    @ViewBuilder
    var body: some View {
        if presentationMode == .postSave {
            NavigationStack { detailScene }
        } else {
            detailScene
        }
    }

    private var detailScene: some View {
        SipDetailScreen(
            presentation: sharedPresentation,
            selectedPhotoIndex: $selectedPhotoIndex,
            commentText: $commentText,
            toolbarProgress: $toolbarProgress,
            commentFocus: $isCommentFocused,
            isWorking: false,
            statusMessage: nil,
            mentionSuggestions: [],
            composerMentionTokens: [],
            onAction: perform,
            onSubmitComment: addComment,
            onReply: { _ in },
            onCommentAction: { _, _ in },
            onCancelReply: {},
            onSelectMention: { _ in },
            onPhotoTap: { index in
                let photos = sharedPresentation.content.photos
                guard photos.indices.contains(index) else { return }
                photoViewerPresentation = SipDetailPhotoViewerPresentation(
                    photos: photos,
                    initialIndex: index,
                    drinkName: sharedPresentation.content.drinkName,
                    locationName: sharedPresentation.content.locationName
                )
            },
            onCafeTap: cafe == nil ? nil : openLocalCafe,
            onRecipeAction: { _ in },
            onTaggedAccount: { _ in },
            onRemoveOwnTag: {}
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .mugshotBottomNavHidden()
        .toolbar { localDetailToolbar }
        .toolbarBackground(Color.creamWhite, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear(perform: refreshVisit)
        .sheet(isPresented: $showEdit) {
            SipDetailEditForm(
                summary: sharedPresentation.content,
                initialVisibility: visit.visibility,
                allowsPrivateNoteEditing: visit.v3Reflection == nil,
                onSave: saveLocalVisitEdits
            )
        }
        .sheet(isPresented: $showDeleteAlert) {
            SipDeleteConfirmationSheet(isDeleting: false, errorMessage: nil) {
                dataManager.deleteVisit(id: visit.id)
                dismiss()
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCafeDetail) { cafe in
            CafeDetailView(
                cafe: cafe,
                dataManager: dataManager,
                initialDetent: .medium
            )
        }
        .fullScreenCover(item: $photoViewerPresentation) { presentation in
            SipDetailPhotoViewer(presentation: presentation)
        }
        .confirmationDialog("Sip actions", isPresented: $showMoreActions, titleVisibility: .visible) {
            ForEach(sharedPresentation.capabilities.menuActions) { action in
                Button(action.title, role: action == .delete ? .destructive : nil) {
                    perform(action)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ToolbarContentBuilder
    private var localDetailToolbar: some ToolbarContent {
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
                drinkName: localDrinkDisplayName,
                progress: toolbarProgress
            )
        }

        ToolbarItem(placement: .topBarTrailing) {
            if isOwnVisit {
                Menu {
                    ForEach(sharedPresentation.capabilities.menuActions) { action in
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
                .accessibilityLabel("Sip actions")
            }
        }
    }

    private var sharedPresentation: SipDetailPresentation {
        SipDetailPresentationAdapter.local(
            visit: visit,
            cafe: cafe,
            user: user,
            comments: comments,
            isCafeSaved: cafe?.isFavorite == true
        )
    }

    private func openLocalCafe() {
        guard let cafe else { return }
        if let onCafeRequested {
            onCafeRequested(cafe)
        } else {
            selectedCafeDetail = cafe
        }
    }

    private func perform(_ action: SipDetailAction) {
        switch action {
        case .like:
            toggleLocalLike()
        case .comment, .share, .report, .block, .correctDrink, .repeatSip, .recommend:
            break
        case .saveCafe:
            toggleLocalCafeFavorite()
        case .more:
            showMoreActions = true
        case .edit:
            showEdit = true
        case .delete:
            showDeleteAlert = true
        }
    }

    @MainActor
    private func saveLocalVisitEdits(
        caption: String,
        notes: String,
        visibility: VisitVisibility
    ) async -> SipDetailEditSaveResult {
        var updated = visit
        updated.caption = caption
        updated.notes = notes.remoteTrimmedNonEmpty
        updated.visibility = visibility
        dataManager.updateVisit(updated)
        visit = updated
        return .success
    }

    private var isOwnVisit: Bool {
        dataManager.appData.currentUser?.id == visit.userId
    }

    private var localDrinkDisplayName: String {
        visit.journalDrinkName
    }

    private var localAuthorName: String {
        isOwnVisit ? "Your sip" : (user?.displayNameOrUsername ?? "Mugshot User")
    }

    private var localUsername: String {
        "@\(user?.username ?? "user")"
    }

    private var localTopControls: some View {
        HStack(spacing: 12) {
            SipTopBarButton(systemImage: "xmark") {
                dismiss()
            }
            .accessibilityLabel("Close sip")

            Spacer()

            if isOwnVisit {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit Sip", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
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
                .accessibilityLabel("Sip actions")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var localHeroSection: some View {
        ZStack(alignment: .bottomLeading) {
            localPhotoPager

            LinearGradient(
                colors: [
                    .black.opacity(0.02),
                    .black.opacity(0.18),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            SipMemoryHeroOverlay(
                authorTitle: localAuthorName,
                avatarName: user?.displayNameOrUsername ?? "User",
                username: localUsername,
                timestamp: SipDetailFormat.relative(visit.createdAt),
                drinkName: localDrinkDisplayName,
                locationTitle: visit.context == .cafe
                    ? (cafe?.consumerDisplayName ?? "Cafe")
                    : (visit.locationName?.remoteTrimmedNonEmpty ?? visit.context.locationFallback),
                locationSubtitle: cafe?.address.isEmpty == false ? cafe?.address : nil,
                score: visit.overallScore,
                visibilityLabel: localAudienceLabel,
                isOwnSip: isOwnVisit
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localDrinkDisplayName) at \(cafe?.consumerDisplayName ?? "Cafe"), rated \(visit.overallScore > 0 ? String(format: "%.1f", visit.overallScore) : "Unrated")")
    }

    @ViewBuilder
    private var localPhotoPager: some View {
        let orderedPhotos = getOrderedPhotos(for: visit)

        if orderedPhotos.isEmpty {
            SipEmptyPhotoBackdrop(
                title: "No photo saved",
                message: "This sip still has its taste memory, notes, and social thread.",
                stableID: visit.id.uuidString
            )
        } else {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(orderedPhotos.enumerated()), id: \.offset) { index, photoPath in
                    PhotoImageView(photoPath: photoPath)
                        .tag(index)
                        .overlay(alignment: .topTrailing) {
                            if orderedPhotos.count > 1 {
                                SipPhotoCountBadge(
                                    current: selectedPhotoIndex + 1,
                                    total: orderedPhotos.count
                                )
                                .padding(.top, 64)
                                .padding(.trailing, 18)
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: orderedPhotos.count > 1 ? .automatic : .never))
        }
    }

    private var localMemoryPanel: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    MugshotAvatar(name: user?.displayNameOrUsername ?? "User", size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isOwnVisit ? "Saved to your journal" : "Posted by \(user?.displayNameOrUsername ?? "Mugshot User")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)

                        Text(SipDetailFormat.timestamp(visit.createdAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }

                if let caption = consumerPreviewCaption(visit.caption) {
                    MentionText(text: caption, mentions: visit.mentions)
                        .font(.system(size: 17))
                        .foregroundColor(.espressoBrown.opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(isOwnVisit ? "No public tasting note yet." : "No tasting note was shared with this sip.")
                        .font(.system(size: 15))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SipTagGrid(tags: localTags)
            }
        }
    }

    private var localActionShelf: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sip actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.espressoBrown)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SipActionButton(
                        title: isLiked ? "Liked" : "Like",
                        value: "\(visit.likeCount)",
                        systemImage: isLiked ? "heart.fill" : "heart",
                        isActive: isLiked,
                        isEnabled: dataManager.appData.currentUser != nil
                    ) {
                        toggleLocalLike()
                    }

                        SipActionButton(
                        title: "Comment",
                        value: "\(visit.commentCount)",
                        systemImage: "bubble.right",
                        isActive: isCommentFocused,
                        isEnabled: dataManager.appData.currentUser != nil
                    ) {
                        isCommentFocused = true
                    }

                        if visit.context == .cafe, cafe != nil {
                            SipActionButton(
                            title: cafe?.isFavorite == true ? "Saved" : "Save",
                            value: nil,
                            systemImage: cafe?.isFavorite == true ? "bookmark.fill" : "bookmark",
                            isActive: cafe?.isFavorite == true,
                            isEnabled: true
                        ) {
                            toggleLocalCafeFavorite()
                        }

                        }

                        SipShareButton(
                        payload: SipShareCardPayload(
                            visitID: visit.id,
                            visibility: visit.visibility,
                            isOwner: user?.id == visit.userId,
                            isRemote: false,
                            authorName: user?.displayNameOrUsername ?? "Mugshot user",
                            authorUsername: user?.username,
                            drinkName: localDrinkDisplayName,
                            cafeName: cafe?.consumerDisplayName ?? visit.locationName ?? "Cafe",
                            locationDetail: visit.context == .cafe
                                ? MugshotPostLocationLine.locality(from: cafe?.address)
                                : nil,
                            rating: visit.overallScore,
                            date: visit.createdAt,
                            publicCaption: consumerPreviewCaption(visit.caption),
                            remotePhotoURL: nil,
                            localPhotoPath: visit.posterImagePath
                        )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var localPrivateNote: some View {
        if isOwnVisit,
           let notes = visit.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            SipPrivateNotePanel(text: notes)
        }
    }

    private var localCommentsSection: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Conversation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Spacer()

                    Text("\(visit.commentCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.espressoBrown.opacity(0.66))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.sandBeige.opacity(0.50))
                        .clipShape(Capsule())
                }

                if comments.isEmpty {
                    Text("No comments yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiaryText)
                        .padding(.vertical, 2)
                } else {
                    VStack(spacing: 10) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, dataManager: dataManager)
                        }
                    }
                }

                if dataManager.appData.currentUser != nil {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Add a thought", text: $commentText, axis: .vertical)
                            .mugshotFormField()
                            .focused($isCommentFocused)
                            .lineLimit(1...4)
                            .submitLabel(.send)

                        Button(action: addComment) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Post comment")
                    }
                }
            }
        }
    }

    private var localTags: [SipTag] {
        var tags = [
            SipTag(title: visit.visibility.rawValue, systemImage: visibilityIcon(for: visit.visibility), isActive: true),
            SipTag(title: visit.drinkType.rawValue, systemImage: "tag.fill", isActive: false)
        ]

        if localDrinkDisplayName != visit.drinkType.rawValue {
            tags.append(SipTag(title: localDrinkDisplayName, systemImage: "sparkles", isActive: false))
        }

        tags.append(SipTag(title: SipDetailFormat.relative(visit.createdAt), systemImage: "clock.fill", isActive: false))

        return tags
    }

    private var localAudienceLabel: String {
        if isOwnVisit {
            return visit.visibility.rawValue
        }

        switch visit.visibility {
        case .private:
            return "Private sip"
        case .friends:
            return "Friend sip"
        case .everyone:
            return "Public sip"
        }
    }

    private func refreshVisit() {
        if let updatedVisit = dataManager.getVisit(id: visit.id) {
            visit = updatedVisit
            selectedPhotoIndex = min(selectedPhotoIndex, max(0, getOrderedPhotos(for: updatedVisit).count - 1))
        }
    }

    private func toggleLocalLike() {
        guard let userId = dataManager.appData.currentUser?.id else {
            return
        }

        let action: MugshotAnalyticsMutationAction = visit.likedByUserIds.contains(userId)
            ? .removed
            : .added
        dataManager.toggleVisitLike(visit.id, userId: userId)
        MugshotAnalytics.shared.capture(
            .sipLiked(action: action, surface: .sipDetail)
        )
        refreshVisit()
    }

    private func toggleLocalCafeFavorite() {
        guard let cafe else {
            return
        }

        dataManager.setCafeState(
            cafeId: cafe.id,
            isFavorite: !cafe.isFavorite,
            wantToTry: cafe.wantToTry
        )
        MugshotAnalytics.shared.capture(
            .cafeStateChanged(
                state: .favorite,
                action: cafe.isFavorite ? .removed : .added,
                surface: .sipDetail
            )
        )
    }

    private func toggleLocalCafeWantToTry() {
        guard let cafe else {
            return
        }

        dataManager.setCafeState(
            cafeId: cafe.id,
            isFavorite: cafe.isFavorite,
            wantToTry: !cafe.wantToTry
        )
        MugshotAnalytics.shared.capture(
            .cafeStateChanged(
                state: .wantToTry,
                action: cafe.wantToTry ? .removed : .added,
                surface: .sipDetail
            )
        )
    }

    private func visibilityIcon(for visibility: VisitVisibility) -> String {
        switch visibility {
        case .private:
            return "lock.fill"
        case .friends:
            return "person.2.fill"
        case .everyone:
            return "globe"
        }
    }
    
    private func addComment() {
        guard let userId = dataManager.appData.currentUser?.id,
              !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        dataManager.addComment(to: visit.id, userId: userId, text: commentText)
        MugshotAnalytics.shared.capture(
            .commentAdded(surface: .sipDetail)
        )
        commentText = ""
        isCommentFocused = false
        
        // Refresh visit to get updated comments
        if let updatedVisit = dataManager.getVisit(id: visit.id) {
            visit = updatedVisit
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // Simple edit screen for a sip (caption, notes, ratings, visibility)
    struct EditVisitView: View {
        @Environment(\.dismiss) var dismiss
        @ObservedObject var dataManager: DataManager
        @State private var editableVisit: Visit
        var onSave: (Visit) -> Void
        
        init(visit: Visit, dataManager: DataManager, onSave: @escaping (Visit) -> Void) {
            self._editableVisit = State(initialValue: visit)
            self.dataManager = dataManager
            self.onSave = onSave
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Public note")
                            TextField("What should people remember?", text: $editableVisit.caption, axis: .vertical)
                                .lineLimit(3...6)
                                .mugshotFormField()
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Private note")
                            TextField("Only visible to you", text: Binding(get: { editableVisit.notes ?? "" }, set: { editableVisit.notes = $0 }), axis: .vertical)
                                .lineLimit(3...8)
                                .mugshotFormField()
                        }
                        
                        // Visibility
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Audience")
                            MugshotSegmentedControl(
                                options: [VisitVisibility.private, .friends, .everyone],
                                selection: $editableVisit.visibility,
                                title: { $0.rawValue },
                                icon: { visibilityIcon(for: $0) }
                            )
                        }
                    }
                    .padding()
                    .cardStyle(radius: DesignSystem.Radius.heroCard)
                    .padding()
                }
                .background(Color.creamWhite)
                .navigationTitle("Edit sip")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.espressoBrown)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dataManager.updateVisit(editableVisit)
                            onSave(editableVisit)
                            dismiss()
                        }
                        .foregroundColor(.mugshotMint)
                    }
                }
            }
        }

        private func visibilityIcon(for visibility: VisitVisibility) -> String {
            switch visibility {
            case .private:
                return "lock.fill"
            case .friends:
                return "person.2.fill"
            case .everyone:
                return "globe"
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to get ordered photos (poster first, then rest)
    private func getOrderedPhotos(for visit: Visit) -> [String] {
        guard !visit.photos.isEmpty else { return [] }
        
        var ordered = visit.photos
        if let posterPath = visit.posterImagePath,
           let posterIndex = ordered.firstIndex(of: posterPath) {
            // Move poster to front
            ordered.remove(at: posterIndex)
            ordered.insert(posterPath, at: 0)
        }
        return ordered
    }
}

struct CommentRow: View {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    
    var user: User? {
        // For now, use current user. Later, fetch by comment.userId
        dataManager.appData.currentUser?.id == comment.userId ? dataManager.appData.currentUser : nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: user?.username ?? "User", size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user?.username ?? "user")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                MentionText(text: comment.text, mentions: comment.mentions)
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
                
                Text(timeAgoString(from: comment.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.sandBeige.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
