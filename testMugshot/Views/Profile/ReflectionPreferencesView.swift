import SwiftUI
import UIKit

struct ReflectionPreferencesView: View {
    @StateObject private var notificationDevice = NotificationDeviceCoordinator.shared
    @State private var preferences: UserReflectionPreferences?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedConfirmation = false
    @State private var hasUnsavedChanges = false

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
                    Toggle(isOn: preferencesBinding.onThisSipReminders) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("On this day")
                            Text("At 10 AM, revisit a Mugshot from this date in a previous year.")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    Toggle(isOn: preferencesBinding.reflectionReminders) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weekly reflection")
                            Text("On Sundays at 6 PM, revisit the Mugshots you saved during the past week.")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Both reminders are opt-in and use your device timezone. They are sent only when there is something to revisit.")
            }

            if notificationDevice.permissionState == .denied {
                Section("Notification access") {
                    Text("iOS notifications are off for Mugshot. Save your preferences here, then enable notification access in Settings.")
                        .foregroundStyle(Color.secondaryText)
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section {
                if hasUnsavedChanges {
                    Text("Unsaved changes — tap Save to apply your preferences.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
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
        .disabled(isSaving)
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Reflections and Recaps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                    .disabled(preferences == nil || isSaving || !hasUnsavedChanges)
            }
        }
        .task {
            await notificationDevice.refreshPermission(reconcileRegistration: false)
            await load()
        }
    }

    private var preferencesBinding: Binding<UserReflectionPreferences>? {
        guard preferences != nil else { return nil }
        return Binding(
            get: { preferences! },
            set: { preferences = $0; savedConfirmation = false; hasUnsavedChanges = true }
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
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            self.preferences = try await ReflectionPreferencesService(
                client: try SupabaseClientProvider.shared.client()
            ).save(preferences, timezoneName: TimeZone.current.identifier)
            await notificationDevice.refreshReflectionDeliveryCapability()
            if preferences.onThisSipReminders || preferences.reflectionReminders,
               notificationDevice.permissionState == .notRequested {
                _ = await notificationDevice.requestAuthorization(source: .reflectionReminders)
            }
            savedConfirmation = true
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .account)
        }
    }
}
