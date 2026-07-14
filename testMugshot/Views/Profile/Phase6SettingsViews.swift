import CoreLocation
import SwiftUI
import UIKit

struct PrivacyVisibilitySettingsView: View {
    @AppStorage(CafeVisibilityPreferenceStore.valueKey) private var cafeVisibility = VisitVisibility.friends.rawValue

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
    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnit = DistanceUnitPreference.automatic.rawValue

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
        }
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Map and Location")
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
    @State private var isPreparingExport = false
    @State private var exportError: String?
    @State private var showDeleteConfirmation = false
    @State private var isRetrying = false

    private var syncSnapshot: SyncHealthSnapshot {
        SyncHealthSnapshot(userID: authModel.authenticatedUser?.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(syncSnapshot.title, systemImage: syncSnapshot.pendingItemCount == 0 ? "checkmark.icloud.fill" : "arrow.triangle.2.circlepath.icloud.fill")
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
                    Text("Export machine-readable journal data, recipes, TasteSignals, lists, friendships, preferences, media references, and available photos.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                    Button(isPreparingExport ? "Preparing export…" : "Prepare Mugshot export") { prepareExport() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isPreparingExport)
                    if let exportPackage {
                        Text("Packaged \(exportPackage.packagedMediaCount) media files. \(exportPackage.unavailableMediaCount) unavailable files remain listed by reference in the JSON export.")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
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
                        Label("Delete Account", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .tint(.red)
                }
            }
            .padding(20)
        }
        .background(Color.creamWhite)
        .navigationTitle("Data, Backup, and Account")
        .sheet(item: $exportPackage) { package in
            ActivityShareView(items: package.shareURLs)
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task { _ = await authModel.deleteAccount(dataManager: dataManager) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account data and Storage photos. This can’t be undone.")
        }
    }

    private func prepareExport() {
        guard let client = try? SupabaseClientProvider.shared.client() else {
            exportError = "Mugshot could not connect to your journal."
            return
        }
        isPreparingExport = true
        exportError = nil
        Task {
            do {
                exportPackage = try await OwnerDataExportService(client: client).prepareExport()
            } catch {
                exportError = "Mugshot couldn’t prepare the export. Your journal is unchanged—please try again."
            }
            isPreparingExport = false
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

    init(userID: UUID?) {
        draftCount = SipDraftStore.shared.allDrafts().count
        guard let userID else {
            pendingSubmissionCount = 0
            analysisRetryCount = 0
            mediaCleanupCount = 0
            return
        }
        pendingSubmissionCount = PendingVisitSubmissionStore.shared.load(userId: userID) == nil ? 0 : 1
        analysisRetryCount = DrinkAnalysisRetryStore.shared.pendingVisitIDs(userId: userID).count
        mediaCleanupCount = VisitMediaCleanupStore.shared.pendingPaths(userId: userID).count
    }

    var pendingItemCount: Int { pendingSubmissionCount + analysisRetryCount + mediaCleanupCount }
    var title: String { pendingItemCount == 0 ? "Cloud journal is up to date" : "Your journal has safe retry work" }
    var detail: String {
        let draftText = draftCount == 1 ? "1 local draft" : "\(draftCount) local drafts"
        guard pendingItemCount > 0 else {
            return "Cloud-backed journal data is current. \(draftText) stay on this device until you publish or discard them."
        }
        return "\(pendingItemCount) cloud items will retry without discarding your sip. \(draftText) remain available locally."
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
