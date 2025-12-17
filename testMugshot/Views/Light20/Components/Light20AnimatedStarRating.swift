//
//  Light20AnimatedStarRating.swift
//  testMugshot
//
//  Light 2.0 animated star rating
//  Staggered fill animation on appearance
//

import SwiftUI

struct Light20AnimatedStarRating: View {
    let rating: Double
    let size: CGFloat
    
    @State private var animatedRating: Double = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: starIcon(for: index))
                    .font(.system(size: size))
                    .foregroundColor(starColor(for: index))
                    .scaleEffect(animatedRating >= Double(index) + 0.5 ? 1.0 : 0.8)
                    .opacity(animatedRating >= Double(index) + 0.5 ? 1.0 : 0.3)
            }
            
            Text(String(format: "%.1f", rating))
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundColor(DS.Colors.light20CharcoalBlack)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedRating = rating
            }
        }
    }
    
    private func starIcon(for index: Int) -> String {
        let starValue = Double(index) + 1
        if animatedRating >= starValue {
            return "star.fill"
        } else if animatedRating >= starValue - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let starValue = Double(index) + 1
        if animatedRating >= starValue - 0.5 {
            if rating >= 4.0 { return DS.Colors.light20GreenAccent }
            if rating >= 3.0 { return DS.Colors.light20YellowAccent }
            return DS.Colors.light20RedAccent
        }
        return DS.Colors.light20IconInactive
    }
}


