//
//  SearchThisAreaButton.swift
//  testMugshot
//
//  Floating button to trigger search in the current map region
//

import SwiftUI

struct SearchThisAreaButton: View {
    let action: () -> Void
    let isSearching: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(DS.Colors.primaryAccent)
                }
                
                Text("Search This Area")
                    .font(DS.Typography.caption1(.semibold))
                    .foregroundColor(DS.Colors.primaryAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DS.Colors.cardBackground)
            .cornerRadius(20)
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 6,
                x: 0,
                y: 3
            )
        }
    }
}

