import Combine
import Foundation

/// Presentation-independent state for every sip capture surface.
///
/// Long Form and Guided render the same model so changing the DEBUG flag only
/// changes presentation. Future entry points can construct the same `SipDraft`
/// without depending on a particular screen hierarchy.
@MainActor
final class SipComposerModel: ObservableObject {
    @Published var draft: SipDraft

    init(draft: SipDraft) {
        self.draft = draft
    }

    func refreshDrinkAnalysis() {
        guard draft.drinkName.remoteTrimmedNonEmpty != nil else {
            draft.drinkAnalysis = nil
            return
        }
        draft.refreshDrinkAnalysis()
    }
}
