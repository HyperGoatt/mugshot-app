import SwiftUI

enum MugsyExpression: String, CaseIterable, Identifiable, Equatable {
    case neutral
    case curious
    case delighted
    case focused
    case tender
    case concerned

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Product empty states intentionally use only expressions that read as
    /// curious, delighted, or calmly engaged. Tender and concerned remain in
    /// the authoring model sheet, but are not valid production scene faces.
    var isPositiveProductExpression: Bool {
        switch self {
        case .neutral, .curious, .delighted, .focused:
            return true
        case .tender, .concerned:
            return false
        }
    }
}

/// Props are objects Mugsy holds or uses. They never become part of his anatomy.
enum MugsyProp: String, CaseIterable, Identifiable, Equatable {
    case none
    case wishlistBadge
    case favoriteHeart
    case guidebookAndPen
    case friendsPhone
    case camera
    case journalNotebook
    case builderTools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .wishlistBadge: return "Wishlist badge"
        case .favoriteHeart: return "Favorite heart"
        case .guidebookAndPen: return "Guidebook and pen"
        case .friendsPhone: return "Friends phone"
        case .camera: return "Camera"
        case .journalNotebook: return "Journal notebook"
        case .builderTools: return "Builder tools"
        }
    }

    var accessibilityPhrase: String? {
        switch self {
        case .none: return nil
        case .wishlistBadge: return "arms crossed over a Wishlist badge"
        case .favoriteHeart: return "holding a favorite heart"
        case .guidebookAndPen: return "reading a cafe guidebook"
        case .friendsPhone: return "holding a friends phone"
        case .camera: return "holding a camera"
        case .journalNotebook: return "holding a journal notebook"
        case .builderTools: return "holding builder tools"
        }
    }

    var defaultArmPose: MugsyArmPose {
        switch self {
        case .none: return .relaxed
        case .wishlistBadge: return .crossedOverProp
        case .favoriteHeart: return .cradling
        case .guidebookAndPen: return .reading
        case .friendsPhone: return .holdingCenter
        case .camera: return .holdingCamera
        case .journalNotebook: return .writing
        case .builderTools: return .presenting
        }
    }
}

/// Outfits are rare context cues. White ceramic and glasses remain permanent.
enum MugsyOutfit: String, CaseIterable, Identifiable, Equatable {
    case none
    case builder
    case cafeScout
    case cameraCompanion
    case cozyRitual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Canonical"
        case .builder: return "Builder"
        case .cafeScout: return "Cafe scout"
        case .cameraCompanion: return "Camera companion"
        case .cozyRitual: return "Cozy ritual"
        }
    }

    var accessibilityPhrase: String? {
        switch self {
        case .none: return nil
        case .builder: return "wearing a mint builder apron and hard hat"
        case .cafeScout: return "wearing a cafe scout hat"
        case .cameraCompanion: return "wearing a camera strap"
        case .cozyRitual: return "wrapped in a knitted ritual blanket"
        }
    }
}

enum MugsyArmPose: String, CaseIterable, Identifiable, Equatable {
    case relaxed
    case waving
    case crossedOverProp
    case cradling
    case reading
    case holdingCenter
    case holdingCamera
    case writing
    case presenting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .waving: return "Waving"
        case .crossedOverProp: return "Crossed over prop"
        case .cradling: return "Cradling"
        case .reading: return "Reading"
        case .holdingCenter: return "Holding center"
        case .holdingCamera: return "Holding camera"
        case .writing: return "Writing"
        case .presenting: return "Presenting"
        }
    }
}

/// Touch reactions are opt-in. Most product surfaces keep Mugsy still so a
/// playful response remains a small reward instead of becoming visual noise.
enum MugsyTapBehavior: String, Equatable {
    case disabled
    case wave
    case playfulCycle
}

enum MugsyTapReaction: String, CaseIterable, Equatable {
    case wave
    case hop
    case happyDance
}

enum MugsyPose: String, CaseIterable, Identifiable, Equatable {
    case neutral
    case leaningLeft
    case leaningRight

    var id: String { rawValue }

    var rotation: Angle {
        switch self {
        case .neutral: return .zero
        case .leaningLeft: return .degrees(-2)
        case .leaningRight: return .degrees(2)
        }
    }

    var horizontalOffset: CGFloat {
        switch self {
        case .neutral: return 0
        case .leaningLeft: return -5
        case .leaningRight: return 5
        }
    }
}

