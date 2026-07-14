import SwiftUI

struct RecommendToFriendView: View {
    let kind: TrustedRecommendationKind
    let targetID: UUID
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [SocialConnection] = []
    @State private var selectedFriend: SocialConnection?
    @State private var note = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommend")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.mugshotSage)
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.espressoBrown)
                    }
                    .padding(.vertical, 4)
                }

                Section("Choose a friend") {
                    if isLoading {
                        ProgressView("Loading friends…")
                    } else if friends.isEmpty {
                        Text("Add a friend first. Mugshot recommendations are person-to-person, not public broadcasts.")
                            .foregroundColor(.secondaryText)
                    } else {
                        ForEach(friends) { friend in
                            Button {
                                selectedFriend = friend
                            } label: {
                                HStack {
                                    MugshotAvatar(name: friend.displayName, size: 38, imageURL: friend.avatarURL)
                                    VStack(alignment: .leading) {
                                        Text(friend.displayName).fontWeight(.semibold)
                                        Text("@\(friend.username)").font(.caption).foregroundColor(.secondaryText)
                                    }
                                    Spacer()
                                    if selectedFriend?.userID == friend.userID {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.mugshotSage)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Optional note") {
                    TextField("Why they might like it", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Share with a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending…" : "Send") {
                        Task { await send() }
                    }
                    .disabled(selectedFriend == nil || isSending)
                }
            }
            .task { await loadFriends() }
        }
    }

    @MainActor
    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await SocialDiscoveryService(
                client: try SupabaseClientProvider.shared.client()
            ).connections(kind: "friends")
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func send() async {
        guard let selectedFriend else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await SocialDiscoveryService(
                client: try SupabaseClientProvider.shared.client()
            ).recommend(
                to: selectedFriend.userID,
                kind: kind,
                targetID: targetID,
                note: note
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}
