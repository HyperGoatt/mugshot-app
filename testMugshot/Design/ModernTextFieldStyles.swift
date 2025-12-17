//
//  ModernTextFieldStyles.swift
//  testMugshot
//
//  Modern Dark Mode text field styles and modifiers
//

import SwiftUI

// MARK: - Modern Text Field Modifiers

extension View {
    /// Standard modern text field with dark surface background
    func modernTextField() -> some View {
        self
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(DS.Colors.modernTextPrimary)
            .accentColor(DS.Colors.modernAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.modernSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
    }
    
    /// Glassmorphism search field for floating search bars
    func modernSearchField() -> some View {
        self
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(DS.Colors.modernTextPrimary)
            .accentColor(DS.Colors.modernAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .background(DS.Colors.modernGlass.opacity(0.6))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
    }
    
    /// Comment/caption field style for user input
    func modernCommentField() -> some View {
        self
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(DS.Colors.modernTextPrimary)
            .accentColor(DS.Colors.modernAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DS.Colors.modernSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Modern TextField Wrapper Components

struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    var style: Style = .standard
    
    enum Style {
        case standard
        case search
        case comment
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .apply { view in
                switch style {
                case .standard:
                    view.modernTextField()
                case .search:
                    view.modernSearchField()
                case .comment:
                    view.modernCommentField()
                }
            }
    }
}

struct ModernTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(DS.Colors.modernTextSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
            }
            
            TextEditor(text: $text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(DS.Colors.modernTextPrimary)
                .accentColor(DS.Colors.modernAccent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .background(DS.Colors.modernSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Helper Extension

extension View {
    func apply<V: View>(@ViewBuilder _ transform: (Self) -> V) -> V {
        transform(self)
    }
}


