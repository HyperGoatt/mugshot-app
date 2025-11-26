//
//  DSBaseCard.swift
//

import SwiftUI

struct DSBaseCard<Content: View>: View {
    let background: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    let showBorder: Bool
    let content: Content
    
    init(
        background: Color = DS.Colors.cardBackground,
        cornerRadius: CGFloat = DS.Radius.card,
        padding: CGFloat = DS.Spacing.cardPadding,
        showBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showBorder = showBorder
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(background)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.borderSubtle.opacity(showBorder ? 0.4 : 0), lineWidth: 0.5)
            )
            .dsCardShadow()
    }
}
