import SwiftUI

struct BlockedUsersSettingsView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var blockedUsers: [SocialConnection] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingUnblock: SocialConnection?
    @State private var unblockingUserID: UUID?
    @State private var loadedAccountID: UUID?

    var body: some View {
        Form {
            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.mugshotSage)
                        .accessibilityElement(children: .combine)
                }
            }

            if let errorMessage, !blockedUsers.isEmpty {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .accessibilityElement(children: .combine)
                }
            }

            Section {
                if authModel.authenticatedUser == nil {
                    ContentUnavailableView(
                        "Sign in required",
                        systemImage: "person.badge.key.fill",
                        description: Text("Sign in to view and manage blocked accounts.")
                    )
                } else if isLoading && blockedUsers.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading blocked accounts…")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(children: .combine)
                } else if let errorMessage, blockedUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Couldn’t load blocked accounts", systemImage: "wifi.exclamationmark")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                        Button("Try again") { Task { await load() } }
                    }
                    .padding(.vertical, 8)
                } else if blockedUsers.isEmpty {
                    ContentUnavailableView(
                        "No blocked accounts",
                        systemImage: "hand.raised.slash",
                        description: Text("Accounts you block will appear here.")
                    )
                } else {
                    ForEach(blockedUsers) { person in
                        HStack(spacing: 12) {
                            MugshotAvatar(
                                name: person.displayName,
                                size: 44,
                                imageURL: person.avatarURL
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.espressoBrown)
                                Text("@\(person.username)")
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            Spacer(minLength: 8)
                            Button(unblockingUserID == person.userID ? "Unblocking…" : "Unblock") {
                                pendingUnblock = person
                            }
                            .disabled(unblockingUserID != nil)
                            .accessibilityLabel("Unblock @\(person.username)")
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Blocked accounts")
            } footer: {
                Text("Blocked people cannot find your profile or interact with your shared Mugshots. Each person’s private journal remains unchanged.")
            }
        }
        .tint(.mugshotSage)
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Blocked Accounts")
        .task(id: authModel.authenticatedUser?.id) { await load() }
        .onChange(of: authModel.authenticatedUser?.id) { _, accountID in
            guard loadedAccountID != accountID else { return }
            blockedUsers = []
            pendingUnblock = nil
            unblockingUserID = nil
            statusMessage = nil
            errorMessage = nil
            isLoading = accountID != nil
            loadedAccountID = accountID
        }
        .refreshable { await load() }
        .alert(
            "Unblock @\(pendingUnblock?.username ?? "this account")?",
            isPresented: Binding(
                get: { pendingUnblock != nil },
                set: { if !$0 { pendingUnblock = nil } }
            ),
            presenting: pendingUnblock
        ) { person in
            Button("Unblock") { Task { await unblock(person) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(SocialSafetyCopy.unblockConsequences)
        }
    }

    @MainActor
    private func load() async {
        guard let expectedAccountID = authModel.authenticatedUser?.id else {
            blockedUsers = []
            errorMessage = nil
            loadedAccountID = nil
            return
        }
        if loadedAccountID != expectedAccountID {
            blockedUsers = []
            pendingUnblock = nil
            unblockingUserID = nil
            statusMessage = nil
            errorMessage = nil
            loadedAccountID = expectedAccountID
        }
        isLoading = true
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                isLoading = false
            }
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == expectedAccountID else { return }
            let loaded = try await SocialSafetyService(client: client).blockedUsers(
                accountID: expectedAccountID
            )
            guard authModel.authenticatedUser?.id == expectedAccountID,
                  client.auth.currentUser?.id == expectedAccountID else { return }
            blockedUsers = loaded
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func unblock(_ person: SocialConnection) async {
        guard let expectedAccountID = authModel.authenticatedUser?.id,
              loadedAccountID == expectedAccountID,
              blockedUsers.contains(where: { $0.userID == person.userID }),
              unblockingUserID == nil else { return }
        unblockingUserID = person.userID
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                unblockingUserID = nil
            }
        }
        errorMessage = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            guard client.auth.currentUser?.id == expectedAccountID else { return }
            try await SocialSafetyService(client: client).unblock(
                userID: person.userID,
                expectedAccountID: expectedAccountID
            )
            guard authModel.authenticatedUser?.id == expectedAccountID,
                  client.auth.currentUser?.id == expectedAccountID else { return }
            blockedUsers.removeAll { $0.userID == person.userID }
            statusMessage = "@\(person.username) is unblocked."
            dataManager.noteJournalMutation()
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}
