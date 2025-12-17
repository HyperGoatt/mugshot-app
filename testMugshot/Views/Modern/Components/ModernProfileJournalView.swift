//
//  ModernProfileJournalView.swift
//  testMugshot
//
//  Journal section for Modern Profile
//

import SwiftUI

struct ModernProfileJournalView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var showLogVisit = false
    
    private var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }
    
    private var currentStreak: Int {
        // Calculate current streak (days in a row with visits)
        guard let currentUserId = dataManager.appData.currentUser?.id else { return 0 }
        let userVisits = dataManager.appData.visits
            .filter { $0.userId == currentUserId }
            .sorted { $0.createdAt > $1.createdAt }
        
        guard !userVisits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var lastDate = calendar.startOfDay(for: Date())
        
        for visit in userVisits {
            let visitDate = calendar.startOfDay(for: visit.createdAt)
            if calendar.isDate(visitDate, inSameDayAs: lastDate) {
                if streak == 0 { streak = 1 }
                continue
            }
            
            let daysBetween = calendar.dateComponents([.day], from: visitDate, to: lastDate).day ?? 0
            if daysBetween == 1 {
                streak += 1
                lastDate = visitDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var todayVisitCount: Int {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return dataManager.appData.visits.filter {
            $0.userId == currentUserId && calendar.isDate($0.createdAt, inSameDayAs: today)
        }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Coffee Journey card (already exists in main profile)
            coffeeJourneyCard
            
            // Today's Mugshot card
            todaysMugshotCard
            
            // Streaks & Consistency card
            streaksCard
            
            // Log a visit button
            Button(action: {
                hapticsManager.mediumTap()
                showLogVisit = true
            }) {
                Text("Log a Visit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.Colors.modernTextOnMint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.Colors.dynamicPrimaryAccent)
                    .cornerRadius(20)
                    .modernMintGlow()
            }
        }
        .fullScreenCover(isPresented: $showLogVisit) {
            ModernLogVisitView(
                dataManager: dataManager,
                preselectedCafe: nil
            )
        }
    }
    
    // MARK: - Coffee Journey Card
    
    private var coffeeJourneyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COFFEE JOURNEY")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            HStack(spacing: 24) {
                statColumn(
                    value: String(format: "%.1f", stats.averageScore),
                    label: "Avg Rating"
                )
                
                statColumn(
                    value: "\(stats.totalVisits)",
                    label: "Total Visits"
                )
                
                statColumn(
                    value: "\(stats.totalCafes)",
                    label: "Cafes"
                )
            }
        }
        .padding(20)
        .themeAwareFloatingCard(cornerRadius: 20)
    }
    
    // MARK: - Today's Mugshot Card
    
    private var todaysMugshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S MUGSHOT")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(todayVisitCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                    
                    Text(todayVisitCount == 1 ? "visit today" : "visits today")
                        .font(.system(size: 15))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.dynamicPrimaryAccent.opacity(0.3))
            }
        }
        .padding(20)
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Streaks Card
    
    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STREAKS & CONSISTENCY")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                    
                    Text("day streak")
                        .font(.system(size: 15))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let favoriteDrink = stats.favoriteDrinkType {
                        Text(favoriteDrink.rawValue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                        
                        Text("Favorite Drink")
                            .font(.system(size: 13))
                            .foregroundColor(DS.Colors.dynamicTextSecondary)
                    }
                }
            }
        }
        .padding(20)
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Helper
    
    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
        }
    }
}
