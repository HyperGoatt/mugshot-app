import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var reminders = MugsyReminderCoordinator.shared
    @ObservedObject private var nearby = NearbyCafeReminderCoordinator.shared
    @State private var nearbyError: String?

    var body: some View {
        Form {
            Section {
                MugsyReminderPreview()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }
            Section("People") {
                NavigationLink("Push access and friend activity", destination: PeopleNotificationSettingsView())
                Text("The Push notifications switch inside controls remote push for every category, including Mugsy and reflections.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Your people, at your pace. Every update stays in Activity, even when push is off.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("My journal") {
                NavigationLink(destination: MugsyReminderPreferencesView()) {
                    LabeledContent("Mugsy reminders", value: reminders.preferences.mugsyEnabled ? "On" : "Off")
                }
                NavigationLink("Weekly Pour and On This Day", destination: ReflectionPreferencesView())
                Text("Up to three optional notifications a week across Mugsy, reflections, nearby reminders, and grouped friend updates. Light pace allows one.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Nearby") {
                Toggle("Saved cafes nearby", isOn: Binding(get: { nearby.isEnabled }, set: { enabled in
                    if enabled {
                        Task {
                            if !(await nearby.requestEnable(cafes: DataManager.shared.appData.cafes)) {
                                nearbyError = "Nearby reminders need notification and location access. You can change access in iOS Settings."
                            }
                        }
                    } else { nearby.setEnabled(false, cafes: DataManager.shared.appData.cafes) }
                }))
                .accessibilityIdentifier("mugsy.settings.nearby")
                Text("Discover cafes you saved. Your location stays on this device. Without a shared reminder slot, discoveries stay in the app.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let nearbyError { Text(nearbyError).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .tint(.mugshotSageText)
        .task(id: authModel.authenticatedUser?.id) {
            await reminders.activate(accountID: authModel.authenticatedUser?.id)
        }
    }
}

struct MugsyReminderPreferencesView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var reminders: MugsyReminderCoordinator
    @ObservedObject private var device = NotificationDeviceCoordinator.shared
    @State private var draft = MugsyReminderPreferences()
    @State private var requestID = UUID()
    private let previewAccountID: UUID?
    private let requestsSystemPermission: Bool

    init(coordinator: MugsyReminderCoordinator = .shared, accountID: UUID? = nil,
         requestsSystemPermission: Bool = true) {
        _reminders = ObservedObject(wrappedValue: coordinator)
        previewAccountID = accountID
        self.requestsSystemPermission = requestsSystemPermission
    }

    var body: some View {
        Form {
            Section {
                MugsyReminderPreview().listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }
            Section {
                Toggle("A little nudge from Mugsy", isOn: $draft.mugsyEnabled)
                    .accessibilityIdentifier("mugsy.settings.consent")
                Text("Occasional reminders to keep a drink memory. No catching up. No daily streak to protect. Choose your pace below.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("My journal") }
            .disabled(!reminders.backendAvailable || reminders.isSaving)

            Section("Pace") {
                Picker("Optional notifications", selection: $draft.pace) {
                    ForEach(MugsyReminderPace.allCases) { pace in Text(pace.title).tag(pace) }
                }.accessibilityIdentifier("mugsy.settings.pace")
                Text(draft.pace == .standard ? "Three a week at most, with at least two days between them." :
                    draft.pace == .light ? "One a week at most. A little more room between visits." :
                    "Optional reminders are off. Your journal and friend Activity remain here.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.disabled(!reminders.backendAvailable || reminders.isSaving)

            Section("Timing") {
                DatePicker("Preferred time", selection: minuteBinding(\.preferredMinute), displayedComponents: .hourAndMinute)
                DatePicker("Daytime starts", selection: minuteBinding(\.windowStartMinute), displayedComponents: .hourAndMinute)
                DatePicker("Quiet time starts", selection: minuteBinding(\.windowEndMinute), displayedComponents: .hourAndMinute)
                Text("Mugsy follows your device timezone. Weekly Pour is Sunday at 6 PM; On This Day is at 10 AM, when enabled and inside your reminder hours.")
                    .font(.footnote).foregroundStyle(.secondary)
                if !draft.timingIsValid {
                    Text("Choose a daytime window that ends later the same day, with your preferred time inside it.")
                        .font(.footnote).foregroundStyle(Color.roastBrown)
                }
            }.disabled(!reminders.backendAvailable || reminders.isSaving)

            Section("Pause") {
                if draft.pausedIndefinitely {
                    Label("Paused until you choose to resume", systemImage: "moon.zzz")
                } else if let until = draft.pausedUntil, until > .now {
                    LabeledContent("Paused until", value: until.formatted(date: .abbreviated, time: .omitted))
                }
                Button("Pause for seven days") { setPause(days: 7) }
                    .accessibilityIdentifier("mugsy.settings.pause7")
                Button("Pause for thirty days") { setPause(days: 30) }
                    .accessibilityIdentifier("mugsy.settings.pause30")
                Button("Pause indefinitely") { setPause(days: nil) }
                    .accessibilityIdentifier("mugsy.settings.pauseIndefinitely")
                if draft.isPaused(at: .now) {
                    Button("Resume optional reminders") { draft.pausedUntil = nil; draft.pausedIndefinitely = false }
                        .accessibilityIdentifier("mugsy.settings.resume")
                }
                Text("Tap Save to apply your pause across supported devices. Direct friend notifications keep their own settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.disabled(!reminders.backendAvailable || reminders.isSaving)

            if device.permissionState == .denied {
                Section("iOS access") {
                    Text("Notifications are off in iOS. You can save your choices here and enable access when you’re ready.")
                    Button("Open iOS Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
            if reminders.isLoading { Section { ProgressView("Opening your preferences…") } }
            if let message = reminders.errorMessage { Section { Text(message).font(.footnote).foregroundStyle(Color.roastBrown) } }
            if let message = reminders.confirmationMessage {
                Section {
                    Label(message, systemImage: "checkmark.circle").foregroundStyle(Color.mugshotSageText)
                    if reminders.preferences.deliveryMode == "off" || reminders.preferences.deliveryMode == "shadow" {
                        Text("Mugsy’s new push reminders haven’t started yet. Your choices are ready for their quiet introduction.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle("Mugsy reminders").navigationBarTitleDisplayMode(.inline)
        .tint(.mugshotSageText)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(reminders.isSaving ? "Saving…" : "Save") { Task { await save() } }
                    .disabled(!reminders.backendAvailable || reminders.isSaving || !draft.timingIsValid)
                    .accessibilityIdentifier("mugsy.settings.save")
            }
        }
        .task(id: previewAccountID ?? authModel.authenticatedUser?.id) {
            await reminders.activate(accountID: previewAccountID ?? authModel.authenticatedUser?.id)
            draft = reminders.preferences
            await device.refreshPermission()
        }
        .onChange(of: draft) { _, _ in requestID = UUID() }
    }

    private func setPause(days: Int?) {
        draft.pausedIndefinitely = days == nil
        draft.pausedUntil = days.map { Date.now.addingTimeInterval(Double($0) * 86400) }
    }

    private func minuteBinding(_ key: WritableKeyPath<MugsyReminderPreferences, Int>) -> Binding<Date> {
        Binding(get: {
            let minute = draft[keyPath: key]
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft[keyPath: key] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })
    }

    private func save() async {
        let needsPermission = draft.mugsyEnabled && draft.pace != .off
        if await reminders.save(draft, requestID: requestID) {
            draft = reminders.preferences
            reminders.dismissInvitation()
            if requestsSystemPermission, needsPermission, device.permissionState == .notRequested {
                _ = await device.requestAuthorization(source: .mugsyReminder)
            }
        }
    }
}

struct MugsyReminderPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little nudge,\na little Mugsy.")
                        .font(.system(.title, design: .serif)).foregroundStyle(Color.espressoBrown)
                    Text("Your journal. Your pace.")
                        .font(.subheadline).foregroundStyle(Color.roastBrown)
                }.frame(maxWidth: .infinity, alignment: .leading)
                MugsyCatalogView(pose: .journalKeeper, rendering: .artwork)
                    .frame(width: 94, height: 112).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Label("MUGSHOT · PREVIEW", systemImage: "bell")
                    .font(.caption2.weight(.semibold)).tracking(1)
                Text(MugsyNotificationCopyCatalog.previewSecondMemory.title).font(.subheadline.weight(.semibold))
                Text(MugsyNotificationCopyCatalog.previewSecondMemory.body).font(.subheadline)
            }
            .foregroundStyle(Color.espressoBrown).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(18).background(Color.mugshotMint.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mugsy.settings.preview")
    }
}

struct MugsyReminderCard: View {
    let invitation: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MugsyCatalogView(pose: invitation ? .welcomeWave : .journalKeeper, rendering: .artwork)
                .frame(width: 62, height: 76).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(invitation ? "A little nudge from Mugsy?" : "Mugsy saved you a seat.")
                    .font(.system(.headline, design: .serif)).foregroundStyle(Color.espressoBrown)
                Text(invitation ? "Occasional reminders. Three a week at most. You choose the pace." :
                    "Had a sip worth keeping? There’s no catching up to do.")
                    .font(.caption).foregroundStyle(Color.roastBrown)
                Button(invitation ? "Choose reminders" : "Keep a memory", action: onOpen)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                    .frame(minHeight: 44).accessibilityIdentifier("mugsy.card.open")
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .foregroundStyle(Color.roastBrown).accessibilityLabel(invitation ? "Not now" : "Dismiss reminder")
                .accessibilityIdentifier("mugsy.card.dismiss")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.mugshotMint.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}

struct MugsyWeeklyPresentation: Identifiable {
    let ownerID: UUID
    let window: WeeklyPourWindow
    var id: Date { window.end }
}

struct MugsyReminderContextBar: View {
    let intent: MugsyNotificationIntent
    let onSettings: () -> Void
    let onClose: () -> Void
    @ObservedObject private var reminders = MugsyReminderCoordinator.shared
    @State private var actionMessage: String?
    @State private var isChanging = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
        HStack {
            Menu {
                Text("You chose occasional reminders for your journal. Your pace and pause controls are always yours.")
                Button("Less often") { adjust { await reminders.useLightPace() } }
                Button("Pause for seven days") { adjust { await reminders.pause(days: 7) } }
                Button("Reminder settings", action: onSettings)
            } label: {
                Label("Why this reminder?", systemImage: "info.circle").font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }.accessibilityIdentifier("mugsy.destination.controls").disabled(isChanging)
            Spacer()
            Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Dismiss reminder controls")
        }
            if let actionMessage {
                Text(actionMessage).font(.caption).foregroundStyle(Color.roastBrown)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 8)
                    .accessibilityIdentifier("mugsy.destination.changeResult")
            }
        }
        .foregroundStyle(Color.mugshotSageText).padding(.horizontal, 20)
        .background(Color.creamWhite)
    }

    private func adjust(_ change: @escaping @MainActor () async -> Void) {
        isChanging = true
        Task {
            await change()
            actionMessage = reminders.errorMessage ?? reminders.confirmationMessage
            isChanging = false
        }
    }
}

struct MugsyReminderRouteStatus: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").accessibilityHidden(true)
            Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Try again", action: onRetry).font(.caption.weight(.semibold)).frame(minHeight: 44)
        }
        .foregroundStyle(Color.espressoBrown).padding(.horizontal, 20)
        .background(Color.mugshotMint.opacity(0.45))
        .accessibilityIdentifier("mugsy.destination.retry")
    }
}
