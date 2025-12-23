//
//  AnimationCompletion.swift
//  testMugshot
//
//  Adapted from ConcentricOnboarding library
//  Restructured for Swift 6 compatibility - uses ViewModifier instead of AnimatableModifier
//

import SwiftUI

/// A view modifier that detects when an animated value reaches a target value.
/// This is a Swift 6-compliant replacement for AnimatableModifier.
/// It uses onChange to detect value changes and fires completion when the target is reached.
struct AnimationCompletionObserverModifier<Value: Equatable>: ViewModifier {
    let observedValue: Value
    let targetValue: Value
    let completion: () -> Void
    
    @State private var hasTriggered = false
    
    init(observedValue: Value, targetValue: Value, completion: @escaping () -> Void) {
        self.observedValue = observedValue
        self.targetValue = targetValue
        self.completion = completion
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: observedValue) { oldValue, newValue in
                // Check if we've reached (or passed) the target value
                // Reset hasTriggered when value moves away from target
                if newValue == targetValue && !hasTriggered {
                    hasTriggered = true
                    // Small delay to ensure animation frame has completed
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps
                        completion()
                    }
                } else if newValue != targetValue {
                    // Reset trigger flag when value moves away from target
                    hasTriggered = false
                }
            }
            .onAppear {
                // Check if already at target on appear
                if observedValue == targetValue && !hasTriggered {
                    hasTriggered = true
                    completion()
                }
            }
    }
}

extension View {
    /// Detects when an animated value reaches a target value and calls a completion handler.
    /// This is a Swift 6-compliant replacement that avoids AnimatableModifier.
    ///
    /// - Parameters:
    ///   - value: The value to observe (should be animated using `withAnimation`)
    ///   - completion: The closure to call when the animation reaches the target value
    ///
    /// Note: This version tracks when the value stabilizes at the target, which works
    /// for discrete target values. For continuous animations, consider using the version
    /// that explicitly specifies a target value.
    func onAnimationCompleted<Value: Equatable & VectorArithmetic>(
        for value: Value,
        completion: @escaping () -> Void
    ) -> some View {
        // For VectorArithmetic types without explicit target, we use a debounce approach
        // to detect when the value stabilizes (indicating animation completion)
        modifier(AnimationCompletionDebounceModifier(observedValue: value, completion: completion))
    }
}

/// A modifier that debounces value changes to detect when an animation completes.
/// Used when no specific target value is provided - it detects when the value stabilizes.
struct AnimationCompletionDebounceModifier<Value: Equatable & VectorArithmetic>: ViewModifier {
    let observedValue: Value
    let completion: () -> Void
    
    @State private var previousValue: Value
    @State private var debounceTask: Task<Void, Never>?
    @State private var hasCompleted = false
    
    init(observedValue: Value, completion: @escaping () -> Void) {
        self.observedValue = observedValue
        self.completion = completion
        _previousValue = State(initialValue: observedValue)
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: observedValue) { oldValue, newValue in
                // Cancel any pending debounce task
                debounceTask?.cancel()
                
                // Reset completion flag when value changes
                if newValue != previousValue {
                    hasCompleted = false
                }
                
                // If value changed, start a debounce timer
                if newValue != previousValue {
                    debounceTask = Task { @MainActor in
                        // Wait for animation to complete (enough time for interpolation to finish)
                        // Two frames should be sufficient to detect when animation stops
                        try? await Task.sleep(nanoseconds: 32_000_000) // ~2 frames at 60fps
                        if !Task.isCancelled {
                            // Check if value is still the same (has stabilized)
                            if newValue == observedValue && !hasCompleted {
                                hasCompleted = true
                                completion()
                            }
                        }
                    }
                }
                
                previousValue = newValue
            }
    }
}
