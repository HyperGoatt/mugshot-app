import SwiftUI
import UIKit

/// A transaction-scoped acknowledgment within the existing destination.
struct MugshotSaveReceiptView: View {
    let receipt: MugshotSaveReceipt
    let detail: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isMugshotTabActive) private var tabIsActive
    @State private var nod: CGFloat = 0
    @State private var cradles = false

    private var configuration: MugsyModelConfiguration {
        var value = MugsyModelConfiguration(expression: .delighted, prop: .journalNotebook)
        value.armPose = cradles ? .cradling : .writing
        value.gaze = nod > 0 ? .bottom : .center
        value.legArticulation = MugsyLegArticulation(bendProgress: nod * 0.25, weightShift: 0)
        return value
    }

    var body: some View {
        HStack(spacing: 12) {
            if receipt.isExpressive {
                MugsyModelView(configuration: configuration)
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(nod * 1.5), anchor: .bottom)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.mugshotSageText)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.title).font(.subheadline.weight(.bold))
                Text("\(receipt.drinkName), remembered.")
                    .font(.subheadline)
                    .foregroundStyle(Color.espressoBrown)
                Text(detail).font(.caption).foregroundStyle(Color.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.mugshotMint.opacity(0.24), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mugshot.saveReceipt")
        .task(id: "\(receipt.id):\(scenePhase):\(tabIsActive):\(motionOverride ?? reduceMotion)") {
            guard scenePhase == .active, tabIsActive, MugshotCompletionFeedback.shared.consume(receipt) else { return }
            MugshotHaptic.success.play()
            UIAccessibility.post(notification: .announcement, argument: "\(receipt.title). \(receipt.drinkName). \(detail)")
            guard receipt.isExpressive, !(motionOverride ?? reduceMotion) else { cradles = true; return }
            defer { nod = 0; cradles = true }
            withAnimation(.easeOut(duration: MugshotMotion.Timing.receiptLift)) { cradles = true; nod = 1 }
            do { try await Task.sleep(for: .milliseconds(MugshotMotion.Timing.receiptHoldMilliseconds)) } catch { return }
            withAnimation(.easeInOut(duration: MugshotMotion.Timing.receiptReturn)) { nod = 0 }
            do { try await Task.sleep(for: .milliseconds(MugshotMotion.Timing.receiptRestMilliseconds)) } catch { return }
        }
        .onDisappear { nod = 0 }
    }
}
