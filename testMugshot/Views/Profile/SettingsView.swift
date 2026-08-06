//
//  SettingsView.swift
//  testMugshot
//

import AuthenticationServices
import SwiftUI
import UIKit

struct AccountDeletionVerificationContext: Identifiable, Equatable {
    let accountID: UUID
    let email: String?
    let providers: Set<MugshotAuthProvider>

    private init(
        accountID: UUID,
        email: String?,
        providers: Set<MugshotAuthProvider>
    ) {
        self.accountID = accountID
        self.email = email
        self.providers = providers
    }

    init(user: AuthenticatedUser) {
        self.init(
            accountID: user.id,
            email: user.email,
            providers: user.providers
        )
    }

    var id: UUID { accountID }

    var canVerifyWithPassword: Bool {
        providers.contains(.email) || (providers.isEmpty && email != nil)
    }

    var canVerifyWithApple: Bool {
        providers.contains(.apple) || providers.isEmpty
    }

    var canVerifyWithGoogle: Bool {
        providers.contains(.google)
    }

    var verificationMethodCount: Int {
        [canVerifyWithPassword, canVerifyWithApple, canVerifyWithGoogle]
            .filter { $0 }
            .count
    }

    var accountLabel: String {
        if let email, !email.isEmpty { return email }
        if canVerifyWithGoogle { return "Google account" }
        if canVerifyWithApple { return "Apple account" }
        return "Mugshot account"
    }
}

enum SettingsDestination: CaseIterable {
    case about
    case privacy
    case terms
    case support

    var detail: String {
        switch self {
        case .about:
            return "Your personal coffee memory book."
        case .privacy:
            return "Your journal content is connected to your account so it can stay with you across devices."
        case .terms:
            return "Use Mugshot respectfully and only share content you have the right to use."
        case .support:
            return "Get help with your account, privacy, or the app."
        }
    }

    var externalURL: URL? {
        switch self {
        case .privacy:
            return URL(string: "https://mugshotapp.co/privacy")
        case .terms:
            return URL(string: "https://mugshotapp.co/terms")
        case .support:
            return URL(string: "mailto:support@mugshot.app")
        case .about:
            return nil
        }
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var showDeleteConfirmation = false
    @State private var deletionVerification: AccountDeletionVerificationContext?
    @State private var copiedSupportEmail = false
    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnitPreferenceRaw = DistanceUnitPreference.automatic.rawValue
#if DEBUG
    @State private var showsLogASipV3Lab = false
    @AppStorage(SipComposerExperience.storageKey) private var sipComposerExperienceRaw = SipComposerExperience.defaultExperience.rawValue
    @AppStorage(RoadmapFeatureFlags.phase2CanonicalJournal) private var phase2CanonicalJournal = true
    @AppStorage(RoadmapFeatureFlags.phase3ExplainableTasteGraph) private var phase3ExplainableTasteGraph = true
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true
    @AppStorage(RoadmapFeatureFlags.phase5Reflections) private var phase5Reflections = true
    @AppStorage(RoadmapFeatureFlags.phase6OwnershipAndSystemEntry) private var phase6OwnershipAndSystemEntry = true
#endif

    private let privacyURL = URL(string: "https://mugshotapp.co/privacy")!
    private let termsURL = URL(string: "https://mugshotapp.co/terms")!
    private let supportEmail = "support@mugshot.app"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if usesPhase6Settings {
                        phase6SettingsHub
                    } else {
                        preferencesSection
                        helpLegalSection
                        accountSection
                    }

#if DEBUG
                    developerSection
#endif

                    if copiedSupportEmail {
                        Text("Support email copied")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mugshotSage)
                    }

