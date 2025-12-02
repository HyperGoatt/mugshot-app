//
//  CaptionNotesSection.swift
//  testMugshot
//
//  Combined caption + notes card with character limits.
//

import SwiftUI

struct CaptionNotesSection: View {
    @Binding var caption: String
    @Binding var notes: String
    let captionLimit: Int
    let notesLimit: Int
    
    init(
        caption: Binding<String>,
        notes: Binding<String>,
        captionLimit: Int = 200,
        notesLimit: Int = 200
    ) {
        self._caption = caption
        self._notes = notes
        self.captionLimit = captionLimit
        self.notesLimit = notesLimit
    }
    
    var body: some View {
        FormSectionCard(title: "Caption & Notes") {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                captionField
                notesField
            }
        }
    }
    
    private var captionField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("Caption")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text("\(caption.count)/\(captionLimit)")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            TextField(
                "Share your thoughts or first impressions…",
                text: Binding(
                    get: { caption },
                    set: { newValue in
                        if newValue.count <= captionLimit {
                            caption = newValue
                        } else {
                            caption = String(newValue.prefix(captionLimit))
                        }
                    }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .foregroundColor(DS.Colors.textPrimary)
            .tint(DS.Colors.primaryAccent)
            .accentColor(DS.Colors.primaryAccent)
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private var notesField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("Notes (Optional)")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text("\(notes.count)/\(notesLimit)")
                    .font(DS.Typography.caption2())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
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
            .foregroundColor(DS.Colors.textPrimary)
            .tint(DS.Colors.primaryAccent)
            .accentColor(DS.Colors.primaryAccent)
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
}


