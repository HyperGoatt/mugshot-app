import SwiftUI

struct ReflectionReminderRouteView: View {
    let route: PendingReflectionReminderRoute
    @ObservedObject var dataManager: DataManager
    let onFinished: () -> Void

    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var summary: RemoteVisitSummary?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let summary {
                    RemoteVisitDetailView(
                        visitId: summary.id,
                        initialSummary: summary,
                        currentUserId: route.accountID,
                        dataManager: dataManager
                    )
                } else if isLoading {
                    ProgressView("Opening your memory…")
                } else {
                    ContentUnavailableView(
                        "Memory unavailable",
                        systemImage: "book.closed",
                        description: Text(errorMessage ?? "This MugShot is no longer available to this account.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { finish() }
                }
            }
        }
        .task(id: route.id) { await load() }
        .onDisappear(perform: onFinished)
    }

    @MainActor
    private func load() async {
        guard authModel.authenticatedUser?.id == route.accountID,
              case .memory(let visitID) = route.destination else {
            isLoading = false
            errorMessage = "Sign in to the account that owns this memory."
            return
        }
        do {
            summary = try await VisitService(
                client: try SupabaseClientProvider.shared.client()
            ).fetchOwnedVisitSummary(visitId: visitID, userId: route.accountID)
            guard summary?.visit.uploadState == VisitUploadState.complete.rawValue else {
                summary = nil
                errorMessage = "This MugShot has not finished publishing."
                isLoading = false
                return
            }
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
        isLoading = false
    }

    private func finish() {
        onFinished()
        dismiss()
    }
}
