//
//  ModernCafePin.swift
//  testMugshot
//
//  Custom mint pill pin for cafe annotations in Modern Dark Mode
//

import SwiftUI
import MapKit

struct ModernCafePin: View {
    let rating: Double
    let isSelected: Bool
    let isWantToTry: Bool
    
    private var pinColor: Color {
        if isWantToTry {
            return .clear // Hollow for want to try
        }
        if rating >= 4.0 {
            return DS.Colors.dynamicPrimaryAccent // Mint for excellent
        }
        if rating >= 3.0 {
            return Color(hex: "FFD700") // Yellow for good
        }
        return Color(hex: "FF3B30") // Red for poor
    }
    
    private var textColor: Color {
        if isWantToTry {
            return .white
        }
        if rating < 3.0 {
            return .white // White text on red
        }
        return Color(hex: "052E16") // Dark text on mint/yellow
    }
    
    private var shadowColor: Color {
        if isWantToTry {
            return DS.Colors.dynamicPrimaryAccent
        }
        return pinColor
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isWantToTry ? "bookmark.fill" : "star.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textColor)
            
            Text(isWantToTry ? "Want" : String(format: "%.1f", rating))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(pinColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isWantToTry ? DS.Colors.dynamicPrimaryAccent : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .shadow(
            color: isSelected ? shadowColor.opacity(0.6) : shadowColor.opacity(0.3),
            radius: isSelected ? 12 : 6,
            x: 0,
            y: isSelected ? 6 : 3
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// Custom annotation for cafe pins
struct ModernCafeAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let cafe: Cafe
    let rating: Double
    let isWantToTry: Bool
}


