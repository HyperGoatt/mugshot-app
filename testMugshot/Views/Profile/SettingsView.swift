//
//  SettingsView.swift
//  testMugshot
//

import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable, Equatable {
    case about = "About Mugshot"
    case privacy = "Privacy"
    case terms = "Terms"
    case support = "Support"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .about:
            return "info.circle"
        case .privacy:
            return "hand.raised.fill"
        case .terms:
            return "doc.text.fill"
        case .support:
            return "envelope.fill"
        }
    }

    var detail: String {
        switch self {
        case .about:
            return "A social sip journal for coffee, matcha, tea, cafes, and taste memory."
        case .privacy:
            return "Mugshot keeps your profile, saved cafes, visit photos, likes, and comments connected to your account."
        case .terms:
            return "Use Mugshot respectfully. Only post photos and comments you have the right to share."
        case .support:
            return "Contact support@mugshot.app for support, privacy questions, or account help."
        }
    }

    var externalURL: URL? {
        switch self {
        case .support:
            return URL(string: "mailto:support@mugshot.app")
        default:
            return nil
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Settings")
                            .mugshotDisplay(size: 30)
                            .foregroundColor(.espressoBrown)

                        Text("Account, privacy, and support.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 0) {
                    ForEach(SettingsDestination.allCases) { destination in
                        if let url = destination.externalURL {
                            Link(destination: url) {
                                settingsRow(destination)
                            }
                        } else {
                            NavigationLink {
                                SettingsDetailView(destination: destination)
                            } label: {
                                settingsRow(destination)
                            }
                        }
                    }
                    }
                    .cardStyle()

                    Button(role: .destructive) {
                        Task {
                            await authModel.signOut()
                            dismiss()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .tint(.red)
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func settingsRow(_ destination: SettingsDestination) -> some View {
        HStack(spacing: 12) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 34, height: 34)
                .background(Color.mugshotSage.opacity(0.16))
                .clipShape(Circle())

            Text(destination.rawValue)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SettingsDetailView: View {
    let destination: SettingsDestination

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 58, height: 58)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                Text(destination.rawValue)
                    .mugshotDisplay(size: 30)
                    .foregroundColor(.espressoBrown)

                Text(destination.detail)
                    .font(.system(size: 15))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.largePadding)
            .cardStyle(radius: DesignSystem.Radius.heroCard)
            .padding()
        }
        .background(Color.creamWhite)
        .navigationTitle(destination.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
