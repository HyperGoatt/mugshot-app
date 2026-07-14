//
//  SettingsView.swift
//  testMugshot
//

import SwiftUI
import UIKit

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
    @State private var copiedSupportEmail = false
    @AppStorage(DistanceUnitPreference.storageKey) private var distanceUnitPreferenceRaw = DistanceUnitPreference.automatic.rawValue
#if DEBUG
    @AppStorage(SipComposerExperience.storageKey) private var sipComposerExperienceRaw = SipComposerExperience.defaultExperience.rawValue
    @AppStorage(RoadmapFeatureFlags.phase2CanonicalJournal) private var phase2CanonicalJournal = true
    @AppStorage(RoadmapFeatureFlags.phase3ExplainableTasteGraph) private var phase3ExplainableTasteGraph = true
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true
    @AppStorage(RoadmapFeatureFlags.phase5Reflections) private var phase5Reflections = true
#endif

    private let privacyURL = URL(string: "https://mugshotapp.co/privacy")!
    private let termsURL = URL(string: "https://mugshotapp.co/terms")!
    private let supportEmail = "support@mugshot.app"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    preferencesSection

#if DEBUG
                    developerSection
#endif

                    VStack(spacing: 0) {
                        NavigationLink {
                            AboutMugshotView()
                        } label: {
                            settingsRow("About Mugshot", systemImage: "info.circle")
                        }

                        Divider().padding(.leading, 60)

                        NavigationLink {
                            PolicyDocumentView(
                                title: "Privacy",
                                subtitle: "How Mugshot handles your journal.",
                                url: privacyURL,
                                sections: PrivacyDocument.sections
                            )
                        } label: {
                            settingsRow("Privacy", systemImage: "hand.raised.fill")
                        }

                        Divider().padding(.leading, 60)

                        NavigationLink {
                            PolicyDocumentView(
                                title: "Terms",
                                subtitle: "The ground rules for Mugshot.",
                                url: termsURL,
                                sections: TermsDocument.sections
                            )
                        } label: {
                            settingsRow("Terms", systemImage: "doc.text.fill")
                        }

                        Divider().padding(.leading, 60)

                        NavigationLink {
                            SupportView(
                                supportEmail: supportEmail,
                                didCopy: $copiedSupportEmail
                            )
                        } label: {
                            settingsRow("Support", systemImage: "envelope.fill")
                        }
                    }
                    .cardStyle()

                    if copiedSupportEmail {
                        Text("Support email copied")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mugshotSage)
                    }

                    accountSection

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
                Button("Delete Account", role: .destructive) {
                    Task {
                        let deleted = await authModel.deleteAccount(dataManager: dataManager)
                        if deleted {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your profile, photos, visits, saved cafes, comments, and account data. This can’t be undone.")
            }
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

            if phase5Reflections, authModel.authenticatedUser != nil {
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

#if DEBUG
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.tertiaryText)

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

private enum PrivacyDocument {
    static let sections = [
        ("Effective date", "This summary applies to the current Mugshot app release. The full, current policy is always available from the link below."),
        ("What Mugshot stores", "Your account profile, saved cafes, visit photos, captions, private notes, ratings, likes, and comments are stored to provide your journal."),
        ("How it is used", "Your information is used to save your Mugshot, display only the visits you choose to share, and keep your profile and cafe library in sync."),
        ("Your choices", "You can edit your profile, choose each visit’s audience, sign out, contact support, or permanently delete your account from Settings.")
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
