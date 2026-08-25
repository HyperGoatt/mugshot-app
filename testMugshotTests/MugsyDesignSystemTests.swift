import SwiftUI
import Testing
@testable import testMugshot

struct MugsyDesignSystemTests {
    @MainActor
    @Test func vectorReferenceExportsOneFiveHundredPointPDFPage() throws {
        let data = MugsyVectorReferenceExporter.pdfData()
        Attachment.record(
            [UInt8](data),
            named: "Mugsy-code-native-reference.pdf"
        )
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        let page = try #require(document.page(at: 1))

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(document.numberOfPages == 1)
        #expect(page.getBoxRect(.mediaBox).size == MugsyVectorReferenceExporter.canvasSize)
    }

    @Test("Canonical palette values stay locked")
    func canonicalPaletteValues() {
        #expect(MugsyStyleTokens.inkHex == "0C0C0C")
        #expect(MugsyStyleTokens.ceramicBaseHex == "F3F3F3")
        #expect(MugsyStyleTokens.ceramicHighlightHex == "F7F7F7")
        #expect(MugsyStyleTokens.ceramicShadowHex == "D7D6D6")
        #expect(MugsyStyleTokens.blushHex == "E8B8B0")
        #expect(MugsyStyleTokens.mintAccentHex == "B8E0C0")
    }

    @Test("Contour metrics preserve the approved size matrix")
    func contourMetricsAtApprovedSizes() {
        let sizes: [CGFloat] = [44, 72, 120, 200]
        let metrics = sizes.map(MugsyRenderMetrics.init(renderSize:))

        for metric in metrics {
            #expect(metric.primaryStroke >= 1.35)
            #expect(metric.detailStroke >= 1.0)
            #expect(metric.microStroke >= 0.8)
            #expect(metric.primaryStroke >= metric.detailStroke)
            #expect(metric.detailStroke >= metric.microStroke)
        }

        for pair in zip(metrics, metrics.dropFirst()) {
            #expect(pair.0.primaryStroke <= pair.1.primaryStroke)
            #expect(pair.0.detailStroke <= pair.1.detailStroke)
            #expect(pair.0.microStroke <= pair.1.microStroke)
        }

        #expect(metrics[0].renderSize == 44)
        #expect(abs(metrics[3].primaryStroke - 1.8) < 0.0001)
        #expect(abs(metrics[3].detailStroke - 1.3) < 0.0001)
        #expect(abs(metrics[3].microStroke - 0.9) < 0.0001)
    }

