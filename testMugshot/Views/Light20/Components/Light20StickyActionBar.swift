//
//  Light20StickyActionBar.swift
//  testMugshot
//
//  Light 2.0 sticky bottom action bar
//  Wide pill button style
//

import SwiftUI

struct Light20StickyActionBar: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DS.Colors.light20Divider)
            
            Button(action: action) {
                Text(title)
            }
            .buttonStyle(Light20PrimaryButtonStyle())
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.vertical, 16)
            .background(DS.Colors.light20Background)
        }
    }
}


