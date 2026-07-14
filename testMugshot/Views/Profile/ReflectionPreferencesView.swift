import SwiftUI

struct ReflectionPreferencesView: View {
    @State private var preferences: UserReflectionPreferences?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedConfirmation = false

    var body: some View {
        Form {
            Section {
                if isLoading && preferences == nil {
                    ProgressView("Opening your preferences…")
                } else if let preferencesBinding {
                    Toggle("Monthly reflections", isOn: preferencesBinding.monthlyRecaps)
                    Toggle("Yearly reflection", isOn: preferencesBinding.yearlyRecaps)
                }
            } header: {
                Text("Recaps")
            } footer: {
                Text("Reflections revisit memories, learning, and places. They never rank caffeine volume or reward daily consumption.")
            }

            Section {
                if let preferencesBinding {
                    Toggle("On This Sip reminders", isOn: preferencesBinding.onThisSipReminders)
                    Toggle("Gentle reflection reminders", isOn: preferencesBinding.reflectionReminders)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Both reminder options start off. Progress never expires.")
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() } else { Text(savedConfirmation ? "Saved" : "Save preferences") }
                        Spacer()
                    }
                }
                .disabled(preferences == nil || isSaving)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Reflections and Recaps")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var preferencesBinding: Binding<UserReflectionPreferences>? {
        guard preferences != nil else { return nil }
        return Binding(
            get: { preferences! },
            set: { preferences = $0; savedConfirmation = false }
        )
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            preferences = try await ReflectionPreferencesService(
                client: try SupabaseClientProvider.shared.client()
            ).fetch()
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func save() async {
        guard let preferences else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            self.preferences = try await ReflectionPreferencesService(
                client: try SupabaseClientProvider.shared.client()
            ).save(preferences)
            savedConfirmation = true
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .account)
        }
    }
}
