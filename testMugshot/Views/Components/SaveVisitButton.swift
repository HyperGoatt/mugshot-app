//
//  SaveVisitButton.swift
//  testMugshot
//
//  Primary CTA button for posting a visit with helper text.
//

import SwiftUI

struct SaveVisitButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let helperText: String?
    let onTap: () -> Void
    
    init(
        title: String = "Post to Journal",
        isEnabled: Bool,
        isLoading: Bool = false,
        helperText: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.helperText = helperText
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Main button
            Button(action: {
                guard isEnabled && !isLoading else { return }
                onTap()
            }) {
                HStack(spacing: DS.Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .tint(DS.Colors.textOnMint)
                    }
                    
                    Text(isLoading ? "Posting..." : title)
                        .font(DS.Typography.buttonLabel)
                        .foregroundColor(isEnabled ? DS.Colors.textOnMint : DS.Colors.textOnMint.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(isEnabled ? DS.Colors.primaryAccent : DS.Colors.primaryAccent.opacity(0.5))
                .cornerRadius(DS.Radius.lg)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!isEnabled || isLoading)
            
            // Helper text (shown when disabled)
            if let helper = helperText, !isEnabled && !isLoading {
                Text(helper)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.md)
        .background(
            DS.Colors.screenBackground.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
