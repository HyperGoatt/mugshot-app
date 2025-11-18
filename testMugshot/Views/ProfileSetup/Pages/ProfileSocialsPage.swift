//
//  ProfileSocialsPage.swift
//  testMugshot
//
//  Page 4: Socials
//

import SwiftUI

struct ProfileSocialsPage: View {
    let initialInstagram: String
    let initialWebsite: String
    let onUpdate: (String, String) -> Void
    
    @State private var instagram: String
    @State private var website: String
    
    init(initialInstagram: String, initialWebsite: String, onUpdate: @escaping (String, String) -> Void) {
        self.initialInstagram = initialInstagram
        self.initialWebsite = initialWebsite
        self.onUpdate = onUpdate
        _instagram = State(initialValue: initialInstagram)
        _website = State(initialValue: initialWebsite)
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("Connect your socials")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Optional - share your Instagram and website")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
                .padding(.top, DS.Spacing.sm)
            
            // Form fields
            VStack(spacing: DS.Spacing.lg) {
                // Instagram
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Instagram")
                            .font(DS.Typography.subheadline())
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    
                    HStack {
                        Text("@")
                            .foregroundStyle(DS.Colors.textSecondary)
                            .padding(.leading, DS.Spacing.md)
                        
                        TextField("username", text: $instagram)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                    }
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(DS.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                    .onChange(of: instagram) { _, _ in
                        onUpdate(instagram, website)
                    }
                }
                
                // Website
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "link")
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Website")
                            .font(DS.Typography.subheadline())
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    
                    TextField("https://yourwebsite.com", text: $website)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .foregroundStyle(DS.Colors.textPrimary)
                        .tint(DS.Colors.primaryAccent)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(DS.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                        .onChange(of: website) { _, _ in
                            onUpdate(instagram, website)
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

