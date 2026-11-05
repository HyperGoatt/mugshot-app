import SwiftUI

/// Sharing starts from a saved attempt, not from its private reflection form.
/// The same visible values below are the only values handed to publication.
struct HomeAttemptPostSurface: View {
    @Binding var draft: SipDraft
    let photoImages: [UIImage]
    let isSaving: Bool
    let isRecoveryLocked: Bool
    let statusMessage: String?
    let onPublish: () -> Void
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var selection: HomeLinkedRecipeSheet?

    private var isCurrentOwner: Bool {
        authModel.authenticatedUser?.id == draft.ownerUserID && store.scope == .forUserID(draft.ownerUserID)
    }

    var body: some View {
        HomeEditorCanvas(title: "Ready to share?", detail: "Your private journal keeps the full story. Choose the parts you want to share.",
                         symbol: "square.and.arrow.up", eyebrow: "YOUR HOME SIP") {
            previewCard
            HomeEditorSection("A few words", symbol: "text.bubble") {
                HomeEditorField("Caption", text: $draft.socialCaption, placeholder: "What made this sip yours?", axis: .vertical)
            }.disabled(isRecoveryLocked)
            audienceCard.disabled(isRecoveryLocked)
            attachmentsCard.disabled(isRecoveryLocked)
            if let statusMessage { Text(statusMessage).font(.callout).foregroundStyle(Color.secondaryText) }
            if let error = SipCaptionPolicy.validationError(for: draft.socialCaption) {
                HomeEditorError(message: error.localizedDescription)
            }
        }
        .disabled(!isCurrentOwner)
        .navigationTitle("Share your make").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 7) {
                Button(isSaving ? "Posting…" : isRecoveryLocked ? "Retry post" : "Post") {
                    guard isCurrentOwner, !isSaving else { return }
                    onPublish()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || !isCurrentOwner || draft.visibility == .private
                    || SipCaptionPolicy.validationError(for: draft.socialCaption) != nil)
                .accessibilityIdentifier("home.legacyShare.post")
                Text("Private notes and next-time notes stay in your journal.")
                    .font(.caption).foregroundStyle(Color.secondaryText).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.vertical, 10).background(Color.creamWhite)
        }
        .onChange(of: draft.visibility) { _, _ in draft.launchContext.homeRecipeAttachments = [] }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in selection = nil }
        .sheet(item: $selection) { selected in
            HomeRecipeSharingConsent(reference: selected.reference, audience: draft.visibility, ownerID: draft.ownerUserID) { attachment in
                guard isCurrentOwner, !isRecoveryLocked else { selection = nil; return }
                var attachments = draft.launchContext.homeRecipeAttachments ?? []
                attachments.removeAll { $0.id == attachment.id }
                attachments.append(attachment)
                draft.launchContext.homeRecipeAttachments = attachments
                selection = nil
            }
        }
    }

    private var previewCard: some View {
        HomeEditorSection("Your sip", symbol: "cup.and.saucer") {
            if photoImages.isEmpty {
                Image(systemName: "mug").font(.system(size: 58)).foregroundStyle(Color.mugshotSageText)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(Color.mugshotMint.opacity(0.24), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("No photo")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoImages.indices, id: \.self) { index in
                            Image(uiImage: photoImages[index]).resizable().scaledToFill()
                                .frame(width: photoImages.count == 1 ? 270 : 220, height: 270).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .accessibilityLabel("Sip photo \(index + 1) of \(photoImages.count)")
                        }
                    }
                }
            }
            Text(draft.drinkName).font(.system(.title2, design: .serif).weight(.semibold))
            Label(draft.locationName.remoteTrimmedNonEmpty ?? "Home", systemImage: "house.fill")
                .font(.subheadline).foregroundStyle(Color.mugshotSageText)
            if draft.overallScore > 0 {
                Label("\(HomeRecipeContent.number(draft.overallScore)) / 5", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
            }
            if !draft.socialCaption.isEmpty { Text(draft.socialCaption).font(.subheadline) }
            Label("Your journal entry is saved privately", systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(Color.secondaryText)
        }
    }

    private var audienceCard: some View {
        HomeEditorSection("Who can see this?", symbol: "person.2") {
            audienceChoice(.friends, title: "Friends", detail: "Share with your Mugshot friends.", symbol: "person.2")
            audienceChoice(.everyone, title: "Everyone", detail: "Make this post visible beyond your friends.", symbol: "globe.americas")
        }
    }

    private func audienceChoice(_ audience: VisitVisibility, title: String, detail: String, symbol: String) -> some View {
        Button { draft.visibility = audience } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 28).foregroundStyle(Color.mugshotSageText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Image(systemName: draft.visibility == audience ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color.mugshotSageText)
            }
            .frame(minHeight: 54).padding(12)
            .background(draft.visibility == audience ? Color.mugshotMint.opacity(0.3) : Color.creamWhite,
                in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.visibility == audience ? .isSelected : [])
    }

    private var attachmentsCard: some View {
        HomeEditorSection("Recipe instructions", symbol: "book.pages",
                          detail: "Attach only what you want to share. Linked components keep their own privacy.") {
            ForEach(store.workspace.recipes.filter { !$0.isArchived }) { recipe in
                if let current = recipe.current {
                    Menu {
                        ForEach(recipe.versions.reversed()) { version in
                            Button("Version \(version.number)") {
                                selection = HomeLinkedRecipeSheet(reference: HomeRecipeReference(recipeID: recipe.id, versionID: version.id))
                            }
                        }
                    } label: {
                        Label(current.content.name, systemImage: "plus.circle").frame(minHeight: 44)
                    }
                }
            }
            ForEach(draft.launchContext.homeRecipeAttachments ?? []) { attachment in
                HStack {
                    Text(store.workspace.recipes.flatMap(\.versions).first { $0.id == attachment.versionID }?.content.name ?? "Recipe")
                    Spacer()
                    Button("Remove", role: .destructive) { draft.launchContext.homeRecipeAttachments?.removeAll { $0.id == attachment.id } }
                        .frame(minHeight: 44)
                }
            }
            if (draft.launchContext.homeRecipeAttachments ?? []).isEmpty {
                Label("No instructions attached", systemImage: "lock")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
    }
}

struct HomeRecipeSharingConsent: View {
    let reference: HomeRecipeReference
    let audience: VisitVisibility
    let ownerID: UUID?
    let onConfirm: (HomeRecipePostAttachment) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var projection: RemoteVisitRecipeProjection?
    @State private var error: String?
    @State private var permissionRequestID = UUID()
    private var isCurrentOwner: Bool {
        ownerID != nil && authModel.authenticatedUser?.id == ownerID
            && HomeRecipeWorkspaceStore.shared.scope == .forUserID(ownerID)
    }
    private var canConfirm: Bool {
        isCurrentOwner && projection != nil && (audience != .everyone || ["original", "adapted"].contains(projection?.sourceKindValue ?? ""))
    }

    var body: some View {
        NavigationStack {
            HomeEditorCanvas(title: "Share the instructions?", detail: "Choose whether people can see how this recipe is made.",
                             symbol: "book.pages", eyebrow: "RECIPE PRIVACY") {
                if let projection {
                    HomeEditorSection(projection.recipeName, symbol: "book.pages") {
                        LabeledContent("Recipe version", value: "\(projection.versionNumber)")
                        LabeledContent("Current audience", value: projection.visibilityValue.capitalized)
                        LabeledContent("Post audience", value: projection.visibilityValue == "everyone" ? "Everyone (unchanged)" : audience.rawValue)
                        Text("The recipe audience changes when posting completes. Linked component instructions keep their own privacy.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                        if audience == .everyone {
                            Text("People may save and adapt this version. Their saved copies can remain if you change visibility later.")
                                .font(.caption).foregroundStyle(Color.secondaryText)
                        }
                    }
                    if !canConfirm {
                        HomeEditorSection("Keep this source private", symbol: "lock") {
                            Text("This source cannot share instructions with Everyone. Choose Friends or leave it unattached.")
                                .font(.subheadline).foregroundStyle(Color.secondaryText)
                        }
                    }
                } else if let error {
                    HomeEditorError(message: error)
                    Button("Retry permission check", systemImage: "arrow.clockwise") {
                        self.error = nil; permissionRequestID = UUID()
                    }
                    .frame(minHeight: 44).disabled(!isCurrentOwner)
                }
                else { ProgressView("Checking recipe permissions…").frame(maxWidth: .infinity).padding(.vertical, 30) }
            }
            .navigationTitle("Recipe instructions").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
            .safeAreaInset(edge: .bottom) {
                if canConfirm {
                    Button("Confirm and attach") {
                        guard canConfirm else { return }
                        onConfirm(HomeRecipePostAttachment(versionID: reference.versionID,
                            audience: audience.supabaseValue, acknowledgesSharing: true))
                    }
                    .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.creamWhite)
                }
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in if !isCurrentOwner { dismiss() } }
            .task(id: permissionRequestID) {
                guard let ownerID, isCurrentOwner else { error = "Sign in before attaching recipe instructions."; return }
                let store = HomeRecipeWorkspaceStore.shared
                await store.synchronize()
                guard !Task.isCancelled, isCurrentOwner else { return }
                do {
                    let client = try SupabaseClientProvider.shared.client()
                    let value = try await VisitService(client: client).fetchRecipeProjection(recipeVersionId: reference.versionID)
                    guard !Task.isCancelled, isCurrentOwner else { return }
                    guard let value, value.owner?.id == ownerID else { throw HomeRecipeWorkspaceError.unavailableReference }
                    projection = value
                } catch { if isCurrentOwner { self.error = "Recipe permissions could not be checked. Your private entry is safe. Try again when online." } }
            }
        }
    }
}
