//
//  DSCafeAttributionPill.swift
//  testMugshot
//
//  Tappable cafe attribution pill for feed posts
//

import SwiftUI

struct DSCafeAttributionPill: View {
    let cafeName: String
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .medium))
                
                Text(cafeName)
                    .font(DS.Typography.subheadline(.medium))
                    .lineLimit(1)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundColor(DS.Colors.textOnMint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Colors.mintSoftFill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DS.Colors.primaryAccent.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        DSCafeAttributionPill(cafeName: "Needle & Bean")
        DSCafeAttributionPill(cafeName: "City Lights Eastside Coffee Roasters")
        DSCafeAttributionPill(cafeName: "babas on cannon")
    }
    .padding()
    .background(DS.Colors.cardBackground)
}

