import SwiftUI
import UIKit

/// One completed transaction inside its existing destination. Result copy and
/// navigation are available from the first frame; only the acknowledgment moves.
struct MugshotSaveReceiptView: View {
    let receipt: MugshotSaveReceipt
    let detail: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    @Environment(\.mugshotFeedbackOwnerID) private var activeOwnerID
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isMugshotTabActive) private var tabIsActive
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var progress: CGFloat = 1

    private var reduced: Bool { motionOverride ?? reduceMotion }
    private var isCurrent: Bool {
        receipt.ownerID == activeOwnerID && scenePhase == .active && tabIsActive
    }
    private var playbackID: String {
        "\(receipt.id):\(activeOwnerID?.uuidString ?? "guest"):\(scenePhase):\(tabIsActive):\(reduced):\(typeSize)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if receipt.isExpressive && !typeSize.isAccessibilitySize {
                MugsyCompletionMoment(progress: progress)
                    .frame(width: 92, height: 100)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 7) {
                Label(receipt.title, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.espressoBrown)
                Text("\(receipt.drinkName), remembered.")
                    .font(.subheadline)
                    .foregroundStyle(Color.espressoBrown)
                Label(detail, systemImage: "book.closed.fill")
                    .font(.caption)
                    .foregroundStyle(Color.mugshotSageText)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mugshotMint.opacity(0.24), in: RoundedRectangle(cornerRadius: 20))
        .opacity(receipt.ownerID == activeOwnerID ? 1 : 0)
        .accessibilityHidden(receipt.ownerID != activeOwnerID)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mugshot.saveReceipt")
        .task(id: playbackID) { await acknowledge() }
        .onDisappear { settleImmediately() }
    }

    @MainActor
    private func acknowledge() async {
        settleImmediately()
        guard isCurrent,
              MugshotCompletionFeedback.shared.consume(receipt, activeOwnerID: activeOwnerID) else { return }
        UIAccessibility.post(notification: .announcement, argument: "\(receipt.title). \(receipt.drinkName). \(detail)")
        let expressive = receipt.isExpressive && !typeSize.isAccessibilitySize
        for beat in MugshotCompletionPlan.beats(expressive: expressive, reduceMotion: reduced) {
            beat.haptic.prepare()
        }
        if expressive && !reduced {
            progress = 0
            do { try await Task.sleep(for: .milliseconds(34)) }
            catch { settleImmediately(); return }
            guard !Task.isCancelled, isCurrent else { settleImmediately(); return }
            withAnimation(.linear(duration: MugshotCompletionPlan.duration)) { progress = 1 }
        }
        await MugshotCompletionPlan.perform(
            beats: MugshotCompletionPlan.beats(expressive: expressive, reduceMotion: reduced),
            isCurrent: { isCurrent },
            emit: { $0.play() }
        )
        if Task.isCancelled { settleImmediately() }
    }

    private func settleImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = 1 }
    }
}

/// Per-frame vector sampling interpolates the whole rig, including custom paths.
/// No video, ambient timer, full-character hop or offscreen playback is involved.
struct MugsyCompletionMoment: View, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let pose = MugsyCompletionPose.sample(progress)
        let pouring = MugsyCompletionPose.smooth(progress, 0.08, 0.18)
            * (1 - MugsyCompletionPose.smooth(progress, 0.40, 0.52))
        ZStack(alignment: .topLeading) {
            MugsyModelView(
                configuration: MugsyModelConfiguration(
                    expression: progress < 0.48 ? .focused : .delighted,
                    armPose: .relaxed,
                    legArticulation: .init(bendProgress: pose.bend, weightShift: pose.wave * 0.3),
                    gaze: UnitPoint(x: 0.5, y: pose.gazeY),
                    liquid: .coffee(fillProgress: pose.fill, steamIntensity: pose.fill * 0.32)
                ),
                presentation: MugsyModelPresentation(waveLift: pose.wave, waveSwing: pose.swing,
                                                     eyeOpenness: pose.eyeOpenness)
            )
            GeometryReader { geometry in
                let rimY = geometry.size.height * (91 + pose.bend * 20) / 500
                Capsule()
                    .fill(MugshotDrinkAppearance.coffee.liquidColor)
                    .frame(width: 2.5, height: rimY)
                    .position(x: geometry.size.width * 205 / 500, y: rimY / 2)
                    .opacity(pouring)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
