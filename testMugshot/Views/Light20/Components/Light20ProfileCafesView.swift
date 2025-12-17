//
//  Light20ProfileCafesView.swift
//  testMugshot
//
//  Light 2.0 profile cafes tab
//  List of visited cafes with stats
//

import SwiftUI

struct Light20ProfileCafesView: View {
    @ObservedObject var dataManager: DataManager
    let onCafeTap: (Cafe) -> Void
    
    private var visitedCafes: [(cafe: Cafe, visitCount: Int, avgRating: Double)] {
        let visitedCafeIds = Set(dataManager.appData.visits.map { $0.cafeId })
        
        let cafes = dataManager.appData.cafes.filter { visitedCafeIds.contains($0.id) }
        return cafes.compactMap { cafe in
            let visits = dataManager.appData.visits.filter { $0.cafeId == cafe.id }
            guard !visits.isEmpty else { return nil }
            let total = visits.reduce(0.0) { $0 + $1.overallScore }
            let avgRating = total / Double(visits.count)
            return (cafe: cafe, visitCount: visits.count, avgRating: avgRating)
        }
        .sorted { $0.avgRating > $1.avgRating }
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if visitedCafes.isEmpty {
                emptyState
            } else {
                ForEach(visitedCafes, id: \.cafe.id) { item in
                    Button(action: {
                        onCafeTap(item.cafe)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.cafe.name)
                                    .light20Subheading()
                                
                                Text(item.cafe.address)
                                    .light20Label()
                                    .lineLimit(1)
                                
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(DS.Colors.light20MintPrimary)
                                        Text(String(format: "%.1f", item.avgRating))
                                            .light20Label()
                                    }
                                    
                                    Text("· \(item.visitCount) visit\(item.visitCount == 1 ? "" : "s")")
                                        .light20Label()
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(DS.Colors.light20IconInactive)
                        }
                        .padding()
                    }
                    .light20FloatingCard()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.light20TextTertiary)
            
            Text("No cafes visited yet")
                .light20Subheading()
            
            Text("Start logging visits to build your coffee journey")
                .light20Label()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
}


