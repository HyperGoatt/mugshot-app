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
            return "Private beta build for logging photo-backed cafe visits."
        case .privacy:
            return "Mugshot stores your profile, saved cafes, visit photos, likes, and comments in Supabase for signed-in beta accounts."
        case .terms:
            return "Use Mugshot respectfully. Only post photos and comments you have the right to share."
        case .support:
            return "Contact support@mugshot.app for beta support, privacy questions, or account help."
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
            List {
                Section {
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

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authModel.signOut()
                            dismiss()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Settings")
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
        Label(destination.rawValue, systemImage: destination.systemImage)
            .foregroundColor(.espressoBrown)
    }
}

struct SettingsDetailView: View {
    let destination: SettingsDestination

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .frame(width: 58, height: 58)
                    .background(Color.mugshotMint.opacity(0.35))
                    .clipShape(Circle())

                Text(destination.rawValue)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.espressoBrown)

                Text(destination.detail)
                    .font(.system(size: 15))
                    .foregroundColor(.espressoBrown.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.largePadding)
        }
        .background(Color.creamWhite)
        .navigationTitle(destination.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