enum MugsyRenderMode: Equatable {
    case standard
    case contours
}

struct MugsyLiquidState: Equatable {
    var appearance: MugshotDrinkAppearance
    var fillProgress: CGFloat
    var steamIntensity: CGFloat

    init(
        appearance: MugshotDrinkAppearance = .coffee,
        fillProgress: CGFloat = 0,
        steamIntensity: CGFloat = 0
    ) {
        self.appearance = appearance
        self.fillProgress = MugshotMotion.normalized(fillProgress)
        self.steamIntensity = MugshotMotion.normalized(steamIntensity)
    }

    static let empty = MugsyLiquidState()

    static func coffee(fillProgress: CGFloat, steamIntensity: CGFloat = 0) -> MugsyLiquidState {
        MugsyLiquidState(
            appearance: .coffee,
            fillProgress: fillProgress,
            steamIntensity: steamIntensity
        )
    }
}

/// Planted-foot articulation for dance and other explicit movement states.
/// The body lowers over the knees while both feet keep their canonical anchors.
struct MugsyLegArticulation: Equatable {
    var bendProgress: CGFloat
    var weightShift: CGFloat

    init(bendProgress: CGFloat = 0, weightShift: CGFloat = 0) {
        self.bendProgress = bendProgress.mugshotClamped(to: 0...1)
        self.weightShift = weightShift.mugshotClamped(to: -1...1)
    }

    static let neutral = MugsyLegArticulation()

    var bodyOffset: CGSize {
        CGSize(
            width: weightShift * bendProgress * 7,
            height: bendProgress * 20
        )
    }
}

struct MugsyModelConfiguration: Equatable {
    var expression: MugsyExpression
    var prop: MugsyProp
    var outfit: MugsyOutfit
    var armPose: MugsyArmPose
    var pose: MugsyPose
    var legArticulation: MugsyLegArticulation
    var gaze: UnitPoint
    var liquid: MugsyLiquidState

    init(
        expression: MugsyExpression = .neutral,
        prop: MugsyProp = .none,
        outfit: MugsyOutfit = .none,
        armPose: MugsyArmPose? = nil,
        pose: MugsyPose = .neutral,
        legArticulation: MugsyLegArticulation = .neutral,
        gaze: UnitPoint = .center,
        liquid: MugsyLiquidState = .empty
    ) {
        self.expression = expression
        self.prop = prop
        self.outfit = outfit
        self.armPose = armPose ?? prop.defaultArmPose
        self.pose = pose
        self.legArticulation = legArticulation
        self.gaze = gaze
        self.liquid = liquid
    }

    /// Glasses and white ceramic are identity invariants, not accessories.
    var hasPermanentGlasses: Bool { true }
    var usesPermanentWhiteCeramic: Bool { true }

    var accessibilityLabel: String {
        var parts = ["Mugsy", expression.title.lowercased()]
        if let phrase = prop.accessibilityPhrase { parts.append(phrase) }
        if let phrase = outfit.accessibilityPhrase { parts.append(phrase) }
        return parts.joined(separator: ", ")
    }
}

enum MugsyActionState: Equatable {
    case resting
    case entering
    case pulling(progress: CGFloat)
    case refreshing
    case composing(progress: CGFloat)
    case focusing
    case capturing
    case saving
    case success
    case recovering
    case celebrating

    var progress: CGFloat {
        switch self {
        case .pulling(let progress), .composing(let progress):
            return MugshotMotion.normalized(progress)
        case .refreshing, .saving, .success, .celebrating:
            return 1
        case .resting, .entering, .focusing, .capturing, .recovering:
            return 0
        }
    }

    var responseKey: String {
        switch self {
        case .resting: return "resting"
        case .entering: return "entering"
        case .pulling: return "pulling"
        case .refreshing: return "refreshing"
        case .composing: return "composing"
        case .focusing: return "focusing"
        case .capturing: return "capturing"
        case .saving: return "saving"
        case .success: return "success"
        case .recovering: return "recovering"
        case .celebrating: return "celebrating"
        }
    }

