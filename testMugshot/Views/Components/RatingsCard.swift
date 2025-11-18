//
//  RatingsCard.swift
//  testMugshot
//
//  Card for per-criterion ratings with animated stars and overall score.
//

import SwiftUI

struct RatingsCard: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    let onCustomizeTapped: () -> Void
    
    var body: some View {
        FormSectionCard(title: "Ratings") {
            headerRow
            
            ForEach(dataManager.appData.ratingTemplate.categories) { category in
                RatingCategoryRow(
                    category: category,
                    rating: Binding(
                        get: { ratings[category.name] ?? 0.0 },
                        set: { ratings[category.name] = $0 }
                    ),
                    weightMultiplier: dataManager.appData.ratingTemplate.getWeightMultiplier(for: category)
                )
            }
            
            Divider()
                .padding(.vertical, DS.Spacing.sm)
            
            HStack {
                Text("Overall Score")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                DSScoreBadge(score: overallScore)
            }
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text("Ratings")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Spacer()
            
            Button(action: onCustomizeTapped) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(DS.Typography.caption2())
                    Text("Customize")
                        .font(DS.Typography.bodyText)
                }
                .foregroundColor(DS.Colors.primaryAccent)
            }
        }
    }
}

struct RatingCategoryRow: View {
    let category: RatingCategory
    @Binding var rating: Double
    let weightMultiplier: Double
    
    @State private var triggerID: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                HStack(spacing: 4) {
                    Text(category.name)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    if weightMultiplier != 1.0 {
                        Text("(\(formatWeight(weightMultiplier)) importance)")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                }
                
                Spacer()
            }
            
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Button(action: {
                            let newRating = Double(index + 1)
                            let oldRating = rating
                            rating = rating == newRating ? 0.0 : newRating
                            
                            if rating != oldRating && rating > 0 {
                                triggerID &+= 1
                            }
                        }) {
                            Image(systemName: rating > Double(index) ? "star.fill" : "star")
                                .foregroundColor(rating > Double(index) ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
                                .font(.system(size: 20))
                        }
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


