import SwiftUI

/// Sharing starts from a saved attempt, not from its private reflection form.
/// The same visible values below are the only values handed to publication.
struct HomeAttemptPostSurface: View {
    @Binding var draft: SipDraft
    let photoImages: [UIImage]
    let isSaving: Bool
    let statusMessage: String?
    let onPublish: () -> Void
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var selection: HomeLinkedRecipeSheet?

    var body: some View {
        Form {
            Section {
                Label("Your journal entry is saved privately", systemImage: "checkmark.circle")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(draft.drinkName).font(.title2).fontDesign(.serif)
                if draft.overallScore > 0 { Text("\(HomeRecipeContent.number(draft.overallScore)) / 5") }
                if photoImages.isEmpty {
                    Image(systemName: "mug").font(.largeTitle).foregroundStyle(Color.mugshotSage)
                        .accessibilityLabel("No photo")
                }
                ForEach(photoImages.indices, id: \.self) { index in
                    Image(uiImage: photoImages[index]).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                TextField("Caption", text: $draft.socialCaption, axis: .vertical)
                    .lineLimit(3...8)
                Picker("Who can see this?", selection: $draft.visibility) {
                    Text("Friends").tag(VisitVisibility.friends)
                    Text("Everyone").tag(VisitVisibility.everyone)
                }
            }
            Section("Post preview") {
                Text(draft.drinkName).font(.headline)
                if !draft.socialCaption.isEmpty { Text(draft.socialCaption) }
                Text(draft.visibility == .everyone ? "Everyone" : "Friends").font(.caption)
                Text("Private notes and next-time notes stay in your journal.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Recipe attachments") {
                ForEach(store.workspace.recipes.filter { !$0.isArchived }) { recipe in
                    if let current = recipe.current {
                        Menu(current.content.name) {
                            ForEach(recipe.versions.reversed()) { version in
                                Button("Version \(version.number)") {
                                    selection = HomeLinkedRecipeSheet(reference: HomeRecipeReference(recipeID: recipe.id, versionID: version.id))
                                }
                            }
                        }
                    }
                }
                ForEach(draft.launchContext.homeRecipeAttachments ?? []) { attachment in
                    HStack {
                        Text(store.workspace.recipes.flatMap(\.versions).first { $0.id == attachment.versionID }?.content.name ?? "Recipe")
                        Spacer()
                        Button("Remove") { draft.launchContext.homeRecipeAttachments?.removeAll { $0.id == attachment.id } }
                    }
                }
                Text("Only selected versions are attached. Linked recipes stay independently private.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let statusMessage { Text(statusMessage).font(.callout) }
            if let error = SipCaptionPolicy.validationError(for: draft.socialCaption) {
                Text(error.localizedDescription).foregroundStyle(.red)
            }
            Section {
                Button(isSaving ? "Posting…" : "Post", action: onPublish)
                    .buttonStyle(.borderedProminent).tint(.mugshotSage)
                    .disabled(isSaving || SipCaptionPolicy.validationError(for: draft.socialCaption) != nil)
            }
        }
        .navigationTitle("Share your make").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .onChange(of: draft.visibility) { _, _ in draft.launchContext.homeRecipeAttachments = [] }
        .sheet(item: $selection) { selected in
            HomeRecipeSharingConsent(reference: selected.reference, audience: draft.visibility, ownerID: draft.ownerUserID) { attachment in
                var attachments = draft.launchContext.homeRecipeAttachments ?? []
                attachments.removeAll { $0.id == attachment.id }
                attachments.append(attachment)
                draft.launchContext.homeRecipeAttachments = attachments
                selection = nil
            }
        }
    }
}

private struct HomeRecipeSharingConsent: View {
    let reference: HomeRecipeReference
    let audience: VisitVisibility
    let ownerID: UUID?
    let onConfirm: (HomeRecipePostAttachment) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var projection: RemoteVisitRecipeProjection?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if let projection {
                    Section {
                        Text(projection.recipeName).font(.headline)
                        Text("Version \(projection.versionNumber)")
                        LabeledContent("Current recipe audience", value: projection.visibilityValue.capitalized)
                        LabeledContent("Proposed audience", value: projection.visibilityValue == "everyone" ? "Everyone (unchanged)" : audience.rawValue)
                        Text("Your post does not share linked component instructions. This recipe’s audience changes only when posting completes.")
                        if audience == .everyone {
                            Text("People may save and adapt this version. Copies already saved may remain available if you change visibility later.")
                        }
                    }
                    if audience != .everyone || ["original", "adapted"].contains(projection.sourceKindValue) {
                        Button("Confirm and attach") {
                            onConfirm(HomeRecipePostAttachment(versionID: reference.versionID,
                                audience: audience.supabaseValue, acknowledgesSharing: true))
                        }.buttonStyle(.borderedProminent).tint(.mugshotSage)
                    } else {
                        Text("This source cannot share instructions with Everyone. Choose Friends or leave it unattached.")
                    }
                } else if let error { Text(error) }
                else { ProgressView("Checking recipe permissions…") }
            }.navigationTitle("Share recipe instructions?")
                .toolbar { Button("Cancel") { dismiss() } }
                .task {
                    guard let ownerID else { error = "Sign in before attaching recipe instructions."; return }
                    let store = HomeRecipeWorkspaceStore.shared
                    guard store.scope == .user(ownerID) else { return }
                    await store.synchronize()
                    do {
                        let client = try SupabaseClientProvider.shared.client()
                        let value = try await VisitService(client: client).fetchRecipeProjection(recipeVersionId: reference.versionID)
                        guard store.scope == .user(ownerID) else { return }
                        guard let value, value.owner?.id == ownerID else { throw HomeRecipeWorkspaceError.unavailableReference }
                        projection = value
                    } catch { self.error = "Recipe permissions could not be checked. Your private entry is safe. Try again when online." }
                }
        }
    }
}
