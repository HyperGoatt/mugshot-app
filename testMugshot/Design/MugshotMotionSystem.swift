import SwiftUI
import UIKit

private struct MugshotReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var mugshotReduceMotionOverride: Bool? {
        get { self[MugshotReduceMotionOverrideKey.self] }
        set { self[MugshotReduceMotionOverrideKey.self] = newValue }
    }
}

/// Mugshot motion is quiet at rest, responsive under a finger, and briefly
/// expressive when an action completes. Feature views own their animation
/// phase; this namespace contains only reusable timing and tactile language.
enum MugshotMotion {
    enum Intensity: String, CaseIterable, Identifiable {
        case still
        case subtle
        case expressive

        var id: String { rawValue }

        var ambientScale: CGFloat {
            switch self {
            case .still: return 0
            case .subtle: return 0.55
            case .expressive: return 1
            }
        }
    }

    static let response = Animation.spring(duration: 0.34, bounce: 0.08)
    static let character = Animation.spring(duration: 0.48, bounce: 0.22)
    static let settle = Animation.spring(duration: 0.72, bounce: 0.10)
    static let reveal = Animation.easeInOut(duration: 0.28)
    static let celebration = Animation.spring(duration: 0.66, bounce: 0.30)

    static func animation(
        _ animation: Animation,
        reduceMotion: Bool,
        fallback: Animation? = .easeOut(duration: 0.16)
    ) -> Animation? {
        reduceMotion ? fallback : animation
    }

    static func normalized(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum MugshotHaptic {
    case selection
    case softImpact
    case refreshArmed
    case success
    case warning

    @MainActor
    func play(isEnabled: Bool = true) {
        guard isEnabled else { return }
        switch self {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .softImpact:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .refreshArmed:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.72)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

enum MugshotDrinkAppearance: String, CaseIterable, Identifiable {
    case coffee
    case matcha
    case tea
    case chai
    case bright

    var id: String { rawValue }

    var liquidColor: Color {
        switch self {
        case .coffee: return Color(hex: "80563C")
        case .matcha: return Color(hex: "87A967")
        case .tea: return Color(hex: "C89554")
        case .chai: return Color(hex: "B87957")
        case .bright: return Color(hex: "D99A71")
        }
    }

    static func infer(from drinkName: String) -> MugshotDrinkAppearance {
        let name = drinkName.lowercased()
        if name.contains("matcha") { return .matcha }
        if name.contains("chai") { return .chai }
        if name.contains("tea") { return .tea }
        if name.contains("lemon") || name.contains("fruit") || name.contains("spritz") { return .bright }
        return .coffee
    }
}

extension Comparable {
    func mugshotClamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
