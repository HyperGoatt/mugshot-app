import SwiftUI

/// A single catalogue across the original stores, without copying draft data.
struct HomeDraftCatalogue {
    let sipDrafts: [SipDraft]
    let workspaceItems: [HomeDraftItem]
    var count: Int { sipDrafts.count + workspaceItems.count }

    init(sipDrafts: [SipDraft], workspace: HomeRecipeWorkspace, excludingSipID: UUID? = nil) {
        let removed = (workspace.deletions?.publicationDrafts ?? []).union(workspace.deletions?.publications ?? [])
        self.sipDrafts = sipDrafts.filter { $0.hasDraftWorthyUserContent && $0.id != excludingSipID && !removed.contains($0.id) }.sorted { $0.updatedAt > $1.updatedAt }
        let represented = sipDrafts.filter { $0.hasDraftWorthyUserContent && !removed.contains($0.id) }
        let makeIDs = Set(represented.flatMap { [$0.id, $0.launchContext.homeAttemptID].compactMap { $0 } })
        let sessionIDs = Set(represented.compactMap { $0.launchContext.homePreparationSessionID })
        workspaceItems = HomeDraftIndex.items(in: workspace).filter {
            !($0.attemptID.map(makeIDs.contains) ?? false) && !($0.sessionID.map(sessionIDs.contains) ?? false)
                && ($0.attemptID == nil || $0.attemptID != excludingSipID)
                && ($0.recipeDraftID.flatMap { id in workspace.recipeDrafts.first { $0.id == id } }?.content.hasMeaningfulDraftContent ?? true)
        }
    }
}

struct HomeDraftSummaryButton: View {
    let count: Int
    var accessibilityID = "home.drafts.open"
    let onOpen: () -> Void
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 13) {
                Image(systemName: "doc.on.doc").font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color.mugshotMint.opacity(0.32), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your drafts").font(.headline)
                    Text(count == 0 ? "A little room for your next idea" : "Pick up where you left off, or clear a little space")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 4)
                Text("\(count)").font(.subheadline.weight(.bold)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.espressoBrown).padding(14)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mugshotLine))
        }
        .buttonStyle(.plain).accessibilityIdentifier(accessibilityID)
        .accessibilityLabel("Your drafts, \(count) unfinished")
    }
}

