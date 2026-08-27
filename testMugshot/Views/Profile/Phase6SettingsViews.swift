import CoreLocation
import SwiftUI
import UIKit

struct PrivacyVisibilitySettingsView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var cafeVisibility = VisitVisibility.friends.rawValue
    @State private var hasLoadedVisibility = false
    @State private var showsFriendsOnProfile = true
    @State private var isSavingProfileVisibility = false
    @State private var profileVisibilityError: String?

    var body: some View {
        Form {
            Section("Cafe sips") {
                Picker("Default audience", selection: $cafeVisibility) {
                    Text("Private").tag(VisitVisibility.private.rawValue)
                    Text("Friends").tag(VisitVisibility.friends.rawValue)
                    Text("Everyone").tag(VisitVisibility.everyone.rawValue)
                }
                Text("Mugshot remembers your latest Cafe audience. Everyone still requires a photo or intentional text-only confirmation.")
            }
            Section("Public profile") {
                Toggle("Show Friends Mugshots", isOn: Binding(
                    get: { showsFriendsOnProfile },
                    set: updateProfileVisibility
                ))
                .disabled(isSavingProfileVisibility)

                if isSavingProfileVisibility {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text("Saving profile visibility…")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                }

                Text("When on, Friends Mugshots stay in Friends Feed and also appear on your public profile. When off, only Everyone Mugshots appear there. Private Mugshots never appear.")

                if let profileVisibilityError {
                    Label(profileVisibilityError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            }
            TastePassportVisibilitySettingsSection()
            Section("Home and Recipe") {
                LabeledContent("Default audience", value: "Private")
                Text("Home and Recipe entries always begin Private. You make any sharing decision inside the sip composer.")
            }
            Section("Private notes") {
                Label("Never included in Feed or sharing", systemImage: "lock.shield.fill")
                    .foregroundStyle(Color.mugshotSage)
                Text("Private notes are stored separately from the social caption and drink analysis.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Privacy and Visibility")
        .task(id: authModel.authenticatedUser?.id) {
            let scope = LocalAccountScope.forUserID(authModel.authenticatedUser?.id)
            cafeVisibility = CafeVisibilityPreferenceStore.shared
                .defaultCafeVisibility(in: scope)
                .rawValue
            hasLoadedVisibility = true
            await loadProfileVisibility()
        }
        .onChange(of: cafeVisibility) { _, rawValue in
            guard hasLoadedVisibility,
                  let visibility = VisitVisibility(rawValue: rawValue) else { return }
            CafeVisibilityPreferenceStore.shared.rememberCafeVisibility(
                visibility,
                in: .forUserID(authModel.authenticatedUser?.id)
            )
        }
    }

    @MainActor
    private func loadProfileVisibility() async {
        guard authModel.authenticatedUser != nil else { return }
        do {
            let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
            showsFriendsOnProfile = try await service.showsFriendsOnPublicProfile()
            profileVisibilityError = nil
        } catch {
            profileVisibilityError = "Mugshot couldn’t load this setting."
        }
    }

    private func updateProfileVisibility(_ isEnabled: Bool) {
        guard !isSavingProfileVisibility else { return }
        let previousValue = showsFriendsOnProfile
        showsFriendsOnProfile = isEnabled
        isSavingProfileVisibility = true
        profileVisibilityError = nil

        Task { @MainActor in
            defer { isSavingProfileVisibility = false }
            do {
                let service = SharedProfileService(client: try SupabaseClientProvider.shared.client())
                showsFriendsOnProfile = try await service.setShowsFriendsOnPublicProfile(isEnabled)
            } catch {
                showsFriendsOnProfile = previousValue
                profileVisibilityError = "That change wasn’t saved. Please try again."
            }
        }
    }
}

struct FriendsDiscoverabilitySettingsView: View {
    var body: some View {
        Form {
            Section("Discovery") {
                LabeledContent("People search", value: "Friends network")
                LabeledContent("Trusted recommendations", value: "Enabled")
                LabeledContent("Taste compatibility", value: "Friends only")
            }
            Section {
                Text("Mugshot’s lightweight friends layer never exposes Private sips or private TasteSignal evidence. Block and friendship controls remain available where you manage each person.")
            }
        }
        .tint(.mugshotSage)
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Friends and Discoverability")
    }
}

struct MapLocationSettingsView: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject private var reminders = NearbyCafeReminderCoordinator.shared
    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnit = DistanceUnitPreference.automatic.rawValue
    @State private var showsReminderEducation = false
    @State private var reminderError: String?

    var body: some View {
        Form {
            Section("Distance") {
                Picker("Distance units", selection: $distanceUnit) {
                    ForEach(DistanceUnitPreference.allCases) { preference in
                        Text(preference.menuTitle()).tag(preference.rawValue)
                    }
                }
            }
            Section("Location") {
                LabeledContent("Permission", value: permissionLabel)
                Text("Location is requested only when you ask for nearby cafes or center the Map. Search remains available without it.")
            }
            if DiscoveryFeatureFlags.isEnabled(.nearbyReminders) {
            Section("Nearby saved cafes") {
                Toggle("Nearby reminders", isOn: Binding(
                    get: { reminders.isEnabled },
                    set: { isEnabled in
                        if isEnabled {
                            showsReminderEducation = true
                        } else {
                            reminders.setEnabled(false, cafes: dataManager.appData.cafes)
                        }
                    }
                ))
                if reminders.isEnabled {
                    LabeledContent("Monitored cafes", value: "\(reminders.monitoredCafeCount)")
                }
                Text("Mugshot can notify you when one of your strongest saved cafes is nearby. It monitors at most 20 cafes, sends no more than one reminder a day, and keeps exact location history on this device.")
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Map and Location")
        .alert("Turn on nearby reminders?", isPresented: $showsReminderEducation) {
            Button("Not now", role: .cancel) {}
            Button("Continue") {
                Task {
                    let enabled = await reminders.requestEnable(cafes: dataManager.appData.cafes)
                    if !enabled {
                        reminderError = "Nearby reminders need notification and Always Location permission. You can change both in iOS Settings."
                    }
                }
            }
        } message: {
            Text("Mugshot will ask for notification permission first, then Always Location. Monitoring applies only to cafes you deliberately saved and can be disabled immediately here.")
        }
        .alert("Nearby reminders are off", isPresented: Binding(
            get: { reminderError != nil },
            set: { if !$0 { reminderError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderError ?? "Please try again.")
        }
    }

    private var permissionLabel: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not requested"
        @unknown default: "Unavailable"
        }
    }
}

struct AppearanceAccessibilitySettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("MugshotSettings.haptics.v1") private var haptics = true

    var body: some View {
        Form {
            Section("Appearance") {
                LabeledContent("Color scheme", value: "Warm light")
                LabeledContent("Photo legibility", value: "Automatic")
            }
            Section("Accessibility") {
                Toggle("Rating haptics", isOn: $haptics)
                LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
                LabeledContent("Text size", value: "Follows iOS")
                Text("Mugshot follows Dynamic Type, VoiceOver, contrast, and Reduce Motion settings from iOS.")
            }
        }
        .tint(.mugshotSage)
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Appearance and Accessibility")
    }
}

struct DataOwnershipSettingsView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var exportPackage: OwnerDataExportPackage?
    @State private var preparedExportDirectory: URL?
    @State private var isPreparingExport = false
    @State private var exportError: String?
    @State private var showDeleteConfirmation = false
    @State private var deletionVerification: AccountDeletionVerificationContext?
    @State private var isRetrying = false

    private var syncSnapshot: SyncHealthSnapshot {
        SyncHealthSnapshot(userID: authModel.authenticatedUser?.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(syncSnapshot.title, systemImage: syncSnapshot.systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(syncSnapshot.detail)
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                    if syncSnapshot.pendingItemCount > 0 {
                        Button(isRetrying ? "Retrying…" : "Retry cloud work") { retryCloudWork() }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(isRetrying)
                    }
                }
                .padding(16)
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your data")
                        .mugshotDisplay(size: 24)
                        .foregroundColor(.espressoBrown)
                    Text("Export machine-readable journal data, private notes, recipes, Taste Passport evidence, saved and collaborative lists, social and safety receipts, your appeal statements, preferences, pending MugShots, media references, and available photos.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                    Button(isPreparingExport ? "Preparing export…" : "Prepare Mugshot export") { prepareExport() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isPreparingExport)
                    if let exportPackage {
                        Text("Packaged \(exportPackage.packagedMediaCount) media files. \(exportPackage.unavailableMediaCount) unavailable files remain listed by reference in the JSON export.")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                        if exportPackage.completeness == .partial {
                            Text("This export is partial: \(exportPackage.omittedCollections.joined(separator: ", ")).")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.roastBrown)
                                .accessibilityLabel("Partial export. Missing: \(exportPackage.omittedCollections.joined(separator: ", "))")
                        }
                    }
                    if let exportError {
                        Text(exportError)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .padding(16)
                .cardStyle()

                VStack(spacing: 12) {
                    Button {
                        Task { await authModel.signOut(dataManager: dataManager) }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Label("Delete Account", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .tint(.red)
                }
            }
            .padding(20)
        }
        .background(Color.creamWhite)
        .navigationTitle("Data, Backup, and Account")
        .sheet(item: $exportPackage, onDismiss: discardPreparedExport) { package in
            ActivityShareView(items: package.shareURLs)
        }
        .sheet(item: $deletionVerification) { context in
            AccountDeletionVerificationView(
                context: context,
                dataManager: dataManager
            )
            .environmentObject(authModel)
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in
            discardPreparedExport()
            showDeleteConfirmation = false
            deletionVerification = nil
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirmation) {
            Button("Verify and Delete", role: .destructive) {
                deletionVerification = authModel.authenticatedUser.map {
                    AccountDeletionVerificationContext(user: $0)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll verify with a fresh sign-in before anything is deleted. Deletion permanently removes your account and journal, then finishes stored-photo cleanup. Limited safety and deletion receipts may remain to prevent abuse and prove completion. This can’t be undone.")
        }
    }

    private func prepareExport() {
        guard let expectedAccountID = authModel.authenticatedUser?.id,
              let client = try? SupabaseClientProvider.shared.client() else {
            exportError = "Mugshot could not connect to your journal."
            return
        }
        discardPreparedExport()
        isPreparingExport = true
        exportError = nil
        Task {
            do {
                let prepared = try await OwnerDataExportService(client: client).prepareExport()
                guard authModel.authenticatedUser?.id == expectedAccountID else {
                    try? FileManager.default.removeItem(at: prepared.directoryURL)
                    isPreparingExport = false
                    return
                }
                preparedExportDirectory = prepared.directoryURL
                exportPackage = prepared
            } catch {
                guard authModel.authenticatedUser?.id == expectedAccountID else {
                    isPreparingExport = false
                    return
                }
                exportError = "Mugshot couldn’t prepare the export. Your journal is unchanged—please try again."
            }
            isPreparingExport = false
        }
    }

    private func discardPreparedExport() {
        let directory = preparedExportDirectory ?? exportPackage?.directoryURL
        exportPackage = nil
        preparedExportDirectory = nil
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func retryCloudWork() {
        guard let userID = authModel.authenticatedUser?.id,
              let client = try? SupabaseClientProvider.shared.client() else { return }
        isRetrying = true
        Task {
            await VisitDeletionService(client: client).retryPendingMediaCleanup(userId: userID)
            await DrinkAnalysisService(client: client).retryPendingAnalyses(userId: userID)
            isRetrying = false
        }
    }
}

struct SyncHealthSnapshot: Equatable {
    let draftCount: Int
    let pendingSubmissionCount: Int
    let analysisRetryCount: Int
    let mediaCleanupCount: Int
    let localReadIssueCount: Int

    init(
        userID: UUID?,
        draftStore: SipDraftStore = .shared,
        pendingStore: PendingVisitSubmissionStore = .shared
    ) {
        let draftReport = draftStore.readReport(in: .forUserID(userID))
        draftCount = draftReport.drafts.count
        var readIssueCount = draftReport.issues.count
        guard let userID else {
            pendingSubmissionCount = 0
            analysisRetryCount = 0
            mediaCleanupCount = 0
            localReadIssueCount = readIssueCount
            return
        }
        do {
            pendingSubmissionCount = try pendingStore.loadAll(userId: userID).count
        } catch {
            pendingSubmissionCount = 0
            readIssueCount += 1
        }
        analysisRetryCount = DrinkAnalysisRetryStore.shared.pendingVisitIDs(userId: userID).count
        mediaCleanupCount = VisitMediaCleanupStore.shared.pendingPaths(userId: userID).count
        localReadIssueCount = readIssueCount
    }

    var pendingItemCount: Int { pendingSubmissionCount + analysisRetryCount + mediaCleanupCount }
    var hasLocalReadIssues: Bool { localReadIssueCount > 0 }
    var systemImage: String {
        if hasLocalReadIssues { return "exclamationmark.triangle.fill" }
        return pendingItemCount == 0
            ? "checkmark.icloud.fill"
            : "arrow.triangle.2.circlepath.icloud.fill"
    }
    var title: String {
        if hasLocalReadIssues { return "Local journal data needs attention" }
        return pendingItemCount == 0
            ? "Cloud journal is up to date"
            : "Your journal has safe retry work"
    }
    var detail: String {
        let draftText = draftCount == 1 ? "1 local draft" : "\(draftCount) local drafts"
        if hasLocalReadIssues {
            let verb = draftCount == 1 ? "is" : "are"
            return "Mugshot couldn’t verify every local draft or protected MugShot. Stored data was left unchanged. Reopen the app and retry; if this remains, keep Mugshot installed so the data can be recovered. \(draftText) \(verb) readable."
        }
        guard pendingItemCount > 0 else {
            let verb = draftCount == 1 ? "stays" : "stay"
            let pronoun = draftCount == 1 ? "it" : "them"
            return "Cloud-backed journal data is current. \(draftText) \(verb) on this device until you publish or discard \(pronoun)."
        }
        let verb = draftCount == 1 ? "remains" : "remain"
        return "\(pendingItemCount) cloud items will retry without discarding your sip. \(draftText) \(verb) available locally."
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
