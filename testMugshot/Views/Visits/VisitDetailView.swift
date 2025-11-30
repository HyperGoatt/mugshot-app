//
//  VisitDetailView.swift
//  testMugshot
//
//  Modern, Instagram-inspired Visit detail view with content-first hierarchy.
//  Redesigned with streamlined UX patterns and reduced visual fragmentation.
//

import SwiftUI
import UIKit

struct VisitDetailView: View {
    @ObservedObject var dataManager: DataManager
    @State private var visit: Visit
    @State private var commentText: String = ""
    @State private var showCafeDetail = false
    @State private var selectedCafe: Cafe?
    @State private var showOwnerOptions = false
    @State private var showDeleteConfirmation = false
    @State private var showEditVisit = false
    @State private var editingComment: Comment?
    @State private var editedCommentText: String = ""
    @State private var newlyAddedCommentIds: Set<UUID> = []
    @State private var lastOptimisticCommentTime: Date?
    @State private var showPostcardPreview = false
    @FocusState private var isCommentFieldFocused: Bool
    let showsDismissButton: Bool
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hapticsManager = HapticsManager.shared
    
    init(dataManager: DataManager, visit: Visit, showsDismissButton: Bool = false) {
        self.dataManager = dataManager
        _visit = State(initialValue: visit)
        self.showsDismissButton = showsDismissButton
    }
    
    // MARK: - Computed Properties
    
    private var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    private var authorProfileImage: UIImage? {
        guard let currentUser = dataManager.appData.currentUser,
              currentUser.id == visit.userId,
              let imageId = dataManager.appData.currentUserProfileImageId else {
            return nil
        }
        return PhotoCache.shared.retrieve(forKey: imageId)
    }
    
