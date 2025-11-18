//
//  ProfileBioLocationPage.swift
//  testMugshot
//
//  Page 2: Bio & Location
//

import SwiftUI

struct ProfileBioLocationPage: View {
    let initialBio: String
    let initialLocation: String
    let onUpdate: (String, String) -> Void
    
    @State private var bio: String
    @State private var location: String
    
    private let bioCharacterLimit = 250
    
    init(initialBio: String, initialLocation: String, onUpdate: @escaping (String, String) -> Void) {
        self.initialBio = initialBio
        self.initialLocation = initialLocation
        self.onUpdate = onUpdate
        _bio = State(initialValue: initialBio)
        _location = State(initialValue: initialLocation)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: DS.Spacing.xl) {
                // Spacer to position title 72pt below safe area
                Spacer()
                    .frame(height: geometry.safeAreaInsets.top + 72)
                
                // Title
                Text("Tell us about yourself")
                    .font(DS.Typography.screenTitle)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Subtitle
                Text("Optional - add a bio and location")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                    .padding(.top, DS.Spacing.sm)
                
                // Form fields - compact layout
                VStack(spacing: DS.Spacing.md) {
                    // Bio - smaller block
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Bio")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                        
                        TextEditor(text: $bio)
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .frame(minHeight: 56, maxHeight: 120)
                            .padding(DS.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(DS.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                            .onChange(of: bio) { _, newValue in
                                handleBioChange(newValue)
                            }
                        
                        HStack {
                            Spacer()
                            Text("\(bio.count)/\(bioCharacterLimit)")
                                .font(DS.Typography.caption2())
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    
                    // Location - smaller block
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("City / Location")
                            .font(DS.Typography.caption1(.semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                        
                        TextField("e.g., San Francisco", text: $location)
                            .textContentType(.location)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .padding(DS.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(DS.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                            .onChange(of: location) { _, newValue in
                                onUpdate(bio, newValue)
                            }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func handleBioChange(_ newValue: String) {
        let trimmed = String(newValue.prefix(bioCharacterLimit))
        if trimmed != bio {
            bio = trimmed
        }
        onUpdate(trimmed, location)
    }
}

