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
            $0.properties["analytics_version"] == .integer(1)
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
}
