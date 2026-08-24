import Foundation
import Testing
@testable import testMugshot

private final class MugshotAnalyticsTransportSpy: MugshotAnalyticsTransport {
    private(set) var configurations: [MugshotAnalyticsConfiguration] = []
    private(set) var payloads: [MugshotAnalyticsPayload] = []
    private(set) var identifiedDistinctIDs: [String] = []
    private(set) var resetCount = 0

    func configure(_ configuration: MugshotAnalyticsConfiguration) {
        configurations.append(configuration)
    }

    func capture(_ payload: MugshotAnalyticsPayload) {
        payloads.append(payload)
    }

    func identify(distinctID: String) {
        identifiedDistinctIDs.append(distinctID)
    }

    func reset() {
        resetCount += 1
    }
}

@Suite(.serialized)
struct MugshotAnalyticsTests {
    @Test func homeWorkbenchAnalyticsContainsOnlyStructuralAction() {
        let payload = MugshotAnalyticsEvent.homeWorkbench(action: .scanSucceeded).payload

        #expect(payload.event == "home_workbench")
        #expect(payload.properties == ["action": .string("scan_succeeded")])
    }

    @Test func notificationAnalyticsUsesOnlyCoarseAllowlistedProperties() {
        let payloads = [
            MugshotAnalyticsEvent.notificationEducationViewed(
                source: .activityCenter
            ).payload,
            MugshotAnalyticsEvent.notificationPermissionResult(
                .provisional,
                source: .notificationSettings
            ).payload,
            MugshotAnalyticsEvent.notificationRegistrationResult(
                .registered,
                environment: .production
            ).payload,
            MugshotAnalyticsEvent.notificationPreferenceChanged(
                .friendPosts,
                enabled: false
            ).payload,
            MugshotAnalyticsEvent.activityOpened(source: .pushTap).payload,
            MugshotAnalyticsEvent.activityRouteResult(
                .accountRejected,
                source: .pushTap
            ).payload
        ]

        #expect(payloads.map(\.event) == [
            "notification_education_viewed",
            "notification_permission_result",
            "notification_registration_result",
            "notification_preference_changed",
            "activity_opened",
            "activity_route_result"
        ])
        let forbiddenKeys = [
            "push_token", "actor_id", "visit_id", "message", "deep_link"
        ]
        #expect(payloads.allSatisfy { payload in
            forbiddenKeys.allSatisfy { !payload.properties.keys.contains($0) }
        })
    }

    @Test func configurationRejectsMissingOrUnresolvedValues() {
        #expect(MugshotAnalyticsConfiguration(infoDictionary: [:]) == nil)
        #expect(MugshotAnalyticsConfiguration(infoDictionary: [
            "MUGSHOT_POSTHOG_PROJECT_TOKEN": "$(MUGSHOT_POSTHOG_PROJECT_TOKEN)",
            "MUGSHOT_POSTHOG_HOST": "https://us.i.posthog.com"
        ]) == nil)
        #expect(MugshotAnalyticsConfiguration(infoDictionary: [
            "MUGSHOT_POSTHOG_PROJECT_TOKEN": "phc_test",
            "MUGSHOT_POSTHOG_HOST": "http://us.i.posthog.com"
        ]) == nil)
    }

    @Test func clientLinksAnonymousEventsThenResetsAfterSignOut() throws {
        let spy = MugshotAnalyticsTransportSpy()
        let analytics = MugshotAnalytics(
            transport: spy,
            buildConfiguration: "test"
        )
        analytics.configure(infoDictionary: [
            "MUGSHOT_POSTHOG_PROJECT_TOKEN": "phc_test",
            "MUGSHOT_POSTHOG_HOST": "https://us.i.posthog.com"
        ])

        analytics.capture(.screenViewed(.map, source: .tab))
        let userID = UUID()
        analytics.identify(userID: userID)
        analytics.capture(.screenViewed(.journal, source: .tab))
        analytics.reset()
        analytics.capture(.screenViewed(.saved, source: .tab))

        #expect(spy.configurations.count == 1)
        #expect(spy.identifiedDistinctIDs == [userID.uuidString.lowercased()])
        #expect(spy.resetCount == 1)
        #expect(spy.payloads.count == 3)
        #expect(spy.payloads[0].properties["is_authenticated"] == .boolean(false))
        #expect(spy.payloads[1].properties["is_authenticated"] == .boolean(true))
        #expect(spy.payloads[2].properties["is_authenticated"] == .boolean(false))
        #expect(spy.payloads.allSatisfy {
            $0.properties["analytics_version"] == .integer(2)
                && $0.properties["platform"] == .string("ios")
                && $0.properties["build_configuration"] == .string("test")
        })
    }

    @Test func sipPayloadContainsOnlyAllowlistedShapeAndNoPrivateContent() {
        let privateCaption = "caption that must never enter analytics"
        let privateNote = "private note that must never enter analytics"
        let privateContextNote = "context note that must never enter analytics"
        let draft = SipDraft(
            captureMode: .addDetails,
            launchContext: SipComposerLaunchContext(source: .cafeDetail),
            context: .cafe,
            drinkName: "drink name that must never enter analytics",
            socialCaption: privateCaption,
            privateNotes: privateNote,
            visibility: .friends,
            ratingCriteria: [
                SipRatingCriterionSnapshot(name: "Acidity", sortOrder: 0)
            ],
            v3Step: .publish,
            contextNotes: privateContextNote,
            contextRatingCriteria: [
                SipRatingCriterionSnapshot(name: "Service", sortOrder: 0)
            ],
            photoFallback: .mugsyMissedPhoto
        )
        let snapshot = MugshotSipAnalyticsSnapshot(
            draft: draft,
            photoCount: 0,
            isDraftResume: true
        )
        let payload = MugshotAnalyticsEvent.sipPublished(
            snapshot,
            durationSeconds: 90,
            isRemote: true,
            wasRecovery: false
        ).payload

        #expect(payload.event == "sip_published")
        #expect(payload.properties["context"] == .string("cafe"))
        #expect(payload.properties["entry_point"] == .string("cafe_detail"))
        #expect(payload.properties["has_caption"] == .boolean(true))
        #expect(payload.properties["has_private_note"] == .boolean(true))
        #expect(payload.properties["has_context_note"] == .boolean(true))
        #expect(payload.properties["uses_photo_placeholder"] == .boolean(true))
        #expect(payload.properties["sip_criteria_count"] == .integer(1))
        #expect(payload.properties["context_criteria_count"] == .integer(1))

        let stringValues = payload.properties.values.compactMap { value -> String? in
            guard case .string(let string) = value else { return nil }
            return string
        }
        #expect(!stringValues.contains(privateCaption))
        #expect(!stringValues.contains(privateNote))
        #expect(!stringValues.contains(privateContextNote))
        #expect(!payload.properties.keys.contains("user_id"))
        #expect(!payload.properties.keys.contains("cafe_id"))
        #expect(!payload.properties.keys.contains("visit_id"))
    }

    @Test func boundedCountsAndDurationsLimitHighCardinalityProperties() {
        let manyCriteria = (0..<30).map {
            SipRatingCriterionSnapshot(name: "Criterion \($0)", sortOrder: $0)
        }
        let draft = SipDraft(
            ratingCriteria: manyCriteria,
            v3Step: .publish,
            contextRatingCriteria: manyCriteria
        )
        let snapshot = MugshotSipAnalyticsSnapshot(
            draft: draft,
            photoCount: 99,
            isDraftResume: false
        )
        let payload = MugshotAnalyticsEvent.sipPublished(
            snapshot,
            durationSeconds: 99_999,
            isRemote: false,
            wasRecovery: false
        ).payload

        #expect(payload.properties["sip_criteria_count"] == .integer(20))
        #expect(payload.properties["context_criteria_count"] == .integer(20))
        #expect(payload.properties["duration_seconds"] == .integer(14_400))
    }

    @Test func activationEventsUseExactNamesAndOnlyCoarseProperties() {
        let snapshot = MugshotSipAnalyticsSnapshot(
            draft: SipDraft(
                launchContext: .centralAdd,
                context: .home,
                drinkName: "never emitted",
                visibility: .private
            ),
            photoCount: 0,
            isDraftResume: true
        )
        let payloads = [
            MugshotAnalyticsEvent.onboardingStarted.payload,
            MugshotAnalyticsEvent.onboardingStepCompleted(step: 1, totalSteps: 8).payload,
            MugshotAnalyticsEvent.onboardingSkipped(step: 2, totalSteps: 8).payload,
            MugshotAnalyticsEvent.onboardingAbandoned(step: 1, totalSteps: 8).payload,
            MugshotAnalyticsEvent.onboardingCompleted(durationSeconds: 12).payload,
            MugshotAnalyticsEvent.guestIntroductionStarted.payload,
            MugshotAnalyticsEvent.guestIntroductionCompleted(durationSeconds: 8).payload,
            MugshotAnalyticsEvent.guestIntroductionDismissed.payload,
            MugshotAnalyticsEvent.timeToFirstValue(
                value: "map_available",
                durationSeconds: 12
            ).payload,
            MugshotAnalyticsEvent.authPromptViewed(source: "guest_publish").payload,
            MugshotAnalyticsEvent.authenticationStarted(
                flow: .signUp,
                method: .email
            ).payload,
            MugshotAnalyticsEvent.authAbandoned(source: "guest_publish").payload,
            MugshotAnalyticsEvent.guestDraftCreated(snapshot).payload,
            MugshotAnalyticsEvent.guestDraftSavedAfterSignup(snapshot).payload,
            MugshotAnalyticsEvent.draftRestored(snapshot, wasGuest: true).payload,
            MugshotAnalyticsEvent.visibilityChanged(
                snapshot,
                from: .private,
                to: .friends
            ).payload,
            MugshotAnalyticsEvent.logAbandoned(
                snapshot,
                durationSeconds: 20
            ).payload
        ]

        #expect(payloads.map(\.event) == [
            "onboarding_started",
            "onboarding_step_completed",
            "onboarding_skipped",
            "onboarding_abandoned",
            "onboarding_completed",
            "guest_introduction_started",
            "guest_introduction_completed",
            "guest_introduction_dismissed",
            "time_to_first_value",
            "auth_prompt_viewed",
            "auth_started",
            "auth_abandoned",
            "guest_draft_created",
            "guest_draft_saved_after_signup",
            "draft_restored",
            "visibility_changed",
            "log_abandoned"
        ])
        #expect(payloads.allSatisfy { payload in
            !payload.properties.keys.contains("email")
                && !payload.properties.keys.contains("drink_name")
                && !payload.properties.keys.contains("notes")
                && !payload.properties.keys.contains("cafe_name")
                && !payload.properties.keys.contains("user_id")
        })
        #expect(payloads[14].properties["was_guest"] == .boolean(true))
        #expect(payloads[15].properties["from_visibility"] == .string("private"))
        #expect(payloads[15].properties["to_visibility"] == .string("friends"))
    }
}