    func applying(to base: MugsyModelConfiguration) -> MugsyModelConfiguration {
        var result = base
        switch self {
        case .resting:
            break
        case .entering:
            result.expression = .curious
        case .pulling(let rawProgress):
            let progress = MugshotMotion.normalized(rawProgress)
            result.expression = progress >= 1 ? .delighted : .curious
            result.gaze = .top
            result.liquid = .coffee(
                fillProgress: MugsyRefreshPresentation.liquidProgress(forPullProgress: progress),
                steamIntensity: progress >= 1 ? 0.42 : 0
            )
        case .refreshing:
            result.expression = .focused
            result.gaze = .top
            result.liquid = .coffee(fillProgress: 1, steamIntensity: 0.82)
        case .composing(let rawProgress):
            let progress = MugshotMotion.normalized(rawProgress)
            result.expression = progress > 0.66 ? .curious : base.expression
            result.gaze = progress > 0.45 ? .topTrailing : base.gaze
            result.liquid.fillProgress = 0.16 + progress * 0.76
            result.liquid.steamIntensity = progress > 0.48 ? 0.54 : 0.08
        case .focusing, .saving:
            result.expression = .focused
        case .capturing:
            result.expression = .delighted
            result.gaze = .topTrailing
        case .success, .celebrating:
            result.expression = .delighted
            result.liquid.steamIntensity = max(result.liquid.steamIntensity, 0.62)
        case .recovering:
            result.expression = .curious
        }
        return result
    }
}

enum MugsyRefreshPresentation {
    /// The first fifth of the pull is anticipation; the remaining distance fills
    /// the visible coffee surface in the rim without recoloring the ceramic.
    static func liquidProgress(forPullProgress progress: CGFloat) -> CGFloat {
        MugshotMotion.normalized((MugshotMotion.normalized(progress) - 0.20) / 0.65)
    }

    static func accessibilityLabel(progress: CGFloat, isRefreshing: Bool) -> String {
        if isRefreshing { return "Refreshing sips" }
        return MugshotMotion.normalized(progress) >= 1 ? "Release to refresh" : "Pull to refresh"
    }

    static func shouldRender(progress: CGFloat, isRefreshing: Bool) -> Bool {
        isRefreshing || MugshotMotion.normalized(progress) > 0.025
    }
}

