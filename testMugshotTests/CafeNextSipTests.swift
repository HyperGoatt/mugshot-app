import Foundation
import Testing
@testable import testMugshot

struct CafeNextSipTests {
    @Test func repeatsOnlyTheLatestOrderAtThisCafeFromThisOwner() throws {
        let owner = UUID()
        let cafe = Cafe(name: "Harborlight", address: "12 Water Street")
        let now = Date()
        var latest = Visit(
            cafeId: cafe.id, userId: owner, createdAt: now.addingTimeInterval(-60),
            drinkType: .coffee, customDrinkType: "Honey oat cortado",
            caption: "Last time", notes: "Private reflection",
            photos: ["yesterday.jpg"], ratings: ["Balance": 4], overallScore: 4.8,
            sipReorderIntention: .yes, visibility: .everyone
        )
        latest.brewDetails.orderNotes = "Oat milk, half sweet"
        latest.brewDetails.additions = "Honey"
        latest.brewDetails.companions = ["A friend"]
        let otherPerson = Visit(cafeId: cafe.id, userId: UUID(), createdAt: now, drinkType: .matcha)
        let otherCafe = Visit(cafeId: UUID(), userId: owner, createdAt: now, drinkType: .chai)
        let older = Visit(cafeId: cafe.id, userId: owner, createdAt: now.addingTimeInterval(-600), drinkType: .tea)

        let order = try #require(CafeNextSipOrder.latestLocal(
            in: [otherPerson, otherCafe, older, latest], cafeID: cafe.id, ownerID: owner
        ))
        let draft = try #require(order.makeDraft(cafe: cafe, ownerID: owner, date: now))
        #expect(draft.id != latest.id)
        #expect(draft.launchContext.source == .nextSip && draft.launchContext.sourceVisitID == latest.id)
        #expect(draft.createdAt == now && draft.ownerUserID == owner && draft.cafe?.id == cafe.id)
        #expect(draft.drinkName == "Honey oat cortado" && draft.drinkType == .coffee)
        #expect(draft.orderNotes == "Oat milk, half sweet" && draft.brewDetails.additions == "Honey")
        #expect(draft.visibility == .private && draft.overallScore == 0)
        #expect(draft.ratingCriteria.isEmpty && draft.privateNotes.isEmpty && draft.socialCaption.isEmpty)
        #expect(draft.localPhotoNames.isEmpty && draft.companions.isEmpty && draft.brewDetails.companions == nil)
        #expect(draft.sipReorderIntention == nil && draft.cafeSessionDraft == nil)
        #expect(order.makeDraft(cafe: cafe, ownerID: UUID()) == nil)
    }

    @Test func declinedLatestOrderNeverFallsBackToAnOlderDrink() throws {
        let owner = UUID()
        let cafe = Cafe(name: "Paper Moon", address: "")
        let older = Visit(
            cafeId: cafe.id, userId: owner, createdAt: .distantPast,
            drinkType: .coffee, sipReorderIntention: .yes
        )
        let declined = Visit(cafeId: cafe.id, userId: owner, drinkType: .chai, sipReorderIntention: .no)
        let order = try #require(CafeNextSipOrder.latestLocal(
            in: [older, declined], cafeID: cafe.id, ownerID: owner
        ))
        #expect(order.id == declined.id && !order.canRepeat)
        #expect(order.makeDraft(cafe: cafe, ownerID: owner) == nil)
        #expect(CafeNextSipOrder.latestLocal(in: [older, declined], cafeID: cafe.id, ownerID: UUID()) == nil)
    }

    @Test func legacyRemoteOrderUsesOnlyMatchingOwnerDetails() throws {
        let owner = UUID()
        let remoteCafeID = UUID()
        let cafe = Cafe(name: "Harborlight", address: "")
        let visit = SupabaseVisitRow(
            id: UUID(), userId: owner, cafeId: remoteCafeID, drinkType: "Other",
            drinkTypeCustom: "Sparkling tea", drinkSubtype: nil, caption: "Public caption",
            notes: "Private note", visibility: "everyone", ratings: ["Balance": 4],
            overallScore: 4, posterPhotoURL: "old.jpg", contextType: nil, locationName: nil,
            cityState: nil, brewMethod: nil, createdAt: "2026-11-08T12:00:00Z"
        )
        let summary = RemoteVisitSummary(visit: visit, cafe: nil)
        var details = BrewDetails.empty
        details.orderNotes = "No ice"
        let brew = OwnerVisitBrewRow(id: visit.id, brewMethod: nil, equipment: nil, brewDetails: details)
        let order = try #require(CafeNextSipOrder(
            remote: summary, ownerID: owner, destinationCafeID: cafe.id, cafeIDs: [remoteCafeID],
            ownerBrew: brew, reorderIntention: nil
        ))
        let draft = try #require(order.makeDraft(cafe: cafe, ownerID: owner))
        #expect(draft.drinkName == "Sparkling tea" && draft.customDrinkType == "Sparkling tea")
        #expect(draft.orderNotes == "No ice" && draft.privateNotes.isEmpty)
        #expect(order.makeDraft(cafe: Cafe(name: "Elsewhere", address: ""), ownerID: owner) == nil)
        #expect(CafeNextSipOrder(
            remote: summary, ownerID: UUID(), destinationCafeID: cafe.id, cafeIDs: [remoteCafeID],
            ownerBrew: brew, reorderIntention: nil
        ) == nil)
        #expect(CafeNextSipOrder(
            remote: summary, ownerID: owner, destinationCafeID: cafe.id, cafeIDs: [UUID()],
            ownerBrew: brew, reorderIntention: nil
        ) == nil)
    }
}
