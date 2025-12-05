//
//  ProfileNavigator.swift
//  testMugshot
//
//  Centralized routing for transitioning into profile experiences (self vs others).
//  Ensures every profile entry point – mentions, friends lists, search, etc. – shares
//  the same presentation + logging + fallback behavior.
//

import Foundation
import SwiftUI

@MainActor
final class ProfileNavigator: ObservableObject {
    struct ProfileHandle: Equatable {
        var supabaseUserId: String?
        var username: String?
        var seedProfile: RemoteUserProfile?
        
        init(supabaseUserId: String? = nil, username: String? = nil, seedProfile: RemoteUserProfile? = nil) {
            self.supabaseUserId = supabaseUserId
            self.username = username
            self.seedProfile = seedProfile
        }
        
        static func mention(username: String) -> ProfileHandle {
            ProfileHandle(username: username)
        }
        
        static func supabase(id: String, username: String? = nil, seedProfile: RemoteUserProfile? = nil) -> ProfileHandle {
            ProfileHandle(supabaseUserId: id, username: username, seedProfile: seedProfile)
        }
        
        static func == (lhs: ProfileHandle, rhs: ProfileHandle) -> Bool {
            if lhs.supabaseUserId != rhs.supabaseUserId { return false }
            if (lhs.username?.lowercased() ?? "") != (rhs.username?.lowercased() ?? "") { return false }
            let lhsSeedId = lhs.seedProfile?.id
            let rhsSeedId = rhs.seedProfile?.id
            return lhsSeedId == rhsSeedId
        }
    }
    
    enum Source: String {
        case mentionCaption
        case mentionComment
        case visitCaption
        case feedAuthor
        case friendsList
        case friendSearch
        case friendRequest
        case mutualFriends
        case cafeVisitors
        case savedCafeVisitors
        case notifications
        case other
        
        var logPrefix: String {
            switch self {
            case .mentionCaption, .mentionComment, .visitCaption:
                return "[Navigation] Tag tapped"
            case .feedAuthor:
                return "[Navigation] Feed author tapped"
            case .friendsList:
                return "[Navigation] Friends list tap"
            case .friendSearch:
                return "[Navigation] Search result tap"
            case .friendRequest:
                return "[Navigation] Friend request tap"
            case .mutualFriends:
                return "[Navigation] Mutual friend tap"
            case .cafeVisitors, .savedCafeVisitors:
                return "[Navigation] Cafe visitor tap"
            case .notifications:
                return "[Navigation] Notification route"
            case .other:
                return "[Navigation] Profile route"
            }
        }
    }
    
    struct Presentation: Identifiable, Equatable {
        let id: UUID
        let source: Source
        var handle: ProfileHandle
        var state: State
        
        enum State: Equatable {
            case loading
            case resolved(userId: String, profile: RemoteUserProfile?)
            case error(message: String)
            
            static func == (lhs: State, rhs: State) -> Bool {
                switch (lhs, rhs) {
                case (.loading, .loading):
                    return true
                case (.error(let lMessage), .error(let rMessage)):
                    return lMessage == rMessage
                case (.resolved(let lId, let lProfile), .resolved(let rId, let rProfile)):
                    let lProfileId = lProfile?.id
                    let rProfileId = rProfile?.id
                    return lId == rId && lProfileId == rProfileId
                default:
                    return false
                }
            }
        }
        
        init(id: UUID = UUID(), source: Source, handle: ProfileHandle, state: State) {
            self.id = id
            self.source = source
            self.handle = handle
            self.state = state
        }
    }
    
    @Published var activePresentation: Presentation?
    
    private let dataManager: DataManager
    private weak var tabCoordinator: TabCoordinator?
    private var usernameCache: [String: RemoteUserProfile] = [:]
    private var resolveTask: Task<Void, Never>?
    
