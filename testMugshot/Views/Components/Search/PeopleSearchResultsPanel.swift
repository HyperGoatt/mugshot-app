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
    @State private var friendshipStatuses: [String: FriendshipStatus] = [:]
    
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
                                    friendshipStatus: friendshipStatuses[profile.id] ?? .none,
                                    dataManager: dataManager,
                                    onStatusChanged: {
                                        // Refresh status if changed
                                        Task {
                                            await refreshFriendshipStatus(for: profile.id)
                                        }
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
        .onAppear {
            // Refresh friends list and friend request data for accurate status display
            Task {
                await dataManager.refreshFriendsList()
                _ = try? await dataManager.fetchFriendRequests()
            }
        }
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            friendshipStatuses = [:]
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
                    // Refresh friendship statuses after results are loaded
                    await refreshFriendshipStatuses(for: users)
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
    
    // MARK: - Friendship Status Management
    
    /// Refresh friendship statuses for all search results using async checks
    private func refreshFriendshipStatuses(for profiles: [RemoteUserProfile]) async {
        // Clear existing statuses
        await MainActor.run {
            friendshipStatuses.removeAll()
        }
        
        // Batch check friendship statuses concurrently (like FriendsHubView does)
        await withTaskGroup(of: (String, FriendshipStatus).self) { group in
            for profile in profiles.prefix(10) { // Limit concurrent checks
                group.addTask {
                    do {
                        let status = try await self.dataManager.checkFriendshipStatus(for: profile.id)
                        return (profile.id, status)
                    } catch {
                        print("[PeopleSearch] Error checking friendship status for \(profile.id): \(error.localizedDescription)")
                        return (profile.id, .none)
                    }
                }
            }
            
            for await (userId, status) in group {
                await MainActor.run {
                    friendshipStatuses[userId] = status
                }
            }
        }
        
        // Fetch remaining statuses if more than 10 results
        if profiles.count > 10 {
            for profile in profiles.dropFirst(10) {
                do {
                    let status = try await dataManager.checkFriendshipStatus(for: profile.id)
                    await MainActor.run {
                        friendshipStatuses[profile.id] = status
                    }
                } catch {
                    print("[PeopleSearch] Error checking friendship status for \(profile.id): \(error.localizedDescription)")
                    await MainActor.run {
                        friendshipStatuses[profile.id] = .none
                    }
                }
            }
        }
    }
    
    /// Refresh friendship status for a single user
    private func refreshFriendshipStatus(for userId: String) async {
        do {
            let status = try await dataManager.checkFriendshipStatus(for: userId)
            await MainActor.run {
                friendshipStatuses[userId] = status
            }
        } catch {
            print("[PeopleSearch] Error refreshing friendship status for \(userId): \(error.localizedDescription)")
        }
    }
}

