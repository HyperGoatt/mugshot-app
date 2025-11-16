//
//  DSPrimaryButton.swift
//

import SwiftUI

struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.buttonLabel)
            .foregroundColor(DS.Colors.textOnMint)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.primaryAccent)
            .cornerRadius(DS.Radius.primaryButton)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                    .fill(Color.clear)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .dsCardShadow()
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


