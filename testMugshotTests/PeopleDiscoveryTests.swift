import Foundation
import Testing
@testable import testMugshot

struct PeopleDiscoveryTests {
    @Test func inviteRoutesAcceptOnlyBoundedAppOrFirstPartyLinks() throws {
        let token = String(repeating: "A", count: 43)
        let publicBaseURL = try #require(URL(string: "https://mugshot.example"))

        let appRoute = FriendInviteRoute.resolve(
            try #require(URL(string: "mugshot://invite/\(token)")),
            publicBaseURL: publicBaseURL
        )
        let webRoute = FriendInviteRoute.resolve(
            try #require(URL(string: "https://mugshot.example/invite/ABCD-EFGH-JKLM")),
            publicBaseURL: publicBaseURL
        )

        #expect(appRoute?.secret == token)
        #expect(webRoute?.secret == "ABCD-EFGH-JKLM")
        #expect(FriendInviteRoute.resolve(
            try #require(URL(string: "https://attacker.example/invite/\(token)")),
            publicBaseURL: publicBaseURL
        ) == nil)
        #expect(FriendInviteRoute.resolve(
            try #require(URL(string: "https://mugshot.example:8443/invite/\(token)")),
            publicBaseURL: publicBaseURL
        ) == nil)
        #expect(FriendInviteRoute.resolve(
            try #require(URL(string: "mugshot://invite/short")),
            publicBaseURL: publicBaseURL
        ) == nil)
    }

    @Test func peopleAnalyticsContainsNoQueriesIdentifiersOrExactCounts() {
        let payloads = [
            MugshotAnalyticsEvent.peopleHubOpened(source: .contacts).payload,
            MugshotAnalyticsEvent.peopleSearchCompleted(
                resultCount: 17,
                outcome: "success",
                durationSeconds: 99_999
            ).payload,
            MugshotAnalyticsEvent.peopleContactsMatchCompleted(
                selectedCount: 48,
                matchedCount: 3,
                outcome: "success"
            ).payload,
            MugshotAnalyticsEvent.peopleInviteResolved(
                outcome: "success",
                source: .inviteCode
            ).payload,
            MugshotAnalyticsEvent.peopleSuggestionOpened(
                reason: "interacted_with_you",
                rankingVersion: "people_v2"
            ).payload,
            MugshotAnalyticsEvent.peopleInviteHandoffCompleted(outcome: "completed").payload,
            MugshotAnalyticsEvent.peopleDiscoveryPreferenceChanged(
                preference: "email",
                enabled: true,
                outcome: "success"
            ).payload
        ]

        #expect(payloads.map(\.event) == [
            "people_hub_opened",
            "people_search_completed",
            "people_contacts_match_completed",
            "people_invite_resolved",
            "people_suggestion_opened",
            "people_invite_handoff_completed",
            "people_discovery_preference_changed"
        ])
        #expect(payloads[1].properties["result_bucket"] == .string("6_20"))
        #expect(payloads[1].properties["duration_seconds"] == .integer(3_600))
        #expect(payloads[2].properties["selected_bucket"] == .string("21_plus"))
        #expect(payloads[2].properties["matched_bucket"] == .string("2_5"))
        #expect(payloads[4].properties["reason"] == .string("interacted_with_you"))
        #expect(payloads[4].properties["ranking_version"] == .string("people_v2"))
        #expect(payloads.allSatisfy { payload in
            ["query", "email", "phone", "user_id", "invite_id", "invite_code", "token"]
                .allSatisfy { !payload.properties.keys.contains($0) }
        })
    }

    @Test func suggestionReasonsExplainVisibleSignals() throws {
        func suggestion(reason: String, mutualCount: Int = 0) -> PeopleSuggestion {
            PeopleSuggestion(
                id: UUID(),
                displayName: "Coffee Friend",
                username: "coffee_friend",
                avatarURL: nil,
                friendshipState: .none,
                mutualFriendCount: mutualCount,
                reason: reason,
                rankingVersion: "people_v2"
            )
        }

        #expect(suggestion(reason: "interacted_with_you").reasonText == "Recently interacted with your Mugshots")
        #expect(suggestion(reason: "you_interacted").reasonText == "You recently interacted with their Mugshots")
        #expect(suggestion(reason: "mutual_friends", mutualCount: 2).reasonText == "2 mutual friends")
        #expect(suggestion(reason: "people_you_may_know").reasonText == "Someone you may know")
    }
}
