//
//  Light20StepProgress.swift
//  testMugshot
//
//  Light 2.0 step progress indicator
//  Mint dots for completed, grey for incomplete
//

import SwiftUI

struct Light20StepProgress: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? DS.Colors.light20MintPrimary : DS.Colors.light20IconInactive.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}


