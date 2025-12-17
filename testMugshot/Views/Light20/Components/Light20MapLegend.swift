//
//  Light20MapLegend.swift
//  testMugshot
//
//  Light 2.0 map rating legend
//  Compact color-coded dots with labels
//

import SwiftUI

struct Light20MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR RATINGS")
                .light20Caption()
            
            Light20LegendItem(color: DS.Colors.light20GreenAccent, label: "≥ 4.0")
            Light20LegendItem(color: DS.Colors.light20YellowAccent, label: "3.0–3.9")
            Light20LegendItem(color: DS.Colors.light20RedAccent, label: "< 3.0")
            Light20LegendItem(color: DS.Colors.light20BlueAccent, label: "Want to try")
            
            Text("Tap pins for details.")
                .font(.system(size: 11))
                .foregroundColor(DS.Colors.light20TextTertiary)
        }
        .padding(12)
        .light20FloatingCard()
    }
}

private struct Light20LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.light20CharcoalBlack)
        }
    }
}