                    Text(versionText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
            .sheet(item: $deletionVerification) { context in
                AccountDeletionVerificationView(
                    context: context,
                    dataManager: dataManager
                )
                .environmentObject(authModel)
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, accountID in
                if accountID == nil {
                    deletionVerification = nil
                    dismiss()
                }
            }
        }
#if DEBUG
        .fullScreenCover(isPresented: $showsLogASipV3Lab) {
            NavigationStack {
                LogASipV3LabView()
            }
        }
#endif
    }

    private var usesPhase6Settings: Bool {
#if DEBUG
        phase6OwnershipAndSystemEntry
#else
        true
#endif
    }

    private var phase6SettingsHub: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("Account and Profile") {
                if let profile = authModel.profile {
                    NavigationLink {
                        EditProfileView(profile: profile, dataManager: dataManager)
                    } label: {
                        settingsRow("Edit Profile", systemImage: "person.crop.circle")
                    }
                    Divider().padding(.leading, 60)
                }
                NavigationLink {
                    DataOwnershipSettingsView(dataManager: dataManager).environmentObject(authModel)
                } label: {
                    settingsRow("Account and Sign In", systemImage: "person.badge.key.fill")
                }
            }

            settingsGroup("Journal and Capture Defaults") {
                NavigationLink {
                    CapturePreferencesView(allowsSkipping: false).environmentObject(authModel)
                } label: {
                    settingsRow("Coffee Preferences", systemImage: "slider.horizontal.3")
                }
            }

            settingsGroup("Privacy and Visibility") {
                NavigationLink { PrivacyVisibilitySettingsView() } label: {
                    settingsRow("Audience Defaults", systemImage: "lock.shield.fill")
                }
            }

            settingsGroup("Friends and Discoverability") {
                NavigationLink { FriendsDiscoverabilitySettingsView() } label: {
                    settingsRow("Friend Discovery", systemImage: "person.2.fill")
                }
            }

            settingsGroup("Safety and Account Status") {
                NavigationLink {
                    EnforcementCenterView()
                        .environmentObject(authModel)
                } label: {
                    settingsRow("Safety and Account Status", systemImage: "checkmark.shield.fill")
                }
                Divider().padding(.leading, 60)
                NavigationLink {
                    BlockedUsersSettingsView(dataManager: dataManager)
                        .environmentObject(authModel)
                } label: {
                    settingsRow("Blocked Accounts", systemImage: "hand.raised.fill")
                }
            }

            settingsGroup("Map, Location, and Distance Units") {
                NavigationLink { MapLocationSettingsView(dataManager: dataManager) } label: {
                    settingsRow("Map and Location", systemImage: "location.fill")
                }
            }

            settingsGroup("Notifications and Recaps") {
                NavigationLink { NotificationSettingsView() } label: {
                    settingsRow("Activity and Push", systemImage: "bell.badge.fill")
                }
                Divider().padding(.leading, 60)
                NavigationLink { ReflectionPreferencesView() } label: {
                    settingsRow("Reflections and Recaps", systemImage: "calendar.badge.clock")
                }
            }

            settingsGroup("Data Export, Backup, and Account Deletion") {
                NavigationLink {
                    DataOwnershipSettingsView(dataManager: dataManager).environmentObject(authModel)
                } label: {
                    settingsRow("Data and Cloud Health", systemImage: "externaldrive.badge.icloud")
                }
            }

            settingsGroup("Appearance and Accessibility") {
                NavigationLink { AppearanceAccessibilitySettingsView() } label: {
                    settingsRow("Display and Accessibility", systemImage: "textformat.size")
                }
            }

            settingsGroup("Help, Feedback, Legal, and About") {
                helpLegalRows
            }
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundColor(.tertiaryText)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }.cardStyle()
        }
    }

    private var helpLegalSection: some View {
        VStack(spacing: 0) { helpLegalRows }.cardStyle()
    }

    @ViewBuilder
    private var helpLegalRows: some View {
        NavigationLink { AboutMugshotView() } label: {
            settingsRow("About Mugshot", systemImage: "info.circle")
        }
        Divider().padding(.leading, 60)
        NavigationLink {
            PolicyDocumentView(title: "Privacy", subtitle: "How Mugshot handles your journal.", url: privacyURL, sections: PrivacyDocument.sections)
        } label: {
            settingsRow("Privacy", systemImage: "hand.raised.fill")
        }
        Divider().padding(.leading, 60)
        NavigationLink {
            PolicyDocumentView(title: "Terms", subtitle: "The ground rules for Mugshot.", url: termsURL, sections: TermsDocument.sections)
        } label: {
            settingsRow("Terms", systemImage: "doc.text.fill")
        }
        Divider().padding(.leading, 60)
        NavigationLink {
            SupportView(supportEmail: supportEmail, didCopy: $copiedSupportEmail)
        } label: {
            settingsRow("Support and Feedback", systemImage: "envelope.fill")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Settings")
                .mugshotDisplay(size: 30)
                .foregroundColor(.espressoBrown)
            Text("Your preferences, account, privacy, and support.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.tertiaryText)
        }
        .padding(.top, 8)
    }

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "ruler")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance Units")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Used across Map and Discover")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 8)

                Picker("Distance Units", selection: distanceUnitPreferenceBinding) {
                    ForEach(DistanceUnitPreference.allCases) { preference in
                        Text(preference.menuTitle()).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .tint(.mugshotSage)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.leading, 60)

            NavigationLink {
                CapturePreferencesView(allowsSkipping: false)
                    .environmentObject(authModel)
            } label: {
                settingsRow("Coffee Preferences", systemImage: "slider.horizontal.3")
            }

            if reflectionsEnabled, authModel.authenticatedUser != nil {
                Divider().padding(.leading, 60)
                NavigationLink {
                    ReflectionPreferencesView()
                } label: {
                    settingsRow("Reflections and Recaps", systemImage: "calendar.badge.clock")
                }
            }
        }
        .cardStyle()
    }

    private var distanceUnitPreferenceBinding: Binding<DistanceUnitPreference> {
        Binding(
            get: { DistanceUnitPreference.stored(distanceUnitPreferenceRaw) },
            set: { distanceUnitPreferenceRaw = $0.rawValue }
        )
    }

    private var reflectionsEnabled: Bool {
#if DEBUG
        phase5Reflections
#else
        true
#endif
    }

