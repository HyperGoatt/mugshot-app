import SwiftUI
import UIKit

struct HomePlaceProfileEditorView: View {
    let ownerID: UUID?
    let onSaved: (HomePlaceProfile) -> Void
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var profile: HomePlaceProfile
    @State private var library = HomeLibrarySnapshot.empty
    @State private var makeDefault = false
    @State private var error: String?
    @FocusState private var isNameFocused: Bool

    init(ownerID: UUID?, profile: HomePlaceProfile? = nil, onSaved: @escaping (HomePlaceProfile) -> Void) {
        self.ownerID = ownerID; self.onSaved = onSaved
        _profile = State(initialValue: profile ?? HomePlaceProfile(ownerUserID: ownerID, name: ""))
    }
    private var scope: LocalAccountScope { .forUserID(ownerID) }
    private var isCurrentOwner: Bool { authModel.authenticatedUser?.id == ownerID }
    private var duplicateName: Bool {
        (library.preferences?.homeProfiles ?? []).contains {
            $0.id != profile.id && $0.ownerUserID == ownerID &&
                $0.name.compare(profile.name.trimmingCharacters(in: .whitespacesAndNewlines), options: .caseInsensitive) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            HomeEditorCanvas(title: "Your kind of Home.", detail: "A familiar spot and the tools you reach for.", symbol: "house.fill", eyebrow: "HOME SETUP") {
                HomeEditorSection("A name to remember", symbol: "house") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Setup name").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                        TextField("My kitchen", text: $profile.name)
                            .font(.body).frame(minHeight: 44)
                            .autocorrectionDisabled().focused($isNameFocused)
                            .submitLabel(.done).onSubmit { isNameFocused = false }
                            .accessibilityLabel("Setup name").accessibilityIdentifier("home.profile.name")
                    }
                    Text("This name appears on your sips. Use a nickname, never an address.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                    if duplicateName { HomeEditorError(message: "Choose a different name so your setups are easy to tell apart.") }
                    if let message = profile.validationMessage, !profile.name.isEmpty { HomeEditorError(message: message) }
                }
                HomeEditorSection("Your tools", symbol: "kettle", detail: "Optional defaults for a fresh setup. Your saved recipes keep their own gear.") {
                    if library.activeEquipment.filter({ $0.ownerUserID == ownerID }).isEmpty {
                        Text("You can add gear to your Home library whenever you like.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                    ForEach(library.activeEquipment.filter { $0.ownerUserID == ownerID }) { gear in
                        Toggle(isOn: Binding(get: { profile.equipmentIDs.contains(gear.id) }, set: { enabled in
                            if enabled { profile.equipmentIDs.insert(gear.id) } else { profile.equipmentIDs.remove(gear.id) }
                        })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(gear.displayName).font(.headline)
                                Text(gear.role.title).font(.caption).foregroundStyle(Color.secondaryText)
                            }
                        }.frame(minHeight: 48).tint(Color.mugshotSageText)
                    }
                }
                HomeEditorSection("For next time", symbol: "pin") {
                    Toggle("Use as my default Home setup", isOn: $makeDefault)
                        .frame(minHeight: 44).tint(Color.mugshotSageText)
                    Text("Saved on this device for this account. Earlier sips keep the name recorded when you made them.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }
                if let error { HomeEditorError(message: error) }
            }
            .navigationTitle("Home setup").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                        .disabled(!isCurrentOwner || profile.validationMessage != nil || duplicateName)
                        .accessibilityIdentifier("home.profile.save")
                }
            }
            .task {
                guard isCurrentOwner else { return }
                library = HomeLibraryStore.shared.load(in: scope)
                makeDefault = library.preferences?.defaultHomeProfileID == profile.id ||
                    (library.preferences?.homeProfiles?.isEmpty ?? true)
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in if !isCurrentOwner { dismiss() } }
        }.tint(Color.mugshotSageText)
    }

    private func save() {
        guard isCurrentOwner, profile.validationMessage == nil, !duplicateName else { return }
        isNameFocused = false
        do {
            let shelf = HomeLibraryStore.shared
            var saved = try shelf.upsertHomeProfile(profile, in: scope)
            var preferences = saved.preferences ?? HomeLibraryPreferences()
            if makeDefault { preferences.defaultHomeProfileID = profile.id }
            else if preferences.defaultHomeProfileID == profile.id { preferences.defaultHomeProfileID = nil }
            saved = try shelf.savePreferences(preferences, in: scope)
            guard let persisted = saved.preferences?.homeProfiles?.first(where: { $0.id == profile.id }) else { return }
            onSaved(persisted); dismiss()
        } catch { self.error = "Couldn’t save this Home setup. Your other setups are safe. Try again." }
    }
}
