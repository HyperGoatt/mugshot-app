//
//  FeedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct FeedTabView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedScope: FeedScope = .friends
    @State private var selectedVisit: Visit?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var showNotifications = false
    @State private var scrollOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    
    private var unreadNotificationCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    private var showStickyHeader: Bool {
        scrollOffset > headerHeight - 20 // Show sticky header when scrolled past header
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                                        set: { selectedScope = FeedScope.allCases[$0] }
                                    )
                                )
                                Spacer()
                            }
                            .padding(.top, DS.Spacing.md)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.appBarBackground)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                    .onAppear {
                                        headerHeight = geometry.size.height
                                    }
                            }
                        )
                        
                        LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                            ForEach(visits) { visit in
                                VisitCard(
                                    visit: visit,
                                    dataManager: dataManager,
                                    selectedScope: selectedScope,
                                    onCafeTap: {
                                        if let cafe = dataManager.getCafe(id: visit.cafeId) {
                                            selectedCafe = cafe
                                            showCafeDetail = true
                                        }
                                    }
                                )
                                .onTapGesture {
                                    selectedVisit = visit
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.xxl)
                        .background(DS.Colors.screenBackground)
                    }
                    .background(DS.Colors.screenBackground)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                
                if showStickyHeader {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("Feed")
                                .font(DS.Typography.screenTitle)
                                .foregroundColor(DS.Colors.textPrimary)
                            
                            Spacer()
                            
                            DSDesignSegmentedControl(
                                options: FeedScope.allCases.map { $0.displayName },
                                selectedIndex: Binding(
                                    get: { FeedScope.allCases.firstIndex(of: selectedScope) ?? 0 },
                                    set: { selectedScope = FeedScope.allCases[$0] }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.appBarBackground)
                    .shadow(color: DS.Shadow.cardSoft.color.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: showStickyHeader)
                }
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .sheet(isPresented: $showCafeDetail) {
                if let cafe = selectedCafe {
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsCenterView(dataManager: dataManager)
            }
        }
    }
    
    private var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else {
            return []
        }
        return dataManager.getFeedVisits(scope: selectedScope, currentUserId: currentUserId)
    }
}

// MARK: - Visit Card

struct VisitCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let selectedScope: FeedScope
    var onCafeTap: (() -> Void)? = nil
    
    private var isLikedByCurrentUser: Bool {
        if let userId = dataManager.appData.currentUser?.id {
            return visit.isLikedBy(userId: userId)
        }
        return false
    }
    
    private var authorProfileImage: UIImage? {
        guard let currentUser = dataManager.appData.currentUser,
              currentUser.id == visit.userId,
              let imageId = dataManager.appData.currentUserProfileImageId else {
            return nil
        }
        return PhotoCache.shared.retrieve(forKey: imageId)
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .center, spacing: DS.Spacing.sm) {
                        FeedAvatarView(
                            image: authorProfileImage,
                            initials: getUserInitials(),
                            size: 44
                        )
                        
                        Text(getUserName())
                            .font(DS.Typography.headline())
                                .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        DSScoreBadge(score: visit.overallScore)
                    }
                    
                    if let cafeName = dataManager.getCafe(id: visit.cafeId)?.name, !cafeName.isEmpty {
                        Button(action: {
                            onCafeTap?()
                        }) {
                            Text(cafeName)
                                    .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.primaryAccent)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(timeAgoString(from: visit.createdAt))
                        .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.md)
                
                // Media carousel
                if !visit.photos.isEmpty {
                    MugshotImageCarousel(
                        photoPaths: visit.photos,
                        height: 280,
                        cornerRadius: DS.Radius.lg
                    )
                    .padding(.top, DS.Spacing.sm)
                }
                
                // Caption with mentions
                if !visit.caption.isEmpty {
                    MentionText(text: visit.caption, mentions: visit.mentions)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        .padding(.top, DS.Spacing.sm)
                }
                
                // Social row: likes, comments, share
                    HStack(spacing: DS.Spacing.lg) {
                    LikeButton(
                        isLiked: isLikedByCurrentUser,
                        likeCount: visit.likeCount,
                        onToggle: {
                        if let userId = dataManager.appData.currentUser?.id {
                            dataManager.toggleVisitLike(visit.id, userId: userId)
                        }
                        }
                    )
                    
                    Button(action: {}) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16))
                                .foregroundColor(DS.Colors.iconDefault)
                            Text("\(visit.comments.count)")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(DS.Colors.iconDefault)
                    }
                }
                .padding(.top, DS.Spacing.md)
            }
        }
    }
    
    private func getUserName() -> String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return user.displayNameOrUsername
        }
        // For now, return a placeholder - in a real app, you'd fetch the user
        return "User"
    }
    
    private func getUserInitials() -> String {
        getUserName().prefix(1).uppercased()
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct FeedAvatarView: View {
    let image: UIImage?
    let initials: String
    let size: CGFloat
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .overlay(
                        Text(initials.prefix(2))
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.textOnMint)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 2)
        )
        .shadow(color: DS.Shadow.cardSoft.color.opacity(0.5),
                radius: DS.Shadow.cardSoft.radius / 2,
                x: DS.Shadow.cardSoft.x,
                y: DS.Shadow.cardSoft.y / 2)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