/// The ten approved, reusable Mugsy scenes. A family owns the semantic prop,
/// outfit, and positive emotional read. Stable variants may change pose, gaze,
/// and coffee state, but never change the family meaning or Mugsy's identity.
enum MugsySceneFamily: String, CaseIterable, Identifiable, Equatable {
    case cheerfulCafeScout
    case delightedWishlistHolder
    case happyHeartKeeper
    case proudCameraCompanion
    case joyfulJournalKeeper
    case welcomingFriendsPhone
    case cozyCoffeeRitual
    case excitedFirstSipCelebration
    case happyBuilder
    case playfulWavingMugsy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cheerfulCafeScout: return "Cheerful Cafe Scout"
        case .delightedWishlistHolder: return "Delighted Wishlist Holder"
        case .happyHeartKeeper: return "Happy Heart Keeper"
        case .proudCameraCompanion: return "Proud Camera Companion"
        case .joyfulJournalKeeper: return "Joyful Journal Keeper"
        case .welcomingFriendsPhone: return "Welcoming Friends Phone"
        case .cozyCoffeeRitual: return "Cozy Coffee Ritual"
        case .excitedFirstSipCelebration: return "Excited First-Sip Celebration"
        case .happyBuilder: return "Happy Builder"
        case .playfulWavingMugsy: return "Playful Waving Mugsy"
        }
    }

    var contextDescription: String {
        switch self {
        case .cheerfulCafeScout:
            return "Cafe discovery, Map, and general cafe placeholders"
        case .delightedWishlistHolder:
            return "Want to Try cafes before the first completed sip"
        case .happyHeartKeeper:
            return "Favorite cafes and keepsakes"
        case .proudCameraCompanion:
            return "Visited cafes and intentionally photo-free sips"
        case .joyfulJournalKeeper:
            return "Journal memories and personal history"
        case .welcomingFriendsPhone:
            return "Friends and attributed community activity"
        case .cozyCoffeeRitual:
            return "Home coffee, quiet rituals, and taste memories"
        case .excitedFirstSipCelebration:
            return "The first sip at a Want to Try cafe"
        case .happyBuilder:
            return "Shared cafe lists and experiences still taking shape"
        case .playfulWavingMugsy:
            return "Welcomes, generic true-empty states, and friendly handoffs"
        }
    }

    var configuration: MugsyModelConfiguration {
        switch self {
        case .cheerfulCafeScout:
            return .init(
                expression: .delighted,
                prop: .guidebookAndPen,
                outfit: .cafeScout,
                pose: .leaningRight
            )
        case .delightedWishlistHolder:
            return .init(
                expression: .delighted,
                prop: .wishlistBadge,
                pose: .leaningLeft
            )
        case .happyHeartKeeper:
            return .init(
                expression: .delighted,
                prop: .favoriteHeart,
                pose: .leaningRight
            )
        case .proudCameraCompanion:
            return .init(
                expression: .delighted,
                prop: .camera,
                outfit: .cameraCompanion,
                pose: .leaningLeft
            )
        case .joyfulJournalKeeper:
            return .init(
                expression: .delighted,
                prop: .journalNotebook,
                pose: .leaningRight,
                liquid: .coffee(fillProgress: 0.48, steamIntensity: 0.28)
            )
        case .welcomingFriendsPhone:
            return .init(
                expression: .delighted,
                prop: .friendsPhone,
                pose: .leaningLeft
            )
        case .cozyCoffeeRitual:
            return .init(
                expression: .delighted,
                prop: .journalNotebook,
                outfit: .cozyRitual,
                liquid: MugsyLiquidState(
                    appearance: .chai,
                    fillProgress: 0.74,
                    steamIntensity: 0.68
                )
            )
        case .excitedFirstSipCelebration:
            return .init(
                expression: .delighted,
                armPose: .presenting,
                pose: .leaningRight,
                legArticulation: MugsyLegArticulation(
                    bendProgress: 0.42,
                    weightShift: 0.34
                ),
                liquid: .coffee(fillProgress: 0.94, steamIntensity: 0.82)
            )
        case .happyBuilder:
            return .init(
                expression: .delighted,
                prop: .builderTools,
                outfit: .builder,
                pose: .leaningLeft
            )
        case .playfulWavingMugsy:
            return .init(
                expression: .delighted,
                armPose: .waving,
                pose: .leaningRight,
                liquid: .coffee(fillProgress: 0.34, steamIntensity: 0.34)
            )
        }
    }

    var tapBehavior: MugsyTapBehavior {
        switch self {
        case .excitedFirstSipCelebration:
            return .playfulCycle
        case .playfulWavingMugsy, .welcomingFriendsPhone:
            return .wave
        case .cheerfulCafeScout,
             .delightedWishlistHolder,
             .happyHeartKeeper,
             .proudCameraCompanion,
             .joyfulJournalKeeper,
             .cozyCoffeeRitual,
             .happyBuilder:
            return .disabled
        }
    }
}

enum MugsyCafePhotoOrigin: String, Equatable {
    case library
    case map
    case discovery
    case friends
    case sharedList
}

enum MugsySceneContext: Equatable {
    case cafePhoto(
        origin: MugsyCafePhotoOrigin,
        isFavorite: Bool,
        wantToTry: Bool,
        hasVisited: Bool
    )
    case missedSipPhoto
    case sipMemory
    case journalMemory
    case communitySip
    case coffeeRitual
    case firstSipMilestone
    case welcoming
}

struct MugsyScene: Identifiable, Equatable {
    let family: MugsySceneFamily
    let variant: Int

    var id: String { "\(family.rawValue)-\(variant)" }

    var configuration: MugsyModelConfiguration {
        var result = family.configuration

        switch variant % 4 {
        case 1:
            result.pose = result.pose == .leaningLeft ? .leaningRight : .leaningLeft
            result.gaze = .topTrailing
        case 2:
            result.pose = .neutral
            result.gaze = UnitPoint(x: 0.28, y: 0.42)
            result.liquid.steamIntensity = max(result.liquid.steamIntensity, 0.24)
        case 3:
            result.gaze = UnitPoint(x: 0.72, y: 0.40)
            result.liquid.fillProgress = max(result.liquid.fillProgress, 0.28)
        default:
            break
        }

        return result
    }

    var accessibilityLabel: String {
        "\(family.title). \(family.contextDescription)."
    }
}