    private var authorDisplayName: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return user.displayNameOrUsername
        }
        return visit.authorDisplayNameOrUsername
    }
    
    private var authorUsername: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return "@\(user.username)"
        }
        return visit.authorUsernameHandle
    }
    
    private var authorInitials: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return String(user.displayNameOrUsername.prefix(1)).uppercased()
        }
        return visit.authorInitials
    }
    
    private var authorRemoteAvatarURL: String? {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return dataManager.appData.currentUserAvatarURL
        }
        return visit.authorAvatarURL
    }
    
    private var isCurrentUserAuthor: Bool {
        dataManager.appData.currentUser?.id == visit.userId
    }
    
    private var isLikedByCurrentUser: Bool {
        guard let userId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: userId)
    }
    
    private var isBookmarked: Bool {
        guard let cafe = cafe else { return false }
        return cafe.wantToTry
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Streamlined Header
                VisitDetailHeader(
                    displayName: authorDisplayName,
                    username: authorUsername,
                    timeAgo: timeAgoString(from: visit.createdAt),
                    avatarImage: authorProfileImage,
                    remoteAvatarURL: authorRemoteAvatarURL,
                    initials: authorInitials,
                    isCurrentUserAuthor: isCurrentUserAuthor,
                    onMenuTap: { showOwnerOptions = true }
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.md)
                
                // 2. Cafe Attribution Pill
                if let cafeName = cafe?.name, !cafeName.isEmpty {
                    DSCafeAttributionPill(cafeName: cafeName) {
                        if let cafe = cafe {
                            selectedCafe = cafe
                            showCafeDetail = true
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.md)
                }
                
                // 3. Caption (no label, flows naturally)
                if !visit.caption.isEmpty {
                    MentionText(text: visit.caption, mentions: visit.mentions)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                }
                
                // 4. Photo Carousel with Score Overlay
                PhotoCarouselWithScore(
                    photoPaths: visit.photos,
                    remotePhotoURLs: visit.remotePhotoURLByKey,
                    score: visit.overallScore,
                    height: 360
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
                
                // 5. Inline Social Actions (directly below image)
                InlineSocialActions(
                    isLiked: isLikedByCurrentUser,
                    likeCount: visit.likeCount,
                    commentCount: visit.comments.count,
                    isBookmarked: isBookmarked,
                    showShareButton: isCurrentUserAuthor, // Only show share on own posts
                    onLikeTap: toggleLike,
                    onCommentTap: {
                        isCommentFieldFocused = true
                    },
                    onBookmarkTap: toggleBookmark,
                    onShareTap: {
                        hapticsManager.lightTap()
                        showPostcardPreview = true
                    }
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // 6. Review Summary (Drink + Ratings)
                if !visit.ratings.isEmpty || visit.drinkType != .other {
                    ReviewSummaryCard(
                        drinkType: visit.drinkType,
                        customDrinkType: visit.customDrinkType,
                        ratings: visit.ratings
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.lg)
                }
                
                // 7. Private Notes (collapsible, only for author)
                if isCurrentUserAuthor, let notes = visit.notes, !notes.isEmpty {
                    CollapsiblePrivateNotes(notes: notes)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                }
                
                // 8. Comments Section
                InlineCommentsSection(
                    comments: visit.comments,
                    commentText: $commentText,
                    dataManager: dataManager,
                    newlyAddedCommentIds: newlyAddedCommentIds,
                    onPostComment: addComment,
                    onEditComment: { comment in
                        editingComment = comment
                        editedCommentText = comment.text
                    },
                    onDeleteComment: { comment in
                        Task {
                            await dataManager.deleteComment(comment, from: visit.id)
                            refreshVisit()
                        }
                    },
                    isCommentFieldFocused: $isCommentFieldFocused
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl * 2)
            }
        }
        .background(DS.Colors.screenBackground.ignoresSafeArea())
        .navigationTitle("Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
        }
        .confirmationDialog("Manage Post", isPresented: $showOwnerOptions, titleVisibility: .visible) {
            Button("Edit Post") {
                print("[VisitEdit] Starting edit for visit id=\(visit.id)")
                showEditVisit = true
            }
            Button("Delete Post", role: .destructive) {
                showDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete this visit?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteVisit()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showEditVisit) {
            EditVisitView(dataManager: dataManager, visit: $visit)
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                NavigationStack {
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
            }
        }
        // Postcard preview sheet
        .sheet(isPresented: $showPostcardPreview) {
            PostcardPreviewSheet(
                visit: visit,
                cafe: cafe,
                authorImage: authorProfileImage,
                authorAvatarURL: authorRemoteAvatarURL
            )
        }
        // Edit comment sheet
        .sheet(item: $editingComment) { comment in
            NavigationStack {
                VStack(spacing: DS.Spacing.lg) {
                    Text("Edit Comment")
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextEditor(text: $editedCommentText)
                        .font(DS.Typography.bodyText)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.cardBackgroundAlt)
                        .cornerRadius(DS.Radius.md)
                        .frame(minHeight: 120)
                    
                    Spacer()
                    
                    Button("Save") {
                        let trimmed = editedCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            await dataManager.editComment(comment, in: visit.id, newText: trimmed)
                            refreshVisit()
                        }
                        editingComment = nil
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    
                    Button("Cancel") {
                        editingComment = nil
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.pagePadding)
                .background(DS.Colors.screenBackground.ignoresSafeArea())
            }
        }
        .onAppear {
            refreshVisit()
        }
        .onChange(of: dataManager.appData.visits) { _, newVisits in
            // Simple reactive sync – always refresh from canonical DataManager copy
            if let updated = newVisits.first(where: { $0.id == visit.id }) {
                #if DEBUG
                print("📝 [Comment] onChange: syncing visit from DataManager – comments: \(updated.comments.count)")
                #endif
                visit = updated
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleLike() {
        Task {
            await dataManager.toggleVisitLike(visit.id)
            refreshVisit()
        }
    }
    
    private func toggleBookmark() {
        if let cafe = cafe {
            dataManager.toggleCafeWantToTry(cafe: cafe)
        }
    }
    
    private func addComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        #if DEBUG
        print("📝 [Comment] addComment called - text: '\(trimmed)'")
        print("📝 [Comment] currentUser: \(dataManager.appData.currentUser != nil ? "✅" : "❌")")
        print("📝 [Comment] supabaseUserId: \(dataManager.appData.supabaseUserId != nil ? "✅" : "❌")")
        #endif
        
        guard !trimmed.isEmpty else {
            #if DEBUG
            print("📝 [Comment] ❌ Empty text, returning")
            #endif
            return
        }
        
        guard let currentUser = dataManager.appData.currentUser else {
            #if DEBUG
            print("📝 [Comment] ❌ currentUser is nil, returning")
            #endif
            // TODO: Show user-friendly error alert
            return
        }
        
        guard let supabaseUserId = dataManager.appData.supabaseUserId else {
            #if DEBUG
            print("📝 [Comment] ❌ supabaseUserId is nil, returning")
            #endif
            // TODO: Show user-friendly error alert
            return
        }
        
        #if DEBUG
        print("📝 [Comment] ✅ Creating optimistic comment")
        #endif
        
        // Create optimistic comment immediately
        let optimisticComment = Comment(
            id: UUID(), // Temporary ID
            visitId: visit.id,
            userId: currentUser.id,
            supabaseUserId: supabaseUserId,
            text: trimmed,
            createdAt: Date(),
            mentions: MentionParser.parseMentions(from: trimmed)
        )
        
        // Clear text field immediately for better UX
        commentText = ""
        
        // Add to local state with animation - use full reassignment to trigger re-render
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            var updatedComments = visit.comments
            updatedComments.append(optimisticComment)
            visit.comments = updatedComments  // Full reassignment ensures SwiftUI detects change
            newlyAddedCommentIds.insert(optimisticComment.id)
            lastOptimisticCommentTime = Date()  // Track when we added optimistic comment
        }
        
        #if DEBUG
        print("📝 [Comment] ✅ Optimistic comment added - total comments: \(visit.comments.count)")
        #endif
        
        // Update server in background, then refresh from canonical DataManager source
        Task {
            await dataManager.addComment(to: visit.id, text: trimmed)
            
            #if DEBUG
            print("📝 [Comment] Server response received – refreshing visit from DataManager")
            #endif
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    refreshVisit()
                    // Clear optimistic tracking once we've synced with server
                    newlyAddedCommentIds.remove(optimisticComment.id)
                    lastOptimisticCommentTime = nil
                }
            }
        }
    }
    
    private func refreshVisit() {
        if let updated = dataManager.getVisit(id: visit.id) {
            visit = updated
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func deleteVisit() {
        dataManager.deleteVisit(id: visit.id)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VisitDetailView(
            dataManager: DataManager.shared,
            visit: Visit(
                cafeId: UUID(),
                userId: UUID(),
                drinkType: .coffee,
                caption: "Coffee and records! Heck yeah 🎵",
                photos: [],
                ratings: [
                    "Ambiance": 3.0,
                    "Presentation": 4.0,
                    "Taste": 3.5,
                    "Value": 4.0
                ],
                overallScore: 3.5,
                likeCount: 12,
                comments: []
            )
        )
    }
}
