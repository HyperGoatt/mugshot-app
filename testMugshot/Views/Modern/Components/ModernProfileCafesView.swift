//
//  ModernProfileCafesView.swift
//  testMugshot
//
//  Cafes section for Modern Profile
//

import SwiftUI

struct ModernProfileCafesView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    private var userCafes: [(cafe: Cafe, visitCount: Int, rating: Double)] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        
        var cafeData: [UUID: (visits: Int, totalRating: Double, ratingCount: Int)] = [:]
        
        for visit in dataManager.appData.visits where visit.userId == currentUserId {
            if cafeData[visit.cafeId] == nil {
                cafeData[visit.cafeId] = (visits: 0, totalRating: 0, ratingCount: 0)
            }
            cafeData[visit.cafeId]?.visits += 1
            if visit.overallScore > 0 {
                cafeData[visit.cafeId]?.totalRating += visit.overallScore
                cafeData[visit.cafeId]?.ratingCount += 1
            }
        }
        
        return cafeData.compactMap { cafeId, data in
            guard let cafe = dataManager.getCafe(id: cafeId) else { return nil }
            let avgRating = data.ratingCount > 0 ? data.totalRating / Double(data.ratingCount) : 0
            return (cafe: cafe, visitCount: data.visits, rating: avgRating)
        }.sorted { $0.visitCount > $1.visitCount }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if userCafes.isEmpty {
                emptyState
            } else {
                ForEach(userCafes, id: \.cafe.id) { cafeData in
                    ModernCafeListCard(
                        cafe: cafeData.cafe,
                        visitCount: cafeData.visitCount,
                        userRating: cafeData.rating,
                        onTap: {
                            hapticsManager.lightTap()
                            selectedCafe = cafeData.cafe
                            showCafeDetail = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                ModernCafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: nil
                )
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            Text("No cafes visited yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text("Start exploring and log your first visit")
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
