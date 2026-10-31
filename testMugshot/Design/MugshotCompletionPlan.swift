import SwiftUI

private struct MugshotFeedbackOwnerKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var mugshotFeedbackOwnerID: UUID? {
        get { self[MugshotFeedbackOwnerKey.self] }
        set { self[MugshotFeedbackOwnerKey.self] = newValue }
    }
}

enum MugshotFeedbackPolicy {
    static func shouldPlay(isEnabled: Bool, appIsActive: Bool) -> Bool {
        isEnabled && appIsActive
    }
}

struct MugshotCompletionBeat: Equatable {
    let milliseconds: Int
    let haptic: MugshotHaptic
}

/// Absolute beat times and the vector timeline share one clock. UIKit provides
/// device fallbacks without an engine or a retained audio session.
enum MugshotCompletionPlan {
    static let duration = 1.32

    static func beats(expressive: Bool, reduceMotion: Bool) -> [MugshotCompletionBeat] {
        guard expressive && !reduceMotion else {
            return [.init(milliseconds: 0, haptic: .success)]
        }
        return [.init(milliseconds: 180, haptic: .softImpact),
                .init(milliseconds: 680, haptic: .success)]
    }

    @MainActor
    static func perform(
        beats: [MugshotCompletionBeat],
        isCurrent: () -> Bool,
        sleep: (Int) async throws -> Void = { try await Task.sleep(for: .milliseconds($0)) },
        emit: (MugshotHaptic) -> Void
    ) async {
        var elapsed = 0
        for beat in beats {
            guard !Task.isCancelled, isCurrent() else { return }
            do { try await sleep(max(0, beat.milliseconds - elapsed)) }
            catch { return }
            guard !Task.isCancelled, isCurrent() else { return }
            emit(beat.haptic)
            elapsed = beat.milliseconds
        }
    }
}

/// Editable numeric rig curves. Both feet keep their canonical anchors;
/// knees/body weight, gaze, eyelids and the waving hand articulate independently.
struct MugsyCompletionPose: Equatable {
    let fill: CGFloat
    let bend: CGFloat
    let wave: CGFloat
    let swing: CGFloat
    let eyeOpenness: CGFloat
    let gazeY: CGFloat

    static func sample(_ progress: CGFloat) -> Self {
        let p = progress.isFinite ? progress.mugshotClamped(to: 0...1) : 1
        let wave = smooth(p, 0.42, 0.62) * (1 - smooth(p, 0.78, 1))
        return Self(
            fill: 0.16 + 0.84 * smooth(p, 0.08, 0.52),
            bend: pulse(p, 0.22, 0.94) * 0.48,
            wave: wave,
            swing: sin(p * .pi * 5) * wave * 12,
            eyeOpenness: 1 - pulse(p, 0.13, 0.23) * 0.9,
            gazeY: 0.12 + smooth(p, 0.30, 0.68) * 0.38
        )
    }

    static func smooth(_ p: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        let t = ((p - start) / (end - start)).mugshotClamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }

    private static func pulse(_ p: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard p > start, p < end else { return 0 }
        return sin((p - start) / (end - start) * .pi)
    }
}
