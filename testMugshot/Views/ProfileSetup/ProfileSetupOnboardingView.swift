//
//  ProfileSetupOnboardingView.swift
//  testMugshot
//
//  Profile completion flow using ConcentricOnboarding
//

import SwiftUI

struct ProfileSetupOnboardingView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var hapticsManager: HapticsManager
    
    var body: some View {
        ConcentricOnboardingView(pageContents: createPages())
            .duration(0.8)
            .nextIcon("arrow.right")
            .didChangeCurrentPage { index in
                // Subtle haptic feedback on page change
                hapticsManager.playImpact(style: .light)
            }
            .insteadOfCyclingToFirstPage {
                completeProfileSetup()
            }
    }
    
    private func createPages() -> [(view: AnyView, background: Color)] {
        return [
            (AnyView(ProfileIntroPage(
                displayName: dataManager.appData.currentUserDisplayName ?? "",
                username: dataManager.appData.currentUserUsername ?? ""
            )), DS.Colors.mintSoftFill),
            (AnyView(ProfileBioLocationPage(
                initialBio: dataManager.appData.currentUserBio ?? "",
                initialLocation: dataManager.appData.currentUserLocation ?? "",
                onUpdate: saveBioAndLocation
            )), DS.Colors.blueSoftFill),
            (AnyView(ProfileFavoriteDrinkPage(
                initialFavoriteDrink: dataManager.appData.currentUserFavoriteDrink,
                onUpdate: saveFavoriteDrink
            )), DS.Colors.mintSoftFill),
            (AnyView(ProfileSocialsPage(
                initialInstagram: dataManager.appData.currentUserInstagramHandle ?? "",
                initialWebsite: dataManager.appData.currentUserWebsite ?? "",
                onUpdate: saveSocials
            )), DS.Colors.blueSoftFill),
            (AnyView(ProfilePhotosPage(
                initialProfileImageId: dataManager.appData.currentUserProfileImageId,
                initialBannerImageId: dataManager.appData.currentUserBannerImageId,
                onUpdate: saveProfileImages
            )), DS.Colors.mintSoftFill),
            (AnyView(ProfileSetupSummaryPage(
                user: dataManager.appData
            )), DS.Colors.blueSoftFill)
        ]
    }
    
    // Completes profile setup and marks onboarding as finished
    // This transitions the user to the main app (Map tab)
    private func completeProfileSetup() {
        Task {
            do {
                try await dataManager.completeProfileSetupWithSupabase()
                await MainActor.run {
                    hapticsManager.playSuccess()
                    // Profile setup completion will trigger the root view to show MainTabView
                    // via hasCompletedProfileSetup flag in AppData
                }
            } catch {
                print("Failed to complete Supabase profile setup: \(error.localizedDescription)")
                // Even if Supabase fails, we should still mark profile setup as complete
                // so the user can use the app (they can retry profile sync later)
                await MainActor.run {
                    dataManager.appData.hasCompletedProfileSetup = true
                    dataManager.save()
                }
            }
        }
    }
    
    private func saveBioAndLocation(bio: String, location: String) {
        dataManager.appData.currentUserBio = bio.isEmpty ? nil : bio
        dataManager.appData.currentUserLocation = location.isEmpty ? nil : location
        dataManager.save()
    }
    
    private func saveFavoriteDrink(_ drink: String?) {
        dataManager.appData.currentUserFavoriteDrink = drink
        dataManager.save()
    }
    
    private func saveSocials(instagram: String, website: String) {
        dataManager.appData.currentUserInstagramHandle = instagram.isEmpty ? nil : instagram
        dataManager.appData.currentUserWebsite = website.isEmpty ? nil : website
        dataManager.save()
    }
    
    private func saveProfileImages(profileImageId: String?, bannerImageId: String?) {
        dataManager.appData.currentUserProfileImageId = profileImageId
        dataManager.appData.currentUserBannerImageId = bannerImageId
        dataManager.save()
    }
}

