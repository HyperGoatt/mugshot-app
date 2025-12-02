//
//  OnboardingPage3_Permissions.swift
//  testMugshot
//
//  Page 3: Location & Photos Permissions
//

import SwiftUI
import PhotosUI

struct PermissionsPage: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var hasLocationPermission: Bool
    @Binding var hasPhotosPermission: Bool
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("Enable Permissions")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.bottom, DS.Spacing.sm)
            
            // Description
            VStack(spacing: DS.Spacing.md) {
                Text("We use your location to find nearby cafes and place your visits on the map.")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text("We use your photos so you can attach drink and cafe photos to your visits.")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.bottom, DS.Spacing.lg)
            
            // Permission buttons
            VStack(spacing: DS.Spacing.lg) {
                // Location permission
                PermissionButton(
                    icon: "location.fill",
                    title: "Enable Location",
                    description: "Find cafes near you",
                    isEnabled: hasLocationPermission,
                    action: {
                        locationManager.requestLocationPermission()
                    }
                )
                
                // Photos permission
                PermissionButton(
                    icon: "photo.on.rectangle",
                    title: "Enable Photos",
                    description: "Add photos to your visits",
                    isEnabled: hasPhotosPermission,
                    action: {
                        requestPhotosPermission()
                    }
                )
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
        .onChange(of: locationManager.authorizationStatus) { _, status in
            hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
        }
    }
    
    private func requestPhotosPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                hasPhotosPermission = status == .authorized || status == .limited
            }
        }
    }
}

struct PermissionButton: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isEnabled ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.headline(.semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Text(description)
                        .font(DS.Typography.bodyText)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                if isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.primaryAccent)
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(isEnabled ? DS.Colors.primaryAccent.opacity(0.5) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

