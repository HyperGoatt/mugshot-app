//
//  DSBaseCard.swift
//

import SwiftUI

struct DSBaseCard<Content: View>: View {
    let background: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content
    
    init(
        background: Color = DS.Colors.cardBackground,
        cornerRadius: CGFloat = DS.Radius.card,
        padding: CGFloat = DS.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(background)
            .cornerRadius(cornerRadius)
            .dsCardShadow()
    }
}


