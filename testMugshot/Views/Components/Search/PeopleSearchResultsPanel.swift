//
//  PeopleSearchResultsPanel.swift
//  testMugshot
//
//  Created by Cursor on 11/30/25.
//

import SwiftUI

struct PeopleSearchResultsPanel: View {
    @Binding var searchText: String
    @ObservedObject var dataManager: DataManager
    
    @State private var results: [RemoteUserProfile] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ZStack(alignment: .top) {
            DS.Colors.cardBackground
            
            Group {
                if isSearching {
                    ProgressView()
                        .padding(DS.Spacing.md)
                } else if results.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 28))
                            .foregroundColor(DS.Colors.iconSubtle)
                        
                        Text("No people found.")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .padding(DS.Spacing.lg)
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                            DSSectionHeader("People", subtitle: "Tap to view profile")
                                .padding(.horizontal, DS.Spacing.pagePadding)
                                .padding(.top, DS.Spacing.md)
                            
                            ForEach(results, id: \.id) { profile in
                                FriendSearchResultRow(
                                    profile: profile,
                                    friendshipStatus: getFriendshipStatus(for: profile.id),
                                    dataManager: dataManager,
                                    onStatusChanged: {
                                        // Refresh status if changed
                                        // DataManager updates should propagate
                                    }
                                )
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                        }
                        .padding(.bottom, DS.Spacing.md)
                    }
                } else {
                    EmptyView()
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .cornerRadius(DS.Radius.card, corners: [.bottomLeft, .bottomRight] as UIRectCorner)
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            
            do {
                let users = try await dataManager.searchUsers(query: trimmed)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.results = users
                        self.isSearching = false
                    }
                }
            } catch {
                print("Error searching users: \(error)")
                if !Task.isCancelled {
                    await MainActor.run {
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    private func getFriendshipStatus(for userId: String) -> FriendshipStatus {
        // For unified search (Map tab), we only differentiate between "Friends" and "Not friends".
        // Detailed request state (incoming/outgoing) is handled in FriendsHubView.
        if dataManager.appData.friendsSupabaseUserIds.contains(userId) {
            return .friends
        } else {
            return .none
        }
    }
}

