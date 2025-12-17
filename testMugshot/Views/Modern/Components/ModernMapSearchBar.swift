//
//  ModernMapSearchBar.swift
//  testMugshot
//
//  Floating glass search bar for Modern Map
//

import SwiftUI

struct ModernMapSearchBar: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
            
            TextField("Search cafes...", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
                .tint(DS.Colors.dynamicPrimaryAccent)
                .autocapitalization(.none)
                .onSubmit(onSubmit)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isActive = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .modernFloatingGlass(cornerRadius: 25)
    }
}


