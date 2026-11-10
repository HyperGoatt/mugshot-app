import Foundation

/// A previous order owned by the current person, with only the fields a new order can reuse.
struct CafeNextSipOrder {
    enum Source {
        case local(Visit)
        case remote(RemoteVisitSummary)
    }

    let source: Source
    let id: UUID
    let date: Date
    let destinationCafeID: UUID
    let drinkName: String
    let drinkType: DrinkType
    let customDrinkType: String
    let orderNotes: String
    let additions: String?
    let reorderIntention: SipReorderIntention?

    var canRepeat: Bool { reorderIntention != SipReorderIntention.no }

    static func latestLocal(in visits: [Visit], cafeID: UUID, ownerID: UUID) -> Self? {
        visits
            .filter { $0.cafeId == cafeID && $0.userId == ownerID && $0.context == .cafe }
            .max { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            .map(Self.init(local:))
    }

    init(local visit: Visit) {
        source = .local(visit)
        id = visit.id
        date = visit.createdAt
        destinationCafeID = visit.cafeId
        drinkName = visit.journalDrinkName
        drinkType = visit.drinkType
        customDrinkType = visit.drinkType == .other ? (visit.customDrinkType ?? "") : ""
        orderNotes = visit.brewDetails.orderNotes?.remoteTrimmedNonEmpty ?? ""
        additions = visit.brewDetails.additions?.remoteTrimmedNonEmpty
        reorderIntention = visit.sipReorderIntention
    }

    init?(
        remote summary: RemoteVisitSummary,
        ownerID: UUID,
        destinationCafeID: UUID,
        cafeIDs: Set<UUID>,
        ownerBrew: OwnerVisitBrewRow?,
        reorderIntention: SipReorderIntention?
    ) {
        let visit = summary.visit
        guard visit.userId == ownerID,
              let cafeID = visit.cafeId, cafeIDs.contains(cafeID),
              visit.journalContext == .cafe,
              visit.uploadState == VisitUploadState.complete.rawValue,
              let name = visit.drinkSubtype?.remoteTrimmedNonEmpty
                ?? visit.drinkTypeCustom?.remoteTrimmedNonEmpty
                ?? visit.drinkType?.remoteTrimmedNonEmpty else { return nil }
        let details = ownerBrew?.id == visit.id ? ownerBrew?.brewDetails : nil
        source = .remote(summary)
        id = visit.id
        date = visit.createdAtDate
        self.destinationCafeID = destinationCafeID
        drinkName = name
        drinkType = DrinkType.allCases.first {
            $0.rawValue.caseInsensitiveCompare(visit.drinkType ?? "") == .orderedSame
        } ?? .other
        customDrinkType = drinkType == .other
            ? (visit.drinkTypeCustom?.remoteTrimmedNonEmpty ?? visit.drinkType?.remoteTrimmedNonEmpty ?? name)
            : ""
        orderNotes = details?.orderNotes?.remoteTrimmedNonEmpty ?? ""
        additions = details?.additions?.remoteTrimmedNonEmpty
        self.reorderIntention = reorderIntention
    }

    func makeDraft(cafe: Cafe, ownerID: UUID, date: Date = .now) -> SipDraft? {
        guard canRepeat, cafe.id == destinationCafeID else { return nil }
        switch source {
        case .local(let visit):
            guard visit.userId == ownerID, visit.cafeId == cafe.id else { return nil }
        case .remote(let summary):
            guard summary.visit.userId == ownerID else { return nil }
        }
        var orderDetails = BrewDetails.empty
        orderDetails.additions = additions
        return SipDraft(
            ownerUserID: ownerID,
            createdAt: date,
            updatedAt: date,
            launchContext: SipComposerLaunchContext(
                source: .nextSip,
                preselectedCafe: cafe,
                sourceVisitID: id
            ),
            context: .cafe,
            cafe: cafe,
            drinkType: drinkType,
            customDrinkType: customDrinkType,
            drinkName: drinkName,
            visibility: .private,
            orderNotes: orderNotes,
            brewDetails: orderDetails
        )
    }
}
