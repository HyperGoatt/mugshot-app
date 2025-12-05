//
//  MyTasteSection.swift
//  testMugshot
//
//  Tag cloud visualization of user's drink preferences
//

import SwiftUI

struct MyTasteSection: View {
    let drinkSubtypes: [(name: String, count: Int)]
    @State private var isExpanded: Bool = true
    
    private var totalDrinks: Int {
        drinkSubtypes.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header with toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.Colors.primaryAccent)
                        
                        Text("My Taste")
                            .font(DS.Typography.sectionTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(drinkSubtypes.count) drinks")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DS.Colors.iconSubtle)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    // Tag cloud layout with wrapping
                    FlowLayout(spacing: DS.Spacing.sm) {
                        ForEach(drinkSubtypes.prefix(20), id: \.name) { drink in
                            DrinkSubtypePill(name: drink.name, count: drink.count)
                        }
                    }
                    .padding(.top, DS.Spacing.xs)
                    
                    // Show more indicator if there are more drinks
                    if drinkSubtypes.count > 20 {
                        Text("+ \(drinkSubtypes.count - 20) more")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textTertiary)
                            .padding(.top, DS.Spacing.xs)
                    }
                }
            }
        }
    }
}

// MARK: - Drink Subtype Pill Component

struct DrinkSubtypePill: View {
    let name: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textPrimary)
                .lineLimit(1)
            
            if count > 1 {
                Text("\(count)")
                    .font(DS.Typography.caption2(.bold))
                    .foregroundColor(DS.Colors.primaryAccent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(DS.Colors.primaryAccent.opacity(0.15))
                    .cornerRadius(DS.Radius.pill)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(DS.Colors.mintSoftFill)
        .cornerRadius(DS.Radius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.pill)
                .stroke(DS.Colors.primaryAccent.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - FlowLayout Helper

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    MyTasteSection(drinkSubtypes: [
        ("Iced Honey Cinnamon Latte", 5),
        ("Cortado", 3),
        ("Iced Vanilla Latte", 4),
        ("Hot Matcha", 2),
        ("Cappuccino", 3),
        ("Oat Milk Latte", 2),
        ("Espresso", 1),
        ("Cold Brew", 2)
    ])
    .padding()
}
