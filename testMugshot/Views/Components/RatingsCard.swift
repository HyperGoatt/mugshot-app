//
//  RatingsCard.swift
//  testMugshot
//
//  Collapsible ratings card with quick-rate stars and detailed category breakdown.
//

import SwiftUI

struct RatingsCard: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    let onCustomizeTapped: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var quickRating: Double = 0
    @StateObject private var hapticsManager = HapticsManager.shared
    
    // Compute if any detailed ratings have been set
    private var hasDetailedRatings: Bool {
        ratings.values.contains(where: { $0 > 0 })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "star.fill")
                    .foregroundColor(DS.Colors.primaryAccent)
                    .font(.system(size: 16))
                Text("How was it?")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                // Score badge - only show when there's a rating
                if overallScore > 0 {
                    DSScoreBadge(score: overallScore)
                }
            }
            
            // Main card content
            DSBaseCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Quick rating stars (large)
                    quickRatingRow
                    
                    // Expand/collapse button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                        hapticsManager.lightTap()
                    }) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isExpanded ? "Hide categories" : "Rate by category")
                                .font(DS.Typography.caption1())
                            
                            Text("(optional)")
                                .font(DS.Typography.caption2())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Expanded category ratings
                    if isExpanded {
                        expandedContent
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .onAppear {
            syncQuickRatingFromCategories()
        }
        .onChange(of: ratings) { _, _ in
            // Keep quick rating in sync when categories change
            if hasDetailedRatings {
                quickRating = overallScore
            }
        }
    }
    
    // MARK: - Quick Rating Row
    
    private var quickRatingRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Large interactive stars
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<5) { index in
                    Button(action: {
                        let newRating = Double(index + 1)
                        
                        // Toggle off if tapping same star
                        if quickRating == newRating {
                            quickRating = 0
                            autoAssignToCategories(0)
                        } else {
                            quickRating = newRating
                            autoAssignToCategories(newRating)
                        }
                        
                        hapticsManager.lightTap()
                    }) {
                        Image(systemName: quickRating > Double(index) ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(quickRating > Double(index) ? DS.Colors.primaryAccent : DS.Colors.textTertiary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Numeric display
            if quickRating > 0 || overallScore > 0 {
                Text(String(format: "%.1f", overallScore > 0 ? overallScore : quickRating))
                    .font(DS.Typography.title2())
                    .foregroundColor(DS.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Divider()
                .background(DS.Colors.dividerSubtle)
                .padding(.vertical, DS.Spacing.xs)
            
            // Category ratings
            ForEach(dataManager.appData.ratingTemplate.categories) { category in
                RatingCategoryRow(
                    category: category,
                    rating: Binding(
                        get: { ratings[category.name] ?? 0.0 },
                        set: { newValue in
                            ratings[category.name] = newValue
                            // Update quick rating to reflect overall
                            quickRating = overallScore
                        }
                    ),
                    weightMultiplier: dataManager.appData.ratingTemplate.getWeightMultiplier(for: category)
                )
            }
            
            Divider()
                .background(DS.Colors.dividerSubtle)
                .padding(.vertical, DS.Spacing.xs)
            
            // Customize link
            Button(action: onCustomizeTapped) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                    Text("Customize categories")
                        .font(DS.Typography.caption1())
                }
                .foregroundColor(DS.Colors.primaryAccent)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    
    private func autoAssignToCategories(_ value: Double) {
        for category in dataManager.appData.ratingTemplate.categories {
            ratings[category.name] = value
        }
    }
    
    private func syncQuickRatingFromCategories() {
        if hasDetailedRatings {
            quickRating = overallScore
        }
    }
}

// MARK: - Rating Category Row

struct RatingCategoryRow: View {
    let category: RatingCategory
    @Binding var rating: Double
    let weightMultiplier: Double
    
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var triggerID: Int = 0
    
    var body: some View {
        HStack {
            // Category name
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if weightMultiplier != 1.0 {
                    Text("\(formatWeight(weightMultiplier)) importance")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Stars (smaller)
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Button(action: {
                            let newRating = Double(index + 1)
                            let oldRating = rating
                            rating = rating == newRating ? 0.0 : newRating
                            
                            hapticsManager.lightTap()
                            
                            if rating != oldRating && rating > 0 {
                                triggerID &+= 1
                            }
                        }) {
                            Image(systemName: rating > Double(index) ? "star.fill" : "star")
                                .foregroundColor(rating > Double(index) ? DS.Colors.primaryAccent : DS.Colors.textTertiary.opacity(0.4))
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                StarBurstOverlay(
                    rating: rating,
                    maxRating: 5,
                    triggerID: $triggerID
                )
                .offset(x: 0, y: -15)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0fx", weight)
        } else {
            return String(format: "%.1fx", weight)
        }
    }
}
