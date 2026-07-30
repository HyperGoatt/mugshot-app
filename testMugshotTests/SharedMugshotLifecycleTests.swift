import Foundation
import Testing
@testable import testMugshot

struct SharedMugshotLifecycleTests {
    @Test func contributionEligibilityRequiresExactOwnerContextCafeAndPrimaryCompletion() {
        let ownerID = UUID()
        let cafeID = UUID()
        let membership = SharedMugshotMembership(
            id: UUID(),
            sharedMemoryID: UUID(),
            status: "accepted",
            inviterID: UUID(),
            inviterDisplayName: "Amanda",
            inviterUsername: "amanda",
            inviterAvatarURL: nil,
            relationshipAvailable: true,
            contextType: "Cafe",
            cafeID: cafeID,
            locationLabel: "Little Fox",
            occurredAt: "2026-07-21T12:00:00Z",
            invitedAt: "2026-07-21T12:01:00Z",
            respondedAt: "2026-07-21T12:02:00Z"
        )
        let eligible = summary(row(ownerID: ownerID, cafeID: cafeID))
        let wrongOwner = summary(row(ownerID: UUID(), cafeID: cafeID))
        let wrongCafe = summary(row(ownerID: ownerID, cafeID: UUID()))
        let incomplete = summary(row(
            ownerID: ownerID,
            cafeID: cafeID,
            uploadState: .uploading
        ))
        let secondary = summary(row(
            ownerID: ownerID,
            cafeID: cafeID,
            sessionID: UUID(),
            sessionRole: CafeSessionSipRole.secondary.rawValue
        ))
        let home = summary(row(
            ownerID: ownerID,
            cafeID: nil,
            contextType: "Home"
        ))
        let unrelatedOldPost = summary(row(
            ownerID: ownerID,
            cafeID: cafeID,
            createdAt: "2026-07-20T23:59:59Z"
        ))
        let unrelatedFuturePost = summary(row(
            ownerID: ownerID,
            cafeID: cafeID,
            createdAt: "2026-07-22T00:00:01Z"
        ))

        let resolved = SharedMugshotContributionEligibility.eligibleVisits(
            from: [
                wrongOwner, wrongCafe, incomplete, secondary, home,
                unrelatedOldPost, unrelatedFuturePost, eligible
            ],
            for: membership,
            ownerID: ownerID
        )

        #expect(resolved.map(\.id) == [eligible.id])
    }

    @Test func groupedProjectionRequiresTwoUniqueVisiblePeople() {
        let currentUserID = UUID()
        let otherUserID = UUID()
        let currentVisitID = UUID()
        let otherVisitID = UUID()
        let current = contribution(
            visitID: currentVisitID,
            userID: currentUserID,
            name: "Joe",
            username: "joe"
        )
        let other = contribution(
            visitID: otherVisitID,
            userID: otherUserID,
            name: "Amanda",
            username: "amanda"
        )
        let grouped = projection(contributions: [current, other])
        let oneVisible = projection(contributions: [current])
        let duplicatePerson = projection(contributions: [
            current,
            contribution(
                visitID: UUID(),
                userID: currentUserID,
                name: "Joe",
                username: "joe"
            )
        ])

        #expect(grouped.groupedContributions?.map(\.visitID) == [currentVisitID, otherVisitID])
        #expect(oneVisible.groupedContributions == nil)
        #expect(duplicatePerson.groupedContributions == nil)
    }

    @Test func detailAdapterShowsOnlyRenderableGroupedProjection() {
        let ownerID = UUID()
        let visit = row(ownerID: ownerID, cafeID: nil, contextType: "Home")
        let first = contribution(
            visitID: visit.id,
            userID: ownerID,
            name: "Joe",
            username: "joe"
        )
        let second = contribution(
            visitID: UUID(),
            userID: UUID(),
            name: "Amanda",
            username: "amanda"
        )

        let visible = presentation(
            visit: visit,
            projection: projection(contributions: [first, second]),
            viewerID: ownerID
        )
        let hidden = presentation(
            visit: visit,
            projection: projection(contributions: [first]),
            viewerID: ownerID
        )

        #expect(visible.content.sharedMugshot?.contributions.count == 2)
        #expect(visible.content.visibleSections(capabilities: visible.capabilities).contains(.sharedMugshot))
        #expect(hidden.content.sharedMugshot == nil)
        #expect(!hidden.content.visibleSections(capabilities: hidden.capabilities).contains(.sharedMugshot))
    }

