//
//  RatingsCard.swift
//  testMugshot
//
//  Collapsible ratings card with quick-rate stars and detailed category breakdown.
//  Supports half-star ratings with intuitive tap-to-cycle interaction.
//

import SwiftUI

struct RatingsCard: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    let onCustomizeTapped: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var quickRating: Double = 0
    @EnvironmentObject private var hapticsManager: HapticsManager
    
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
                    // Quick rating stars (large) - now with half-star support
                    HalfStarRatingRow(
                        rating: $quickRating,
                        starSize: 32,
                        onRatingChanged: { newRating in
                            autoAssignToCategories(newRating)
                        }
                    )
                    
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
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Divider()
                .background(DS.Colors.dividerSubtle)
                .padding(.vertical, DS.Spacing.xs)
            
            // Category ratings with half-star support
            ForEach(dataManager.appData.ratingTemplate.categories) { category in
                HalfStarCategoryRow(
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

// MARK: - Half Star Rating Row (Main Quick Rating)

struct HalfStarRatingRow: View {
    @Binding var rating: Double
    var starSize: CGFloat = 32
    var onRatingChanged: ((Double) -> Void)?
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var lastTappedStar: Int? = nil
    @State private var tapCount: Int = 0
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Interactive half-star rating
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<5) { index in
                    HalfStarButton(
                        index: index,
                        rating: rating,
                        size: starSize,
                        onTap: { handleStarTap(index) }
                    )
                }
            }
            
            Spacer()
            
            // Numeric display with half-star formatting
            if rating > 0 {
                Text(formatRating(rating))
                    .font(DS.Typography.title2())
                    .foregroundColor(DS.Colors.textPrimary)
            }
        }
    }
    
    private func handleStarTap(_ index: Int) {
        let starNumber = index + 1
        
        if lastTappedStar == starNumber {
            // Same star tapped again - cycle through states
            tapCount += 1
            
            let currentForThisStar = rating
            
            if tapCount == 1 && currentForThisStar == Double(starNumber) {
                // First re-tap: full star → half star (e.g., 4.0 → 4.5)
                rating = Double(starNumber) + 0.5
            } else if tapCount >= 2 || currentForThisStar == Double(starNumber) + 0.5 {
                // Second re-tap or already at half: reset to 0
                rating = 0
                tapCount = 0
                lastTappedStar = nil
            }
        } else {
            // Different star tapped - set to full star value
            rating = Double(starNumber)
            lastTappedStar = starNumber
            tapCount = 0
        }
        
        hapticsManager.selectionChanged()
        onRatingChanged?(rating)
    }
    
    private func formatRating(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Half Star Button

struct HalfStarButton: View {
    let index: Int
    let rating: Double
    var size: CGFloat = 32
    let onTap: () -> Void
    
    private var starState: StarState {
        let starNumber = Double(index + 1)
        if rating >= starNumber {
            return .full
        } else if rating >= starNumber - 0.5 {
            return .half
        } else {
            return .empty
        }
    }
    
    enum StarState {
        case empty, half, full
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                switch starState {
                case .full:
                    Image(systemName: "star.fill")
                        .font(.system(size: size))
                        .foregroundColor(DS.Colors.primaryAccent)
                case .half:
                    Image(systemName: "star.leadinghalf.filled")
                        .font(.system(size: size))
                        .foregroundColor(DS.Colors.primaryAccent)
                case .empty:
                    Image(systemName: "star")
                        .font(.system(size: size))
                        .foregroundColor(DS.Colors.textTertiary.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
            .frame(width: size + 4, height: size + 4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: starState)
    }
}

// MARK: - Half Star Category Row

struct HalfStarCategoryRow: View {
    let category: RatingCategory
    @Binding var rating: Double
    let weightMultiplier: Double
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var lastTappedStar: Int? = nil
    @State private var tapCount: Int = 0
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
            
            // Half-star rating
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        HalfStarButton(
                            index: index,
                            rating: rating,
                            size: 20,
                            onTap: { handleStarTap(index) }
                        )
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
    
    private func handleStarTap(_ index: Int) {
        let starNumber = index + 1
        let oldRating = rating
        
        if lastTappedStar == starNumber {
            // Same star tapped again - cycle through states
            tapCount += 1
            
            if tapCount == 1 && rating == Double(starNumber) {
                // First re-tap: full star → half star
                rating = Double(starNumber) + 0.5
            } else if tapCount >= 2 || rating == Double(starNumber) + 0.5 {
                // Second re-tap or already at half: reset to 0
                rating = 0
                tapCount = 0
                lastTappedStar = nil
            }
        } else {
            // Different star tapped - set to full star value
            rating = Double(starNumber)
            lastTappedStar = starNumber
            tapCount = 0
        }
        
        hapticsManager.selectionChanged()
        
        if rating != oldRating && rating > 0 {
            triggerID &+= 1
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0fx", weight)
        } else {
            return String(format: "%.1fx", weight)
        }
    }
}

// MARK: - Legacy Rating Category Row (kept for backward compatibility)

struct RatingCategoryRow: View {
    let category: RatingCategory
    @Binding var rating: Double
    let weightMultiplier: Double
    
    var body: some View {
        HalfStarCategoryRow(
            category: category,
            rating: $rating,
            weightMultiplier: weightMultiplier
        )
    }
}