/// Pure resolver used by production views and the Studio. Selection is stable
/// across app launches; Swift's randomized `hashValue` is deliberately avoided.
enum MugsySceneResolver {
    static func scene(
        for context: MugsySceneContext,
        stableID: String
    ) -> MugsyScene {
        let seed = stableSeed(for: stableID)
        let family: MugsySceneFamily

        switch context {
        case let .cafePhoto(origin, isFavorite, wantToTry, hasVisited):
            if hasVisited {
                family = .proudCameraCompanion
            } else if wantToTry {
                family = .delightedWishlistHolder
            } else if isFavorite {
                family = .happyHeartKeeper
            } else {
                switch origin {
                case .friends:
                    family = .welcomingFriendsPhone
                case .sharedList:
                    family = .happyBuilder
                case .library, .map, .discovery:
                    let generalFamilies: [MugsySceneFamily] = [
                        .cheerfulCafeScout,
                        .playfulWavingMugsy,
                        .cozyCoffeeRitual
                    ]
                    family = generalFamilies[Int(seed % UInt64(generalFamilies.count))]
                }
            }
        case .missedSipPhoto:
            family = .proudCameraCompanion
        case .sipMemory:
            family = .cozyCoffeeRitual
        case .journalMemory:
            family = .joyfulJournalKeeper
        case .communitySip:
            family = .welcomingFriendsPhone
        case .coffeeRitual:
            family = .cozyCoffeeRitual
        case .firstSipMilestone:
            family = .excitedFirstSipCelebration
        case .welcoming:
            family = .playfulWavingMugsy
        }

        return MugsyScene(family: family, variant: Int((seed >> 8) % 4))
    }

    static func cafePhoto(
        stableID: String,
        origin: MugsyCafePhotoOrigin,
        isFavorite: Bool,
        wantToTry: Bool,
        hasVisited: Bool
    ) -> MugsyScene {
        scene(
            for: .cafePhoto(
                origin: origin,
                isFavorite: isFavorite,
                wantToTry: wantToTry,
                hasVisited: hasVisited
            ),
            stableID: stableID
        )
    }

    static func stableSeed(for value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

/// Central registry keeps Mugsy intentional and consistent across product flows.
enum MugsyPlacement: String, CaseIterable, Identifiable {
    case feedEmpty
    case feedFiltered
    case discoveryEmpty
    case locationRecovery
    case savedFavorites
    case savedWishlist
    case savedCafes
    case sharedLists
    case friendsEmpty
    case journalEmpty
    case ritual
    case composer
    case camera
    case onboarding
    case authentication
    case recovery
    case comingSoon

    var id: String { rawValue }

    var configuration: MugsyModelConfiguration {
        switch self {
        case .feedEmpty:
            return MugsySceneFamily.joyfulJournalKeeper.configuration
        case .feedFiltered:
            return MugsySceneFamily.cheerfulCafeScout.configuration
        case .discoveryEmpty:
            return MugsySceneFamily.cheerfulCafeScout.configuration
        case .locationRecovery:
            return MugsySceneFamily.cheerfulCafeScout.configuration
        case .savedFavorites:
            return MugsySceneFamily.happyHeartKeeper.configuration
        case .savedWishlist:
            return MugsySceneFamily.delightedWishlistHolder.configuration
        case .savedCafes:
            return MugsySceneFamily.cheerfulCafeScout.configuration
        case .sharedLists:
            return MugsySceneFamily.happyBuilder.configuration
        case .friendsEmpty:
            return MugsySceneFamily.welcomingFriendsPhone.configuration
        case .journalEmpty:
            return MugsySceneFamily.joyfulJournalKeeper.configuration
        case .ritual:
            return MugsySceneFamily.cozyCoffeeRitual.configuration
        case .composer:
            return MugsySceneFamily.cozyCoffeeRitual.configuration
        case .camera:
            return MugsySceneFamily.proudCameraCompanion.configuration
        case .onboarding:
            return MugsySceneFamily.playfulWavingMugsy.configuration
        case .authentication:
            return MugsySceneFamily.playfulWavingMugsy.configuration
        case .recovery:
            return MugsySceneFamily.playfulWavingMugsy.configuration
        case .comingSoon:
            return MugsySceneFamily.happyBuilder.configuration
        }
    }

    var tapBehavior: MugsyTapBehavior {
        switch self {
        case .feedEmpty, .savedFavorites, .savedWishlist, .friendsEmpty, .journalEmpty, .onboarding:
            return .playfulCycle
        case .discoveryEmpty, .authentication:
            return .wave
        case .feedFiltered, .locationRecovery, .savedCafes, .sharedLists, .ritual, .composer, .camera, .recovery, .comingSoon:
            return .disabled
        }
    }
}

enum MugsyStyleTokens {
    static let inkHex = "0C0C0C"
    static let ceramicBaseHex = "F3F3F3"
    static let ceramicHighlightHex = "F7F7F7"
    static let ceramicShadowHex = "D7D6D6"
    static let blushHex = "E8B8B0"
    static let mintAccentHex = "B8E0C0"

    static let ink = Color(hex: inkHex)
    static let ceramicBase = Color(hex: ceramicBaseHex)
    static let ceramicHighlight = Color(hex: ceramicHighlightHex)
    static let ceramicShadow = Color(hex: ceramicShadowHex)
    static let blush = Color(hex: blushHex)
    static let mintAccent = Color(hex: mintAccentHex)
}

struct MugsyRenderMetrics: Equatable {
    static let primaryStrokeRatio: CGFloat = 0.009
    static let detailStrokeRatio: CGFloat = 0.0065
    static let microStrokeRatio: CGFloat = 0.0045

    let renderSize: CGFloat
    let primaryStroke: CGFloat
    let detailStroke: CGFloat
    let microStroke: CGFloat

    init(renderSize: CGFloat) {
        self.renderSize = max(1, renderSize)
        primaryStroke = max(1.35, renderSize * Self.primaryStrokeRatio)
        detailStroke = max(1.0, renderSize * Self.detailStrokeRatio)
        microStroke = max(0.8, renderSize * Self.microStrokeRatio)
    }
}

enum MugsyModelAnchor: String, CaseIterable, Identifiable {
    case rim
    case body
    case handle
    case glasses
    case cheeks
    case feet
    case leftHandProp
    case rightHandProp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHandProp: return "Left prop"
        case .rightHandProp: return "Right prop"
        default: return rawValue.capitalized
        }
    }
}

