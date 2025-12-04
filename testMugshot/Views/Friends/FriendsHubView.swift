//
//  FriendsHubView.swift
//  testMugshot
//
//  Central hub for friend management: search, friends list, and requests.
//

import SwiftUI
import Combine

struct FriendsHubView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    
    @State private var searchQuery: String = ""
    @State private var selectedTab: FriendsTab = .friends
    @State private var searchResults: [RemoteUserProfile] = []
    @State private var friendshipStatuses: [String: FriendshipStatus] = [:]
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    enum FriendsTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.md)
                
                // Tab selector (only show when not searching)
                if searchQuery.isEmpty {
                    DSDesignSegmentedControl(
                        options: FriendsTab.allCases.map { $0.rawValue },
                        selectedIndex: Binding(
                            get: { FriendsTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                            set: { selectedTab = FriendsTab.allCases[$0] }
                        )
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.md)
                }
                
                // Content
                ScrollView {
                    contentView
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.xxl * 2)
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .onAppear {
                print("[Friends] FriendsHubView opened")
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.iconDefault)
            
            TextField("Search by username or name", text: $searchQuery)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: searchQuery) { _, newValue in
                    handleSearchQueryChange(newValue)
                }
            
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                    friendshipStatuses = [:]
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if !searchQuery.isEmpty {
            // Search results
            searchResultsView
        } else {
            // Tab content
            switch selectedTab {
            case .friends:
                FriendsListView(dataManager: dataManager)
            case .requests:
                FriendRequestsContentView(dataManager: dataManager)
            }
        }
    }
    
    // MARK: - Search Results
    
    @ViewBuilder
    private var searchResultsView: some View {
        if searchResults.isEmpty && !isSearching && !searchQuery.isEmpty {
            // No results
            DSBaseCard {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Colors.iconSubtle)
                    
                    Text("No users found")
                        .font(DS.Typography.sectionTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Text("Try a different username or name")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        } else {
            LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                ForEach(searchResults, id: \.id) { profile in
                    FriendSearchResultRow(
                        profile: profile,
                        friendshipStatus: friendshipStatuses[profile.id] ?? .none,
                        dataManager: dataManager,
                        onStatusChanged: {
                            // Refresh friendship status for this user
                            Task {
                                await refreshFriendshipStatus(for: profile.id)
                            }
                        }
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func handleSearchQueryChange(_ newQuery: String) {
        // Cancel any existing search task
        searchTask?.cancel()
        
        let trimmedQuery = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[FriendsSearch] Query changed to: '\(trimmedQuery)'")
        
        if trimmedQuery.isEmpty {
            print("[FriendsSearch] Empty query, clearing results")
            searchResults = []
            friendshipStatuses = [:]
            isSearching = false
            return
        }
        
        // Debounce: wait 300ms before searching
        print("[FriendsSearch] Starting 300ms debounce for query: '\(trimmedQuery)'")
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            } catch {
                print("[FriendsSearch] Debounce cancelled")
                return // Task was cancelled
            }
            
            guard !Task.isCancelled else {
                print("[FriendsSearch] Task cancelled after debounce")
                return
            }
            
            await performSearch(query: trimmedQuery)
        }
    }
    
    @MainActor
    private func performSearch(query: String) async {
        #if DEBUG
        print("[FriendsSearch] performSearch called with query='\(query)'")
        #endif
        isSearching = true
        defer { isSearching = false }
        
        do {
            let results = try await dataManager.searchUsers(query: query)
            
            guard !Task.isCancelled else { return }
            
            searchResults = results
            
            // PERFORMANCE: Batch friendship status checks using concurrent tasks
            // Limited to avoid overwhelming the server
            await withTaskGroup(of: (String, FriendshipStatus).self) { group in
                for profile in results.prefix(10) { // Limit concurrent checks
                    group.addTask {
                        do {
                            let status = try await self.dataManager.checkFriendshipStatus(for: profile.id)
                            return (profile.id, status)
                        } catch {
                            return (profile.id, .none)
                        }
                    }
                }
                
                for await (userId, status) in group {
                    friendshipStatuses[userId] = status
                }
            }
            
            // Fetch remaining statuses if more than 10 results
            if results.count > 10 {
                for profile in results.dropFirst(10) {
                    await refreshFriendshipStatus(for: profile.id)
                }
            }
        } catch {
            #if DEBUG
            print("[FriendsHub] Search error: \(error.localizedDescription)")
            #endif
            searchResults = []
        }
    }
    
    @MainActor
    private func refreshFriendshipStatus(for userId: String) async {
        do {
            let status = try await dataManager.checkFriendshipStatus(for: userId)
            friendshipStatuses[userId] = status
        } catch {
            print("[FriendsHub] Error checking friendship status for \(userId): \(error.localizedDescription)")
            friendshipStatuses[userId] = FriendshipStatus.none
        }
    }
}

// MARK: - Friend Requests Content View (Embedded version)

/// A version of FriendRequestsView that can be embedded without its own NavigationStack
struct FriendRequestsContentView: View {
    @ObservedObject var dataManager: DataManager
    
    @State private var incomingRequests: [FriendRequest] = []
    @State private var outgoingRequests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var currentUserId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
            // Incoming Requests Section
            if !incomingRequests.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    DSSectionHeader("Incoming Requests")
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    
                    ForEach(incomingRequests) { request in
                        if let userId = currentUserId {
                            FriendRequestRow(
                                request: request,
                                isIncoming: true,
                                currentUserId: userId,
                                dataManager: dataManager,
                                onRequestAction: {
                                    Task {
                                        await refreshAfterAction()
                                    }
                                }
                            )
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                    }
                }
            }
            
            // Outgoing Requests Section
            if !outgoingRequests.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    DSSectionHeader("Outgoing Requests")
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    
                    ForEach(outgoingRequests) { request in
                        if let userId = currentUserId {
                            OutgoingRequestRow(
                                request: request,
                                currentUserId: userId,
                                dataManager: dataManager,
                                onRequestAction: {
                                    Task {
                                        await refreshAfterAction()
                                    }
                                }
                            )
                            .padding(.horizontal, DS.Spacing.pagePadding)
                        }
                    }
                }
            }
            
            // Empty State
            if incomingRequests.isEmpty && outgoingRequests.isEmpty && !isLoading {
                DSBaseCard {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(DS.Colors.iconSubtle)
                        
                        Text("No Friend Requests")
                            .font(DS.Typography.sectionTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        Text("You don't have any pending friend requests")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            // Loading State
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .task {
            await loadFriendRequests()
        }
        .refreshable {
            await loadFriendRequests()
        }
    }
    
    private func loadFriendRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = dataManager.appData.supabaseUserId else {
            return
        }
        
        currentUserId = userId
        
        do {
            let requests = try await dataManager.fetchFriendRequests()
            await MainActor.run {
                incomingRequests = requests.incoming
                outgoingRequests = requests.outgoing
            }
            print("[FriendsRequests] Fetched incoming=\(requests.incoming.count), outgoing=\(requests.outgoing.count)")
        } catch {
            print("[FriendsRequests] Error loading friend requests: \(error.localizedDescription)")
        }
    }
    
    private func refreshAfterAction() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        await loadFriendRequests()
        await dataManager.refreshFriendsList()
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow: View {
    let request: FriendRequest
    let currentUserId: String
    @ObservedObject var dataManager: DataManager
    var onRequestAction: (() -> Void)? = nil
    
    @StateObject private var hapticsManager = HapticsManager.shared
    @State private var isLoading = false
    @State private var userProfile: RemoteUserProfile?
    @State private var isLoadingProfile = false
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    
    var body: some View {
        DSBaseCard {
            HStack(spacing: DS.Spacing.md) {
                // Avatar
                ProfileAvatarView(
                    profileImageId: nil,
                    profileImageURL: userProfile?.avatarURL,
                    username: userProfile?.username ?? "user",
                    size: 50
                )
                
                // User info - use flexible layout
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(userProfile?.displayName ?? userProfile?.username ?? "User")
                        .font(DS.Typography.cardTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("@\(userProfile?.username ?? "user")")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                
                // Cancel button - fixed width with icon only
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Button(action: cancelRequest) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .frame(width: 40, height: 36)
                            .background(DS.Colors.cardBackgroundAlt)
                            .cornerRadius(DS.Radius.md)
                    }
                }
            }
        }
        .onTapGesture {
            if !isLoading {
                hapticsManager.lightTap()
                profileNavigator.openProfile(
                    handle: .supabase(
                        id: request.toUserId,
                        username: userProfile?.username,
                        seedProfile: userProfile
                    ),
                    source: .friendRequest,
                    triggerHaptic: false
                )
            }
        }
        .task {
            await loadUserProfile()
        }
    }
    
    private func cancelRequest() {
        hapticsManager.lightTap()
        isLoading = true
        
        Task {
            defer { isLoading = false }
            do {
                try await dataManager.cancelFriendRequest(requestId: request.id)
                print("[FriendsRequests] Canceled outgoing request id=\(request.id)")
                onRequestAction?()
            } catch {
                print("[OutgoingRequestRow] Error canceling request: \(error.localizedDescription)")
                hapticsManager.playError()
            }
        }
    }
    
    private func loadUserProfile() async {
        guard userProfile == nil && !isLoadingProfile else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        do {
            if let profile = try await dataManager.fetchOtherUserProfile(userId: request.toUserId) {
                await MainActor.run {
                    userProfile = profile
                }
            }
        } catch {
            print("[OutgoingRequestRow] Error loading user profile: \(error.localizedDescription)")
        }
    }
}

