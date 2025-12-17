//
//  ModernStepProgress.swift
//  testMugshot
//
//  Progress dots indicator for multi-step flow
//

import SwiftUI

struct ModernStepProgress: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicTextTertiary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.vertical, 12)
    }
}


