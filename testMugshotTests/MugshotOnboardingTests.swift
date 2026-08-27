import Foundation
import Testing
@testable import testMugshot

struct MugshotOnboardingTests {
    @Test func onboardingGoalDefaultsToNearbyWithoutInventingCompletedProgress() {
        #expect(CapturePreferences.empty.onboardingGoal == nil)
        #expect(CapturePreferences.empty.setupCompletedAt == nil)
    }

    @Test func applyingOnboardingGoalPreservesExistingPersonalization() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let original = CapturePreferences(
            usualDrinkFamilies: ["Coffee", "Tea"],
            cafeHomeHabit: "both",
            discoveryIntents: ["home", "friends"],
            setupCompletedAt: completedAt
        )

        let updated = original.applyingOnboardingGoal(.journal)

        #expect(updated.usualDrinkFamilies == original.usualDrinkFamilies)
        #expect(updated.cafeHomeHabit == original.cafeHomeHabit)
        #expect(updated.setupCompletedAt == completedAt)
        #expect(updated.discoveryIntents == ["home", "journal"])
        #expect(updated.onboardingGoal == .journal)
    }

    @Test func applyingAnotherOnboardingGoalKeepsOnlyOnePrimaryGoal() {
        let preferences = CapturePreferences.empty
            .applyingOnboardingGoal(.nearby)
            .applyingOnboardingGoal(.taste)

        #expect(preferences.discoveryIntents == ["taste"])
        #expect(preferences.onboardingGoal == .taste)
    }

    @Test func productTourVisitsEveryCoreDestinationAndShareShortcutBeforeFirstSip() {
        #expect(MugshotOnboardingPlan.totalSteps == 10)
        #expect(MugshotProductTourStep.allCases.map(\.number) == [4, 5, 6, 7, 8])
        #expect(
            MugshotProductTourStep.allCases.map(\.tab)
                == [.map, .feed, .saved, .journal, .map]
        )
        #expect(MugshotProductTourStep.shareImport.number == 8)
    }

    @Test func firstLaunchEducationCoversCoreTabsFriendsAndGoogleMapsBeforeAuthentication() {
        #expect(MugshotFirstLaunchStep.allCases.count == 9)
        #expect(MugshotFirstLaunchStep.allCases.map(\.number) == Array(1...9))
        #expect(
            MugshotFirstLaunchStep.allCases == [
                .welcome, .map, .feed, .friends, .saved, .journal,
                .tastePassport, .googleMaps, .add
            ]
        )
        #expect(MugshotFirstLaunchStep.allCases.last == .add)
        #expect(MugshotFirstLaunchStep.add.isAuthenticationStep)
        #expect(MugshotFirstLaunchStep.welcome.title == "Capture Every Sip")
        #expect(MugshotFirstLaunchStep.map.title == "Watch your world take shape.")
        #expect(MugshotFirstLaunchStep.welcome.message.contains("matcha"))
        #expect(MugshotFirstLaunchStep.welcome.message.contains("tea"))
        #expect(MugshotFirstLaunchStep.friends.message.contains("confirmed mutual friends"))
        #expect(MugshotFirstLaunchStep.friends.message.contains("Private is owner-only"))
        #expect(MugshotFirstLaunchStep.friends.message.contains("Everyone is public"))
        #expect(MugshotFirstLaunchStep.allCases.map(\.artworkName) == [
            "OnboardingMarketing01Capture",
            "OnboardingMarketing02Map",
            "OnboardingMarketing03Feed",
            "OnboardingMarketing04Friends",
            "OnboardingMarketing05Saved",
            "OnboardingMarketing06Journal",
            "OnboardingMarketing07TastePassport",
            "OnboardingMarketing08GoogleMaps",
            "OnboardingMarketing09Account"
        ])
    }

    @Test func signedInOnboardingRemainsRequiredUntilCompletedOrSkipped() {
        let requiredAfterRelaunch = MugshotSignedInOnboardingGate.requiresPresentation(
            isSignedIn: true,
            shouldOfferCapturePreferences: true,
            hasPendingGuestSavedCafes: false,
            hasAuthenticationPrompt: false,
            isGuestSavedMergePresented: false,
            isProductTourActive: false
        )
        let dismissedByCompletionOrSkip = MugshotSignedInOnboardingGate.requiresPresentation(
            isSignedIn: true,
            shouldOfferCapturePreferences: false,
            hasPendingGuestSavedCafes: false,
            hasAuthenticationPrompt: false,
            isGuestSavedMergePresented: false,
            isProductTourActive: false
        )

        #expect(requiredAfterRelaunch)
        #expect(!dismissedByCompletionOrSkip)
    }

    @Test func firstSipGuideStateIsScopedToTheSignedInAccount() {
        let firstAccount = UUID()
        let secondAccount = UUID()
        defer {
            MugshotFirstSipGuideStore.setActive(false, accountID: firstAccount)
            MugshotFirstSipGuideStore.setActive(false, accountID: secondAccount)
        }

        MugshotFirstSipGuideStore.setActive(true, accountID: firstAccount)

        #expect(MugshotFirstSipGuideStore.isActive(accountID: firstAccount))
        #expect(!MugshotFirstSipGuideStore.isActive(accountID: secondAccount))
        #expect(!MugshotFirstSipGuideStore.isActive(accountID: nil))
    }
}
