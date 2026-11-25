#if DEBUG
import SwiftUI

/// Uses the production settings and card with a fictional owner and isolated
/// local preferences. It never registers a device, sends push, or calls a backend.
struct MugsyReminderPreviewHost: View {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
    @StateObject private var coordinator: MugsyReminderCoordinator
    @State private var showsPreferences = false
    private let state: String

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let state = arguments.first(where: { $0.hasPrefix("--mugsy-reminders-state=") })?
            .replacingOccurrences(of: "--mugsy-reminders-state=", with: "") ?? "settings"
        self.state = state
        let service = MugsyReminderPreviewService(unavailable: state == "unavailable", failSave: state == "save-failure")
        let defaults = UserDefaults(suiteName: "MugsyReminderPreview.\(UUID())")!
        _coordinator = StateObject(wrappedValue: MugsyReminderCoordinator(defaults: defaults, makeService: { _ in service }))
    }

    var body: some View {
        NavigationStack {
            if state == "invitation" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Journal").font(.system(.largeTitle, design: .serif)).padding(.horizontal, 20)
                        Text("Your first little memory is kept.").foregroundStyle(Color.roastBrown).padding(.horizontal, 20)
                        MugsyReminderCard(invitation: true, onOpen: { showsPreferences = true }, onDismiss: {})
                        MugsyReminderPreview().padding(.horizontal, 20)
                    }.padding(.vertical, 24)
                }.background(Color.creamWhite)
                .navigationDestination(isPresented: $showsPreferences) {
                    MugsyReminderPreferencesView(coordinator: coordinator, accountID: owner, requestsSystemPermission: false)
                }
            } else {
                MugsyReminderPreferencesView(coordinator: coordinator, accountID: owner, requestsSystemPermission: false)
            }
        }
    }
}

@MainActor
private final class MugsyReminderPreviewService: MugsyReminderServicing {
    var value: MugsyReminderPreferences
    let unavailable: Bool
    var failSave: Bool
    init(unavailable: Bool, failSave: Bool) {
        self.unavailable = unavailable; self.failSave = failSave
        var value = MugsyReminderPreferences(); value.timezoneName = "America/New_York"; value.deliveryMode = "shadow"
        self.value = value
    }
    func fetch() async throws -> MugsyReminderPreferences {
        if unavailable { throw URLError(.notConnectedToInternet) }
        return value
    }
    func save(_ preferences: MugsyReminderPreferences, requestID: UUID) async throws -> MugsyReminderPreferences {
        if failSave { failSave = false; throw URLError(.networkConnectionLost) }
        guard value.revision == preferences.revision else { throw URLError(.cannotParseResponse) }
        value = preferences; value.revision += 1; return value
    }
    func record(_ signal: MugsyCompletedMemorySignal) async throws {}
    func withdraw(memoryID: UUID) async throws {}
    func capability(deviceID: UUID) async throws {}
    func activity(deviceID: UUID, active: Bool, composing: Bool) async throws {}
    func viewed(weekEnd: Date) async throws {}
    func nearbyPermit(deviceID: UUID, requestID: UUID) async throws -> MugsyNearbyPermit {
        .init(allowed: false, reason: "preview", permitID: nil, expiresAt: nil)
    }
    func authorize(_ intent: MugsyNotificationIntent) async throws -> Bool { false }
    func opened(occurrenceID: UUID) async throws {}
    func baseline(ready: Bool) async throws {}
}
#endif
