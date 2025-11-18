//
//  VisitDetailView.swift
//  testMugshot
//
//  Canonical single-source-of-truth screen for viewing a visit/post in detail.
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
    @State private var showEditPlaceholder = false
    let showsDismissButton: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    init(dataManager: DataManager, visit: Visit, showsDismissButton: Bool = false) {
        self.dataManager = dataManager
        _visit = State(initialValue: visit)
        self.showsDismissButton = showsDismissButton
    }
    
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
        return dataManager.appData.currentUserDisplayName ?? "Mugshot Member"
    }
    
    private var authorUsername: String {
        if let user = dataManager.appData.currentUser, user.id == visit.userId {
            return "@\(user.username)"
        }
        if let username = dataManager.appData.currentUserUsername {
            return "@\(username)"
        }
        return "@you"
    }
    
    private var authorInitials: String {
        String(authorDisplayName.prefix(1)).uppercased()
    }
    
    private var drinkDescription: String {
        if let custom = visit.customDrinkType, !custom.isEmpty {
            return "\(visit.drinkType.rawValue) • \(custom)"
        }
        return visit.drinkType.rawValue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sectionVerticalGap) {
                VisitHeaderView(
                    displayName: authorDisplayName,
                    username: authorUsername,
                    cafeName: cafe?.name,
                    timeAgo: timeAgoString(from: visit.createdAt),
                    avatarImage: authorProfileImage,
                    score: visit.overallScore,
                    onCafeTap: {
                        if let cafe = cafe {
                            selectedCafe = cafe
                            showCafeDetail = true
                        }
                    }
                )
                
                MugshotImageCarousel(
                    photoPaths: visit.photos,
                    height: 320,
                    cornerRadius: DS.Radius.card
                )
                .shadow(color: DS.Shadow.cardSoft.color.opacity(0.35),
                        radius: DS.Shadow.cardSoft.radius,
                        x: DS.Shadow.cardSoft.x,
                        y: DS.Shadow.cardSoft.y)
                
                if !visit.caption.isEmpty {
                    captionCard
                }
                
                visitInfoCard
                
                if !visit.ratings.isEmpty {
                    ratingBreakdownCard
                }
                
                if let notes = visit.notes, !notes.isEmpty {
                    notesCard(notes)
                }
                
                socialActionsCard
                commentsSection
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.vertical, DS.Spacing.sectionVerticalGap)
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isCurrentUserAuthor {
                    Button {
                        showOwnerOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                }
            }
        }
        .confirmationDialog("Manage Post", isPresented: $showOwnerOptions, titleVisibility: .visible) {
            Button("Edit Post") {
                showEditPlaceholder = true
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
        .alert("Edit coming soon", isPresented: $showEditPlaceholder) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Editing posts will be available in a future update.")
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                NavigationStack {
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
            }
        }
        .onAppear {
            refreshVisit()
        }
    }
    
    private var captionCard: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Caption")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                MentionText(text: visit.caption, mentions: visit.mentions)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
            }
        }
    }
    
    private var visitInfoCard: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                VisitMetaRow(label: "Drink", value: drinkDescription)
                VisitMetaRow(label: "Visibility", value: visit.visibility.rawValue)
                VisitMetaRow(label: "Logged", value: visit.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
    
    private var ratingBreakdownCard: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Rating Breakdown")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                ForEach(visit.ratings.keys.sorted(), id: \.self) { key in
                    RatingRow(title: key, value: visit.ratings[key] ?? 0)
                }
            }
        }
    }
    
    private func notesCard(_ notes: String) -> some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Private Notes")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textSecondary)
                Text(notes)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }
    
    private var socialActionsCard: some View {
        DSBaseCard {
            HStack(spacing: DS.Spacing.lg) {
                LikeButton(
                    isLiked: isLikedByCurrentUser,
                    likeCount: visit.likeCount,
                    onToggle: toggleLike
                )
                
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.iconDefault)
                    Text("\(visit.comments.count)")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.iconDefault)
                }
            }
        }
    }
    
    private var commentsSection: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Comments")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if visit.comments.isEmpty {
                    Text("No comments yet")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(visit.comments) { comment in
                            CommentRow(comment: comment, dataManager: dataManager)
                        }
                    }
                }
                
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Add a comment…", text: $commentText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Post") {
                        addComment()
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var isLikedByCurrentUser: Bool {
        guard let userId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: userId)
    }
    
    private func toggleLike() {
        guard let userId = dataManager.appData.currentUser?.id else { return }
        dataManager.toggleVisitLike(visit.id, userId: userId)
        refreshVisit()
    }
    
    private func addComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = dataManager.appData.currentUser?.id else { return }
        dataManager.addComment(to: visit.id, userId: userId, text: trimmed)
        commentText = ""
        refreshVisit()
    }
    
    private func refreshVisit() {
        if let updated = dataManager.getVisit(id: visit.id) {
            visit = updated
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var isCurrentUserAuthor: Bool {
        dataManager.appData.currentUser?.id == visit.userId
    }
    
    private func deleteVisit() {
        dataManager.deleteVisit(id: visit.id)
        dismiss()
    }
}

// MARK: - Shared Components

private struct VisitHeaderView: View {
    let displayName: String
    let username: String
    let cafeName: String?
    let timeAgo: String
    let avatarImage: UIImage?
    let score: Double
    var onCafeTap: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VisitAuthorAvatar(image: avatarImage, initials: String(displayName.prefix(1)), size: 56)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(displayName)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                HStack(spacing: DS.Spacing.xs) {
                    if let cafeName = cafeName {
                        Button(action: { onCafeTap?() }) {
                            Text(cafeName)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.primaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if cafeName != nil {
                        Text("•")
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Text(timeAgo)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Text(username)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            DSScoreBadge(score: score)
        }
    }
}

private struct VisitMetaRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    
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
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Circle()
                .fill(DS.Colors.primaryAccent)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(commenterInitials)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textOnMint)
                )
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text(commenterUsername)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(timeAgoString(from: comment.createdAt))
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                MentionText(text: comment.text, mentions: comment.mentions)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.md)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct VisitAuthorAvatar: View {
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
                        Text(initials)
                            .font(DS.Typography.title2(.bold))
                            .foregroundColor(DS.Colors.textOnMint)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 3)
        )
        .shadow(color: DS.Shadow.cardSoft.color.opacity(0.5),
                radius: DS.Shadow.cardSoft.radius / 2,
                x: DS.Shadow.cardSoft.x,
                y: DS.Shadow.cardSoft.y / 2)
    }
}

private struct RatingRow: View {
    let title: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
            Spacer()
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: starIcon(for: star))
                        .font(.system(size: 14))
                        .foregroundColor(starColor(for: star))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
    }
    
    private func starIcon(for index: Int) -> String {
        if Double(index) <= floor(value) {
            return "star.fill"
        } else if Double(index) - value <= 0.5 && Double(index) - value > 0 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for index: Int) -> Color {
        Double(index) <= value ? DS.Colors.primaryAccent : DS.Colors.iconSubtle
    }
}

