//
//  DSDesignSegmentedControl.swift
//

import SwiftUI

struct DSDesignSegmentedControl: View {
    let options: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = index
                    }
                }) {
                    Text(options[index])
                        .font(DS.Typography.callout())
                        .foregroundColor(selectedIndex == index ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Group {
                                if selectedIndex == index {
                                    DS.Colors.cardBackground
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .cornerRadius(DS.Radius.segmentedOption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(DS.Colors.screenBackground)
        .cornerRadius(DS.Radius.segmentedContainer)
    }
}