#if DEBUG
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.tertiaryText)

            Button {
                showsLogASipV3Lab = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 34, height: 34)
                        .background(Color.mugshotSage.opacity(0.16))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log a Sip V3 UI Lab")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Text("Five-screen visual prototype with fixture data")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 46)

            NavigationLink {
                MugsyStudioView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.square.filled.and.at.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 34, height: 34)
                        .background(Color.mugshotSage.opacity(0.16))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mugsy Studio")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Text("Canonical model sheet and identity checks")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 46)

            NavigationLink {
                MotionLabView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 34, height: 34)
                        .background(Color.mugshotSage.opacity(0.16))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Motion Lab")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Text("Mugsy reactions, refresh, camera, ritual, and saved celebrations")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sip Composer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Switch without losing the active draft")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 8)

                Picker("Sip Composer", selection: sipComposerExperienceBinding) {
                    ForEach(SipComposerExperience.allCases) { experience in
                        Text(experience.title).tag(experience)
                    }
                }
                .pickerStyle(.menu)
                .tint(.mugshotSage)
            }

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 2 Journal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Calendar, map, drafts, tags, and memory tools")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 8)

                Toggle("Phase 2 Journal", isOn: $phase2CanonicalJournal)
                    .labelsHidden()
                    .tint(.mugshotSage)
            }

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 3 Taste Graph")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Evidence, corrections, and Your Mix reasons")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 8)

                Toggle("Phase 3 Taste Graph", isOn: $phase3ExplainableTasteGraph)
                    .labelsHidden()
                    .tint(.mugshotSage)
            }

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 4 Friends")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Shared lists, recommendations, and reactions")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }

                Spacer(minLength: 8)

                Toggle("Phase 4 Friends", isOn: $phase4LightweightFriends)
                    .labelsHidden()
                    .tint(.mugshotSage)
            }

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 5 Reflections")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Monthly memories, milestones, and recap controls")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
                Spacer(minLength: 8)
                Toggle("Phase 5 Reflections", isOn: $phase5Reflections)
                    .labelsHidden()
                    .tint(.mugshotSage)
            }

            Divider().padding(.leading, 46)

            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.icloud")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 6 Ownership")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text("Settings, export, accessibility, and system entry")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
                Spacer(minLength: 8)
                Toggle("Phase 6 Ownership", isOn: $phase6OwnershipAndSystemEntry)
                    .labelsHidden()
                    .tint(.mugshotSage)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var sipComposerExperienceBinding: Binding<SipComposerExperience> {
        Binding(
            get: { SipComposerExperience(rawValue: sipComposerExperienceRaw) ?? .defaultExperience },
            set: { sipComposerExperienceRaw = $0.rawValue }
        )
    }
