//
//  Light20MapSearchBar.swift
//  testMugshot
//
//  Light 2.0 map search bar
//  Floating white bar with shadow
//

import SwiftUI

struct Light20MapSearchBar: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DS.Colors.light20TextSecondary)
            
            TextField("Search cafes...", text: $searchText, onCommit: onSubmit)
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.light20CharcoalBlack)
                .onTapGesture {
                    isActive = true
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isActive = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DS.Colors.light20IconInactive)
                }
            }
        }
        .padding(14)
        .light20FloatingCard()
    }
}


