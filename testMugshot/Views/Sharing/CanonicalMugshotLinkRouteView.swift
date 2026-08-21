import SwiftUI

/// Resolves an opaque share capability and hands the visit to the same post
/// screen used everywhere else in the app. This view never renders a second
/// representation of a Mugshot.
struct CanonicalMugshotLinkRouteView: View {
    let route: MugshotSharedLinkRoute
    let currentUserID: UUID?
    @ObservedObject var dataManager: DataManager

    @Environment(\.dismiss) private var dismiss
    @State private var visitID: UUID?
    @State private var summary: RemoteVisitSummary?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let visitID, let summary {
                RemoteVisitDetailView(
                    visitId: visitID,
                    initialSummary: summary,
                    currentUserId: currentUserID,
                    dataManager: dataManager,
                    presentationMode: .postSave
                )
            } else if isLoading {
                ProgressView("Opening Mugshot…")
                    .tint(.mugshotSage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.creamWhite)
            } else {
                ContentUnavailableView(
                    "This Mugshot is not available.",
                    systemImage: "cup.and.saucer",
                    description: Text("It may have been removed or its audience may have changed.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.creamWhite)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .task(id: route.slug) { await resolve() }
    }

    @MainActor
    private func resolve() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let shareService = MugshotShareLinkService(client: client)
            guard let resolvedID = try await shareService.resolveVisitID(slug: route.slug) else {
                visitID = nil
                summary = nil
                return
            }
            let detail = try await VisitService(client: client).fetchVisitDetail(
                visitId: resolvedID,
                currentUserId: currentUserID
            )
            visitID = resolvedID
            summary = detail.summary
            await shareService.recordPublicEvent(slug: route.slug, eventName: "app_open")
        } catch {
            visitID = nil
            summary = nil
        }
    }
}
