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
            result.expression = .concerned
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
            return .init(expression: .tender, prop: .journalNotebook)
        case .feedFiltered:
            return .init(expression: .curious, prop: .guidebookAndPen, outfit: .cafeScout)
        case .discoveryEmpty:
            return .init(expression: .curious, prop: .guidebookAndPen, outfit: .cafeScout)
        case .locationRecovery:
            return .init(expression: .concerned, prop: .guidebookAndPen, outfit: .cafeScout)
        case .savedFavorites:
            return .init(expression: .tender, prop: .favoriteHeart)
        case .savedWishlist:
            return .init(expression: .concerned, prop: .wishlistBadge)
        case .savedCafes, .sharedLists:
            return .init(expression: .curious, prop: .guidebookAndPen)
        case .friendsEmpty:
            return .init(expression: .tender, prop: .friendsPhone)
        case .journalEmpty:
            return .init(expression: .tender, prop: .journalNotebook)
        case .ritual:
            return .init(
                expression: .tender,
                prop: .journalNotebook,
                outfit: .cozyRitual,
                liquid: MugsyLiquidState(appearance: .chai, fillProgress: 0.74, steamIntensity: 0.68)
            )
        case .composer:
            return .init(expression: .neutral, liquid: .coffee(fillProgress: 0.16))
        case .camera:
            return .init(expression: .curious, prop: .camera, outfit: .cameraCompanion)
        case .onboarding:
            return .init(expression: .delighted, pose: .leaningRight)
        case .authentication:
            return .init(expression: .tender)
        case .recovery:
            return .init(expression: .concerned)
        case .comingSoon:
            return .init(expression: .curious, prop: .builderTools, outfit: .builder)
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
