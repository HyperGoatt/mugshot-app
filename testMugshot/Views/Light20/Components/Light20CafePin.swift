//
//  Light20CafePin.swift
//  testMugshot
//
//  Light 2.0 map cafe pin
//  Rating-based colors: green ≥4.0, yellow 3.0-3.9, red <3.0, blue want-to-try
//

import SwiftUI

struct Light20CafePin: View {
    let rating: Double?
    let isSelected: Bool
    let isWantToTry: Bool
    
    private var pinColor: Color {
        if isWantToTry {
            return DS.Colors.light20BlueAccent
        }
        
        guard let rating = rating else {
            return DS.Colors.light20IconInactive
        }
        
        if rating >= 4.0 { return DS.Colors.light20GreenAccent }
        if rating >= 3.0 { return DS.Colors.light20YellowAccent }
        return DS.Colors.light20RedAccent
    }
    
    var body: some View {
        ZStack {
            // Pin shadow
            Circle()
                .fill(pinColor.opacity(0.3))
                .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                .blur(radius: 4)
            
            // Pin circle
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
            
            // Rating text
            if let rating = rating, !isWantToTry {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: isSelected ? 11 : 9, weight: .bold))
                    .foregroundColor(.white)
            } else if isWantToTry {
                Image(systemName: "star.fill")
                    .font(.system(size: isSelected ? 14 : 12))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}


