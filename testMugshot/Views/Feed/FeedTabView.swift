//
//  FeedTabView.swift
//  testMugshot
//
//  Redesigned feed with coffee-first information hierarchy
//

import SwiftUI

struct FeedTabView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var tabCoordinator: TabCoordinator
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var selectedScope: FeedScope = .friends
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showNotifications = false
    @State private var isRefreshing = false
    @State private var refreshRotation: Double = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    private var showStickyHeader: Bool {
        scrollOffset < -50 // Show sticky header when scrolled down
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Mint background extends to top of screen
                DS.Colors.appBarBackground
                    .ignoresSafeArea()
                
                // Main scrollable content with pull-to-refresh
                ScrollView {
                    VStack(spacing: 0) {
                        // Header section (scrolls with content)
                        feedHeader
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                        .onAppear {
                                            headerHeight = geometry.size.height
                                        }
                                }
                            )
                        
                        // Refresh indicator
                        if isRefreshing {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(DS.Colors.primaryAccent)
                                    .rotationEffect(.degrees(refreshRotation))
                                Text("Refreshing...")
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            .transition(.opacity.combined(with: .scale))
                        }
                        
                        // Feed content with white background
                        if selectedScope == .discover {
                            // Discover content (Social Radar + Guides + Spin)
                            DiscoverContentView(
                                dataManager: dataManager,
                                onCafeTap: { cafe in
                                    selectedCafe = cafe
                                }
                            )
                            .padding(.bottom, DS.Spacing.xxl * 2)
                            .background(DS.Colors.screenBackground)
                        } else {
                            // Standard feed (Friends / Everyone)
                            if dataManager.isBootstrapping && visits.isEmpty {
                                VStack(spacing: DS.Spacing.lg) {
                                    ForEach(0..<3) { _ in
                                        DSFeedPostSkeleton()
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.pagePadding)
                                .padding(.top, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.xxl * 2)
                                .background(DS.Colors.screenBackground)
                            } else if visits.isEmpty && selectedScope == .friends {
                                // Empty state for Friends tab
                                friendsEmptyState
                                    .padding(.bottom, DS.Spacing.xxl * 2)
                                    .background(DS.Colors.screenBackground)
                            } else {
                                // PERF: LazyVStack ensures views are only created when visible
                                // Each VisitCard is an independent view with stable .id() for better performance
                                LazyVStack(spacing: DS.Spacing.lg) {
                                    ForEach(visits) { visit in
                                        VisitCard(
                                            visit: visit,
                                            dataManager: dataManager,
                                            selectedScope: selectedScope,
                                            onCafeTap: {
                                                print("🔵 [FeedTabView] Cafe pill tapped for visit: \(visit.id)")
                                                print("🔵 [FeedTabView] visit.cafeId: \(visit.cafeId)")
                                                if let cafe = dataManager.getCafe(id: visit.cafeId) {
                                                    print("🔵 [FeedTabView] Found cafe: '\(cafe.name)' with id: \(cafe.id)")
                                                    selectedCafe = cafe
                                                    print("🔵 [FeedTabView] selectedCafe set to: \(selectedCafe?.name ?? "nil")")
                                                } else {
                                                    print("🔴 [FeedTabView] getCafe returned nil for cafeId: \(visit.cafeId)")
                                                }
                                            },
                                            onAuthorTap: {
                                                if isCurrentUser(
                                                    supabaseUserId: visit.supabaseUserId,
                                                    localUserId: visit.userId
                                                ) {
                                                    tabCoordinator.switchToProfile()
                                                    return
                                                }
                                                if let supabaseUserId = visit.supabaseUserId {
                                                    // Extract plain username (strip @ if present)
                                                    let plainUsername = visit.authorUsername?.hasPrefix("@") == true
                                                        ? String(visit.authorUsername!.dropFirst())
                                                        : visit.authorUsername
                                                    profileNavigator.openProfile(
                                                        handle: .supabase(
                                                            id: supabaseUserId,
                                                            username: plainUsername
                                                        ),
                                                        source: .feedAuthor,
                                                        triggerHaptic: false
                                                    )
                                                } else if let username = visit.authorUsername {
                                                    // Extract plain username (strip @ if present)
                                                    let plainUsername = username.hasPrefix("@") ? String(username.dropFirst()) : username
                                                    profileNavigator.openProfile(
                                                        handle: .mention(username: plainUsername),
                                                        source: .feedAuthor,
                                                        triggerHaptic: false
                                                    )
                                                }
                                            },
                                            onCommentTap: {
                                                // Open the visit detail view and let the user comment there
                                                hapticsManager.lightTap()
                                                selectedVisit = visit
                                            },
                                            onMentionTap: { username in
                                                profileNavigator.openProfile(
                                                    handle: .mention(username: username),
                                                    source: .mentionCaption,
                                                    triggerHaptic: true
                                                )
                                            }
                                        )
                                        .onTapGesture {
                                            hapticsManager.lightTap()
                                            selectedVisit = visit
                                        }
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.pagePadding)
                                .padding(.top, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.xxl * 2)
                                .background(DS.Colors.screenBackground)
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .refreshable {
                    await performRefresh()
                }
                
                // Sticky header (appears when scrolled down)
                if showStickyHeader {
                    stickyHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showStickyHeader)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(item: $selectedCafe) { cafe in
                UnifiedCafeView(
                    cafe: cafe,
                    dataManager: dataManager,
                    presentationMode: .fullScreen
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    notificationButton
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsCenterView(dataManager: dataManager)
            }
        }
        .task {
            // Don't refresh feed for discover scope (it uses local data)
            if selectedScope != .discover {
                await dataManager.refreshFeed(scope: selectedScope)
            }
        }
        .onChange(of: selectedScope) { _, newScope in
            // Don't refresh feed for discover scope (it uses local data)
            if newScope != .discover {
                Task {
                    await dataManager.refreshFeed(scope: newScope)
                }
            }
        }
        .onChange(of: tabCoordinator.navigationTarget) { _, target in
            handleNavigationTarget(target)
        }
        .onAppear {
            if let target = tabCoordinator.navigationTarget {
                handleNavigationTarget(target)
            }
        }
    }
    
    // MARK: - Refresh
    
    private func performRefresh() async {
        print("[Feed] Refresh triggered via pull-to-refresh")
        
        // Start animation
        withAnimation(.easeInOut(duration: 0.2)) {
            isRefreshing = true
        }
        
        // Animate the refresh icon rotation
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            refreshRotation = 360
        }
        
        // Perform the actual refresh
        await dataManager.refreshFeed(scope: selectedScope)
        
        // Stop animation
        withAnimation(.easeInOut(duration: 0.2)) {
            isRefreshing = false
            refreshRotation = 0
        }
    }
    
    // MARK: - Header Components
    
    private var feedHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Feed")
                .font(DS.Typography.screenTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("Sips from the community")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            
            HStack {
                Spacer()
                DSDesignSegmentedControl(
                    options: FeedScope.allCases.map { $0.displayName },
                    selectedIndex: Binding(
                        get: { FeedScope.allCases.firstIndex(of: selectedScope) ?? 0 },
                        set: { newIndex in
                            let newScope = FeedScope.allCases[newIndex]
                            if newScope != selectedScope {
                                hapticsManager.selectionChanged()
                            }
                            selectedScope = newScope
                        }
                    )
                )
                Spacer()
            }
            .padding(.top, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }
    
    private var stickyHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Feed")
                .font(DS.Typography.headline(.bold))
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("Sips from the community")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.sm)
        .background(.ultraThinMaterial)
        .background(DS.Colors.appBarBackground.opacity(0.85))
        .overlay(
            Rectangle()
                .fill(DS.Colors.dividerSubtle)
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }
    
    private var notificationButton: some View {
        Button(action: { showNotifications = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .foregroundColor(DS.Colors.iconDefault)
                
                if unreadNotificationCount > 0 {
                    Text("\(unreadNotificationCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DS.Colors.textOnMint)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(DS.Colors.primaryAccent)
                        )
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    private func handleNavigationTarget(_ target: TabCoordinator.NavigationTarget?) {
        guard let target = target else { return }
        
        switch target {
        case .visitDetail(let visitId):
            if let visit = visits.first(where: { $0.id == visitId || $0.supabaseId == visitId }) {
                selectedVisit = visit
            } else {
                Task {
                    await dataManager.refreshFeed(scope: selectedScope)
                    if let visit = dataManager.getVisit(id: visitId) {
                        await MainActor.run {
                            selectedVisit = visit
                        }
                    } else {
                        print("⚠️ [Push] Could not find visit with id: \(visitId)")
                    }
                }
            }
            tabCoordinator.clearNavigationTarget()
            
        case .friendProfile(let userId):
            profileNavigator.openProfile(
                handle: .supabase(id: userId),
                source: .notifications,
                triggerHaptic: false
            )
            tabCoordinator.clearNavigationTarget()
            
        case .friendsFeed:
            selectedScope = .friends
            Task {
                await dataManager.refreshFeed(scope: .friends)
            }
            tabCoordinator.clearNavigationTarget()
            
        case .notifications:
            showNotifications = true
            tabCoordinator.clearNavigationTarget()
            
        case .friendRequests:
            // Friend requests are handled by ProfileTabView, not FeedTabView
            // Just clear the target to avoid infinite loops
            tabCoordinator.clearNavigationTarget()
            
        case .friendsHub:
            // Friends hub is handled by ProfileTabView, not FeedTabView
            // Just clear the target to avoid infinite loops
            tabCoordinator.clearNavigationTarget()
        }
    }
    
    private var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else {
            return []
        }
        return dataManager.getFeedVisits(scope: selectedScope, currentUserId: currentUserId)
    }
    
    private func isCurrentUser(supabaseUserId: String?, localUserId: UUID) -> Bool {
        if let currentLocalId = dataManager.appData.currentUser?.id,
           currentLocalId == localUserId {
            return true
        }
        if let currentSupabaseId = dataManager.appData.supabaseUserId,
           let supabaseUserId {
            return currentSupabaseId == supabaseUserId
        }
        return false
    }
    
    // MARK: - Empty States
    
    private var friendsEmptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: DS.Spacing.lg) {
                // Illustration
                Image("MugsyNoFriends")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)
                
                // Text content
                VStack(spacing: DS.Spacing.sm) {
                    Text("No friends yet")
                        .font(DS.Typography.title2())
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Connect with friends to see their sips in your feed.")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                }
                
                // CTA button
                Button(action: {
                    hapticsManager.lightTap()
                    tabCoordinator.navigateToFriendsHub()
                }) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Find Friends")
                            .font(DS.Typography.buttonLabel)
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .frame(maxWidth: 280)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.primaryAccent)
                    .cornerRadius(DS.Radius.primaryButton)
                }
                .padding(.top, DS.Spacing.md)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.screenBackground)
    }
}

// MARK: - Redesigned Visit Card

struct VisitCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let selectedScope: FeedScope
    var onCafeTap: (() -> Void)? = nil
    var onAuthorTap: (() -> Void)? = nil
    var onCommentTap: (() -> Void)? = nil
    var onMentionTap: ((String) -> Void)? = nil
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    private var isLikedByCurrentUser: Bool {
        if let userId = dataManager.appData.currentUser?.id {
            return visit.isLikedBy(userId: userId)
        }
        return false
    }
    
    private var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    private var isBookmarked: Bool {
        guard let cafe = cafe else { return false }
        return cafe.wantToTry
    }
    
    private var authorProfileImage: UIImage? {
        guard let currentUser = dataManager.appData.currentUser,
              currentUser.id == visit.userId,
              let imageId = dataManager.appData.currentUserProfileImageId else {
            return nil
        }
        return PhotoCache.shared.retrieve(forKey: imageId)
    }
    
    private var authorRemoteAvatarURL: String? {
        if let currentUser = dataManager.appData.currentUser,
           currentUser.id == visit.userId {
            return dataManager.appData.currentUserAvatarURL
        }
        return visit.authorAvatarURL
    }
    
    private var authorName: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return user.displayNameOrUsername
        }
        return visit.authorDisplayNameOrUsername
    }
    
    private var authorInitials: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return String(user.displayNameOrUsername.prefix(1)).uppercased()
        }
        return visit.authorInitials
    }
    
    private var cafeName: String? {
        dataManager.getCafe(id: visit.cafeId)?.name
    }
    
    var body: some View {
        DSBaseCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Avatar, Name, Time, Score
                headerSection
                
                // Cafe attribution and drink info (stacked vertically for clarity)
                VStack(alignment: .leading, spacing: 4) {
                    // Cafe pill - primary location context
                    if let name = cafeName, !name.isEmpty {
                        DSCafeAttributionPill(cafeName: name) {
                            onCafeTap?()
                        }
                    }
                    
                    // Drink info - secondary metadata with icon
                    HStack(spacing: 4) {
                        Image(systemName: drinkIconForType(visit.drinkType))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        Text(visit.drinkDisplayText)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, DS.Spacing.cardPadding)
                .padding(.top, DS.Spacing.xs)
                
                // Caption (above image for context)
                if !visit.caption.isEmpty {
                    MentionText(
                        text: visit.caption,
                        mentions: visit.mentions,
                        onMentionTap: onMentionTap
                    )
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(3)
                        .padding(.horizontal, DS.Spacing.cardPadding)
                        .padding(.top, DS.Spacing.md)
                }
                
                // Photo carousel
                if !visit.photos.isEmpty {
                    MugshotImageCarousel(
                        photoPaths: visit.photos,
                        remotePhotoURLs: visit.remotePhotoURLByKey,
                        height: 320,
                        cornerRadius: 0,
                        showIndicators: true
                    )
                    .padding(.top, DS.Spacing.md)
                }
                
                // Social actions bar
                socialActionsBar
                    .padding(.horizontal, DS.Spacing.cardPadding)
                    .padding(.vertical, DS.Spacing.md)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            // Tappable author avatar + name + time
            Button(action: { onAuthorTap?() }) {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    // Avatar (48pt for better presence)
                    FeedAvatarView(
                        image: authorProfileImage,
                        remoteURL: authorRemoteAvatarURL,
                        initials: authorInitials,
                        size: 48
                    )
                    
                    // Name and timestamp on same row
                    HStack(spacing: 0) {
                        Text(authorName)
                            .font(DS.Typography.headline())
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(" · ")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        Text(timeAgoString(from: visit.createdAt))
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Score badge (slightly larger)
            DSScoreBadge(score: visit.overallScore)
        }
        .padding(.horizontal, DS.Spacing.cardPadding)
        .padding(.top, DS.Spacing.cardPadding)
    }
    
    // MARK: - Social Actions Bar
    
    private var socialActionsBar: some View {
        HStack(spacing: 0) {
            // Like button
            LikeButton(
                isLiked: isLikedByCurrentUser,
                likeCount: visit.likeCount,
                onToggle: {
                    Task {
                        await dataManager.toggleVisitLike(visit.id)
                    }
                }
            )
            
            // Comment button
            Button(action: {
                hapticsManager.lightTap()
                onCommentTap?()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DS.Colors.iconDefault)
                    Text("\(visit.comments.count)")
                        .font(DS.Typography.subheadline(.medium))
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, DS.Spacing.md)
            
            Spacer()
            
            // Bookmark button
            Button(action: {
                hapticsManager.lightTap()
                if let cafe = cafe {
                    dataManager.toggleCafeWantToTry(cafe: cafe)
                } else {
                    // If cafe doesn't exist in local list, we need to get it from the visit
                    // This shouldn't happen normally, but handle gracefully
                    print("⚠️ [VisitCard] Cannot bookmark: cafe not found in local list")
                }
            }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(isBookmarked ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
                    .scaleEffect(isBookmarked ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isBookmarked)
            }
            .buttonStyle(.plain)
        }
    }
    
    // PERFORMANCE: Static formatter to avoid creating new ones on every render
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    private func timeAgoString(from date: Date) -> String {
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func drinkIconForType(_ type: DrinkType) -> String {
        switch type {
        case .coffee:
            return "cup.and.saucer.fill"
        case .matcha, .hojicha, .tea:
            return "leaf.fill"
        case .chai:
            return "flame.fill"
        case .hotChocolate:
            return "mug.fill"
        case .other:
            return "drop.fill"
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Feed Avatar View

private struct FeedAvatarView: View {
    let image: UIImage?
    let remoteURL: String?
    let initials: String
    let size: CGFloat
    
    var body: some View {
        CachedAvatarImage(
            image: image,
            imageURL: remoteURL,
            cacheNamespace: "feed-avatar"
        ) {
            placeholder
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 2)
        )
        .shadow(color: DS.Shadow.cardSoft.color.opacity(0.4),
                radius: 4,
                x: 0,
                y: 2)
    }
    
    private var placeholder: some View {
        Circle()
            .fill(DS.Colors.primaryAccent)
            .overlay(
                Text(initials.prefix(2))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
}

