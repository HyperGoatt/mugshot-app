import SwiftUI

/// A private Home attempt rendered by the same post-detail surface as a cafe sip.
/// The workspace remains its source of truth until an optional publication exists.
struct HomeAttemptCanonicalDetailView: View {
    let attemptID: UUID
    let onShare: () -> Void
    let onMakeAgain: () -> Void
    let onDone: () -> Void
    var onHistory: (() -> Void)? = nil
    var onLogServing: (() -> Void)? = nil

    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var photoIndex = 0
    @State private var comment = ""
    @State private var toolbarProgress: CGFloat = 0
    @State private var viewer: SipDetailPhotoViewerPresentation?
    @State private var showsActions = false
    @FocusState private var commentFocused: Bool

    private var attempt: HomeAttemptRecord? {
        store.workspace.attempts.first { $0.id == attemptID }
    }

    var body: some View {
        Group {
            if let attempt {
                let presentation = SipDetailPresentationAdapter.homeAttempt(
                    attempt,
                    authorName: authModel.profile?.displayName ?? "You",
                    username: authModel.profile?.username ?? "you",
                    resolveLinked: { store.workspace.version($0)?.content }
                )
                SipDetailScreen(
                    presentation: presentation,
                    selectedPhotoIndex: $photoIndex,
                    commentText: $comment,
                    toolbarProgress: $toolbarProgress,
                    commentFocus: $commentFocused,
                    isWorking: false,
                    statusMessage: store.errorMessage
                        ?? (!attempt.pendingKeptIngredientIDs.isEmpty
                            ? "Sip saved · Recipe change pending"
                            : store.workspace.pendingOperationID == nil ? nil : "Saved here · Sync pending"),
                    mentionSuggestions: [],
                    composerMentionTokens: [],
                    onAction: { action in
                        switch action {
                        case .share: onShare()
                        case .repeatSip: onMakeAgain()
                        case .more: showsActions = true
                        default: break
                        }
                    },
                    onSubmitComment: {},
                    onReply: { _ in },
                    onCommentAction: { _, _ in },
                    onCancelReply: {},
                    onSelectMention: { _ in },
                    onPhotoTap: { index in
                        guard presentation.content.photos.indices.contains(index) else { return }
                        viewer = SipDetailPhotoViewerPresentation(
                            photos: presentation.content.photos,
                            initialIndex: index,
                            drinkName: presentation.content.drinkName,
                            locationName: "Home"
                        )
                    },
                    onRecipeAction: { _ in },
                    onTaggedAccount: { _ in },
                    onCommentMention: { _ in },
                    onRemoveOwnTag: {}
                )
                .confirmationDialog("Your Home sip", isPresented: $showsActions) {
                    Button("Make again", action: onMakeAgain)
                    if !attempt.pendingKeptIngredientIDs.isEmpty {
                        Button("Retry keeping recipe changes") {
                            do {
                                try store.applyKeptIngredientChanges(attemptID: attempt.id)
                                store.errorMessage = nil
                                Task { await store.synchronize() }
                            } catch {
                                store.errorMessage = "Your sip is safe. Recipe change needs attention: \(error.localizedDescription)"
                            }
                        }
                    }
                    if attempt.batchID != nil, attempt.batchSourceAttemptID == nil,
                       let onLogServing {
                        Button("Log a serving from this batch", action: onLogServing)
                    }
                    Button("Share", action: onShare)
                    if let onHistory { Button("History", action: onHistory) }
                    Button("Done", action: onDone)
                }
            } else {
                ContentUnavailableView("Sip unavailable", systemImage: "cup.and.saucer")
            }
        }
        .background(Color.creamWhite)
        .fullScreenCover(item: $viewer) { SipDetailPhotoViewer(presentation: $0) }
    }
}
