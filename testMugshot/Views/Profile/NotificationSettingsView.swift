import Combine
import SwiftUI
import UIKit

@MainActor
private final class NotificationSettingsStore: ObservableObject {
    @Published var preferences = ActivityNotificationPreferences.alphaDefaults
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var backendPreferencesAvailable = false
    @Published var errorMessage: String?
    @Published var confirmationMessage: String?
    private var accountID: UUID?

    func load(accountID expectedAccountID: UUID?) async {
        accountID = expectedAccountID
        preferences = .alphaDefaults
        confirmationMessage = nil
        errorMessage = nil
        backendPreferencesAvailable = false
        guard let expectedAccountID else {
            isLoading = false
            errorMessage = "Sign in to manage push preferences."
            return
        }
        isLoading = true
        defer {
            if accountID == expectedAccountID {
                isLoading = false
            }
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == expectedAccountID else { return }
            let loaded = try await ActivityService(client: client).preferences(
                accountID: expectedAccountID
            )
            guard accountID == expectedAccountID,
                  client.auth.currentUser?.id == expectedAccountID else { return }
            preferences = loaded
            backendPreferencesAvailable = true
            errorMessage = nil
        } catch ActivityServiceError.notificationPreferencesUnavailable {
            guard accountID == expectedAccountID else { return }
            preferences = .alphaDefaults
            preferences.pushEnabled = false
            backendPreferencesAvailable = false
            errorMessage = "Push preferences aren’t available yet. In-app Activity still works."
        } catch {
            guard accountID == expectedAccountID else { return }
            preferences = .alphaDefaults
            preferences.pushEnabled = false
            backendPreferencesAvailable = false
            errorMessage = "Mugshot couldn’t verify your push preferences. In-app Activity still works."
        }
    }

    func save(accountID expectedAccountID: UUID?) async {
        guard let expectedAccountID,
              accountID == expectedAccountID else {
            errorMessage = "Sign in to save push preferences."
            return
        }
        guard backendPreferencesAvailable else {
            errorMessage = "Push preferences aren’t available yet. In-app Activity still works."
            return
        }
        let proposedPreferences = preferences
        isSaving = true
        defer {
            if accountID == expectedAccountID {
                isSaving = false
            }
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == expectedAccountID else { return }
            let saved = try await ActivityService(client: client)
                .savePreferences(
                    proposedPreferences,
                    accountID: expectedAccountID
                )
            guard accountID == expectedAccountID,
                  client.auth.currentUser?.id == expectedAccountID else { return }
            preferences = saved
            await NotificationDeviceCoordinator.shared.applyPushPreference(
                enabled: saved.pushEnabled,
                accountID: expectedAccountID
            )
            guard accountID == expectedAccountID else { return }
            confirmationMessage = "Push preferences saved."
            errorMessage = nil
        } catch {
            guard accountID == expectedAccountID else { return }
            errorMessage = "Mugshot couldn’t save those push preferences. Your previous settings are unchanged."
        }
    }
}

struct NotificationSettingsView: View {
    @StateObject private var store = NotificationSettingsStore()
    @ObservedObject private var deviceCoordinator = NotificationDeviceCoordinator.shared
    @EnvironmentObject private var authModel: AppAuthModel

    var body: some View {
        Form {
            Section("Activity history") {
                LabeledContent("In-app activity", value: "Always on")
                Text("Friend posts, tags, invitations, likes, comments, reactions, and requests remain in Activity even when push is off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Push on this device") {
                pushCapabilityContent
            }

            Section("Push preferences") {
                Toggle("Push notifications", isOn: $store.preferences.pushEnabled)
                Toggle("Friend posts", isOn: $store.preferences.friendPosts)
                Toggle("Tags", isOn: $store.preferences.tags)
                Toggle("Collaborative cafe lists", isOn: $store.preferences.collaborativeListInvitations)
                Toggle("Likes", isOn: $store.preferences.likes)
                Toggle("Comments and mentions", isOn: $store.preferences.comments)
                Toggle("Reactions", isOn: $store.preferences.reactions)
                Toggle("Friend requests", isOn: $store.preferences.friendRequests)
            }
            .disabled(
                store.isLoading
                    || store.isSaving
                    || authModel.authenticatedUser == nil
                    || !store.backendPreferencesAvailable
                    || !deviceCoordinator.capability.isConfigured
            )

            if let confirmationMessage = store.confirmationMessage {
                Section {
                    Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.mugshotSage)
                }
            }

            if let errorMessage = store.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(store.isSaving ? "Saving…" : "Save") {
                    Task {
                        await store.save(accountID: authModel.authenticatedUser?.id)
                    }
                }
                .disabled(
                    store.isLoading
                        || store.isSaving
                        || authModel.authenticatedUser == nil
                        || !store.backendPreferencesAvailable
                        || !deviceCoordinator.capability.isConfigured
                )
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            await store.load(accountID: authModel.authenticatedUser?.id)
            await deviceCoordinator.refreshPermission()
        }
    }

    @ViewBuilder
    private var pushCapabilityContent: some View {
        switch deviceCoordinator.capability {
        case .unavailable(let reason):
            Label("Push is not available in this build", systemImage: "bell.slash.fill")
                .foregroundStyle(.secondary)
            Text(reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("The delivery worker is local-only until APNs credentials, scheduling, and a signed push-capable build are configured.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .configured:
            if !store.backendPreferencesAvailable {
                Label("Push isn’t available yet", systemImage: "bell.slash.fill")
                    .foregroundStyle(.secondary)
                Text("Mugshot will keep in-app Activity available without asking iOS for notification permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                configuredPushContent
            }
        }
    }

    @ViewBuilder
    private var configuredPushContent: some View {
        switch deviceCoordinator.permissionState {
            case .notRequested:
                Text("Get a quiet heads-up when people interact with you. Mugshot asks iOS only after you choose Enable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Enable Push on This iPhone") {
                    Task { _ = await deviceCoordinator.requestAuthorization() }
                }
            case .denied:
                Label("Push is off in iOS Settings", systemImage: "bell.slash.fill")
                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            case .authorized, .provisional:
                Label("This iPhone can receive push", systemImage: "bell.badge.fill")
                    .foregroundStyle(Color.mugshotSage)
                registrationStatus
            case .unsupported, .unavailable:
                Text("iOS notification status is unavailable. In-app activity still works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var registrationStatus: some View {
        switch deviceCoordinator.registrationState {
        case .idle:
            Text("Push registration will finish while you use Mugshot.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .registering:
            ProgressView("Registering this iPhone…")
        case .registered:
            Text("Registered with Mugshot")
                .font(.footnote)
                .foregroundStyle(Color.mugshotSage)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
