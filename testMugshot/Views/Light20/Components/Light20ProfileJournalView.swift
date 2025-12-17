//
//  Light20ProfileJournalView.swift
//  testMugshot
//
//  Light 2.0 profile journal tab
//  Chronological visit entries with date headers
//

import SwiftUI

struct Light20ProfileJournalView: View {
    @ObservedObject var dataManager: DataManager
    let onVisitTap: (Visit) -> Void
    
    private var sortedVisits: [Visit] {
        dataManager.appData.visits
            .filter { $0.userId == dataManager.appData.currentUser?.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var groupedByMonth: [(month: String, visits: [Visit])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedVisits) { visit in
            calendar.dateComponents([.year, .month], from: visit.createdAt)
        }
        
        return grouped
            .sorted { lhs, rhs in
                let lhsDate = calendar.date(from: lhs.key) ?? Date.distantPast
                let rhsDate = calendar.date(from: rhs.key) ?? Date.distantPast
                return lhsDate > rhsDate
            }
            .map { (month: monthString(from: $0.key), visits: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if sortedVisits.isEmpty {
                emptyState
            } else {
                ForEach(groupedByMonth, id: \.month) { group in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(group.month)
                            .light20Caption()
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        
                        ForEach(group.visits) { visit in
                            let cafeName = dataManager.appData.cafes.first { $0.id == visit.cafeId }?.name ?? "Unknown Cafe"
                            JournalEntryRow(
                                visit: visit,
                                cafeName: cafeName,
                                onTap: { onVisitTap(visit) }
                            )
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                    }
                }
            }
        }
        .padding(.top, DS.Spacing.lg)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.light20TextTertiary)
            
            Text("No journal entries")
                .light20Subheading()
            
            Text("Start logging visits to create your coffee story")
                .light20Label()
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private func monthString(from components: DateComponents) -> String {
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct JournalEntryRow: View {
    let visit: Visit
    let cafeName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let photo = visit.photos.first {
                    PhotoImageView(
                        photoPath: photo,
                        remoteURL: visit.remotePhotoURLByKey[photo]
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafeName)
                        .light20Subheading()
                        .lineLimit(1)
                    
                    Text(drinkLabel)
                        .light20Label()
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.light20MintPrimary)
                        Text(String(format: "%.1f", visit.overallScore))
                            .light20Label()
                    }
                }
                
                Spacer()
                
                Text(dayString(from: visit.createdAt))
                    .light20Caption()
            }
            .padding()
        }
        .light20FloatingCard()
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

extension JournalEntryRow {
    private var drinkLabel: String {
        if let subtype = visit.drinkSubtype, !subtype.isEmpty {
            return subtype
        }
        if let custom = visit.customDrinkType, !custom.isEmpty {
            return custom
        }
        return visit.drinkType.rawValue
    }
}


