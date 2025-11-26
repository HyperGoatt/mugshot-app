//
//  CoffeeStatsRibbon.swift
//  testMugshot
//
//  Horizontal scrolling stats ribbon for profile
//

import SwiftUI

struct CoffeeStatsRibbon: View {
    let totalVisits: Int
    let totalCafes: Int
    let averageRating: Double
    let favoriteDrinkType: String?
    let topCafe: (name: String, rating: Double)?
    let onTopCafeTap: (() -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                // Total Visits
                StatPill(
                    value: "\(totalVisits)",
                    label: "Visits",
                    icon: nil
                )
                
                // Total Cafés
                StatPill(
                    value: "\(totalCafes)",
                    label: "Cafés",
                    icon: nil
                )
                
                // Average Rating
                StatPill(
                    value: averageRating > 0 ? String(format: "%.1f", averageRating) : "—",
                    label: "Avg",
                    icon: "star.fill",
                    iconColor: DS.Colors.secondaryAccent
                )
                
                // Favorite Drink
                if let drink = favoriteDrinkType, !drink.isEmpty {
                    StatPill(
                        value: drink,
                        label: "Favorite",
                        icon: "cup.and.saucer.fill",
                        iconColor: DS.Colors.primaryAccent,
                        isTextValue: true
                    )
                }
                
                // Top Café (if exists)
                if let cafe = topCafe {
                    Button(action: { onTopCafeTap?() }) {
                        TopCafeStatPill(
                            cafeName: cafe.name,
                            rating: cafe.rating
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
}

// MARK: - Stat Pill Component

struct StatPill: View {
    let value: String
    let label: String
    let icon: String?
    var iconColor: Color = DS.Colors.textPrimary
    var isTextValue: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                    
                    Text(value)
                        .font(isTextValue ? DS.Typography.subheadline(.semibold) : DS.Typography.title2(.bold))
                        .foregroundColor(DS.Colors.textPrimary)
                }
            } else {
                Text(value)
                    .font(isTextValue ? DS.Typography.subheadline(.semibold) : DS.Typography.title2(.bold))
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            Text(label)
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.lg)
    }
}

// MARK: - Top Café Stat Pill

struct TopCafeStatPill: View {
    let cafeName: String
    let rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.primaryAccent)
                Text("Top Café")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
                    .textCase(.uppercase)
            }
            
            Text(cafeName)
                .font(DS.Typography.subheadline(.semibold))
                .foregroundColor(DS.Colors.textPrimary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.secondaryAccent)
                Text(String(format: "%.1f", rating))
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Beverage Breakdown Compact

struct BeverageBreakdownCompact: View {
    let beverageData: [(drinkType: DrinkType, count: Int, fraction: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Beverage Mix")
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textSecondary)
                .textCase(.uppercase)
            
            if beverageData.isEmpty {
                Text("No drinks yet")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
            } else {
                // Show top 3 beverages as small bars
                ForEach(beverageData.prefix(3), id: \.drinkType) { item in
                    HStack(spacing: DS.Spacing.sm) {
                        Text(item.drinkType.rawValue)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DS.Colors.mintSoftFill)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DS.Colors.primaryAccent)
                                    .frame(width: geometry.size.width * CGFloat(item.fraction), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(item.count)")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textSecondary)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.lg)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        CoffeeStatsRibbon(
            totalVisits: 42,
            totalCafes: 15,
            averageRating: 4.2,
            favoriteDrinkType: "Latte",
            topCafe: (name: "Needle & Bean", rating: 4.5),
            onTopCafeTap: {}
        )
        
        CoffeeStatsRibbon(
            totalVisits: 2,
            totalCafes: 2,
            averageRating: 3.2,
            favoriteDrinkType: "Coffee",
            topCafe: nil,
            onTopCafeTap: nil
        )
        
        HStack {
            BeverageBreakdownCompact(beverageData: [
                (drinkType: .coffee, count: 15, fraction: 0.6),
                (drinkType: .matcha, count: 8, fraction: 0.32),
                (drinkType: .tea, count: 2, fraction: 0.08)
            ])
            .frame(width: 180)
            
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    .padding(.vertical, DS.Spacing.lg)
    .background(DS.Colors.screenBackground)
}

