//
//  FeedbackBoardView.swift
//  testMugshot
//
//  Main feedback board view with category filters and post list
//

import SwiftUI

struct FeedbackBoardView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    // State
    @State private var posts: [FeedbackPost] = []
    @State private var selectedCategory: FeedbackCategory? = nil
    @State private var sortOption: FeedbackSortOption = .new
    @State private var isLoading = true
    @State private var showSubmitSheet = false
    @State private var selectedPost: FeedbackPost?
    @State private var userVotes: [UUID: FeedbackVoteType] = [:]
    
    private let feedbackService = SupabaseFeedbackService.shared
    
    private var currentUserId: String? {
        dataManager.appData.supabaseUserId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.screenBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filters
                    filtersSection
                    
                    // Content
                    if isLoading && posts.isEmpty {
                        loadingView
                    } else if posts.isEmpty {
                        emptyStateView
                    } else {
                        postsList
                    }
                }
                
                // FAB for new post
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            hapticsManager.mediumTap()
                            showSubmitSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(DS.Colors.textOnMint)
                                .frame(width: 56, height: 56)
                                .background(DS.Colors.primaryAccent)
                                .clipShape(Circle())
                                .dsLiftedShadow()
                        }
                        .padding(.trailing, DS.Spacing.pagePadding)
                        .padding(.bottom, DS.Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .task {
                await loadPosts()
            }
            .refreshable {
                await loadPosts()
            }
            .sheet(isPresented: $showSubmitSheet) {
                FeedbackSubmitSheet(dataManager: dataManager) { newPost in
                    // Add the new post to the top of the list
                    posts.insert(newPost, at: 0)
                }
            }
            .sheet(item: $selectedPost) { post in
                FeedbackDetailView(
                    dataManager: dataManager,
                    post: post,
                    onPostUpdated: { updatedPost in
                        // Update the post in the list
                        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                            posts[index] = updatedPost
                        }
                    },
                    onPostDeleted: { deletedPostId in
                        // Remove the post from the list
                        posts.removeAll { $0.id == deletedPostId }
                    }
                )
            }
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Category pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    // All category
                    FilterPill(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil
                    ) {
                        hapticsManager.selectionChanged()
                        selectedCategory = nil
                        Task { await loadPosts() }
                    }
                    
                    // Specific categories
                    ForEach(FeedbackCategory.allCases, id: \.self) { category in
                        FilterPill(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            hapticsManager.selectionChanged()
                            selectedCategory = category
                            Task { await loadPosts() }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            // Sort options
            HStack(spacing: DS.Spacing.sm) {
                Text("Sort by:")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
                
                DSDesignSegmentedControl(
                    options: FeedbackSortOption.allCases.map { $0.rawValue },
                    selectedIndex: Binding(
                        get: { FeedbackSortOption.allCases.firstIndex(of: sortOption) ?? 0 },
                        set: { newIndex in
                            let newSort = FeedbackSortOption.allCases[newIndex]
                            if newSort != sortOption {
                                hapticsManager.selectionChanged()
                                sortOption = newSort
                                Task { await loadPosts() }
                            }
                        }
                    )
                )
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground)
    }
    
    // MARK: - Posts List
    
    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                ForEach(posts) { post in
                    FeedbackPostCard(
                        post: postWithVote(post),
                        onTap: {
                            selectedPost = postWithVote(post)
                        },
                        onUpvote: {
                            Task { await handleVote(post: post, voteType: .up) }
                        },
                        onDownvote: {
                            Task { await handleVote(post: post, voteType: .down) }
                        }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.vertical, DS.Spacing.md)
            .padding(.bottom, 80) // Space for FAB
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "text.bubble")
                .font(.system(size: 64))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No feedback yet")
                .font(DS.Typography.screenTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("Be the first to share your thoughts!")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                hapticsManager.mediumTap()
                showSubmitSheet = true
            }) {
                Text("Submit Feedback")
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding(.horizontal, DS.Spacing.xxl * 2)
            .padding(.top, DS.Spacing.md)
        }
        .padding(DS.Spacing.pagePadding)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
            Text("Loading feedback...")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    
    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedPosts = try await feedbackService.fetchFeedbackPosts(
                category: selectedCategory,
                sortBy: sortOption
            )
            
            await MainActor.run {
                posts = fetchedPosts
            }
            
            // Load user votes for these posts
            if let userId = currentUserId, !fetchedPosts.isEmpty {
                let postIds = fetchedPosts.map { $0.id }
                let votes = try await feedbackService.getUserVotes(userId: userId, postIds: postIds)
                
                await MainActor.run {
                    userVotes = votes
                }
            }
        } catch {
            print("[FeedbackBoard] Error loading posts: \(error.localizedDescription)")
        }
    }
    
    private func postWithVote(_ post: FeedbackPost) -> FeedbackPost {
        var updatedPost = post
        updatedPost.currentUserVote = userVotes[post.id]
        return updatedPost
    }
    
    // MARK: - Voting
    
    private func handleVote(post: FeedbackPost, voteType: FeedbackVoteType) async {
        guard let userId = currentUserId else { return }
        
        let currentVote = userVotes[post.id]
        
        do {
            if currentVote == voteType {
                // Remove vote if tapping the same vote type
                try await feedbackService.removeVote(userId: userId, postId: post.id)
                await MainActor.run {
                    userVotes.removeValue(forKey: post.id)
                }
            } else {
                // Add or change vote
                try await feedbackService.voteFeedbackPost(userId: userId, postId: post.id, voteType: voteType)
                await MainActor.run {
                    userVotes[post.id] = voteType
                }
            }
            
            // Refresh the post to get updated counts
            if let updatedPost = try await feedbackService.fetchFeedbackPost(id: post.id) {
                await MainActor.run {
                    if let index = posts.firstIndex(where: { $0.id == post.id }) {
                        posts[index] = updatedPost
                    }
                }
            }
        } catch {
            print("[FeedbackBoard] Error voting: \(error.localizedDescription)")
            hapticsManager.playError()
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(DS.Typography.caption1(.medium))
            }
            .foregroundColor(isSelected ? DS.Colors.textOnMint : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.primaryAccent : DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .stroke(isSelected ? Color.clear : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
