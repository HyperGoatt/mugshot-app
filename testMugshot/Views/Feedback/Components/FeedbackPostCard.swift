//
//  FeedbackPostCard.swift
//  testMugshot
//
//  Compact card for displaying feedback posts in a list
//

import SwiftUI

struct FeedbackPostCard: View {
    let post: FeedbackPost
    let onTap: () -> Void
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    var body: some View {
        Button(action: {
            hapticsManager.lightTap()
            onTap()
        }) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Vote control on the left
                FeedbackVoteControl(
                    voteScore: post.voteScore,
                    currentUserVote: post.currentUserVote,
                    onUpvote: onUpvote,
                    onDownvote: onDownvote
                )
                
                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Category pill and timestamp
                    HStack(spacing: DS.Spacing.sm) {
                        FeedbackCategoryPill(category: post.category)
                        
                        Spacer()
                        
                        Text(post.timeAgo)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    
                    // Title
                    Text(post.title)
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Body preview
                    Text(post.body)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Footer: author and comment count
                    HStack(spacing: DS.Spacing.md) {
                        // Author
                        HStack(spacing: DS.Spacing.xs) {
                            if let avatarUrl = post.authorAvatarUrl, let url = URL(string: avatarUrl) {
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
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                            } else {
                                authorPlaceholder
                            }
                            
                            Text(post.authorName)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Comment count
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.iconSubtle)
                            
                            Text("\(post.commentCount)")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
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
        .buttonStyle(.plain)
    }
    
    private var authorPlaceholder: some View {
        Circle()
            .fill(DS.Colors.cardBackgroundAlt)
            .frame(width: 20, height: 20)
            .overlay(
                Text(post.authorName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            )
    }
}

// MARK: - Category Pill

struct FeedbackCategoryPill: View {
    let category: FeedbackCategory
    
    private var backgroundColor: Color {
        switch category {
        case .bug:
            return DS.Colors.redAccent.opacity(0.15)
        case .feature:
            return DS.Colors.blueSoftFill
        case .general:
            return DS.Colors.primaryAccentSoftFill
        }
    }
    
    private var foregroundColor: Color {
        switch category {
        case .bug:
            return DS.Colors.redAccent
        case .feature:
            return DS.Colors.blueAccent
        case .general:
            return DS.Colors.textPrimary
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
            
            Text(category.displayName)
                .font(DS.Typography.caption2(.medium))
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(DS.Radius.pill)
    }
}



