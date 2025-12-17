//
//  ModernAnimatedStarRating.swift
//  testMugshot
//
//  Animated circle star rating with bounce effect for Modern Log Visit
//

import SwiftUI

struct ModernAnimatedStarRating: View {
    let category: String
    @Binding var rating: Double
    @State private var animatedStars: [Bool] = Array(repeating: false, count: 5)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
                .textCase(.uppercase)
                .kerning(0.5)
            
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    Button(action: {
                        selectStar(index)
                    }) {
                        ZStack {
                            // Outline circle
                            Circle()
                                .stroke(DS.Colors.dynamicTextSecondary, lineWidth: 2)
                                .frame(width: 50, height: 50)
                            
                            // Filled circle
                            if rating > Double(index) {
                                Circle()
                                    .fill(DS.Colors.dynamicPrimaryAccent)
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(animatedStars[index] ? 1.0 : 0.8)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func selectStar(_ index: Int) {
        let newRating = Double(index + 1)
        rating = newRating
        
        // Animate stars with stagger
        for i in 0...index {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    animatedStars[i] = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        animatedStars[i] = false
                    }
                }
            }
        }
        
        // Clear stars after the selected one
        for i in (index + 1)..<5 {
            animatedStars[i] = false
        }
        
        HapticsManager.shared.lightTap()
    }
}


