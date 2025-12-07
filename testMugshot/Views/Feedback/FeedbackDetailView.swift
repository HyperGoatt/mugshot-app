//
//  FeedbackDetailView.swift
//  testMugshot
//
//  Detail view for a feedback post with comments
//

import SwiftUI

struct FeedbackDetailView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    let post: FeedbackPost
    let onPostUpdated: (FeedbackPost) -> Void
    let onPostDeleted: (UUID) -> Void
    
    // State
    @State private var currentPost: FeedbackPost
    @State private var comments: [FeedbackComment] = []
    @State private var isLoadingComments = true
    @State private var commentText = ""
    @State private var replyingTo: FeedbackComment?
    @State private var isSubmittingComment = false
    @State private var showDeleteConfirmation = false
    @State private var userVote: FeedbackVoteType?
    
    private let feedbackService = SupabaseFeedbackService.shared
    
    private var currentUserId: String? {
        dataManager.appData.supabaseUserId
    }
    
    private var canDeletePost: Bool {
        guard let currentUserId = currentUserId else { return false }
        return currentPost.userId == currentUserId
    }
    
    private var organizedComments: [FeedbackComment] {
        // Organize comments into threads
        let topLevel = comments.filter { $0.parentCommentId == nil }
        return topLevel.map { comment in
            var commentWithReplies = comment
            commentWithReplies.replies = comments.filter { $0.parentCommentId == comment.id }
            return commentWithReplies
        }
    }
    
    init(
        dataManager: DataManager,
        post: FeedbackPost,
        onPostUpdated: @escaping (FeedbackPost) -> Void,
        onPostDeleted: @escaping (UUID) -> Void
    ) {
        self.dataManager = dataManager
        self.post = post
        self.onPostUpdated = onPostUpdated
        self.onPostDeleted = onPostDeleted
        self._currentPost = State(initialValue: post)
        self._userVote = State(initialValue: post.currentUserVote)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DS.Colors.screenBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                        // Post content
                        postContentSection
                        
                        Divider()
                            .background(DS.Colors.dividerSubtle)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        // Comments section
                        commentsSection
                    }
                    .padding(.bottom, 100) // Space for comment composer
                }
                
                // Comment composer
                VStack(spacing: 0) {
                    Divider()
                    
                    if let replyingTo = replyingTo {
                        replyingToIndicator(replyingTo)
                    }
                    
                    FeedbackCommentComposer(
                        text: $commentText,
                        placeholder: replyingTo != nil ? "Write a reply..." : "Add a comment...",
                        isLoading: isSubmittingComment,
                        onSubmit: submitComment
                    )
                }
                .background(DS.Colors.cardBackground)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.textPrimary)
                }
                
                if canDeletePost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete Post", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(DS.Colors.iconDefault)
                        }
                    }
                }
            }
            .task {
                await loadComments()
                await loadUserVote()
            }
            .alert("Delete Post", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deletePost()
                }
            } message: {
                Text("Are you sure you want to delete this feedback post? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Post Content Section
    
    private var postContentSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header: Category and timestamp
            HStack {
                FeedbackCategoryPill(category: currentPost.category)
                
                Spacer()
                
                Text(currentPost.timeAgo)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
            }
            
            // Title
            Text(currentPost.title)
                .font(DS.Typography.title2())
                .foregroundColor(DS.Colors.textPrimary)
            
            // Author
            HStack(spacing: DS.Spacing.sm) {
                if let avatarUrl = currentPost.authorAvatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            authorPlaceholder
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    authorPlaceholder
                }
                
                Text(currentPost.authorName)
                    .font(DS.Typography.subheadline(.medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            // Body
            Text(currentPost.body)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Vote control
            HStack(spacing: DS.Spacing.lg) {
                FeedbackVoteControlHorizontal(
                    voteScore: currentPost.voteScore + voteScoreAdjustment,
                    currentUserVote: userVote,
                    onUpvote: { Task { await handleVote(.up) } },
                    onDownvote: { Task { await handleVote(.down) } }
                )
                
                Spacer()
                
                // Comment count
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("\(comments.count) \(comments.count == 1 ? "comment" : "comments")")
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
    }
    
    private var authorPlaceholder: some View {
        Circle()
            .fill(DS.Colors.cardBackgroundAlt)
            .frame(width: 24, height: 24)
            .overlay(
                Text(currentPost.authorName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            )
    }
    
    // Adjustment for optimistic UI updates
    private var voteScoreAdjustment: Int {
        let originalVote = post.currentUserVote
        
        if originalVote == userVote {
            return 0
        }
        
        var adjustment = 0
        
        // Remove original vote effect
        if let original = originalVote {
            adjustment -= original.rawValue
        }
        
        // Add new vote effect
        if let current = userVote {
            adjustment += current.rawValue
        }
        
        return adjustment
    }
    
    // MARK: - Comments Section
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Comments")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            if isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if organizedComments.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("No comments yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Text("Be the first to share your thoughts")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(organizedComments) { comment in
                        FeedbackCommentRow(
                            comment: comment,
                            currentUserId: currentUserId,
                            isReply: false,
                            onReply: {
                                replyingTo = comment
                            },
                            onDelete: {
                                deleteComment(comment)
                            }
                        )
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        Divider()
                            .background(DS.Colors.dividerSubtle)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                }
            }
        }
    }
    
    // MARK: - Replying To Indicator
    
    private func replyingToIndicator(_ comment: FeedbackComment) -> some View {
        HStack {
            Text("Replying to \(comment.authorName)")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            Spacer()
            
            Button(action: {
                replyingTo = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.iconSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.primaryAccentSoftFill)
    }
    
    // MARK: - Data Loading
    
    private func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        
        do {
            let fetchedComments = try await feedbackService.fetchComments(postId: currentPost.id)
            await MainActor.run {
                comments = fetchedComments
            }
        } catch {
            print("[FeedbackDetail] Error loading comments: \(error.localizedDescription)")
        }
    }
    
    private func loadUserVote() async {
        guard let userId = currentUserId else { return }
        
        do {
            let vote = try await feedbackService.getUserVote(userId: userId, postId: currentPost.id)
            await MainActor.run {
                userVote = vote
            }
        } catch {
            print("[FeedbackDetail] Error loading user vote: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Actions
    
    private func handleVote(_ voteType: FeedbackVoteType) async {
        guard let userId = currentUserId else { return }
        
        let previousVote = userVote
        
        do {
            if userVote == voteType {
                // Remove vote
                await MainActor.run { userVote = nil }
                try await feedbackService.removeVote(userId: userId, postId: currentPost.id)
            } else {
                // Add or change vote
                await MainActor.run { userVote = voteType }
                try await feedbackService.voteFeedbackPost(userId: userId, postId: currentPost.id, voteType: voteType)
            }
            
            // Refresh post to get updated counts
            if let updatedPost = try await feedbackService.fetchFeedbackPost(id: currentPost.id) {
                var postWithVote = updatedPost
                postWithVote.currentUserVote = userVote
                await MainActor.run {
                    currentPost = postWithVote
                }
                onPostUpdated(postWithVote)
            }
        } catch {
            print("[FeedbackDetail] Error voting: \(error.localizedDescription)")
            await MainActor.run { userVote = previousVote }
            hapticsManager.playError()
        }
    }
    
    private func submitComment() {
        guard let userId = currentUserId else { return }
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSubmittingComment = true
        
        Task {
            defer {
                Task { @MainActor in
                    isSubmittingComment = false
                }
            }
            
            do {
                let newComment = try await feedbackService.addComment(
                    userId: userId,
                    postId: currentPost.id,
                    text: text,
                    parentCommentId: replyingTo?.id
                )
                
                await MainActor.run {
                    comments.append(newComment)
                    commentText = ""
                    replyingTo = nil
                    hapticsManager.playSuccess()
                }
            } catch {
                print("[FeedbackDetail] Error submitting comment: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
    
    private func deleteComment(_ comment: FeedbackComment) {
        Task {
            do {
                try await feedbackService.deleteComment(id: comment.id)
                await MainActor.run {
                    comments.removeAll { $0.id == comment.id }
                    // Also remove any replies to this comment
                    comments.removeAll { $0.parentCommentId == comment.id }
                    hapticsManager.mediumTap()
                }
            } catch {
                print("[FeedbackDetail] Error deleting comment: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
    
    private func deletePost() {
        Task {
            do {
                try await feedbackService.deleteFeedbackPost(id: currentPost.id)
                await MainActor.run {
                    onPostDeleted(currentPost.id)
                    hapticsManager.mediumTap()
                    dismiss()
                }
            } catch {
                print("[FeedbackDetail] Error deleting post: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
}