#endif

    private var accountSection: some View {
        VStack(spacing: 12) {
            if let error = authModel.profileUpdateError {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.sandBeige.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Task {
                    await authModel.signOut(dataManager: dataManager)
                    dismiss()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(authModel.status == .working)

            Button(role: .destructive) {
                authModel.clearProfileUpdateError()
                showDeleteConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .tint(.red)
            .disabled(authModel.status == .working)
        }
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotSage.opacity(0.16))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Mugshot \(version) (\(build))"
    }
}

private struct AboutMugshotView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("MugshotAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Mugshot")
                    .mugshotDisplay(size: 34)
                    .foregroundColor(.espressoBrown)

                Text("Mugshot is a personal coffee memory book. Save the drinks you loved, the cafes worth returning to, and the details that make each sip yours.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)

                Text("Photo-backed visits, private notes, and saved cafes are tied to your Mugshot account so they stay with you across devices.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color.creamWhite)
        .navigationTitle("About Mugshot")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SupportView: View {
    let supportEmail: String
    @Binding var didCopy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Need a hand?")
                .mugshotDisplay(size: 30)
                .foregroundColor(.espressoBrown)

            Text("Email us for account, privacy, or beta support. If Mail is not set up on this device, copy the address and use the email app you prefer.")
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)

            Text(supportEmail)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .textSelection(.enabled)

            Link(destination: URL(string: "mailto:\(supportEmail)")!) {
                Label("Email Support", systemImage: "envelope.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                UIPasteboard.general.string = supportEmail
                didCopy = true
            } label: {
                Label("Copy Email Address", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.creamWhite)
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicyDocumentView: View {
    let title: String
    let subtitle: String
    let url: URL
    let sections: [(String, String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)

                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.0)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text(section.1)
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                    }
                }

                Link(destination: url) {
                    Label("Read the full \(title.lowercased()) policy", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
        .background(Color.creamWhite)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountDeletionVerificationView: View {
    let context: AccountDeletionVerificationContext
    @ObservedObject var dataManager: DataManager

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @FocusState private var passwordIsFocused: Bool
    @State private var password = ""
    @State private var appleNonce: String?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.roastBrown)
                            .accessibilityHidden(true)
                        Text("Verify it’s you")
                            .mugshotDisplay(size: 30)
                            .foregroundColor(.espressoBrown)
                        Text("Mugshot will first create a one-time security challenge. A fresh sign-in then authorizes deletion for this account only.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account to delete")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.tertiaryText)
                            .textCase(.uppercase)

                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.mugshotSage)
                                .accessibilityHidden(true)
                            Text(context.accountLabel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Color.sandBeige.opacity(0.58))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignSystem.Radius.control,
                                style: .continuous
                            )
                        )
                        .privacySensitive()
                        .accessibilityLabel("Locked account, \(context.accountLabel)")
                    }

                    if context.canVerifyWithPassword,
                       let email = context.email,
                       !email.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            SecureField("Password for \(email)", text: $password)
                                .textContentType(.password)
                                .focused($passwordIsFocused)
                                .submitLabel(.continue)
                                .mugshotFormField()
                                .privacySensitive()
                                .accessibilityIdentifier("accountDeletionPassword")
                                .onSubmit(submitPassword)

                            Button(role: .destructive, action: submitPassword) {
                                HStack(spacing: 8) {
                                    if isWorking {
                                        ProgressView()
                                            .tint(.red)
                                    }
                                    Label("Verify and Delete Account", systemImage: "trash")
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(!canSubmitPassword)
                            .opacity(canSubmitPassword ? 1 : 0.55)
                            .accessibilityHint("Permanently deletes the locked account after a fresh sign-in")
                        }

                    }

                    if context.verificationMethodCount > 1 {
                        HStack(spacing: 10) {
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                            Text("or use another sign-in method")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.tertiaryText)
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                        }
                    }

                    if context.canVerifyWithGoogle {
                        MugshotGoogleSignInButton(
                            title: "Verify with Google",
                            isDisabled: isWorking
                        ) {
                            performDeletion {
                                await authModel.deleteAccountWithGoogle(
                                    dataManager: dataManager
                                )
                            }
                        }
                        .accessibilityHint("Verifies this account and then permanently deletes it")
                    }

                    if context.canVerifyWithApple {
                        SignInWithAppleButton(.continue) { request in
                            prepareAppleRequest(request)
                        } onCompletion: { result in
                            handleAppleAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignSystem.Radius.control,
                                style: .continuous
                            )
                        )
                        .disabled(isWorking)
                        .accessibilityHint("Verifies this account and then permanently deletes it")
                    }

                    if let message {
                        Text(message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.07))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: DesignSystem.Radius.control,
                                    style: .continuous
                                )
                            )
                            .accessibilityIdentifier("accountDeletionError")
                    }

                    Text("Nothing is deleted if verification is canceled, expires, uses another account, or cannot be confirmed. Mugshot does not store the password or provider credential used for this check.")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .onChange(of: authModel.authenticatedUser?.id) { _, accountID in
            if accountID == nil {
                dismiss()
            } else if accountID != context.accountID {
                message = "The signed-in account changed. Nothing was deleted."
            }
        }
    }

    private var canSubmitPassword: Bool {
        password.count >= 6 && !isWorking
    }

    private func submitPassword() {
        guard canSubmitPassword else { return }
        let submittedPassword = password
        password = ""
        performDeletion {
            await authModel.deleteAccount(
                password: submittedPassword,
                dataManager: dataManager
            )
        }
    }

    private func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.random()
            appleNonce = nonce
            message = nil
            request.requestedScopes = [.email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            appleNonce = nil
            message = "Mugshot couldn’t prepare Apple verification. Nothing was deleted. Try again."
        }
    }

    private func handleAppleAuthorization(
        _ result: Result<ASAuthorization, Error>
    ) {
        switch result {
        case .failure(let error):
            appleNonce = nil
            if (error as? ASAuthorizationError)?.code == .canceled {
                message = "Verification was canceled. Nothing was deleted."
            } else {
                message = "Apple verification couldn’t be completed. Nothing was deleted. Try again."
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                appleNonce = nil
                message = "Apple verification returned an invalid credential. Nothing was deleted. Try again."
                return
            }
            appleNonce = nil
            performDeletion {
                await authModel.deleteAccountWithApple(
                    idToken: idToken,
                    nonce: nonce,
                    dataManager: dataManager
                )
            }
        }
    }

    private func performDeletion(
        _ operation: @escaping () async -> Bool
    ) {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        passwordIsFocused = false
        Task {
            let deleted = await operation()
            isWorking = false
            if deleted {
                dismiss()
            } else if authModel.authenticatedUser?.id == context.accountID {
                message = accountDeletionFailureMessage
            }
        }
    }

    private var accountDeletionFailureMessage: String {
        if let profileUpdateError = authModel.profileUpdateError {
            return profileUpdateError
        }
        switch authModel.status {
        case .sessionUnavailable(let message),
             .failed(let message),
             .signedOut(let message?):
            return message
        default:
            return "Mugshot couldn’t complete account deletion. Nothing unconfirmed was cleared; try again or contact support."
        }
    }
}

