#if DEBUG
import SwiftUI

/// Fictional fixtures may run only in the isolated flow app, never Luna QA.
struct HomeDraftControlsPreviewHost: View {
    var showsProfiles = false
    @State private var ready = false
    @State private var resumeName: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let error { ContentUnavailableView(error, systemImage: "lock") }
            else if let resumeName {
                Text("Resumed \(resumeName)").accessibilityIdentifier("home.fixture.resumed")
            } else if ready {
                if showsProfiles {
                    HomeLibraryView(ownerID: nil, initialSection: .preferences, onComposeDraft: { resumeName = $0.drinkName }, includesSipDrafts: true)
                } else {
                    HomeDraftManagementView(ownerID: nil, onResumeSip: { resumeName = $0.drinkName },
                        onResumeSession: { _ in resumeName = "Matcha practice" })
                }
            } else { ProgressView("Preparing fictional Home controls…") }
        }
        .task {
            guard MugshotLaunchEnvironment.isUITesting, Bundle.main.bundleIdentifier == "co.mugshot.app.homeqa" else {
                error = "Isolated flow app required"; return
            }
            guard !ready else { return }
            do {
                let workspace = HomeRecipeWorkspaceStore.shared
                workspace.activate(.guest)
                let sipID = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!
                if !workspace.workspace.attemptDrafts.contains(where: { $0.id == sipID }) {
                    let sip = SipDraft(id: sipID, context: .home, drinkName: "Iced latte")
                    _ = try SipDraftStore.shared.save(sip, images: [], in: .guest)
                    let duplicate = HomeAttemptRecord(id: sipID, name: "Iced latte")
                    try workspace.saveAttemptDraft(duplicate)
                    try workspace.saveSession(HomePreparationSession(attempt: duplicate))
                    let matcha = HomeAttemptRecord(id: UUID(uuidString: "00000000-0000-4000-8000-000000000502")!, name: "Matcha practice")
                    try workspace.saveAttemptDraft(matcha)
                    try workspace.saveSession(HomePreparationSession(attempt: matcha))
                    try workspace.saveDraft(HomeRecipeEditorDraft(id: UUID(uuidString: "00000000-0000-4000-8000-000000000503")!,
                        content: HomeRecipeContent(name: "Vanilla syrup", template: .component, method: .syrupSauce)))
                    let library = HomeLibraryStore.shared
                    let gear = EquipmentProfile(nickname: "Everyday kettle")
                    _ = try library.upsert(gear, in: .guest)
                    _ = try library.upsertHomeProfile(HomePlaceProfile(name: "Kitchen counter", equipmentIDs: [gear.id]), in: .guest)
                }
                ready = true
            } catch { self.error = "Fictional fixture setup failed" }
        }
    }
}
#endif
