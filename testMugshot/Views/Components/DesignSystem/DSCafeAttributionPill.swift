//
//  DSCafeAttributionPill.swift
//  testMugshot
//
//  Tappable cafe attribution pill for feed posts
//

import SwiftUI

struct DSCafeAttributionPill: View {
    let cafeName: String
    var icon: String = "location.fill"
    var isTappable: Bool = true
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { if isTappable { onTap?() } }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                
                Text(cafeName)
                    .font(DS.Typography.subheadline(.medium))
                    .lineLimit(1)
                
                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.7)
                }
            }
            .foregroundColor(isTappable ? DS.Colors.textOnMint : DS.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isTappable ? DS.Colors.mintSoftFill : DS.Colors.cardBackgroundAlt)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isTappable ? DS.Colors.primaryAccent.opacity(0.3) : DS.Colors.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
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

