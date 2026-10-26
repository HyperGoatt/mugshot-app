import SwiftUI

/// Presentation only. A fill describes a pull gesture, never network progress.
enum FeedRefreshOutcome: Equatable {
    case success, failure, cancelled, skipped
}

enum FeedRefreshOrigin: Equatable { case pull, accessibility }

enum FeedRefreshPhase: Equatable {
    case idle, pulling, armed, refreshing, finishing(FeedRefreshOutcome)
}

struct FeedRefreshPresentationState: Equatable {
    private(set) var phase: FeedRefreshPhase = .idle
    private(set) var progress: CGFloat = 0
    private(set) var requestID: UUID?
    private(set) var origin: FeedRefreshOrigin = .pull
    private var armedThisGesture = false

    var isRefreshing: Bool { phase == .refreshing }
    var isFinishing: Bool {
        if case .finishing = phase { return true }
        return false
    }
    var isVisible: Bool { phase != .idle }
    var displaysCoffee: Bool { isVisible && origin == .pull }
    var reservesPullSpace: Bool { origin == .pull && (isRefreshing || isFinishing) }

    /// True only at the first threshold crossing of this gesture.
    mutating func pull(to value: CGFloat) -> Bool {
        guard !isRefreshing, !isFinishing else { return false }
        origin = .pull
        progress = min(max(value.isFinite ? value : 0, 0), 1)
        phase = progress >= 1 ? .armed : progress > 0.025 ? .pulling : .idle
        guard progress >= 1, !armedThisGesture else { return false }
        armedThisGesture = true
        return true
    }

    /// Release commits an armed gesture; a partial gesture returns to rest.
    mutating func release() -> Bool {
        guard phase == .armed else { endPull(); return false }
        return true
    }

    mutating func endPull() {
        guard !isRefreshing, !isFinishing else { return }
        reset()
    }

    mutating func begin(origin: FeedRefreshOrigin = .pull) -> UUID? {
        guard !isRefreshing else { return nil }
        let id = UUID()
        requestID = id
        self.origin = origin
        phase = .refreshing
        progress = 1
        return id
    }

    @discardableResult
    mutating func finish(_ outcome: FeedRefreshOutcome, requestID id: UUID) -> Bool {
        guard requestID == id, isRefreshing else { return false }
        if outcome == .cancelled || outcome == .skipped {
            reset()
        } else {
            phase = .finishing(outcome)
        }
        return true
    }

    mutating func reset() {
        phase = .idle
        progress = 0
        requestID = nil
        origin = .pull
        armedThisGesture = false
    }
}

/// Shared canonical-space geometry keeps the stream attached to the open rim.
struct MugsyRefreshGeometry {
    static let armingDistance: CGFloat = 82
    static let anticipationFraction: CGFloat = 0.35
    let size: CGSize
    var characterSide: CGFloat { min(96, max(72, size.width * 0.24)) }
    var characterOrigin: CGPoint {
        CGPoint(x: (size.width - characterSide) / 2, y: 8)
    }
    var rim: CGPoint {
        CGPoint(x: characterOrigin.x + characterSide * 205 / 500,
                y: characterOrigin.y + characterSide * 91 / 500)
    }

    /// The first drop stays inside the gap already revealed by the finger.
    func anticipationDrop(from origin: CGPoint, progress: CGFloat) -> CGPoint {
        let fraction = min(max(progress / Self.anticipationFraction, 0), 1)
        return CGPoint(x: origin.x + (rim.x - origin.x) * fraction,
                       y: min(rim.y * fraction, max(0, progress * Self.armingDistance - DesignSystem.Space.sm - 3.5)))
    }
}

enum MugshotPolishState {
    static func ratingText(_ value: Double) -> String {
        value.isFinite && value > 0 ? String(format: "%.1f", value) : "Not rated"
    }
    static func changedRating(from old: Double, to new: Double) -> Bool {
        new.isFinite && old != new && (0...5).contains(new)
    }
}

struct MugshotSaveReceipt: Identifiable, Equatable {
    let id: UUID
    let ownerID: UUID?
    let drinkName: String
    let isExpressive: Bool
    var audience: VisitVisibility? = nil
    var title: String {
        switch audience {
        case .friends: return "Posted to Friends"
        case .everyone: return "Posted to Everyone"
        default: return "Saved privately"
        }
    }
}

/// Receipts arrive only from a completed transaction, not a detail read.
struct MugshotReceiptLedger {
    private var consumed: Set<String> = []
    mutating func consume(_ receipt: MugshotSaveReceipt) -> Bool {
        consumed.insert("\(receipt.ownerID?.uuidString ?? "guest"):\(receipt.id)").inserted
    }
}

