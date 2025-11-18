//
//  OnboardingPage2_Identity.swift
//  testMugshot
//
//  Page 2: Identity (Display Name & Username)
//

import SwiftUI

struct IdentityPage: View {
    @Binding var displayName: String
    @Binding var username: String
    @Binding var location: String
    
    private var isValid: Bool {
        !username.isEmpty && !location.isEmpty
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("Tell us about yourself")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.bottom, DS.Spacing.sm)
            
            // Form fields
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Display Name
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Display Name")
                        .font(DS.Typography.headline(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    TextField("Your name", text: $displayName)
                        .font(DS.Typography.bodyText)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(DS.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                }
                
                // Username
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Username")
                        .font(DS.Typography.headline(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    HStack {
                        Text("@")
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(DS.Colors.textSecondary)
                        
                        TextField("username", text: $username)
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .fill(DS.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                
                // Location
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Location")
                        .font(DS.Typography.headline(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    TextField("City", text: $location)
                        .font(DS.Typography.bodyText)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(DS.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Preview card
            if !displayName.isEmpty || !username.isEmpty {
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(displayName.isEmpty ? username : displayName)
                            .font(DS.Typography.screenTitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                        
                        Text("@\(username.isEmpty ? "username" : username)")
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(DS.Colors.textSecondary)
                        
                        if !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Text(location)
                                    .font(DS.Typography.caption1())
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            // Validation hint
            if !isValid {
                Text("Please fill in username and location to continue")
                    .font(DS.Typography.caption1())
                    .foregroundStyle(DS.Colors.negativeChange)
                    .padding(.top, DS.Spacing.sm)
            } else {
                Text("You can change this later in Profile.")
                    .font(DS.Typography.caption1())
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.top, DS.Spacing.sm)
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
    }
}

