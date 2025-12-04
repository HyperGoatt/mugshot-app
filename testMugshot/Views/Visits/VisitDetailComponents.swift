//
//  VisitDetailComponents.swift
//  testMugshot
//
//  Modern, Instagram-inspired components for Visit Detail view.
//  Follows Mugshot design system with streamlined UX patterns.
//

import SwiftUI
import UIKit

// MARK: - Streamlined Header

/// Simplified header showing avatar, name, time, and username
/// Score badge moved to image overlay for content-first hierarchy
struct VisitDetailHeader: View {
    let displayName: String
    let username: String
    let timeAgo: String
    let avatarImage: UIImage?
    let remoteAvatarURL: String?
    let initials: String
    let isCurrentUserAuthor: Bool
    var onMenuTap: (() -> Void)? = nil
    var onAvatarTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            // Avatar
            VisitAvatarView(
                image: avatarImage,
                remoteURL: remoteAvatarURL,
                initials: initials,
                size: 44,
                onTap: onAvatarTap
            )
            
            // Name and metadata
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(displayName)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(" · ")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Text(timeAgo)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Text(username)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            // Menu button (only for author)
            if isCurrentUserAuthor {
                Button(action: { onMenuTap?() }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Avatar View

struct VisitAvatarView: View {
    let image: UIImage?
    let remoteURL: String?
    let initials: String
    let size: CGFloat
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        CachedAvatarImage(
            image: image,
            imageURL: remoteURL,
            cacheNamespace: "visit-avatar"
        ) {
            placeholder
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 2)
        )
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
    }
    
    private var placeholder: some View {
        Circle()
            .fill(DS.Colors.primaryAccent)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
}

// MARK: - Photo Carousel with Score Overlay

/// Image carousel with glassmorphism score badge overlaid in top-right
struct PhotoCarouselWithScore: View {
    let photoPaths: [String]
    let remotePhotoURLs: [String: String]
    let score: Double
    let height: CGFloat
    
    @State private var currentIndex: Int = 0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo carousel
            if photoPaths.isEmpty {
                placeholderImage
            } else {
                ZStack(alignment: .bottom) {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photoPaths.enumerated()), id: \.offset) { index, path in
                            PhotoImageView(photoPath: path, remoteURL: remotePhotoURLs[path])
                                .frame(maxWidth: .infinity)
                                .frame(height: height)
                                .background(DS.Colors.cardBackgroundAlt)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: height)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentIndex)
                    
                    // Page indicators
                    if photoPaths.count > 1 {
                        pageIndicators
                    }
                }
            }
            
            // Score badge overlay with glassmorphism
            GlassmorphicScoreBadge(score: score)
                .padding(.top, DS.Spacing.md)
                .padding(.trailing, DS.Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .dsCardShadow()
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: DS.Radius.xl)
            .fill(DS.Colors.cardBackgroundAlt)
            .frame(height: height)
            .overlay(
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(DS.Colors.iconSubtle)
                    Text("No photos")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            )
    }
    
    private var pageIndicators: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                // Gradient fade for visibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
                
                HStack(spacing: 6) {
                    ForEach(photoPaths.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(
                                width: index == currentIndex ? 8 : 6,
                                height: index == currentIndex ? 8 : 6
                            )
                            .animation(.easeInOut(duration: 0.15), value: currentIndex)
                    }
                }
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }
}

// MARK: - Glassmorphic Score Badge

struct GlassmorphicScoreBadge: View {
    let score: Double
    
    private var scoreText: String {
        String(format: "%.1f", score)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(scoreText)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.pill)
                        .fill(Color.black.opacity(0.2))
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Inline Social Actions

/// Social action bar without card wrapper - sits directly below image
struct InlineSocialActions: View {
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let isBookmarked: Bool
    var showShareButton: Bool = false // Only show share button for own posts
    var onLikeTap: (() -> Void)? = nil
    var onCommentTap: (() -> Void)? = nil
    var onBookmarkTap: (() -> Void)? = nil
    var onShareTap: (() -> Void)? = nil
    
    @StateObject private var hapticsManager = HapticsManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Like button reuses the shared animated component for consistency
            LikeButton(
                isLiked: isLiked,
                likeCount: likeCount,
                onToggle: {
                    #if DEBUG
                    print("❤️ [VisitDetail] Like button tapped - isLiked=\(isLiked) likeCount=\(likeCount)")
                    #endif
                    onLikeTap?()
                }
            )
            .padding(.trailing, DS.Spacing.sm)
            
            // Comment button
            Button(action: { onCommentTap?() }) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DS.Colors.iconDefault)
                    
