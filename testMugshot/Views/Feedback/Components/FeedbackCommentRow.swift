//
//  FeedbackCommentRow.swift
//  testMugshot
//
//  Comment row with threading support for feedback posts
//

import SwiftUI

struct FeedbackCommentRow: View {
    let comment: FeedbackComment
    let currentUserId: String?
    let isReply: Bool
    let onReply: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var showDeleteConfirmation = false
    
    private var canDelete: Bool {
        guard let currentUserId = currentUserId else { return false }
        return comment.userId == currentUserId
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Thread indicator for replies
            if isReply {
                Rectangle()
                    .fill(DS.Colors.borderSubtle)
                    .frame(width: 2)
                    .padding(.leading, DS.Spacing.md)
            }
            
            // Avatar
            if let avatarUrl = comment.authorAvatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: isReply ? 28 : 36, height: isReply ? 28 : 36)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            
            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Author and timestamp
                HStack(spacing: DS.Spacing.sm) {
                    Text(comment.authorName)
                        .font(isReply ? DS.Typography.caption1(.semibold) : DS.Typography.subheadline(.semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text(comment.timeAgo)
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    Spacer()
                }
                
                // Comment text
                Text(comment.text)
                    .font(isReply ? DS.Typography.caption1() : DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                HStack(spacing: DS.Spacing.lg) {
                    Button(action: {
                        hapticsManager.lightTap()
                        onReply()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 12))
                            Text("Reply")
                                .font(DS.Typography.caption1())
                        }
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    if canDelete {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Delete")
                                    .font(DS.Typography.caption1())
                            }
                            .foregroundColor(DS.Colors.negativeChange)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, DS.Spacing.xs)
                
                // Nested replies
                if let replies = comment.replies, !replies.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        ForEach(replies) { reply in
                            FeedbackCommentRow(
                                comment: reply,
                                currentUserId: currentUserId,
                                isReply: true,
                                onReply: onReply,
                                onDelete: onDelete
                            )
                        }
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                hapticsManager.mediumTap()
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.cardBackgroundAlt)
            .frame(width: isReply ? 28 : 36, height: isReply ? 28 : 36)
            .overlay(
                Text(comment.authorName.prefix(1).uppercased())
                    .font(.system(size: isReply ? 12 : 14, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            )
    }
}

// MARK: - Comment Composer

struct FeedbackCommentComposer: View {
    @Binding var text: String
    let placeholder: String
    let isLoading: Bool
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(isFocused ? DS.Colors.primaryAccent : DS.Colors.borderSubtle, lineWidth: 1)
                )
            
            Button(action: {
                hapticsManager.mediumTap()
                onSubmit()
            }) {
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                            ? DS.Colors.iconSubtle 
                            : DS.Colors.primaryAccent)
                }
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackground)
    }
}





