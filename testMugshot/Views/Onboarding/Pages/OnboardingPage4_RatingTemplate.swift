//
//  OnboardingPage4_RatingTemplate.swift
//  testMugshot
//
//  Page 4: Rating Template
//

import SwiftUI

struct RatingTemplatePage: View {
    @Binding var ratingTemplate: RatingTemplate
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("How do you judge a great coffee?")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.bottom, DS.Spacing.sm)
            
            // Categories
            VStack(spacing: DS.Spacing.md) {
                ForEach(ratingTemplate.categories) { category in
                    CategoryToggleRow(
                        category: category,
                        isEnabled: true,
                        onToggle: {
                            // Categories are always enabled in onboarding
                            // User can customize later
                        }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Info text
            Text("You can customize these later in your profile.")
                .font(DS.Typography.caption1())
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.top, DS.Spacing.md)
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
    }
}

struct CategoryToggleRow: View {
    let category: RatingCategory
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Text(category.name)
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textPrimary)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(isEnabled ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(DS.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