    @Test func managerRosterAllowsCancellationOnlyWhilePending() throws {
        let pendingJSON = managedInvitationJSON(status: "pending")
        let acceptedJSON = managedInvitationJSON(status: "accepted")
        let pending = try JSONDecoder().decode(
            ManagedSharedMugshotInvitation.self,
            from: Data(pendingJSON.utf8)
        )
        let accepted = try JSONDecoder().decode(
            ManagedSharedMugshotInvitation.self,
            from: Data(acceptedJSON.utf8)
        )

        #expect(pending.canCancel)
        #expect(!accepted.canCancel)
    }

    private func presentation(
        visit: SupabaseVisitRow,
        projection: RemoteSharedMugshotProjection,
        viewerID: UUID
    ) -> SipDetailPresentation {
        let detail = RemoteVisitDetail(
            summary: summary(visit),
            photos: [],
            comments: [],
            likeCount: 0,
            currentUserHasLiked: false,
            sharedMugshotProjection: projection
        )
        return SipDetailPresentationAdapter.remote(
            detail: detail,
            currentUserID: viewerID,
            reactions: [],
            isCafeSaved: false,
            canRecommend: false,
            canRepeat: false,
            replyingToUsername: nil
        )
    }

    private func row(
        ownerID: UUID,
        cafeID: UUID?,
        contextType: String = "Cafe",
        uploadState: VisitUploadState = .complete,
        sessionID: UUID? = nil,
        sessionRole: String? = nil,
        createdAt: String = "2026-07-21T12:00:00Z"
    ) -> SupabaseVisitRow {
        SupabaseVisitRow(
            id: UUID(),
            userId: ownerID,
            cafeId: cafeID,
            drinkType: "Coffee",
            drinkTypeCustom: nil,
            drinkSubtype: "Cortado",
            caption: "",
            notes: nil,
            visibility: "friends",
            uploadState: uploadState.rawValue,
            ratings: ["Taste": 4],
            overallScore: 4,
            posterPhotoURL: nil,
            contextType: contextType,
            locationName: contextType,
            cityState: nil,
            brewMethod: nil,
            createdAt: createdAt,
            cafeSessionID: sessionID,
            cafeSessionOrder: sessionID == nil ? nil : 1,
            cafeSessionRole: sessionRole
        )
    }

    private func summary(_ visit: SupabaseVisitRow) -> RemoteVisitSummary {
        RemoteVisitSummary(visit: visit, cafe: nil)
    }

    private func contribution(
        visitID: UUID,
        userID: UUID,
        name: String,
        username: String
    ) -> RemoteSharedMugshotContribution {
        RemoteSharedMugshotContribution(
            visitID: visitID,
            userID: userID,
            displayName: name,
            username: username,
            avatarURL: nil,
            caption: nil,
            drink: "Cortado",
            overallScore: 4,
            posterPhotoURL: nil,
            visibility: "friends",
            createdAt: "2026-07-21T12:00:00Z"
        )
    }

    private func projection(
        contributions: [RemoteSharedMugshotContribution]
    ) -> RemoteSharedMugshotProjection {
        RemoteSharedMugshotProjection(
            sharedMugshotID: UUID(),
            contextType: "Home",
            cafeID: nil,
            locationLabel: "Home",
            occurredAt: "2026-07-21T12:00:00Z",
            contributions: contributions
        )
    }

    private func managedInvitationJSON(status: String) -> String {
        """
        {
          "invitation_id": "\(UUID().uuidString)",
          "user_id": "\(UUID().uuidString)",
          "display_name": "Amanda",
          "username": "amanda",
          "avatar_url": null,
          "status": "\(status)",
          "invited_at": "2026-07-21T12:00:00Z",
          "responded_at": null,
          "left_at": null
        }
        """
    }
}
