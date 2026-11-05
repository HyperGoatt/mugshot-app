#if DEBUG
import SwiftUI

/// Fictional confirmed-result fixtures. No publication or backend mutation.
struct PostedResultPreviewHost: View {
    private let owner = UUID(uuidString: "00000000-0000-4000-8000-000000000061")!
    @State private var presentsResult = true
    @State private var seesPost = false
    @State private var operation = UUID()
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    private var privateSave: Bool { ProcessInfo.processInfo.arguments.contains("--ui-testing-private-result") }
    private var context: String {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-result-cafe") { return "Maple Cafe" }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-result-elsewhere") { return "A little coffee break" }
        return "Home"
    }
    private var receipt: MugshotSaveReceipt {
        .init(id: operation, ownerID: owner,
              drinkName: "Cinnamon latte", isExpressive: true, audience: privateSave ? nil : .friends)
    }
    private var summary: LogASipV3PassportSummary {
        .init(visitID: receipt.id, visibility: privateSave ? .private : .friends,
              isOwner: true, isRemote: false, displayName: "Jamie", authorUsername: "fixture",
              drinkName: "Cinnamon latte", contextName: context, createdAt: .now,
              sipScore: 4, contextScore: nil, mugshotScore: 4, identityTitle: "A coffee moment",
              identityDetail: "", memoryCount: 1, criteria: [], evidence: [],
              publicCaption: "A cozy little coffee break.", photoImages: [], coverImage: nil)
    }
    var body: some View {
        Group {
            if privateSave { hub }
            else {
                Text("Completed sip")
                    .fullScreenCover(isPresented: $presentsResult) {
                        if seesPost {
                            VStack(spacing: 24) {
                                Text("Your posted cinnamon latte").font(.largeTitle)
                                    .accessibilityIdentifier("mugshot.fixture.post")
                                Button("Done") { presentsResult = false }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.creamWhite)
                        } else { hub }
                    }
            }
        }
        .environment(\.mugshotFeedbackOwnerID, owner)
    }
    private var hub: some View {
        MugshotShareHubView(summary: summary, receipt: receipt, isOpeningMugshot: false, statusMessage: nil,
            onViewMugshot: { seesPost = true }, onViewPassport: {},
            onFinish: { presentsResult = false }, onStartAnother: nil)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.mugshotReduceMotionOverride, motionOverride)
    }
}
#endif