    @Test("Every canonical anchor stays within two percent of the master")
    func canonicalAnchorAlignment() {
        for anchor in MugsyModelAnchor.allCases {
            #expect(
                MugsyReferenceGeometry.alignmentError(for: anchor)
                    <= MugsyReferenceGeometry.maximumAnchorError,
                "\(anchor.title) exceeded the approved alignment tolerance"
            )
        }
    }

    @Test("All model and attachment anchors remain inside Mugsy bounds")
    func anchorBounds() {
        #expect(MugsyReferenceGeometry.designCanvas == CGSize(width: 500, height: 500))
        #expect(MugsyReferenceGeometry.sourceAlphaBounds == CGRect(x: 145, y: 154, width: 271, height: 274))

        for anchor in MugsyModelAnchor.allCases {
            #expect(
                MugsyReferenceGeometry.modelContentBounds.contains(
                    MugsyReferenceGeometry.modelAnchor(anchor)
                )
            )
        }
    }

    @Test("Glasses remain permanent across every value state")
    func permanentIdentityInvariant() {
        for expression in MugsyExpression.allCases {
            for prop in MugsyProp.allCases {
                for outfit in MugsyOutfit.allCases {
                    let configuration = MugsyModelConfiguration(
                        expression: expression,
                        prop: prop,
                        outfit: outfit,
                        pose: .neutral,
                        gaze: .center
                    )

                    #expect(configuration.hasPermanentGlasses)
                    #expect(configuration.usesPermanentWhiteCeramic)
                }
            }
        }

        #expect(MugsyProp.allCases.contains(.wishlistBadge))
        #expect(MugsyProp.wishlistBadge.defaultArmPose == .crossedOverProp)
    }

    @Test("Model configuration uses deterministic value semantics")
    func configurationValueSemantics() {
        let first = MugsyModelConfiguration(
            expression: .curious,
            prop: .wishlistBadge,
            pose: .leaningLeft,
            gaze: UnitPoint(x: 0.2, y: 0.4)
        )
        let second = first

        #expect(first == second)
        #expect(first.armPose == .crossedOverProp)
        #expect(first.accessibilityLabel == "Mugsy, curious, arms crossed over a Wishlist badge")

        let deepestLeftBend = MugsyLegArticulation(bendProgress: 4, weightShift: -3)
        #expect(deepestLeftBend.bendProgress == 1)
        #expect(deepestLeftBend.weightShift == -1)
        #expect(deepestLeftBend.bodyOffset == CGSize(width: -7, height: 20))
        #expect(MugsyLegArticulation.neutral.bodyOffset == .zero)
    }

    @Test("Pull progress fills coffee only after the anticipation range")
    func refreshLiquidMapping() {
        #expect(MugsyRefreshPresentation.liquidProgress(forPullProgress: 0) == 0)
        #expect(MugsyRefreshPresentation.liquidProgress(forPullProgress: 0.2) == 0)
        #expect(abs(MugsyRefreshPresentation.liquidProgress(forPullProgress: 0.85) - 1) < 0.0001)
        #expect(MugsyRefreshPresentation.liquidProgress(forPullProgress: 1) == 1)

        let armed = MugsyActionState.pulling(progress: 1).applying(to: .init())
        #expect(armed.expression == .delighted)
        #expect(armed.liquid.fillProgress == 1)
        #expect(armed.usesPermanentWhiteCeramic)

        let clamped = MugsyLiquidState(fillProgress: -2, steamIntensity: 4)
        #expect(clamped.fillProgress == 0)
        #expect(clamped.steamIntensity == 1)
    }

    @Test("Placement registry uses context-specific props without changing identity")
    func placementRegistry() {
        #expect(MugsyPlacement.savedWishlist.configuration.prop == .wishlistBadge)
        #expect(MugsyPlacement.savedWishlist.configuration.armPose == .crossedOverProp)
        #expect(MugsyPlacement.savedFavorites.configuration.prop == .favoriteHeart)
        #expect(MugsyPlacement.friendsEmpty.configuration.prop == .friendsPhone)
        #expect(MugsyPlacement.camera.configuration.outfit == .cameraCompanion)
        #expect(MugsyPlacement.camera.configuration.expression == .delighted)
        #expect(MugsyPlacement.comingSoon.configuration.outfit == .builder)

        #expect(MugsyPlacement.savedWishlist.tapBehavior == .playfulCycle)
        #expect(MugsyPlacement.onboarding.tapBehavior == .playfulCycle)
        #expect(MugsyPlacement.authentication.tapBehavior == .wave)
        #expect(MugsyPlacement.camera.tapBehavior == .disabled)

        #expect(MugsyArmPose.allCases.contains(.waving))
        #expect(MugsyTapReaction.allCases == [.wave, .hop, .happyDance])

        #expect(!MugsyRefreshPresentation.shouldRender(progress: 0, isRefreshing: false))
        #expect(MugsyRefreshPresentation.shouldRender(progress: 0.2, isRefreshing: false))
        #expect(MugsyRefreshPresentation.shouldRender(progress: 0, isRefreshing: true))

        for placement in MugsyPlacement.allCases {
            #expect(placement.configuration.hasPermanentGlasses)
            #expect(placement.configuration.usesPermanentWhiteCeramic)
            #expect(
                placement.configuration.expression.isPositiveProductExpression,
                "\(placement.rawValue) must use a positive product expression"
            )
        }
    }

    @Test("Dynamic Mugsy registry contains exactly ten positive scene families")
    func positiveSceneFamilyRegistry() {
        #expect(MugsySceneFamily.allCases.count == 10)
        #expect(Set(MugsySceneFamily.allCases.map(\.title)).count == 10)

        for family in MugsySceneFamily.allCases {
            let configuration = family.configuration
            #expect(configuration.expression.isPositiveProductExpression)
            #expect(configuration.hasPermanentGlasses)
            #expect(configuration.usesPermanentWhiteCeramic)
        }
    }

    @Test("Scene selection is deterministic across stable identifiers")
    func deterministicSceneSelection() {
        let first = MugsySceneResolver.scene(
            for: .cafePhoto(
                origin: .library,
                isFavorite: false,
                wantToTry: false,
                hasVisited: false
            ),
            stableID: "60000000-0000-4000-8000-000000000006"
        )
        let second = MugsySceneResolver.scene(
            for: .cafePhoto(
                origin: .library,
                isFavorite: false,
                wantToTry: false,
                hasVisited: false
            ),
            stableID: "60000000-0000-4000-8000-000000000006"
        )

        #expect(first == second)
        #expect(MugsySceneResolver.stableSeed(for: "Mugshot") == 17_620_294_719_749_117_680)
    }

    @Test("Cafe relationship takes precedence over generic origin")
    func cafeRelationshipPrecedence() {
        let id = "70000000-0000-4000-8000-000000000007"

        let visited = MugsySceneResolver.cafePhoto(
            stableID: id,
            origin: .discovery,
            isFavorite: true,
            wantToTry: true,
            hasVisited: true
        )
        let wantToTry = MugsySceneResolver.cafePhoto(
            stableID: id,
            origin: .friends,
            isFavorite: true,
            wantToTry: true,
            hasVisited: false
        )
        let favorite = MugsySceneResolver.cafePhoto(
            stableID: id,
            origin: .sharedList,
            isFavorite: true,
            wantToTry: false,
            hasVisited: false
        )
        let friend = MugsySceneResolver.cafePhoto(
            stableID: id,
            origin: .friends,
            isFavorite: false,
            wantToTry: false,
            hasVisited: false
        )

        #expect(visited.family == .proudCameraCompanion)
        #expect(wantToTry.family == .delightedWishlistHolder)
        #expect(favorite.family == .happyHeartKeeper)
        #expect(friend.family == .welcomingFriendsPhone)
    }

    @Test("Stable variants preserve the scene family meaning")
    func stableVariantsPreserveFamily() {
        for family in MugsySceneFamily.allCases {
            for variant in 0..<8 {
                let scene = MugsyScene(family: family, variant: variant)
                #expect(scene.family == family)
                #expect(scene.configuration.prop == family.configuration.prop)
                #expect(scene.configuration.outfit == family.configuration.outfit)
                #expect(scene.configuration.expression.isPositiveProductExpression)
            }
        }
    }
}
