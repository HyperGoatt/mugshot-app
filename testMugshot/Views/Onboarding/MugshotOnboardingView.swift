//
//  MugshotOnboardingView.swift
//  testMugshot
//
//  Main onboarding flow using ConcentricOnboarding
//

import SwiftUI

struct MugshotOnboardingView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var hapticsManager = HapticsManager.shared
    
    private var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse
    }
    
    var body: some View {
        ConcentricOnboardingView(pageContents: createPages())
            .duration(0.8)
            .nextIcon("arrow.right")
            .didChangeCurrentPage { index in
                // Subtle haptic feedback on page change
                hapticsManager.playImpact(style: .light)
            }
            .insteadOfCyclingToFirstPage {
                // Completion handler - called when user taps next on last page
                hapticsManager.playSuccess()
                dataManager.appData.hasSeenMarketingOnboarding = true
                dataManager.save()
            }
            .onChange(of: locationManager.authorizationStatus) {
                // Trigger view update when permission status changes
            }
    }
    
    private func createPages() -> [(view: AnyView, background: Color)] {
        return [
            (AnyView(ConcentricWelcomePage()), DS.Colors.mintSoftFill),
            (AnyView(ConcentricJournalFeedPage()), DS.Colors.blueSoftFill),
            (AnyView(ConcentricMapSavedPage()), DS.Colors.mintSoftFill),
            (AnyView(ConcentricLocationPage(
                locationManager: locationManager,
                onRequestLocation: {
                    locationManager.requestLocationPermission()
                }
            )), DS.Colors.blueSoftFill),
            (AnyView(ConcentricReadyPage()), DS.Colors.mintSoftFill)
        ]
    }
}