private enum PrivacyDocument {
    static let sections = [
        ("Effective date", "This summary applies to the current Mugshot app release. The full, current policy is always available from the link below."),
        ("What Mugshot stores", "Mugshot stores your profile, journal, photos, private notes, ratings, recipes, saved cafes and lists, social interactions, activity history, and safety reports to provide the app."),
        ("How it is used", "Your information keeps your journal in sync and shows each post, recipe, Taste Passport, list, and social interaction only to its permitted audience. Private journal notes are not used as social copy."),
        ("Your choices", "You can manage post, recipe, and Taste Passport audiences; push preferences; blocked accounts; appeals; data export; sign-out; and account deletion from Settings."),
        ("Deletion and safety records", "Deleting your account removes your profile, journal, media, social access, and account access. Limited safety evidence and deletion receipts may remain in restricted records to prevent abuse and prove completion.")
    ]
}

private enum TermsDocument {
    static let sections = [
        ("Effective date", "This summary applies to the current Mugshot app release. The full, current terms are available from the link below."),
        ("Your content", "Only share photos, notes, and comments you have the right to use. Keep the coffee community respectful."),
        ("Your account", "You are responsible for keeping your account credentials private and for the audience you choose for each visit."),
        ("Questions", "Contact Mugshot support if you have questions about these terms or your account.")
    ]
}
