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

    @Test func productTourVisitsEveryCoreDestinationBeforeFirstSip() {
        #expect(MugshotOnboardingPlan.totalSteps == 8)
        #expect(MugshotProductTourStep.allCases.map(\.number) == [4, 5, 6, 7, 8])
        #expect(MugshotProductTourStep.allCases.map(\.tabIndex) == [0, 1, 3, 4, 2])
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