struct HomeDraftManagementView: View {
    let ownerID: UUID?
    var includesSipDrafts = true
    var excludingSipID: UUID? = nil
    var onResumeSip: ((SipDraft) -> Void)? = nil
    var onResumeSession: ((UUID) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var workspace = HomeRecipeWorkspaceStore.shared
    @State private var sipDrafts: [SipDraft] = []
    @State private var protectedIDs: Set<UUID> = []
    @State private var canVerifyDiscard = false
    @State private var error: String?
    @State private var pendingDiscard: DiscardTarget?
    @State private var destination: Destination?

    private enum DiscardTarget { case sip(SipDraft), home(HomeDraftItem) }
    private enum Destination: Identifiable {
        case recipe(HomeRecipeEditorDraft), attempt(HomeAttemptRecord), session(UUID)
        var id: String {
            switch self {
            case .recipe(let draft): "recipe-\(draft.id)"
            case .attempt(let draft): "attempt-\(draft.id)"
            case .session(let id): "session-\(id)"
            }
        }
    }

    private var scope: LocalAccountScope { .forUserID(ownerID) }
    private var isCurrentOwner: Bool { authModel.authenticatedUser?.id == ownerID && workspace.scope == scope }
    private var catalogue: HomeDraftCatalogue {
        HomeDraftCatalogue(sipDrafts: includesSipDrafts ? sipDrafts : [], workspace: workspace.workspace, excludingSipID: excludingSipID)
    }
    private var makes: [HomeDraftItem] { catalogue.workspaceItems.filter { $0.kind != .recipe } }
    private var recipes: [HomeDraftItem] { catalogue.workspaceItems.filter { $0.kind == .recipe } }

    var body: some View {
        NavigationStack {
            HomeEditorCanvas(title: "Ideas can wait.", detail: "Your sips, recipes and in-progress makes. Keep what matters; let the rest go.", symbol: "doc.on.doc", eyebrow: "YOUR DRAFTS") {
                if let error { HomeEditorError(message: error) }
                if catalogue.count == 0 {
                    ContentUnavailableView("All caught up", systemImage: "checkmark.circle",
                        description: Text("Your next good sip starts whenever you’re ready."))
                        .accessibilityIdentifier("home.drafts.empty")
                }
                if !catalogue.sipDrafts.isEmpty {
                    HomeEditorSection("Sips", symbol: "cup.and.saucer") {
                        ForEach(catalogue.sipDrafts) { draft in sipRow(draft) }
                    }
                }
                if !makes.isEmpty {
                    HomeEditorSection("In the making", symbol: "timer") {
                        ForEach(makes) { item in homeRow(item) }
                    }
                }
                if !recipes.isEmpty {
                    HomeEditorSection("Recipe ideas", symbol: "book.pages") {
                        ForEach(recipes) { item in homeRow(item) }
                    }
                }
            }
            .navigationTitle("Your drafts").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                guard authModel.authenticatedUser?.id == ownerID else { return }
                workspace.activate(scope); reload()
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in
                if authModel.authenticatedUser?.id != ownerID { destination = nil; pendingDiscard = nil; dismiss() }
            }
            .sheet(isPresented: Binding(
                get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } }
            )) {
                SipDeleteConfirmationSheet(isDeleting: false, errorMessage: nil,
                    title: "Delete this draft?", deleteTitle: "Delete draft", cancelTitle: "Keep draft",
                    message: "Only this unfinished work is removed. Saved sips and recipes stay in your library.",
                    onDelete: discardPending)
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(item: $destination, onDismiss: { reload() }) { item in destinationView(item) }
        }
        .tint(Color.mugshotSageText)
        .disabled(!isCurrentOwner)
    }

    private func sipRow(_ draft: SipDraft) -> some View {
        let protected = !HomeJourneyControlPolicy.canDiscard(draft, in: scope,
            hasProtectedSubmission: protectedIDs.contains(draft.id))
        let setting = draft.context == .elsewhere ? draft.locationName.remoteTrimmedNonEmpty : nil
        return draftRow(title: draft.drinkName.remoteTrimmedNonEmpty ?? setting ?? "Untitled sip",
            detail: protected ? "Interrupted post · resume to recover" : "\(draft.context.rawValue) · saved \(draft.updatedAt.formatted(.relative(presentation: .named)))",
            symbol: draft.context.systemImage, identifier: "sip-\(draft.id)", locked: !canVerifyDiscard || protected,
            onResume: {
                guard isCurrentOwner, let fresh = SipDraftStore.shared.load(id: draft.id, in: scope)?.draft else {
                    error = "That draft could not be opened. Its files are still safe."; return
                }
                guard let onResumeSip else { error = "Open Your drafts from Journal to resume this sip."; return }
                dismiss(); onResumeSip(fresh)
            }, onDiscard: { pendingDiscard = .sip(draft) })
    }

    private func homeRow(_ item: HomeDraftItem) -> some View {
        let locked = !canVerifyDiscard || item.attemptID.map(protectedIDs.contains) == true
        return draftRow(title: item.title, detail: item.detail,
            symbol: item.kind == .recipe ? "book.pages" : "timer", identifier: item.id, locked: locked,
            onResume: { resume(item) }, onDiscard: { pendingDiscard = .home(item) })
    }

    private func draftRow(title: String, detail: String, symbol: String, identifier: String, locked: Bool,
                          onResume: @escaping () -> Void, onDiscard: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onResume) {
                HStack(spacing: 12) {
                    Image(systemName: symbol).font(.title3).foregroundStyle(Color.mugshotSageText)
                        .frame(width: 40, height: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline).foregroundStyle(Color.espressoBrown)
                        Text(detail).font(.caption).foregroundStyle(Color.secondaryText)
                    }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            }
            .buttonStyle(.plain).accessibilityIdentifier("home.drafts.resume.\(identifier)")
            .accessibilityLabel("Resume \(title)")
            if locked {
                Image(systemName: "lock.fill").foregroundStyle(Color.secondaryText).frame(width: 44, height: 44)
                    .accessibilityLabel("Resume to recover this post")
            } else {
                Button(action: onDiscard) { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .foregroundStyle(.red).accessibilityLabel("Delete \(title) draft")
                    .accessibilityIdentifier("home.drafts.delete.\(identifier)")
            }
        }
    }

    @ViewBuilder private func destinationView(_ item: Destination) -> some View {
        switch item {
        case .recipe(let draft):
            if draft.content.template == .drink {
                HomeDrinkBuilderSheet(store: workspace, draft: draft) { _ in destination = nil }
                    .environment(\.dynamicTypeSize, typeSize)
            } else {
                NavigationStack { HomeRecipeEditorView(store: workspace, draft: draft) { _ in destination = nil } }
                    .environment(\.dynamicTypeSize, typeSize)
            }
        case .attempt(let attempt):
            HomeRecipeExperienceView(ownerID: ownerID, initialAttempt: attempt, onShare: handoffSip)
                .environment(\.dynamicTypeSize, typeSize)
        case .session(let id):
            HomeRecipeExperienceView(ownerID: ownerID, initialSessionID: id, onShare: handoffSip)
                .environment(\.dynamicTypeSize, typeSize)
        }
    }

    private func handoffSip(_ draft: SipDraft) {
        guard isCurrentOwner, let onResumeSip else { return }
        destination = nil; dismiss(); onResumeSip(draft)
    }

    private func resume(_ item: HomeDraftItem) {
        guard isCurrentOwner else { return }
        switch item.kind {
        case .recipe:
            guard let id = item.recipeDraftID, let draft = workspace.workspace.recipeDrafts.first(where: { $0.id == id }) else { reload(); return }
            destination = .recipe(draft)
        case .attempt:
            guard let id = item.attemptID, let attempt = workspace.workspace.attemptDrafts.first(where: { $0.id == id }) else { reload(); return }
            destination = .attempt(attempt)
        case .session:
            guard let id = item.sessionID, let session = workspace.workspace.sessions.first(where: { $0.id == id }) else { reload(); return }
            if let onResumeSession { dismiss(); onResumeSession(id) }
            else {
                if session.currentPhase == .awaitingReflection,
                   !workspace.workspace.attemptDrafts.contains(where: { $0.id == session.attempt.id }) {
                    do { try workspace.saveAttemptDraft(session.attempt) }
                    catch { self.error = "This make could not be reopened. Its preparation is still safe."; return }
                }
                destination = .session(id)
            }
        }
    }

    private func discardPending() {
        guard isCurrentOwner, canVerifyDiscard, let target = pendingDiscard else { pendingDiscard = nil; return }
        pendingDiscard = nil
        do {
            switch target {
            case .sip(let draft):
                try SipDraftStore.shared.discard(draft, in: scope)
                let makeIDs = Set([draft.id, draft.launchContext.homeAttemptID].compactMap { $0 })
                for id in makeIDs where !workspace.workspace.attempts.contains(where: { $0.id == id }) {
                    if workspace.workspace.attemptDrafts.contains(where: { $0.id == id }) || workspace.workspace.sessions.contains(where: { $0.attempt.id == id }) {
                        try workspace.discardAttemptDraft(id: id, expectedScope: scope)
                    }
                }
                try workspace.mutate { state in
                    for index in state.attempts.indices where state.attempts[index].publicationDraftID == draft.id
                        && state.attempts[index].publicationStatus != .published && state.attempts[index].publicationStatus != .posting {
                        state.attempts[index].publicationDraftID = nil; state.attempts[index].publicationStatus = nil
                    }
                }
            case .home(let item):
                if let id = item.recipeDraftID { try workspace.discardRecipeDraft(id: id, expectedScope: scope) }
                else if let id = item.attemptID { try workspace.discardAttemptDraft(id: id, expectedScope: scope) }
            }
            Task { guard workspace.scope == scope else { return }; await workspace.synchronize() }
            error = nil
        } catch { self.error = "Couldn’t finish deleting this draft. Your other work is safe. Try again." }
        reload(preservingError: true)
    }

    private func reload(preservingError: Bool = false) {
        guard isCurrentOwner else { return }
        if !preservingError { error = nil }
        let report = SipDraftStore.shared.readReport(in: scope)
        sipDrafts = report.drafts
        canVerifyDiscard = report.isComplete
        if !report.isComplete { error = "Some drafts could not be opened. Their files were left untouched." }
        do {
            protectedIDs = try ownerID.map { Set(try PendingVisitSubmissionStore.shared.loadAll(userId: $0).map(\.id)) } ?? []
            if report.isComplete {
                let queued = (workspace.workspace.deletions?.publicationDrafts ?? []).union(workspace.workspace.deletions?.publications ?? [])
                for draft in report.drafts where queued.contains(draft.id) {
                    guard HomeJourneyControlPolicy.canDiscard(draft, in: scope, hasProtectedSubmission: protectedIDs.contains(draft.id)) else {
                        self.error = "Some deleted work still needs posting recovery before its local cleanup can finish."
                        continue
                    }
                    do { try SipDraftStore.shared.discard(draft, in: scope) }
                    catch { self.error = "A deleted draft is still being cleaned up. Your other work is safe; try again." }
                }
            }
        } catch {
            canVerifyDiscard = false
            self.error = "Posting work could not be checked. Resume an interrupted sip to recover it; your drafts are safe."
        }
    }
}
