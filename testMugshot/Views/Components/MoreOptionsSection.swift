//
//  MoreOptionsSection.swift
//  testMugshot
//
//  Expandable section for additional options like Notes.
//

import SwiftUI

struct MoreOptionsSection: View {
    @Binding var notes: String
    let notesLimit: Int
    @State private var isExpanded: Bool = false
    
    init(notes: Binding<String>, notesLimit: Int = 200) {
        self._notes = notes
        self.notesLimit = notesLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Expand/collapse header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Text("More options")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Spacer()
                    
                    if !notes.isEmpty && !isExpanded {
                        // Show indicator that notes exist
                        Text("Notes added")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Divider()
                        .background(DS.Colors.dividerSubtle)
                    
                    // Notes field
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "note.text")
                                    .foregroundColor(DS.Colors.iconSubtle)
                                    .font(.system(size: 14))
                                Text("Private Notes")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text("\(notes.count)/\(notesLimit)")
                                .font(DS.Typography.caption2())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        
                        Text("Only you can see these")
                            .font(DS.Typography.caption2())
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        TextField(
                            "Anything extra you'd like to remember?",
                            text: Binding(
                                get: { notes },
                                set: { newValue in
                                    if newValue.count <= notesLimit {
                                        notes = newValue
                                    } else {
                                        notes = String(newValue.prefix(notesLimit))
                                    }
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackgroundAlt)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                }
                .padding(.bottom, DS.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

