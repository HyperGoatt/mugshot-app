import Foundation
import Testing
@testable import testMugshot

struct TastePassportTests {
    @Test func visibleProjectionDecodesOnlyTheCallerBoundContract() throws {
        let ownerID = UUID()
        let data = Data(
            """
            {
              "user_id": "\(ownerID.uuidString)",
              "visibility": "everyone",
              "descriptors": [
                {"kind": "order_preference", "label": "Fruit-Forward"},
                {"kind": "sensory_lens", "label": "Clarity-Seeking"},
                {"kind": "ritual", "label": "Cafe Explorer"}
              ],
              "description": "Often reaches for fruit-forward cups and tends to notice clarity.",
              "is_forming": false,
              "confidence_band": "established",
              "calculation_version": "taste-passport-1",
              "updated_at": "2026-07-21T20:00:00Z"
            }
            """.utf8
        )

        let projection = try JSONDecoder().decode(TastePassportProjection.self, from: data)
        let state = try TastePassportAccessState.resolve(
            projection,
            requestedUserID: ownerID
        )

        guard case .visible(let visible) = state else {
            Issue.record("Expected a visible Taste Passport")
            return
        }
        #expect(visible.userID == ownerID)
        #expect(visible.visibility == .everyone)
        #expect(visible.descriptors.map(\.displayLabel) == [
            "Fruit-Forward",
            "Clarity-Seeking",
            "Cafe Explorer"
        ])
        #expect(visible.calculationVersion == "taste-passport-1")
    }

    @Test func nullProjectionResolvesToEvidenceFreeHiddenState() throws {
        let projection = try JSONDecoder().decode(
            TastePassportProjection?.self,
            from: Data("null".utf8)
        )

        let state = try TastePassportAccessState.resolve(
            projection,
            requestedUserID: UUID()
        )

        #expect(state == .hidden)
    }

    @Test func formingProjectionDiscardsLowEvidenceDescriptors() throws {
        let ownerID = UUID()
        let data = Data(
            """
            {
              "user_id": "\(ownerID.uuidString)",
              "visibility": "friends",
              "descriptors": [
                {"kind": "order_preference", "label": "Unverified order guess"},
                {"kind": "sensory_lens", "label": "Unverified sensory guess"},
                {"kind": "ritual", "label": "Unverified ritual guess"}
              ],
              "description": "A low-evidence description that must not reach presentation.",
              "is_forming": true,
              "confidence_band": "emerging",
              "calculation_version": "taste-passport-1",
              "updated_at": null
            }
            """.utf8
        )
        let projection = try JSONDecoder().decode(TastePassportProjection.self, from: data)

        let state = try TastePassportAccessState.resolve(
            projection,
            requestedUserID: ownerID
        )

        #expect(state == .insufficient(visibility: .friends))
    }

    @Test func compatibilityPreviewNeverClaimsAnUnconfirmedAudienceWhileForming() throws {
        let state = try TastePassportCompatibility.accessState(
            userID: UUID(),
            summary: .empty
        )

        #expect(state == .compatibilityInsufficient)
    }

    @Test func passportProjectionCannotCrossRequestedAccounts() throws {
        let projectionOwnerID = UUID()
        let requestedOwnerID = UUID()
        let projection = TastePassportProjection(
            userID: projectionOwnerID,
            visibility: .everyone,
            descriptors: [
                TastePassportDescriptor(kind: .orderPreference, label: "Fruit-Forward"),
                TastePassportDescriptor(kind: .sensoryLens, label: "Clarity-Seeking"),
                TastePassportDescriptor(kind: .ritual, label: "Cafe Explorer")
            ],
            summaryDescription: "Safe summary",
            isForming: false,
            confidenceBand: .growing,
            calculationVersion: "taste-passport-1",
            updatedAt: nil
        )

        do {
            _ = try TastePassportAccessState.resolve(
                projection,
                requestedUserID: requestedOwnerID
            )
            Issue.record("A projection from another account was accepted")
        } catch let error as TastePassportContractError {
            #expect(error == .accountScopeMismatch)
        }
    }

    @Test func visibilityReadCannotCrossAuthenticatedAccounts() throws {
        let signedInAccountID = UUID()
        let response = TastePassportVisibilityProjection(
            userID: UUID(),
            visibility: .everyone
        )

        do {
            _ = try response.value(forAccountID: signedInAccountID)
            Issue.record("A visibility setting from another account was accepted")
        } catch let error as TastePassportContractError {
            #expect(error == .accountScopeMismatch)
        }
    }

    @Test func ownerVisibilityResponseDecodesEveryoneDefault() throws {
        let accountID = UUID()
        let data = Data(
            """
            {"user_id": "\(accountID.uuidString)", "visibility": "everyone"}
            """.utf8
        )
        let projection = try JSONDecoder().decode(
            TastePassportVisibilityProjection.self,
            from: data
        )

        #expect(try projection.value(forAccountID: accountID) == .everyone)
    }
}