                    if commentCount > 0 {
                        Text("\(commentCount)")
                            .font(DS.Typography.subheadline(.medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, DS.Spacing.sm)
            
            Spacer()
            
            // Bookmark button
            Button(action: {
                hapticsManager.lightTap()
                onBookmarkTap?()
            }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isBookmarked ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            // Share button - only visible for own posts
            if showShareButton {
                Button(action: { onShareTap?() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DS.Colors.iconDefault)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Drink Type Pill

struct DrinkTypePill: View {
    let drinkType: DrinkType
    let customDrinkType: String?
    
    private var displayText: String {
        let trimmedCustom = customDrinkType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if drinkType == .other {
            return trimmedCustom.isEmpty ? "Other" : trimmedCustom
        }
        
        if !trimmedCustom.isEmpty {
            return "\(drinkType.rawValue) · \(trimmedCustom)"
        }
        return drinkType.rawValue
    }
    
    private var icon: String {
        switch drinkType {
        case .coffee: return "cup.and.saucer.fill"
        case .matcha, .tea, .hojicha: return "leaf.fill"
        case .chai: return "flame.fill"
        case .hotChocolate: return "mug.fill"
        case .other: return "drop.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(displayText)
                .font(DS.Typography.subheadline(.medium))
        }
        .foregroundColor(DS.Colors.textOnMint)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.mintSoftFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(DS.Colors.primaryAccent.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Compact Rating Grid

/// 2x2 grid layout with dot-based rating indicators
struct CompactRatingGrid: View {
    let ratings: [String: Double]
    
    private var sortedRatings: [(String, Double)] {
        ratings.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: DS.Spacing.lg),
            GridItem(.flexible(), spacing: DS.Spacing.lg)
        ]
        
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(sortedRatings, id: \.0) { key, value in
                CompactRatingRow(title: key, value: value)
            }
        }
    }
}

struct CompactRatingRow: View {
    let title: String
    let value: Double
    
    private var clampedValue: Double {
        min(max(value, 0), 5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DS.Typography.caption1(.medium))
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(1)
            
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    RatingStar(state: starState(for: index))
                }
            }
        }
    }
    
    private func starState(for index: Int) -> RatingStar.FillState {
        let threshold = Double(index)
        
        if clampedValue >= threshold {
            return .full
        } else if clampedValue >= threshold - 0.5 {
            return .half
        } else {
            return .empty
        }
    }
}

struct RatingStar: View {
    enum FillState {
        case empty
        case half
        case full
    }
    
    let state: FillState
    
    private var symbolName: String {
        switch state {
        case .full:
            return "star.fill"
        case .half:
            return "star.leadinghalf.filled"
        case .empty:
            return "star"
        }
    }
    
    private var color: Color {
        switch state {
        case .full, .half:
            return DS.Colors.primaryAccent
        case .empty:
            return DS.Colors.iconSubtle.opacity(0.4)
        }
    }
    
    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
    }
}

// MARK: - Review Summary Card

/// Combines drink type and compact ratings in one card
struct ReviewSummaryCard: View {
    let drinkType: DrinkType
    let customDrinkType: String?
    let ratings: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Drink pill
            DrinkTypePill(drinkType: drinkType, customDrinkType: customDrinkType)
            
            // Ratings grid
            if !ratings.isEmpty {
                CompactRatingGrid(ratings: ratings)
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Colors.borderSubtle.opacity(0.4), lineWidth: 0.5)
        )
        .dsCardShadow()
    }
}

// MARK: - Collapsible Private Notes

