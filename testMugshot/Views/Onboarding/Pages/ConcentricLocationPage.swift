//
//  ConcentricLocationPage.swift
//  testMugshot
//
//  Page 4: Location Permission
//

import SwiftUI

struct ConcentricLocationPage: View {
    @ObservedObject var locationManager: LocationManager
    let onRequestLocation: () -> Void
    
    private var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon in circular mint background
            ZStack {
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.textOnMint)
            }
            .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("See cafes near you")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Body
            Text("Allow location so Mugshot can help you find nearby spots.")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            // Permission button or status
            if hasLocationPermission {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.primaryAccent)
                    Text("Location enabled")
                        .font(DS.Typography.headline())
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.Colors.cardBackground)
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
            } else {
                Button(action: onRequestLocation) {
                    Text("Enable Location")
                        .font(DS.Typography.buttonLabel)
                        .foregroundStyle(DS.Colors.textOnMint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(DS.Colors.primaryAccent)
                        )
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.top, DS.Spacing.lg)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

