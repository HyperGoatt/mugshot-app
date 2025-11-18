//
//  SaveVisitButton.swift
//  testMugshot
//
//  Primary CTA button for saving a visit.
//

import SwiftUI

struct SaveVisitButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let onTap: () -> Void
    
    init(
        title: String = "Save Visit",
        isEnabled: Bool,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            onTap()
        }) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(DS.Colors.textOnMint)
                }
                
                Text(title)
                    .font(DS.Typography.buttonLabel)
                    .foregroundColor(DS.Colors.textOnMint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(isEnabled ? DS.Colors.primaryAccent : DS.Colors.primaryAccent.opacity(0.5))
            .cornerRadius(DS.Radius.lg)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.screenBackground.opacity(0.95))
    }
}