/// Normalized against the alpha bounds of MugsyNoWishlist, the primary master.
enum MugsyReferenceGeometry {
    static let designCanvas = CGSize(width: 500, height: 500)
    static let sourceAlphaBounds = CGRect(x: 145, y: 154, width: 271, height: 274)
    static let modelContentBounds = CGRect(x: 67, y: 65, width: 366, height: 370)
    static let maximumAnchorError: CGFloat = 0.02

    private static let referenceAnchors: [MugsyModelAnchor: CGPoint] = [
        .rim: CGPoint(x: 0.373, y: 0.062),
        .body: CGPoint(x: 0.373, y: 0.412),
        .handle: CGPoint(x: 0.867, y: 0.350),
        .glasses: CGPoint(x: 0.378, y: 0.296),
        .cheeks: CGPoint(x: 0.292, y: 0.398),
        .feet: CGPoint(x: 0.362, y: 0.974),
        .leftHandProp: CGPoint(x: 0.218, y: 0.610),
        .rightHandProp: CGPoint(x: 0.340, y: 0.610)
    ]

    private static let modelAnchors: [MugsyModelAnchor: CGPoint] = [
        .rim: CGPoint(x: 204, y: 88),
        .body: CGPoint(x: 206, y: 219),
        .handle: CGPoint(x: 384, y: 196),
        .glasses: CGPoint(x: 205, y: 175),
        .cheeks: CGPoint(x: 174, y: 212),
        .feet: CGPoint(x: 200, y: 425),
        .leftHandProp: CGPoint(x: 147, y: 291),
        .rightHandProp: CGPoint(x: 191, y: 291)
    ]

    static func referenceAnchor(_ anchor: MugsyModelAnchor) -> CGPoint {
        referenceAnchors[anchor] ?? .zero
    }

    static func modelAnchor(_ anchor: MugsyModelAnchor) -> CGPoint {
        modelAnchors[anchor] ?? .zero
    }

    static func normalizedModelAnchor(_ anchor: MugsyModelAnchor) -> CGPoint {
        let point = modelAnchor(anchor)
        return CGPoint(
            x: (point.x - modelContentBounds.minX) / modelContentBounds.width,
            y: (point.y - modelContentBounds.minY) / modelContentBounds.height
        )
    }

    static func alignmentError(for anchor: MugsyModelAnchor) -> CGFloat {
        let reference = referenceAnchor(anchor)
        let model = normalizedModelAnchor(anchor)
        return max(abs(reference.x - model.x), abs(reference.y - model.y))
    }
}
