//
//  ModernMapLegend.swift
//  testMugshot
//
//  Map legend showing rating color system in Modern Dark Mode
//

import SwiftUI

struct ModernMapLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: DS.Colors.dynamicPrimaryAccent, label: "4.0+")
            legendItem(color: Color(hex: "FFD700"), label: "3.0-3.9")
            legendItem(color: Color(hex: "FF3B30"), label: "<3.0")
            legendItem(color: .clear, label: "Want", hasStroke: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .modernFloatingGlass(cornerRadius: 20)
    }
    
    private func legendItem(color: Color, label: String, hasStroke: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(hasStroke ? DS.Colors.dynamicPrimaryAccent : Color.clear, lineWidth: 2)
                )
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
        }
    }
}


