//
//  FeedbackVoteControl.swift
//  testMugshot
//
//  Reusable vote control for feedback posts
//

import SwiftUI

struct FeedbackVoteControl: View {
    let voteScore: Int
    let currentUserVote: FeedbackVoteType?
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    private var displayScore: String {
        if voteScore > 0 {
            return "+\(voteScore)"
        } else {
            return "\(voteScore)"
        }
    }
    
    private var scoreColor: Color {
        if voteScore > 0 {
            return DS.Colors.positiveChange
        } else if voteScore < 0 {
            return DS.Colors.negativeChange
        } else {
            return DS.Colors.textSecondary
        }
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Upvote button
            Button(action: {
                hapticsManager.lightTap()
                onUpvote()
            }) {
                Image(systemName: currentUserVote == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(currentUserVote == .up ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
            }
            .buttonStyle(.plain)
            
            // Vote count
            Text(displayScore)
                .font(DS.Typography.headline())
                .foregroundColor(scoreColor)
                .monospacedDigit()
            
            // Downvote button
            Button(action: {
                hapticsManager.lightTap()
                onDownvote()
            }) {
                Image(systemName: currentUserVote == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(currentUserVote == .down ? DS.Colors.negativeChange : DS.Colors.iconDefault)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 44)
    }
}

// MARK: - Horizontal Variant

struct FeedbackVoteControlHorizontal: View {
    let voteScore: Int
    let currentUserVote: FeedbackVoteType?
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    private var displayScore: String {
        if voteScore > 0 {
            return "+\(voteScore)"
        } else {
            return "\(voteScore)"
        }
    }
    
    private var scoreColor: Color {
        if voteScore > 0 {
            return DS.Colors.positiveChange
        } else if voteScore < 0 {
            return DS.Colors.negativeChange
        } else {
            return DS.Colors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Upvote button
            Button(action: {
                hapticsManager.lightTap()
                onUpvote()
            }) {
                Image(systemName: currentUserVote == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(currentUserVote == .up ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
            }
            .buttonStyle(.plain)
            
            // Vote count
            Text(displayScore)
                .font(DS.Typography.subheadline(.semibold))
                .foregroundColor(scoreColor)
                .monospacedDigit()
                .frame(minWidth: 30)
            
            // Downvote button
            Button(action: {
                hapticsManager.lightTap()
                onDownvote()
            }) {
                Image(systemName: currentUserVote == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(currentUserVote == .down ? DS.Colors.negativeChange : DS.Colors.iconDefault)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.pill)
    }
}