    init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
    }
    
    func attach(tabCoordinator: TabCoordinator) {
        self.tabCoordinator = tabCoordinator
    }
    
    func dismissPresentation() {
        resolveTask?.cancel()
        activePresentation = nil
    }
    
    func openProfile(handle: ProfileHandle, source: Source, triggerHaptic: Bool) {
        if triggerHaptic {
            HapticsManager.shared.lightTap()
        }
        
        let normalizedHandle = sanitize(handle: handle)
        
        if let supabaseUserId = normalizedHandle.supabaseUserId {
            routeUsingUserId(
                supabaseUserId,
                username: normalizedHandle.username,
                seedProfile: normalizedHandle.seedProfile,
                source: source
            )
            return
        }
        
        guard let username = normalizedHandle.username, !username.isEmpty else {
            print("\(source.logPrefix): missing username – aborting")
            return
        }
        
        if isCurrentUser(username: username) {
            routeToCurrentUser(source: source, identifier: "@\(username)")
            return
        }
        
        if let cached = usernameCache[username.lowercased()] {
            // Check if cached user is current user before presenting
            if isCurrentUser(userId: cached.id) {
                routeToCurrentUser(source: source, identifier: "@\(username)")
                return
            }
            presentResolved(
                userId: cached.id,
                profile: normalizedHandle.seedProfile ?? cached,
                source: source,
                username: username
            )
            return
        }
        
        // Show loading shell immediately so the sheet feels instant.
        activePresentation = Presentation(
            source: source,
            handle: normalizedHandle,
            state: .loading
        )
        print("\(source.logPrefix): resolving @\(username)")
        
        resolveTask?.cancel()
        resolveTask = Task { [weak self] in
            guard let self else { return }
            await self.resolveUsername(username, seedProfile: normalizedHandle.seedProfile, source: source)
        }
    }
    
    // MARK: - Private Helpers
    
    private func sanitize(handle: ProfileHandle) -> ProfileHandle {
        var username = handle.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let current = username, current.hasPrefix("@") {
            username = String(current.dropFirst())
        }
        return ProfileHandle(
            supabaseUserId: handle.supabaseUserId,
            username: username,
            seedProfile: handle.seedProfile
        )
    }
    
    private func routeUsingUserId(
        _ userId: String,
        username: String?,
        seedProfile: RemoteUserProfile?,
        source: Source
    ) {
        if isCurrentUser(userId: userId) {
            routeToCurrentUser(source: source, identifier: username ?? userId)
        } else {
            presentResolved(
                userId: userId,
                profile: seedProfile,
                source: source,
                username: username
            )
        }
    }
    
    private func routeToCurrentUser(source: Source, identifier: String) {
        print("\(source.logPrefix): \(identifier) is current user → route=ProfileTab")
        tabCoordinator?.switchToProfile()
        dismissPresentation()
    }
    
    private func presentResolved(
        userId: String,
        profile: RemoteUserProfile?,
        source: Source,
        username: String?
    ) {
        let handle = ProfileHandle(
            supabaseUserId: userId,
            username: username ?? profile?.username,
            seedProfile: profile
        )
        
        if var current = activePresentation {
            current.handle = handle
            current.state = .resolved(userId: userId, profile: profile)
            activePresentation = current
        } else {
            activePresentation = Presentation(
                source: source,
                handle: handle,
                state: .resolved(userId: userId, profile: profile)
            )
        }
        
        let label = username.map { "@\($0)" } ?? userId
        print("\(source.logPrefix): \(label) → userId=\(userId) → route=OtherUserProfile")
    }
    
    private func presentError(message: String, source: Source) {
        if var current = activePresentation {
            current.state = .error(message: message)
            activePresentation = current
        } else {
            activePresentation = Presentation(
                source: source,
                handle: ProfileHandle(),
                state: .error(message: message)
            )
        }
        
        print("\(source.logPrefix): error → \(message)")
    }
    
    private func resolveUsername(
        _ username: String,
        seedProfile: RemoteUserProfile?,
        source: Source
    ) async {
        do {
            let users = try await dataManager.searchUsers(query: username)
            guard !Task.isCancelled else { return }
            
            let lower = username.lowercased()
            let resolved = users.first(where: { $0.username.lowercased() == lower }) ?? users.first
            
            guard let user = resolved else {
                presentError(message: "We couldn't find @\(username).", source: source)
                return
            }
            
            usernameCache[user.username.lowercased()] = user
            
            // Check if resolved user is current user before presenting
            if isCurrentUser(userId: user.id) {
                await MainActor.run {
                    routeToCurrentUser(source: source, identifier: "@\(username)")
                }
                return
            }
            
            presentResolved(
                userId: user.id,
                profile: seedProfile ?? user,
                source: source,
                username: username
            )
        } catch {
            guard !Task.isCancelled else { return }
            print("\(source.logPrefix): resolve failed for @\(username) → \(error.localizedDescription)")
            presentError(
                message: "We couldn't load this profile. Please try again.",
                source: source
            )
        }
    }
    
    private func isCurrentUser(userId: String) -> Bool {
        dataManager.appData.supabaseUserId == userId
    }
    
    private func isCurrentUser(username: String) -> Bool {
        guard let currentUsername = dataManager.appData.currentUserUsername else {
            return false
        }
        return currentUsername.compare(username, options: .caseInsensitive) == .orderedSame
    }
}