struct CollapsiblePrivateNotes: View {
    let notes: String
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Text("Private Notes")
                        .font(DS.Typography.subheadline(.medium))
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.cardPadding)
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if isExpanded {
                Text(notes)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.cardPadding)
                    .padding(.bottom, DS.Spacing.cardPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Colors.borderSubtle.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Inline Comments Section

struct InlineCommentsSection: View {
    let comments: [Comment]
    @Binding var commentText: String
    let dataManager: DataManager
    let newlyAddedCommentIds: Set<UUID>
    var onPostComment: (() -> Void)? = nil
    var onEditComment: ((Comment) -> Void)? = nil
    var onDeleteComment: ((Comment) -> Void)? = nil
    var isCommentFieldFocused: FocusState<Bool>.Binding
    
    // Mention autocomplete state
    @State private var showMentionAutocomplete = false
    @State private var mentionSearchText = ""
    @State private var friendProfiles: [RemoteUserProfile] = []
    
    private var filteredFriends: [RemoteUserProfile] {
        guard !mentionSearchText.isEmpty else { return friendProfiles }
        let searchLower = mentionSearchText.lowercased()
        return friendProfiles.filter { profile in
            profile.username.lowercased().contains(searchLower) ||
            profile.displayName.lowercased().contains(searchLower)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack {
                Text("Comments")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if !comments.isEmpty {
                    Text("(\(comments.count))")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Comments list
            if comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.vertical, DS.Spacing.sm)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(comments) { comment in
                        InlineCommentRow(
                            comment: comment,
                            dataManager: dataManager,
                            isNewlyAdded: newlyAddedCommentIds.contains(comment.id),
                            onEdit: onEditComment,
                            onDelete: onDeleteComment
                        )
                        .id(comment.id)
                        // Swipe actions only for comments authored by the current user
                        .modifier(CommentSwipeActionsModifier(
                            comment: comment,
                            dataManager: dataManager,
                            onEdit: onEditComment,
                            onDelete: onDeleteComment
                        ))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: comments.count)
            }
            
            // Mention autocomplete dropdown
            if showMentionAutocomplete && !filteredFriends.isEmpty {
                MentionAutocompleteDropdown(
                    friends: filteredFriends,
                    onSelect: { profile in
                        insertMention(username: profile.username)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Comment input
            HStack(spacing: DS.Spacing.sm) {
                TextField("Add a comment...", text: $commentText)
                    .font(DS.Typography.bodyText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.cardBackgroundAlt)
                    .cornerRadius(DS.Radius.pill)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.pill)
                            .stroke(DS.Colors.borderSubtle.opacity(0.5), lineWidth: 1)
                    )
                    .focused(isCommentFieldFocused)
                    .onChange(of: commentText) { _, newValue in
                        checkForMentionTrigger(newValue)
                    }
                
                Button(action: {
                    onPostComment?()
                    isCommentFieldFocused.wrappedValue = false
                    showMentionAutocomplete = false
                }) {
                    Text("Post")
                        .font(DS.Typography.subheadline(.semibold))
                        .foregroundColor(DS.Colors.textOnMint)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? DS.Colors.primaryAccent.opacity(0.5)
                                : DS.Colors.primaryAccent
                        )
                        .cornerRadius(DS.Radius.pill)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Colors.borderSubtle.opacity(0.4), lineWidth: 0.5)
        )
        .dsCardShadow()
        .onAppear {
            loadFriendProfiles()
        }
    }
    
    // MARK: - Mention Helpers
    
    private func checkForMentionTrigger(_ text: String) {
        // Find the last @ in the text
        guard let atIndex = text.lastIndex(of: "@") else {
            withAnimation { showMentionAutocomplete = false }
            mentionSearchText = ""
            return
        }
        
        // Get text after the @
        let afterAt = String(text[text.index(after: atIndex)...])
        
        // Check if we're still in a mention context (no space after @)
        if afterAt.contains(" ") || afterAt.contains("\n") {
            // User typed space after mention, hide autocomplete
            withAnimation { showMentionAutocomplete = false }
            mentionSearchText = ""
            return
        }
        
        // Show autocomplete with the search text
        mentionSearchText = afterAt
        withAnimation { showMentionAutocomplete = true }
    }
    
    private func insertMention(username: String) {
        // Find the last @ and the text after it
        guard let atIndex = commentText.lastIndex(of: "@") else { return }
        
        // Get text before @
        let beforeAt = String(commentText[..<atIndex])
        
        // Get text after @ (might contain partial username or other text)
        let afterAtIndex = commentText.index(after: atIndex)
        let afterAt = String(commentText[afterAtIndex...])
        
        // Find where the mention search text ends (if user typed partial username)
        // We want to replace only the search portion, not everything after @
        let searchText = mentionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let textToReplace: String
        if !searchText.isEmpty && afterAt.hasPrefix(searchText) {
            // User was typing a username, replace that portion
            textToReplace = searchText
        } else {
            // No search text or it doesn't match, replace everything after @
            // But preserve any text that looks like it's after the mention (has space before it)
            if let spaceIndex = afterAt.firstIndex(of: " ") {
                // There's a space, so there's text after the mention
                // Replace up to the space
                textToReplace = String(afterAt[..<spaceIndex])
            } else {
                // No space, replace everything
                textToReplace = afterAt
            }
        }
        
        // Get remaining text after what we're replacing
        let remainingText: String
        if afterAt.hasPrefix(textToReplace) {
            let remainingStart = afterAt.index(afterAt.startIndex, offsetBy: textToReplace.count)
            remainingText = String(afterAt[remainingStart...])
        } else {
            remainingText = afterAt
        }
        
        // Insert the mention with proper spacing
        let mention = "@\(username)"
        let spacing = remainingText.isEmpty || remainingText.hasPrefix(" ") ? "" : " "
        commentText = beforeAt + mention + spacing + remainingText
        
        // Hide autocomplete
        withAnimation { showMentionAutocomplete = false }
        mentionSearchText = ""
    }
    
    private func loadFriendProfiles() {
        Task {
            do {
                let profiles = try await dataManager.fetchFriendProfiles()
                await MainActor.run {
                    friendProfiles = profiles
                }
            } catch {
                print("[InlineCommentsSection] Error loading friend profiles: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Mention Autocomplete Dropdown

struct MentionAutocompleteDropdown: View {
    let friends: [RemoteUserProfile]
    let onSelect: (RemoteUserProfile) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(friends.prefix(5), id: \.id) { profile in
                Button {
                    onSelect(profile)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        // Avatar
                        ProfileAvatarView(
                            profileImageId: nil,
                            profileImageURL: profile.avatarURL,
                            username: profile.username,
                            size: 32
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(DS.Typography.subheadline(.medium))
                                .foregroundColor(DS.Colors.textPrimary)
                            Text("@\(profile.username)")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.primaryAccent)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if profile.id != friends.prefix(5).last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.md + 32 + DS.Spacing.sm)
                }
            }
        }
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.md)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct InlineCommentRow: View {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    let isNewlyAdded: Bool
    var onEdit: ((Comment) -> Void)?
    var onDelete: ((Comment) -> Void)?
    
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    
    private var isCurrentUserComment: Bool {
        guard let currentUser = dataManager.appData.currentUser else { return false }
        return currentUser.id == comment.userId
    }
    
    private var commenterProfileImage: UIImage? {
        guard isCurrentUserComment,
              let imageId = dataManager.appData.currentUserProfileImageId else {
            return nil
        }
        return PhotoCache.shared.retrieve(forKey: imageId)
    }
    
    private var commenterRemoteAvatarURL: String? {
        guard isCurrentUserComment else { return nil }
        return dataManager.appData.currentUserAvatarURL
    }
    
    private var commenterInitials: String {
        if let user = dataManager.appData.currentUser, user.id == comment.userId {
            return String(user.displayNameOrUsername.prefix(1)).uppercased()
        }
        return "U"
    }
    
    private var commenterUsername: String {
        if let user = dataManager.appData.currentUser, user.id == comment.userId {
            return "@\(user.username)"
        }
        return "@friend"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            // Avatar - use VisitAvatarView for consistency and proper image loading
            VisitAvatarView(
                image: commenterProfileImage,
                remoteURL: commenterRemoteAvatarURL,
                initials: commenterInitials,
                size: 28,
                onTap: { handleAvatarTap() }
            )
            
            VStack(alignment: .leading, spacing: 2) {
                // Username and time
                HStack(spacing: 4) {
                    Text(commenterUsername)
                        .font(DS.Typography.caption1(.semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text(timeAgoString(from: comment.createdAt))
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                }
                
                // Comment text with tappable mentions
                MentionText(
                    text: comment.text,
                    mentions: comment.mentions,
                    onMentionTap: { username in
                        handleMentionTap(username: username)
                    }
                )
                .font(DS.Typography.subheadline())
                .foregroundColor(DS.Colors.textPrimary)
            }
            
            Spacer(minLength: DS.Spacing.sm)
            
            if isCurrentUserComment, onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button {
                            onEdit(comment)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete(comment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Colors.iconSubtle)
                        .padding(.horizontal, DS.Spacing.xs)
                }
                .contentShape(Rectangle())
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.md)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func handleMentionTap(username: String) {
        profileNavigator.openProfile(
            handle: .mention(username: username),
            source: .mentionComment,
            triggerHaptic: true
        )
    }
    
    private func handleAvatarTap() {
        if isCurrentUserComment || comment.supabaseUserId == dataManager.appData.supabaseUserId {
            tabCoordinator.switchToProfile()
            return
        }
        if let supabaseUserId = comment.supabaseUserId {
            profileNavigator.openProfile(
                handle: .supabase(id: supabaseUserId),
                source: .other,
                triggerHaptic: true
            )
            return
        }
        
        if let username = fallbackUsername {
            profileNavigator.openProfile(
                handle: .mention(username: username),
                source: .other,
                triggerHaptic: true
            )
        }
    }
    
    private var fallbackUsername: String? {
        let trimmed = commenterUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("@") {
            let withoutAt = trimmed.dropFirst()
            return withoutAt.isEmpty ? nil : String(withoutAt)
        }
        return trimmed
    }
}

// MARK: - Swipe Actions Modifier

/// Adds swipe actions for editing and deleting comments authored by the current user.
private struct CommentSwipeActionsModifier: ViewModifier {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    var onEdit: ((Comment) -> Void)?
    var onDelete: ((Comment) -> Void)?
    
    private var isCurrentUserComment: Bool {
        guard let currentUser = dataManager.appData.currentUser else { return false }
        return currentUser.id == comment.userId
    }
    
    func body(content: Content) -> some View {
        if isCurrentUserComment {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let onEdit = onEdit {
                        Button {
                            onEdit(comment)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    if let onDelete = onDelete {
                        Button(role: .destructive) {
                            onDelete(comment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        } else {
            content
        }
    }
}