@MainActor
final class MugshotCompletionFeedback {
    static let shared = MugshotCompletionFeedback()
    private var ledger = MugshotReceiptLedger()
    func consume(_ receipt: MugshotSaveReceipt) -> Bool { ledger.consume(receipt) }
}

/// Visual feedback never owns a haptic or changes the hit target.
struct MugshotPressFeedback: ViewModifier {
    let isPressed: Bool
    var disabledOpacity: Double = 0.55
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var override
    func body(content: Content) -> some View {
        content
            .scaleEffect(isEnabled && isPressed && !(override ?? reduceMotion) ? 0.98 : 1)
            .opacity(!isEnabled ? disabledOpacity : isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: isPressed ? MugshotMotion.Timing.pressIn : MugshotMotion.Timing.pressOut), value: isPressed)
    }
}

struct MugshotQuietButtonStyle: ButtonStyle {
    var disabledOpacity: Double = 0.55
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(MugshotPressFeedback(isPressed: configuration.isPressed, disabledOpacity: disabledOpacity))
    }
}

struct MugshotSelectionPulse: ViewModifier {
    let value: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var override
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isMugshotTabActive) private var tabIsActive
    @State private var lastHandledValue: Bool?
    @State private var lifted = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(lifted ? 1.08 : 1)
            .task(id: "\(value):\(tabIsActive):\(scenePhase):\(override ?? reduceMotion)") {
                // Visibility changes never replay a consumed selection.
                guard let previous = lastHandledValue else { lastHandledValue = value; return }
                guard previous != value else { return }
                lastHandledValue = value
                guard !(override ?? reduceMotion), scenePhase == .active, tabIsActive else { return }
                withAnimation(.easeOut(duration: MugshotMotion.Timing.pulseRise)) { lifted = true }
                do { try await Task.sleep(for: .milliseconds(70)) } catch { lifted = false; return }
                guard scenePhase == .active, tabIsActive else { lifted = false; return }
                withAnimation(.easeOut(duration: MugshotMotion.Timing.pulseSettle)) { lifted = false }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { lifted = false }
            }
            .onChange(of: tabIsActive) { _, active in if !active { lifted = false } }
            .onDisappear { lifted = false }
    }
}

extension View {
    func mugshotSelectionPulse(_ value: Bool) -> some View {
        modifier(MugshotSelectionPulse(value: value))
    }
}

/// Pure formatting cannot promote a target to an actual measurement.
enum MugshotHomePreparationPresentation {
    static func recordedSummary(_ actuals: HomeAttemptActuals, method: HomeBrewMethod, ingredients: [HomeRecipeIngredient] = []) -> String? {
        var facts: [String] = []
        if let value = actuals.dose { facts.append("\(HomeRecipeContent.number(value)) g \(method.inputLabel.lowercased())") }
        if let value = actuals.output { facts.append("\(HomeRecipeContent.number(value)) \(method.outputUnit) \(method.outputLabel.lowercased())") }
        if let value = actuals.seconds { facts.append("\(HomeRecipeContent.number(value)) sec") }
        if let value = actuals.temperature { facts.append("\(HomeRecipeContent.number(value))°") }
        if !actuals.grind.isEmpty { facts.append("Grind: \(actuals.grind)") }
        if let value = actuals.batchMilliliters { facts.append("\(HomeRecipeContent.number(value)) ml batch") }
        if let value = actuals.servingMilliliters { facts.append("\(HomeRecipeContent.number(value)) ml serving") }
        if !actuals.dilution.isEmpty { facts.append("Dilution: \(actuals.dilution)") }
        for field in actuals.customFields where !field.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            facts.append("\(field.label): \(field.value)\(field.unit.isEmpty ? "" : " " + field.unit)")
        }
        for ingredient in actuals.ingredients {
            let name = ingredients.first(where: { $0.id == ingredient.ingredientID })?.name ?? "Ingredient"
            facts.append("\(HomeRecipeContent.number(ingredient.amount)) \(ingredient.unit) \(name.lowercased())")
        }
        return facts.isEmpty ? nil : facts.joined(separator: " · ")
    }
}

enum MugshotLibraryPresentation: Equatable {
    case loading, failure, empty, content
    static func resolve(isLoading: Bool, hasContent: Bool, hasError: Bool) -> Self {
        if hasContent { return .content }
        if isLoading { return .loading }
        if hasError { return .failure }
        return .empty
    }
}
