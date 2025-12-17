//
//  ModernCafeListCard.swift
//  testMugshot
//
//  Cafe list card for Modern Profile cafes section
//

import SwiftUI

struct ModernCafeListCard: View {
    let cafe: Cafe
    let visitCount: Int
    let userRating: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cafe image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                    )
                
                // Cafe info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                        .lineLimit(1)
                    
                    Text(cafe.address)
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(visitCount) \(visitCount == 1 ? "visit" : "visits")")
                            .font(.system(size: 13))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                        
                        if userRating > 0 {
                            Text("•")
                                .foregroundColor(DS.Colors.dynamicTextTertiary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text(String(format: "%.1f", userRating))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            }
            .padding(12)
            .background(DS.Colors.dynamicCardBackgroundAlt)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


