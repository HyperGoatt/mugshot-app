import Foundation
import Testing
import UIKit
@testable import testMugshot

struct PostPresentationPolicyTests {
    @Test func supportedAspectRatiosRemainUnchangedAndExtremesClamp() {
        #expect(abs(MugshotPostAspectRatioPolicy.clamped(1) - 1) < 0.0001)
        #expect(abs(MugshotPostAspectRatioPolicy.clamped(1.5) - 1.5) < 0.0001)
        #expect(abs(MugshotPostAspectRatioPolicy.clamped(0.3) - 0.75) < 0.0001)
        #expect(abs(MugshotPostAspectRatioPolicy.clamped(3.2) - 1.91) < 0.0001)
        #expect(abs(MugshotPostAspectRatioPolicy.ratio(for: .zero) - 0.75) < 0.0001)
    }

    @Test func carouselAspectRatioAlwaysUsesTheFirstImage() {
        let sizes = [
            CGSize(width: 900, height: 1_200),
            CGSize(width: 1_200, height: 600),
            CGSize(width: 400, height: 1_200)
        ]

        #expect(abs(MugshotPostAspectRatioPolicy.carouselRatio(for: sizes) - 0.75) < 0.0001)
        #expect(abs(MugshotPostAspectRatioPolicy.carouselRatio(for: []) - 0.75) < 0.0001)
    }

    @Test func postLocationLineAddsOneCompactLocality() {
        #expect(
            MugshotPostLocationLine.displayName(
                name: "Uptown Coffee",
                locality: MugshotPostLocationLine.locality(from: "Pittsburgh, PA")
            ) == "Uptown Coffee · Pittsburgh"
        )
        #expect(
            MugshotPostLocationLine.locality(
                from: "723 Washington Rd, Mt Lebanon, PA 15228"
            ) == "Mt Lebanon"
        )
        #expect(
            MugshotPostLocationLine.displayName(name: "Home", locality: nil) == "Home"
        )
    }

    @Test func captionPolicyAcceptsOneThousandScalarsAndRejectsOneThousandOne() throws {
        let maximumASCII = String(repeating: "a", count: 1_000)
        let overLimitASCII = maximumASCII + "b"
        let maximumDecomposedUnicode = String(repeating: "e\u{301}", count: 500)
        let overLimitDecomposedUnicode = maximumDecomposedUnicode + "e\u{301}"

        #expect(try SipCaptionPolicy.validateAndNormalize("  \(maximumASCII)\n") == maximumASCII)
        #expect(try SipCaptionPolicy.validateAndNormalize(maximumDecomposedUnicode) == maximumDecomposedUnicode)
        #expect(
            SipCaptionPolicy.validationError(for: overLimitASCII)
                == .tooLong(maximum: 1_000)
        )
        #expect(
            SipCaptionPolicy.validationError(for: overLimitDecomposedUnicode)
                == .tooLong(maximum: 1_000)
        )
    }

    @Test func emptyAndWhitespaceCaptionsRemainInvalid() {
        #expect(SipCaptionPolicy.validationError(for: "") == .required)
        #expect(SipCaptionPolicy.validationError(for: " \n\t ") == .required)
    }

    @Test @MainActor func twoLineCaptionOnlyShowsMoreWhenActuallyTruncated() {
        let font = UIFont.systemFont(ofSize: 15)
        let short = MugshotCaptionTruncation.truncatedText(
            "Bright, balanced, and worth another visit.",
            width: 320,
            font: font
        )
        let longCaption = String(
            repeating: "Bright citrus, silky texture, and a finish worth remembering. ",
            count: 12
        )
        let long = MugshotCaptionTruncation.truncatedText(
            longCaption,
            width: 320,
            font: font
        )

        #expect(short == nil)
        #expect(long?.hasSuffix(MugshotCaptionTruncation.suffix) == true)
        #expect(long != longCaption)
    }

    @Test func localAndRemoteRoutesKeepTheTappedUUIDAfterFeedReordering() {
        let amandaID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let joeID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        var remoteFeed = [makeRemoteVisit(id: amandaID), makeRemoteVisit(id: joeID)]
        let tappedRemoteRoute = FeedPostRoute.remote(remoteFeed[0])
        remoteFeed.reverse()

        let localAmanda = Visit(
            id: amandaID,
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            caption: "Amanda caption"
        )
        let localJoe = Visit(
            id: joeID,
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            caption: "Joe caption"
        )
        var localFeed = [localAmanda, localJoe]
        let tappedLocalRoute = FeedPostRoute.local(localFeed[0])
        localFeed.reverse()

        #expect(tappedRemoteRoute.visitID == amandaID)
        #expect(tappedLocalRoute.visitID == amandaID)
        #expect(remoteFeed.first?.id == joeID)
        #expect(localFeed.first?.id == joeID)
        #expect(tappedRemoteRoute.id != tappedLocalRoute.id)
    }

    private func makeRemoteVisit(id: UUID) -> RemoteVisitSummary {
        RemoteVisitSummary(
            visit: SupabaseVisitRow(
                id: id,
                userId: UUID(),
                cafeId: nil,
                drinkType: "Coffee",
                drinkTypeCustom: nil,
                drinkSubtype: "Latte",
                caption: "Route contract",
                notes: nil,
                visibility: "friends",
                ratings: ["Taste": 4],
                overallScore: 4,
                posterPhotoURL: nil,
                contextType: "Home",
                locationName: "Kitchen",
                cityState: nil,
                brewMethod: nil,
                createdAt: "2026-07-31T12:00:00Z"
            ),
            cafe: nil
        )
    }
}
