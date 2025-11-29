//
//  EmptyStateView.swift
//  testMugshot
//
//  Generic centered empty-state component used across Saved tab segments.
//  Now with optional CTA buttons for actionable empty states.
//

import SwiftUI

struct EmptyStateAction {
    let title: String
    let icon: String?
    let style: ActionStyle
    let action: () -> Void
    
    enum ActionStyle {
        case primary
        case secondary
    }
    
    init(title: String, icon: String? = nil, style: ActionStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
}

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    var primaryAction: EmptyStateAction?
    var secondaryAction: EmptyStateAction?
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DS.Spacing.lg) {
                // Illustration
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)
                
                // Text content
                VStack(spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.title2())
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                }
                
                // Action buttons
                if primaryAction != nil || secondaryAction != nil {
                    VStack(spacing: DS.Spacing.md) {
                        if let primary = primaryAction {
                            actionButton(primary)
                        }
                        
                        if let secondary = secondaryAction {
                            actionButton(secondary)
                        }
                    }
                    .padding(.top, DS.Spacing.md)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.screenBackground)
    }
    
    @ViewBuilder
    private func actionButton(_ action: EmptyStateAction) -> some View {
        Button {
            action.action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(action.title)
                    .font(DS.Typography.buttonLabel)
            }
            .frame(maxWidth: 280)
        }
        .buttonStyle(action.style == .primary ? AnyButtonStyle(DSPrimaryButtonStyle()) : AnyButtonStyle(DSSecondaryButtonStyle()))
    }
}

// MARK: - Type-erased button style for conditional styling

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Secondary Button Style

struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .foregroundColor(DS.Colors.textPrimary)
            .cornerRadius(DS.Radius.primaryButton)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("With Actions") {
    EmptyStateView(
        iconName: "DreamingMug",
        title: "No favorites yet",
        subtitle: "Heart a cafe from your visits to add it here.",
        primaryAction: EmptyStateAction(
            title: "View Your Visits",
            icon: "list.bullet",
            action: {}
        ),
        secondaryAction: EmptyStateAction(
            title: "Explore the Map",
            icon: "map",
            style: .secondary,
            action: {}
        )
    )
}

#Preview("Without Actions") {
    EmptyStateView(
        iconName: "BookmarkMug",
        title: "Nothing on your wishlist",
        subtitle: "Bookmark cafes you want to try from the Feed or Map."
    )
}
