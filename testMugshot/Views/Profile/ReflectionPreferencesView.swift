import SwiftUI
import UIKit

struct ReflectionPreferencesView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var generation = UUID()
    @State private var loadedOwnerID: UUID?
    @StateObject private var notificationDevice = NotificationDeviceCoordinator.shared
    @State private var preferences: UserReflectionPreferences?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedConfirmation = false
    @State private var hasUnsavedChanges = false

#if DEBUG
    struct PreviewTransport {
        let owner: UUID
        let fetch: @MainActor () async throws -> UserReflectionPreferences
        let save: @MainActor (UserReflectionPreferences) async throws -> UserReflectionPreferences
    }
    var previewTransport: PreviewTransport? = nil
#endif

    private var accountID: UUID? {
#if DEBUG
        if MugshotLaunchEnvironment.isUITesting, let previewTransport { return previewTransport.owner }
#endif
        return authModel.authenticatedUser?.id
    }

    var body: some View {
        Form {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if preferences == nil, accountID != nil {
                        Button("Reload preferences") { Task { await load() } }
                            .disabled(isLoading)
                            .accessibilityIdentifier("settings.reflections.retry")
                    }
                }
            }
            if preferences != nil || isLoading {
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

            if preferences != nil {
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
        .task(id: accountID) {
            generation = UUID()
            preferences = nil
            loadedOwnerID = nil
            isLoading = false
            isSaving = false
            hasUnsavedChanges = false
            savedConfirmation = false
            await notificationDevice.refreshPermission(reconcileRegistration: false)
            await load()
        }
        .onDisappear { generation = UUID() }
    }

    private var preferencesBinding: Binding<UserReflectionPreferences>? {
        guard let confirmed = preferences else { return nil }
        return Binding(
            get: { preferences ?? confirmed },
            set: { value in
                guard preferences != nil, loadedOwnerID == accountID, !isSaving else { return }
                preferences = value
                savedConfirmation = false
                hasUnsavedChanges = true
            }
        )
    }

    @MainActor
    private func load() async {
        guard !isLoading, !Task.isCancelled else { return }
        guard let owner = accountID else {
            errorMessage = "Sign in to manage reflection preferences."
            return
        }
        let token = generation
        isLoading = true
        errorMessage = nil
        defer { if generation == token { isLoading = false } }
        do {
            let loaded = try await fetchPreferences(owner: owner)
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            preferences = loaded
            loadedOwnerID = owner
        } catch {
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            errorMessage = "Mugshot couldn’t load your reflection preferences. Reload to try again."
        }
    }

    @MainActor
    private func save() async {
        guard !Task.isCancelled, let preferences, let owner = loadedOwnerID,
              accountID == owner, !isSaving else { return }
        let token = generation
        isSaving = true
        defer { if generation == token { isSaving = false } }
        do {
            let saved = try await persistPreferences(preferences, owner: owner)
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            self.preferences = saved
            await notificationDevice.refreshReflectionDeliveryCapability()
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            if saved.onThisSipReminders || saved.reflectionReminders,
               notificationDevice.permissionState == .notRequested {
                _ = await notificationDevice.requestAuthorization(source: .reflectionReminders)
            }
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            savedConfirmation = true
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            guard generation == token, !Task.isCancelled,
                  accountID == owner else { return }
            errorMessage = "Mugshot couldn’t confirm the save. Your edits are still here. Try saving again."
        }
    }

    @MainActor private func fetchPreferences(owner: UUID) async throws -> UserReflectionPreferences {
#if DEBUG
        if MugshotLaunchEnvironment.isUITesting, let previewTransport {
            return try await previewTransport.fetch()
        }
#endif
        let client = try SupabaseClientProvider.shared.client()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        let value = try await ReflectionPreferencesService(client: client).fetch()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        return value
    }

    @MainActor private func persistPreferences(_ value: UserReflectionPreferences, owner: UUID) async throws -> UserReflectionPreferences {
#if DEBUG
        if MugshotLaunchEnvironment.isUITesting, let previewTransport {
            return try await previewTransport.save(value)
        }
#endif
        let client = try SupabaseClientProvider.shared.client()
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        let saved = try await ReflectionPreferencesService(client: client)
            .save(value, timezoneName: TimeZone.current.identifier)
        guard client.auth.currentUser?.id == owner else { throw CancellationError() }
        return saved
    }

}
