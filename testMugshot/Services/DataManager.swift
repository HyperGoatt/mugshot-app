//
//  DataManager.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import Combine
import MapKit
import UIKit

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var appData: AppData = AppData()
    @Published var isCheckingEmailVerification = false
    @Published var authErrorMessage: String?
    @Published var isBootstrapping = true // Track initial load
    
    /// Prevent overlapping refresh operations from cancelling each other.
    private var isRefreshingAuthStatus = false
    
    private let dataKey = "MugshotAppData"
    
    private let authService: SupabaseAuthService
    private let profileService: SupabaseUserProfileService
    private let storageService: SupabaseStorageService
    private let cafeService: SupabaseCafeService
    private let visitService: SupabaseVisitService
    private let socialGraphService: SupabaseSocialGraphService
    private let notificationService: SupabaseNotificationService
    private let userCafeStateService: SupabaseUserCafeStateService
    private let maxRecentSearches = 10
    
    // Network Monitoring
    private let networkMonitor = NetworkMonitor.shared
    @Published var isOffline: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init(
        authService: SupabaseAuthService = .shared,
        profileService: SupabaseUserProfileService = .shared,
        storageService: SupabaseStorageService = .shared,
        cafeService: SupabaseCafeService = .shared,
        visitService: SupabaseVisitService = .shared,
        socialGraphService: SupabaseSocialGraphService = .shared,
        notificationService: SupabaseNotificationService = .shared,
        userCafeStateService: SupabaseUserCafeStateService = .shared
    ) {
        self.authService = authService
        self.profileService = profileService
        self.storageService = storageService
        self.cafeService = cafeService
        self.visitService = visitService
        self.socialGraphService = socialGraphService
        self.notificationService = notificationService
        self.userCafeStateService = userCafeStateService
        
        // Bind network monitor
        networkMonitor.$isConnected
            .receive(on: RunLoop.main)
            .map { !$0 }
            .assign(to: \.isOffline, on: self)
            .store(in: &cancellables)
        
        // Schedule disk cache cleanup
        PhotoCache.shared.cleanDiskCache()
            
        // Try to load existing data, otherwise start fresh
        if let data = UserDefaults.standard.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
            self.appData = decoded
            // PERFORMANCE: Defer image preloading to background after UI is responsive
            // Capture photo paths before async dispatch to avoid MainActor isolation issues
            let photoPaths = decoded.visits.flatMap { $0.photos }
            let profileImageId = decoded.currentUserProfileImageId
            let bannerImageId = decoded.currentUserBannerImageId
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
                PhotoCache.shared.preloadImages(for: photoPaths)
                
                // Preload profile images
                var profileImagePaths: [String] = []
                if let profileId = profileImageId {
                    profileImagePaths.append(profileId)
                }
                if let bannerId = bannerImageId {
                    profileImagePaths.append(bannerId)
                }
                if !profileImagePaths.isEmpty {
                    PhotoCache.shared.preloadImages(for: profileImagePaths)
                }
            }
        } else {
            self.appData = AppData()
        }
        
        Task {
            await bootstrapAuthStateOnLaunch()
        }
    }
    
    // Preload images for all visits when app starts
    private func preloadVisitImages() {
        let allPhotoPaths = appData.visits.flatMap { $0.photos }
        PhotoCache.shared.preloadImages(for: allPhotoPaths)
        
        // Also preload profile and banner images
        var profileImagePaths: [String] = []
        if let profileId = appData.currentUserProfileImageId {
            profileImagePaths.append(profileId)
        }
        if let bannerId = appData.currentUserBannerImageId {
            profileImagePaths.append(bannerId)
        }
        if !profileImagePaths.isEmpty {
            PhotoCache.shared.preloadImages(for: profileImagePaths)
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(appData) {
            UserDefaults.standard.set(encoded, forKey: dataKey)
        }
    }

    // MARK: - Supabase Auth
    
    /// Check if a username is available (not already taken by another user)
    /// Returns true if the username is available, false if taken
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        return try await profileService.checkUsernameAvailability(username)
    }

    func signUp(
        displayName: String,
        username: String,
        email: String,
        password: String
    ) async throws {
        print("[Auth] signUp: Starting signup for email: \(email)")
        authErrorMessage = nil
        
        do {
            // Tuple return type change
            let (session, userId) = try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                username: username
            )

            print("[Auth] signUp: Signup successful - userId: \(userId), displayName: \(displayName), username: \(username)")
            appData.supabaseUserId = userId
            appData.currentUserEmail = email
            appData.currentUserDisplayName = displayName
            appData.currentUserUsername = username
            appData.hasEmailVerified = false
            print("[Auth] signUp: Stored profile data - currentUserDisplayName=\(appData.currentUserDisplayName ?? "nil"), currentUserUsername=\(appData.currentUserUsername ?? "nil")")
            
            // Mark this as a NEW account signup - user should see onboarding flow
            appData.isNewAccountSignup = true

            if let _ = session {
                 print("[Auth] signUp: Session obtained immediately")
                 // If we get a session, we are authenticated, but we still assume unverified
                 // until proven otherwise (unless Supabase config allows unverified sessions)
                 appData.isUserAuthenticated = true
            } else {
                 print("[Auth] signUp: No session (awaiting verification)")
                 // No token = not authenticated
                 appData.isUserAuthenticated = false
            }

            let localUser = User(
                id: UUID(uuidString: userId) ?? UUID(),
                supabaseUserId: userId,
                username: username,
                displayName: displayName,
                location: appData.currentUserLocation ?? "",
                bio: appData.currentUserBio ?? ""
            )
            appData.currentUser = localUser
            save()
            print("[Auth] signUp: Auth state set - isUserAuthenticated=\(appData.isUserAuthenticated), hasEmailVerified=false, isNewAccountSignup=true")
            print("[SignUp] Success – verification email sent to \(email)")
        } catch {
            print("[SignUp] Error – \(error.localizedDescription)")
            throw error
        }
    }
    
    func resendVerificationEmail() async throws {
        guard let email = appData.currentUserEmail else {
            throw SupabaseError.invalidSession
        }
        try await authService.resendVerificationEmail(email: email)
    }

    /// Requests a password reset email for the given address.
    /// This is used by the Sign In screen's "Forgot password?" flow.
    func requestPasswordReset(email: String) async throws {
        try await authService.sendPasswordResetEmail(email: email)
    }
    
    func checkEmailVerificationStatus() async {
        guard let userId = appData.supabaseUserId else {
            print("[Auth] checkEmailVerificationStatus: No supabaseUserId found")
            return
        }
        do {
            print("[Auth] checkEmailVerificationStatus: Checking for userId: \(userId)")
            let isVerified = try await authService.checkEmailVerificationStatus(userId: userId)
            if isVerified {
                print("[Auth] checkEmailVerificationStatus: Email is verified!")
                appData.hasEmailVerified = true
                save()
            } else {
                print("[Auth] checkEmailVerificationStatus: Email not yet verified")
            }
        } catch {
            print("[Auth] checkEmailVerificationStatus: Error - \(error.localizedDescription)")
        }
    }
    
    /// Single source of truth: Refreshes auth status from Supabase and updates app state accordingly
    /// This method determines the correct auth flow state based on:
    /// - Session existence
    /// - Email verification status
    /// - Profile existence in public.users
    @MainActor
    func refreshAuthStatusFromSupabase() async {
        if isRefreshingAuthStatus {
            print("[Auth] refreshAuthStatusFromSupabase: Already refreshing, skipping")
            return
        }
        isRefreshingAuthStatus = true
        defer { isRefreshingAuthStatus = false }
        
        print("[Auth] refreshAuthStatusFromSupabase: Starting")
        
        // Step 1: Check if we have a session
        guard let session = authService.restoreSession() else {
            print("[Auth] refreshAuthStatusFromSupabase: No session found - setting loggedOut")
            appData.isUserAuthenticated = false
            appData.hasEmailVerified = false
            appData.supabaseUserId = nil
            save()
            return
        }
        
        print("[Auth] refreshAuthStatusFromSupabase: Session found - userId=\(session.userId)")
        appData.supabaseUserId = session.userId
        appData.isUserAuthenticated = true
        
        do {
            // Step 2: Fetch current user from Supabase Auth to check email verification
            let userDict = try await authService.fetchCurrentUser()
            let userId = userDict["id"] as? String ?? session.userId
            let email = userDict["email"] as? String
            let emailConfirmedAt = userDict["email_confirmed_at"]
            
            // Determine if email is verified - handle all possible cases
            var isVerified = false
            
            // Check 1: Standard email_confirmed_at field
            if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                isVerified = true
                print("[Auth] refreshAuthStatusFromSupabase: Email is verified (confirmed_at=\(confirmedAtString))")
            }
            
            // Check 2: Fallback to user_metadata.email_verified if standard check fails
            if !isVerified {
                if let metadata = userDict["user_metadata"] as? [String: Any],
                   let metaVerified = metadata["email_verified"] as? Bool,
                   metaVerified == true {
                    isVerified = true
                    print("[Auth] refreshAuthStatusFromSupabase: Email verified via user_metadata.email_verified")
                }
            }
            
            if !isVerified {
                 // Check 3: Log failure reason
                 if emailConfirmedAt == nil || emailConfirmedAt is NSNull {
                     print("[Auth] refreshAuthStatusFromSupabase: Email not verified (email_confirmed_at is null/empty and metadata check failed)")
                 } else {
                     print("[Auth] refreshAuthStatusFromSupabase: Email not verified (email_confirmed_at present but check failed: \(String(describing: emailConfirmedAt)))")
                 }
            }
            
            if let email = email {
                appData.currentUserEmail = email
            }
            
            // Step 3: If email is verified, ensure profile exists and load it
            if isVerified {
                print("[Auth] refreshAuthStatusFromSupabase: Email verified - checking profile")
                appData.hasEmailVerified = true
                
                // Request push notification permissions if we just verified email
                await registerPushNotificationsIfNeeded()
                
                // Fetch or create profile in public.users
                if let profile = try await profileService.fetchUserProfile(userId: userId) {
                    print("[Auth] refreshAuthStatusFromSupabase: Profile found - mapping to local user")
                    mapRemoteUserProfile(profile)
                    // If profile exists in Supabase, profile setup is complete
                    appData.hasCompletedProfileSetup = true
                    print("[Auth] refreshAuthStatusFromSupabase: Profile exists - setting hasCompletedProfileSetup=true")
                } else {
                    print("[Auth] refreshAuthStatusFromSupabase: No profile found - attempting to create from signup data")
                    // Profile doesn't exist - try to create it from signup data if we have it
                    // Use the signup values from appData (set during signUp), never derive from email
                    let userUUID = UUID(uuidString: userId) ?? UUID()
                    // Prefer signup values, only use minimal fallbacks if truly missing
                    let username = appData.currentUserUsername ?? "user"
                    let displayName = appData.currentUserDisplayName ?? username.capitalized
                    
                    // Try to create the profile automatically if we have the required data
                    if !username.isEmpty && username != "user" {
                        do {
                            let remoteProfile = RemoteUserProfile(
                                id: userId,
                                displayName: displayName,
                                username: username.lowercased(),
                                bio: appData.currentUserBio,
                                location: appData.currentUserLocation,
                                favoriteDrink: appData.currentUserFavoriteDrink,
                                instagramHandle: appData.currentUserInstagramHandle,
                                avatarURL: appData.currentUserAvatarURL,
                                bannerURL: appData.currentUserBannerURL,
                                createdAt: nil,
                                updatedAt: nil
                            )
                            let savedProfile = try await profileService.upsertUserProfile(remoteProfile)
                            print("[Auth] refreshAuthStatusFromSupabase: Profile created successfully - id=\(savedProfile.id)")
                            mapRemoteUserProfile(savedProfile)
                            // Profile was successfully created/upserted, so setup is complete
                            appData.hasCompletedProfileSetup = true
                            print("[Auth] refreshAuthStatusFromSupabase: Profile auto-created - setting hasCompletedProfileSetup=true")
                        } catch {
                            print("[Auth] refreshAuthStatusFromSupabase: Failed to auto-create profile: \(error.localizedDescription). User will need to complete profile setup.")
                            // Fall back to creating local user only
                            if appData.currentUser == nil {
                                appData.currentUser = User(
                                    id: userUUID,
                                    supabaseUserId: userId,
                                    username: username,
                                    displayName: displayName,
                                    location: appData.currentUserLocation ?? "",
                                    bio: appData.currentUserBio ?? ""
                                )
                            }
                        }
                    } else {
                        print("[Auth] refreshAuthStatusFromSupabase: No profile found and insufficient signup data - will be created during profile setup")
                        // Profile doesn't exist yet - user needs to complete profile setup
                        if appData.currentUser == nil {
                            appData.currentUser = User(
                                id: userUUID,
                                supabaseUserId: userId,
                                username: username,
                                displayName: displayName,
                                location: appData.currentUserLocation ?? "",
                                bio: appData.currentUserBio ?? ""
                            )
                        }
                    }
                }
                
                // Load rating template if it exists
                if let template = try? await profileService.fetchRatingTemplate(userId: userId) {
                    appData.ratingTemplate = template.toLocalRatingTemplate()
                }
                
                // Refresh visits
                try? await refreshProfileVisits()
                
                // Restore favorites and wishlist
                await fetchAndApplyUserCafeStates()
            } else {
                print("[Auth] refreshAuthStatusFromSupabase: Email not verified - awaiting verification")
                appData.hasEmailVerified = false
            }
            
            // Always save state after checking verification status
            save()
            print("[Auth] refreshAuthStatusFromSupabase: Complete - isUserAuthenticated=\(appData.isUserAuthenticated), hasEmailVerified=\(appData.hasEmailVerified)")
        } catch let error as SupabaseError {
            print("[Auth] refreshAuthStatusFromSupabase: SupabaseError - \(error.localizedDescription)")
            
            // Check if this is an expired token error that we should try to refresh
            var isExpiredTokenError = false
            if case .server(let status, let message) = error {
                let messageLower = message?.lowercased() ?? ""
                isExpiredTokenError = (status == 401 || status == 403) && 
                                     (messageLower.contains("expired") || 
                                      messageLower.contains("bad_jwt"))
            }
            
            // If we have an expired token error and a session, try to refresh it
            if isExpiredTokenError, let session = authService.restoreSession(), session.refreshToken != nil {
                print("[Auth] refreshAuthStatusFromSupabase: Detected expired token, attempting session refresh")
                do {
                    let refreshedSession = try await authService.refreshSession()
                    print("[Auth] refreshAuthStatusFromSupabase: Session refreshed successfully, retrying fetchCurrentUser")
                    
                    // Retry fetching user with refreshed session
                    let userDict = try await authService.fetchCurrentUser()
                    let userId = userDict["id"] as? String ?? refreshedSession.userId
                    let email = userDict["email"] as? String
                    let emailConfirmedAt = userDict["email_confirmed_at"]
                    
                    // Determine if email is verified
                    var isVerified = false
                    if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                        isVerified = true
                        print("[Auth] refreshAuthStatusFromSupabase: Email is verified (confirmed_at=\(confirmedAtString))")
                    } else if let metadata = userDict["user_metadata"] as? [String: Any],
                              let metaVerified = metadata["email_verified"] as? Bool,
                              metaVerified == true {
                        isVerified = true
                        print("[Auth] refreshAuthStatusFromSupabase: Email verified via user_metadata.email_verified")
                    }
                    
                    if let email = email {
                        appData.currentUserEmail = email
                    }
                    
                    // Update auth state
                    appData.supabaseUserId = userId
                    appData.isUserAuthenticated = true
                    appData.hasEmailVerified = isVerified
                    
                    // If email is verified, ensure profile exists and load it
                    if isVerified {
                        print("[Auth] refreshAuthStatusFromSupabase: Email verified - checking profile")
                        
                        if let profile = try await profileService.fetchUserProfile(userId: userId) {
                            print("[Auth] refreshAuthStatusFromSupabase: Profile found - mapping to local user")
                            mapRemoteUserProfile(profile)
                        } else {
                            print("[Auth] refreshAuthStatusFromSupabase: No profile found - attempting to create from signup data")
                            // Try to auto-create profile (same logic as above)
                            let userUUID = UUID(uuidString: userId) ?? UUID()
                            let username = appData.currentUserUsername ?? "user"
                            let displayName = appData.currentUserDisplayName ?? username.capitalized
                            
                            if !username.isEmpty && username != "user" {
                                do {
                                    let remoteProfile = RemoteUserProfile(
                                        id: userId,
                                        displayName: displayName,
                                        username: username.lowercased(),
                                        bio: appData.currentUserBio,
                                        location: appData.currentUserLocation,
                                        favoriteDrink: appData.currentUserFavoriteDrink,
                                        instagramHandle: appData.currentUserInstagramHandle,
                                        avatarURL: appData.currentUserAvatarURL,
                                        bannerURL: appData.currentUserBannerURL,
                                        createdAt: nil,
                                        updatedAt: nil
                                    )
                                    let savedProfile = try await profileService.upsertUserProfile(remoteProfile)
                                    print("[Auth] refreshAuthStatusFromSupabase: Profile created successfully")
                                    mapRemoteUserProfile(savedProfile)
                                } catch {
                                    print("[Auth] refreshAuthStatusFromSupabase: Failed to auto-create profile: \(error.localizedDescription)")
                                    if appData.currentUser == nil {
                                        appData.currentUser = User(
                                            id: userUUID,
                                            supabaseUserId: userId,
                                            username: username,
                                            displayName: displayName,
                                            location: appData.currentUserLocation ?? "",
                                            bio: appData.currentUserBio ?? ""
                                        )
                                    }
                                }
                            } else {
                                if appData.currentUser == nil {
                                    appData.currentUser = User(
                                        id: userUUID,
                                        supabaseUserId: userId,
                                        username: username,
                                        displayName: displayName,
                                        location: appData.currentUserLocation ?? "",
                                        bio: appData.currentUserBio ?? ""
                                    )
                                }
                            }
                        }
                        
                        // Load rating template if it exists
                        if let template = try? await profileService.fetchRatingTemplate(userId: userId) {
                            appData.ratingTemplate = template.toLocalRatingTemplate()
                        }
                        
                        // Refresh visits
                        try? await refreshProfileVisits()
                        
                        // Restore favorites and wishlist
                        await fetchAndApplyUserCafeStates()
                    }
                    
                    save()
                    print("[Auth] refreshAuthStatusFromSupabase: Complete after refresh - isUserAuthenticated=\(appData.isUserAuthenticated), hasEmailVerified=\(appData.hasEmailVerified)")
                    return
                } catch {
                    print("[Auth] refreshAuthStatusFromSupabase: Session refresh failed - \(error.localizedDescription). Clearing session.")
                    // Refresh failed - clear the session
                    await authService.signOut()
                    appData.isUserAuthenticated = false
                    appData.hasEmailVerified = false
                    appData.supabaseUserId = nil
                    save()
                    return
                }
            }
            
            // Do not automatically log out on server errors, only on invalid session
            if case .invalidSession = error {
                // Session expired - clear auth state
                print("[Auth] refreshAuthStatusFromSupabase: Invalid session - clearing auth state")
                appData.isUserAuthenticated = false
                appData.hasEmailVerified = false
                appData.supabaseUserId = nil
            } else {
                // Special-case cancelled requests (typically -999)
                if case .network(let message) = error,
                   message.localizedCaseInsensitiveContains("cancelled") ||
                   message.localizedCaseInsensitiveContains("canceled") ||
                   message.contains("-999") {
                    print("[Auth] refreshAuthStatusFromSupabase: Request was cancelled, leaving auth state unchanged")
                } else {
                    print("[Auth] refreshAuthStatusFromSupabase: Non-session error, defaulting to unverified")
                    appData.hasEmailVerified = false
                }
            }
            save()
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("[Auth] refreshAuthStatusFromSupabase: URLSession cancelled, leaving auth state unchanged")
            } else {
                print("[Auth] refreshAuthStatusFromSupabase: Error - \(error.localizedDescription)")
                // On error, assume email is not verified to be safe
                appData.hasEmailVerified = false
                save()
            }
        }
    }
    
    /// Called when user taps "I've verified my email" button
    /// Verifies email status with Supabase and advances the flow if verified
    @MainActor
    func confirmEmailAndAdvanceFlow() async {
        print("[Auth] confirmEmailAndAdvanceFlow: Button tapped")
        isCheckingEmailVerification = true
        authErrorMessage = nil
        
        // We might not have a session if we came from fresh launch
        // Try to restore session first
        if authService.restoreSession() == nil {
             print("[Auth] confirmEmailAndAdvanceFlow: No local session found. User needs to sign in or we need to rely on checkEmailVerificationStatus (if possible without session)")
             // NOTE: We can't easily check verification without a session using standard endpoints usually.
             // But if the user JUST signed up, they might not have a session token yet if one wasn't returned.
             // In that case, they might need to "Sign In" to prove they are verified.
             
             // However, Supabase usually allows sign-in ONLY if verified.
             // So if we try to sign in and it works -> verified.
             
             if let email = appData.currentUserEmail, !email.isEmpty {
                  // We can't auto-sign-in without password.
                  // If no session, we direct user to sign in?
                  authErrorMessage = "Please sign in to continue."
                  isCheckingEmailVerification = false
                  // We could potentially reset `isUserAuthenticated` to false to trigger sign in screen,
                  // but we are in `VerifyEmailView`.
                  return
             }
        }
        
        await refreshAuthStatusFromSupabase()
        
        if appData.hasEmailVerified {
             print("[Auth] confirmEmailAndAdvanceFlow: Verified!")
        } else {
             print("[Auth] confirmEmailAndAdvanceFlow: Not verified yet")
             authErrorMessage = "Looks like your email isn't verified yet. Tap the link in your inbox, then try again."
        }
        
        isCheckingEmailVerification = false
    }

    // MARK: - Sign In Flow
    // Signs in user, fetches profile from public.users by Supabase user ID,
    // loads rating template and visits, then updates local AppData.
    // All state mutations happen on @MainActor automatically.
    func signIn(email: String, password: String) async throws {
        print("[DataManager] signIn started for email: \(email)")
        
        // Step 1: Authenticate with Supabase Auth
        print("[DataManager] Calling SupabaseAuthService.signIn...")
        let session = try await authService.signIn(email: email, password: password)
        print("[DataManager] auth success - userId: \(session.userId)")

        // Step 2: Update auth state
        appData.supabaseUserId = session.userId
        appData.isUserAuthenticated = true
        appData.currentUserEmail = email
        // Don't set verified yet - verify it first
        appData.hasEmailVerified = false
        
        // IMPORTANT: This is a returning user login, NOT a new signup
        // They should skip the marketing onboarding flow entirely
        appData.isNewAccountSignup = false
        
        save()

        // Step 3: Verify email status and fetch profile
        print("[DataManager] Verifying email status and fetching profile...")
        await refreshAuthStatusFromSupabase()
        
        if !appData.hasEmailVerified {
             print("[DataManager] Sign in successful but email not verified")
             // User remains on verify screen
             return
        }

        // Step 4: Fetch rating template (optional, don't fail sign-in if this fails)
        print("[DataManager] Fetching rating template...")
        if let template = try? await profileService.fetchRatingTemplate(userId: session.userId) {
            print("[DataManager] Rating template found")
            appData.ratingTemplate = template.toLocalRatingTemplate()
        } else {
            print("[DataManager] No rating template found (optional)")
        }
        
        // Step 5: Refresh profile visits (this might take a while, but shouldn't block sign-in)
        print("[DataManager] Refreshing profile visits...")
        do {
            try await refreshProfileVisits()
            print("[DataManager] Profile visits refreshed")
        } catch {
            // Don't fail sign-in if visits refresh fails - just log it
            print("[DataManager] Error refreshing profile visits (non-fatal): \(error.localizedDescription)")
        }
        
        // Step 5b: Restore favorites and wishlist from Supabase
        print("[DataManager] Restoring favorites and wishlist...")
        await fetchAndApplyUserCafeStates()

        // Step 6: Ensure currentUser is set with correct identity (userId must match supabaseUserId)
        let userUUID = UUID(uuidString: session.userId) ?? UUID()
        if appData.currentUser == nil {
            print("[Identity] Creating currentUser from profile data - id=\(userUUID.uuidString), username=\(appData.currentUserUsername ?? "nil")")
            // Prefer existing values from appData (from profile or previous session), only use email as last resort
            let username = appData.currentUserUsername ?? email.components(separatedBy: "@").first ?? "user"
            appData.currentUser = User(
                id: userUUID,
                supabaseUserId: session.userId,
                username: username,
                displayName: appData.currentUserDisplayName,
                location: appData.currentUserLocation ?? "",
                bio: appData.currentUserBio ?? ""
            )
        } else {
            print("[Identity] Updating existing currentUser - preserving id=\(appData.currentUser!.id), setting supabaseUserId=\(session.userId)")
            // Preserve User.id (identity) but update supabaseUserId reference
            var updatedUser = appData.currentUser!
            updatedUser.supabaseUserId = session.userId
            // Ensure id matches supabaseUserId (migrate if needed)
            if updatedUser.id != userUUID {
                print("[Identity] Migrating User.id from \(updatedUser.id) to \(userUUID) to match supabaseUserId")
                updatedUser = User(
                    id: userUUID,
                    supabaseUserId: session.userId,
                    username: updatedUser.username,
                    displayName: updatedUser.displayName,
                    location: updatedUser.location,
                    avatarImageName: updatedUser.avatarImageName,
                    profileImageID: updatedUser.profileImageID,
                    bannerImageID: updatedUser.bannerImageID,
                    bio: updatedUser.bio,
                    instagramURL: updatedUser.instagramURL,
                    websiteURL: updatedUser.websiteURL,
                    favoriteDrink: updatedUser.favoriteDrink
                )
            }
            appData.currentUser = updatedUser
        }

        save()
        print("[Identity] Sign in completed - userId=\(session.userId), username=\(appData.currentUser?.username ?? "nil"), displayName=\(appData.currentUser?.displayName ?? "nil")")
        print("[DataManager] signIn completed OK - user is signed in and ready")
        
        // Step 7: Request push notification permissions and register token
        await registerPushNotificationsIfNeeded()
        
        // Step 8: Refresh friends list to get accurate count
        print("[DataManager] Refreshing friends list...")
        await refreshFriendsList()
    }

    func bootstrapAuthStateOnLaunch() async {
        print("[Auth] bootstrapAuthStateOnLaunch: Starting")
        isBootstrapping = true
        
        // Use the single source of truth method to refresh auth status
        await refreshAuthStatusFromSupabase()
        
        // Refresh friends list and notifications if authenticated to get accurate counts
        if appData.isUserAuthenticated && appData.hasEmailVerified {
            print("[Auth] bootstrapAuthStateOnLaunch: Refreshing friends list and notifications")
            await refreshFriendsList()
            await refreshNotifications()
        }
        
        isBootstrapping = false
        print("[Auth] bootstrapAuthStateOnLaunch: Complete")
    }

    func completeProfileSetupWithSupabase() async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }

        var avatarURL = appData.currentUserAvatarURL
        if let profileId = appData.currentUserProfileImageId,
           let image = PhotoCache.shared.retrieve(forKey: profileId) {
            do {
                let path = "\(supabaseUserId)/avatar-\(profileId).jpg"
                avatarURL = try await storageService.uploadImage(image, path: path)
                print("[ProfileSetup] Avatar image uploaded successfully: \(avatarURL ?? "nil")")
            } catch {
                print("[ProfileSetup] Failed to upload avatar image: \(error.localizedDescription). Continuing without avatar.")
                // Continue without avatar - profile creation should still succeed
            }
        }

        var bannerURL = appData.currentUserBannerURL
        if let bannerId = appData.currentUserBannerImageId,
           let image = PhotoCache.shared.retrieve(forKey: bannerId) {
            do {
                let path = "\(supabaseUserId)/banner-\(bannerId).jpg"
                bannerURL = try await storageService.uploadImage(image, path: path)
                print("[ProfileSetup] Banner image uploaded successfully: \(bannerURL ?? "nil")")
            } catch {
                print("[ProfileSetup] Failed to upload banner image: \(error.localizedDescription). Continuing without banner.")
                // Continue without banner - profile creation should still succeed
            }
        }

        // Use onboarding values for display name and username, never fall back to email
        // These should have been set during signup and preserved through the flow
        let finalDisplayName: String
        if let displayName = appData.currentUserDisplayName, !displayName.isEmpty {
            finalDisplayName = displayName
            print("[ProfileSetup] Using signup displayName: \(displayName)")
        } else if let username = appData.currentUserUsername, !username.isEmpty {
            finalDisplayName = username.capitalized
            print("[ProfileSetup] Using username as displayName fallback: \(username.capitalized)")
        } else {
            finalDisplayName = "User"
            print("[ProfileSetup] WARNING: No displayName or username found, using 'User' fallback")
        }
        
        let finalUsername: String
        if let username = appData.currentUserUsername, !username.isEmpty {
            finalUsername = username.lowercased()
            print("[ProfileSetup] Using signup username: \(username.lowercased())")
        } else {
            finalUsername = "user"
            print("[ProfileSetup] WARNING: No username found, using 'user' fallback")
        }
        
        let remoteProfile = RemoteUserProfile(
            id: supabaseUserId,
            displayName: finalDisplayName,
            username: finalUsername,
            bio: appData.currentUserBio,
            location: appData.currentUserLocation,
            favoriteDrink: appData.currentUserFavoriteDrink,
            instagramHandle: appData.currentUserInstagramHandle,
            avatarURL: avatarURL,
            bannerURL: bannerURL,
            createdAt: nil,
            updatedAt: nil
        )

        let savedProfile = try await profileService.upsertUserProfile(remoteProfile)

        if let templateUserId = appData.supabaseUserId {
            let remoteTemplate = RemoteRatingTemplate.fromLocal(userId: templateUserId, template: appData.ratingTemplate)
            _ = try? await profileService.upsertRatingTemplate(remoteTemplate)
        }

        mapRemoteUserProfile(savedProfile)
        // Ensure display name and username are preserved (don't let remote overwrite with wrong values)
        appData.currentUserDisplayName = finalDisplayName
        appData.currentUserUsername = finalUsername
        appData.currentUserAvatarURL = avatarURL
        appData.currentUserBannerURL = bannerURL
        appData.hasCompletedProfileSetup = true
        
        // Clear the new account signup flag - onboarding is complete
        appData.isNewAccountSignup = false
        
        try await refreshProfileVisits()
        save()
        
        // Request push notification permissions after profile setup
        await registerPushNotificationsIfNeeded()
        
        // Refresh friends list (should be empty for new users, but ensures accurate state)
        await refreshFriendsList()
    }
    
    private func mapRemoteUserProfile(_ profile: RemoteUserProfile) {
        appData.supabaseUserId = profile.id
        
        // Helper to check if a value is a meaningful user-entered value (not a generic default)
        func isGenericDefault(_ value: String) -> Bool {
            let lowered = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return lowered == "user" || lowered == "username" || lowered.isEmpty
        }
        
        // Helper to check if local has a meaningful value that should be preserved
        func localHasMeaningfulValue(_ local: String?) -> Bool {
            guard let local = local else { return false }
            return !isGenericDefault(local)
        }
        
        // For display name: prefer local signup value over generic remote defaults
        // Only update from remote if: remote is meaningful AND (local is empty OR local is generic)
        if !profile.displayName.isEmpty && !isGenericDefault(profile.displayName) {
            // Remote has meaningful value - use it unless local also has meaningful value
            if !localHasMeaningfulValue(appData.currentUserDisplayName) {
                appData.currentUserDisplayName = profile.displayName
                print("[mapRemoteUserProfile] Updated displayName from remote: \(profile.displayName)")
            } else {
                print("[mapRemoteUserProfile] Preserved local displayName: \(appData.currentUserDisplayName ?? "nil") (remote was: \(profile.displayName))")
            }
        } else if localHasMeaningfulValue(appData.currentUserDisplayName) {
            // Remote is generic but local has good value - keep local
            print("[mapRemoteUserProfile] Kept local displayName: \(appData.currentUserDisplayName ?? "nil") (remote was generic: \(profile.displayName))")
        }
        
        // For username: same logic - preserve local signup value over generic remote defaults
        if !profile.username.isEmpty && !isGenericDefault(profile.username) {
            // Remote has meaningful value - use it unless local also has meaningful value
            if !localHasMeaningfulValue(appData.currentUserUsername) {
                appData.currentUserUsername = profile.username
                print("[mapRemoteUserProfile] Updated username from remote: \(profile.username)")
            } else {
                print("[mapRemoteUserProfile] Preserved local username: \(appData.currentUserUsername ?? "nil") (remote was: \(profile.username))")
            }
        } else if localHasMeaningfulValue(appData.currentUserUsername) {
            // Remote is generic but local has good value - keep local
            print("[mapRemoteUserProfile] Kept local username: \(appData.currentUserUsername ?? "nil") (remote was generic: \(profile.username))")
        }
        
        // For optional fields, only update if remote has a value
        if let bio = profile.bio, !bio.isEmpty {
            appData.currentUserBio = bio
        }
        if let location = profile.location, !location.isEmpty {
            appData.currentUserLocation = location
        }
        if let favoriteDrink = profile.favoriteDrink, !favoriteDrink.isEmpty {
            appData.currentUserFavoriteDrink = favoriteDrink
        }
        if let instagram = profile.instagramHandle, !instagram.isEmpty {
            appData.currentUserInstagramHandle = instagram
        }
        if let website = profile.websiteURL, !website.isEmpty {
            appData.currentUserWebsite = website
        }
        // URLs should always be updated from remote (authoritative source)
        if let avatarURL = profile.avatarURL {
            appData.currentUserAvatarURL = avatarURL
        }
        if let bannerURL = profile.bannerURL {
            appData.currentUserBannerURL = bannerURL
        }

        // When creating localUser, use the preserved appData values (which may be local signup values)
        let remoteUUID = UUID(uuidString: profile.id) ?? appData.currentUser?.id ?? UUID()
        var localUser = User(
            id: remoteUUID,
            supabaseUserId: profile.id,
            username: appData.currentUserUsername ?? profile.username,
            displayName: appData.currentUserDisplayName ?? profile.displayName,
            location: profile.location ?? appData.currentUserLocation ?? "",
            avatarImageName: appData.currentUser?.avatarImageName,
            profileImageID: appData.currentUser?.profileImageID,
            bannerImageID: appData.currentUser?.bannerImageID,
            bio: profile.bio ?? appData.currentUserBio ?? "",
            instagramURL: profile.instagramHandle,
            websiteURL: profile.websiteURL ?? appData.currentUser?.websiteURL,
            favoriteDrink: profile.favoriteDrink ?? appData.currentUserFavoriteDrink
        )
        localUser.supabaseUserId = profile.id
        appData.currentUser = localUser
    }

    private func applyEmailFallbackIdentity(email: String) {
        let localPart = email.components(separatedBy: "@").first ?? "user"
        if appData.currentUserUsername == nil {
            appData.currentUserUsername = localPart.lowercased()
        }
        if appData.currentUserDisplayName == nil {
            appData.currentUserDisplayName = localPart.capitalized
        }
    }

    // MARK: - User Operations
    
    /// Update current user profile by Supabase userId (identity-safe: updates existing user)
    func updateCurrentUserProfile(
        displayName: String?,
        username: String,
        bio: String?,
        location: String?,
        favoriteDrink: String?,
        instagramHandle: String?,
        websiteURL: String?,
        avatarImage: UIImage?,
        bannerImage: UIImage?
    ) async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        print("[Identity] Updating profile for userId=\(supabaseUserId) with username=\(username), displayName=\(displayName ?? "nil")")
        
        // Upload images if provided
        var avatarURL = appData.currentUserAvatarURL
        if let avatarImage = avatarImage {
            do {
                let path = "\(supabaseUserId)/avatar-\(UUID().uuidString).jpg"
                avatarURL = try await storageService.uploadImage(avatarImage, path: path)
                print("[Identity] Avatar image uploaded successfully: \(avatarURL ?? "nil")")
            } catch {
                print("[Identity] Failed to upload avatar image: \(error.localizedDescription). Continuing without avatar update.")
                // Continue without updating avatar URL - user can retry later
            }
        }
        
        var bannerURL = appData.currentUserBannerURL
        if let bannerImage = bannerImage {
            do {
                let path = "\(supabaseUserId)/banner-\(UUID().uuidString).jpg"
                bannerURL = try await storageService.uploadImage(bannerImage, path: path)
                print("[Identity] Banner image uploaded successfully: \(bannerURL ?? "nil")")
            } catch {
                print("[Identity] Failed to upload banner image: \(error.localizedDescription). Continuing without banner update.")
                // Continue without updating banner URL - user can retry later
            }
        }
        
        // Build update payload (all fields are included - Supabase will only update provided ones)
        var payload = RemoteUserProfile.UpdatePayload()
        payload.username = username
        payload.displayName = displayName
        payload.bio = bio
        payload.location = location
        payload.favoriteDrink = favoriteDrink
        payload.instagramHandle = instagramHandle
        payload.websiteURL = websiteURL
        if let avatarURL = avatarURL {
            payload.avatarURL = avatarURL
        }
        if let bannerURL = bannerURL {
            payload.bannerURL = bannerURL
        }
        
        // Update in Supabase by userId (identity-safe)
        let savedProfile = try await profileService.updateUserProfile(for: supabaseUserId, with: payload)
        
        // Update local state (preserve User.id - never change identity)
        if let currentUser = appData.currentUser {
            var updatedUser = currentUser
            updatedUser.username = savedProfile.username
            updatedUser.displayName = savedProfile.displayName
            updatedUser.bio = savedProfile.bio ?? ""
            updatedUser.location = savedProfile.location ?? ""
            updatedUser.favoriteDrink = savedProfile.favoriteDrink
            updatedUser.instagramURL = savedProfile.instagramHandle
            updatedUser.websiteURL = websiteURL
            // Preserve id - never change identity
            appData.currentUser = updatedUser
        }
        
        // Update AppData fields
        appData.currentUserDisplayName = savedProfile.displayName
        appData.currentUserUsername = savedProfile.username
        appData.currentUserBio = savedProfile.bio
        appData.currentUserLocation = savedProfile.location
        appData.currentUserFavoriteDrink = savedProfile.favoriteDrink
        appData.currentUserInstagramHandle = savedProfile.instagramHandle
        appData.currentUserWebsite = websiteURL
        appData.currentUserAvatarURL = avatarURL
        appData.currentUserBannerURL = bannerURL
        
        save()
        print("[Identity] Profile updated successfully - userId=\(supabaseUserId) (unchanged), username=\(savedProfile.username), displayName=\(savedProfile.displayName)")
    }
    
    func setCurrentUser(_ user: User) {
        appData.currentUser = user
        save()
    }
    
    func updateCurrentUser(_ user: User) {
        appData.currentUser = user
        save()
    }
    
    func logout() {
        // Log what we're clearing for debugging
        let favoritesCount = appData.cafes.filter { $0.isFavorite }.count
        let wantToTryCount = appData.cafes.filter { $0.wantToTry }.count
        let visitsCount = appData.visits.count
        let cafesCount = appData.cafes.count
        
        print("[Logout] Starting logout - clearing LOCAL state only")
        print("[Logout] Local data being cleared:")
        print("[Logout]   - Favorites: \(favoritesCount)")
        print("[Logout]   - Want to Try: \(wantToTryCount)")
        print("[Logout]   - Visits: \(visitsCount)")
        print("[Logout]   - Cafes: \(cafesCount)")
        print("[Logout] ℹ️ Backend data (Supabase) is preserved and will be restored on next login")
        
        // Preserve certain device-specific settings that shouldn't reset on logout
        let preserveMarketingOnboarding = appData.hasSeenMarketingOnboarding
        
        Task {
            await authService.signOut()
        }
        
        // Clear all data and reset to initial state
        appData = AppData()
        
        // Restore device-specific settings
        // hasSeenMarketingOnboarding is device-specific (user has seen the intro)
        // but isNewAccountSignup is NOT restored (that's account-specific)
        appData.hasSeenMarketingOnboarding = preserveMarketingOnboarding
        
        save()
        // Clear photo cache
        PhotoCache.shared.clear()
        // Note: We don't delete the device token on logout - it will be cleaned up
        // when the user logs in again or if they uninstall the app
        
        print("[Logout] ✅ Local state cleared successfully")
    }
    
    func deleteAccount() async throws {
        print("[DataManager] DELETE ACCOUNT requested")
        
        // 1. Try to delete the user profile from public.users
        // This relies on RLS allowing users to delete their own profile
        // If this fails, we still proceed with local cleanup
        if appData.supabaseUserId != nil {
            // Assuming profileService has a delete method or we use a raw query
            // Since profileService might not have it, we'll try to delete the user via Auth if possible
            // or just proceed. For Alpha, the most critical part is ensuring the user *feels* deleted locally.
            // NOTE: Supabase client-side deletion is restricted. 
            // We will try to call an RPC if it existed, but for now we'll rely on the manual profile deletion 
            // if we had that method.
            
            // For now, we will sign out and clear data, effectively "deleting" access from this device.
            // In a production app with Edge Functions, we would call:
            // try await supabase.functions.invoke("delete-user")
        }
        
        // 2. Sign out from Auth
        await authService.signOut()
        
        // 3. Clear all local data
        appData = AppData()
        appData.hasSeenMarketingOnboarding = true // Keep this so they aren't treated as a fresh install if they reinstall immediately
        save()
        PhotoCache.shared.clear()
    }
    
    // MARK: - Cafe Operations
    func addCafe(_ cafe: Cafe) {
        appData.cafes.append(cafe)
        save()
    }
    
    func updateCafe(_ cafe: Cafe) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
            appData.cafes[index] = cafe
            save()
        }
    }
    
    func getCafe(id: UUID) -> Cafe? {
        return appData.cafes.first(where: { $0.id == id })
    }
    
    func toggleCafeFavorite(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            let wasFavorite = appData.cafes[index].isFavorite
            appData.cafes[index].isFavorite.toggle()
            save()
            syncWidgetData() // Update widgets when favorites change
            print("[Favorites] Toggled favorite for \(appData.cafes[index].name) → \(!wasFavorite)")
            
            // Sync to Supabase in background
            let cafe = appData.cafes[index]
            Task {
                await syncCafeStateToSupabase(cafe: cafe)
            }
        } else {
            print("⚠️ [Favorites] toggleCafeFavorite: Cafe \(cafeId) not found in user's cafe list")
        }
    }
    
    /// Toggle favorite for a cafe, adding it to the list if it doesn't exist
    func toggleCafeFavorite(cafe: Cafe) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
            // Cafe exists, just toggle
            let wasFavorite = appData.cafes[index].isFavorite
            appData.cafes[index].isFavorite.toggle()
            save()
            syncWidgetData() // Update widgets when favorites change
            print("[Favorites] Toggled favorite for \(cafe.name) → \(!wasFavorite)")
            
            // Sync to Supabase in background
            let updatedCafe = appData.cafes[index]
            Task {
                await syncCafeStateToSupabase(cafe: updatedCafe)
            }
        } else {
            // Cafe doesn't exist, add it with isFavorite = true (user is favoriting it)
            var newCafe = cafe
            newCafe.isFavorite = true
            appData.cafes.append(newCafe)
            save()
            syncWidgetData() // Update widgets when favorites change
            print("[Favorites] Toggled favorite for \(cafe.name) → true (added new cafe)")
            
            // Sync to Supabase in background
            Task {
                await syncCafeStateToSupabase(cafe: newCafe)
            }
        }
    }
    
    func toggleCafeWantToTry(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            // Cafe exists, just toggle
            let wasWantToTry = appData.cafes[index].wantToTry
            appData.cafes[index].wantToTry.toggle()
            save()
            syncWidgetData() // Update widgets when want-to-try changes
            print("[WantToTry] Toggled wantToTry for \(appData.cafes[index].name) → \(!wasWantToTry)")
            
            // Sync to Supabase in background
            let cafe = appData.cafes[index]
            Task {
                await syncCafeStateToSupabase(cafe: cafe)
            }
        } else {
            // Cafe doesn't exist in user's list yet - need to get it from visit or create it
            // This can happen when user bookmarks a cafe from a feed post
            // For now, we'll need the cafe object to add it
            print("⚠️ [WantToTry] toggleCafeWantToTry: Cafe \(cafeId) not found in user's cafe list")
        }
    }
    
    /// Toggle wantToTry for a cafe, adding it to the list if it doesn't exist
    func toggleCafeWantToTry(cafe: Cafe) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
            // Cafe exists, just toggle
            let wasWantToTry = appData.cafes[index].wantToTry
            appData.cafes[index].wantToTry.toggle()
            save()
            syncWidgetData() // Update widgets when want-to-try changes
            print("[WantToTry] Toggled wantToTry for \(cafe.name) → \(!wasWantToTry)")
            
            // Sync to Supabase in background
            let updatedCafe = appData.cafes[index]
            Task {
                await syncCafeStateToSupabase(cafe: updatedCafe)
            }
        } else {
            // Cafe doesn't exist, add it with wantToTry = true (user is bookmarking it)
            var newCafe = cafe
            newCafe.wantToTry = true
            appData.cafes.append(newCafe)
            save()
            syncWidgetData() // Update widgets when want-to-try changes
            print("[WantToTry] Toggled wantToTry for \(cafe.name) → true (added new cafe)")
            
            // Sync to Supabase in background
            Task {
                await syncCafeStateToSupabase(cafe: newCafe)
            }
        }
    }
    
    // Find existing Cafe by location (within ~50 meters) or create new one
    // IMPORTANT: This does NOT automatically add the cafe to AppData.cafes
    // Cafes are only added when:
    // 1. A visit is posted (via upsertCafe in createVisit)
    // 2. User marks as favorite/wantToTry
    // 3. Visits are fetched from Supabase (via upsertCafe in mapRemoteVisit)
    func findOrCreateCafe(from mapItem: MKMapItem) -> Cafe {
        print("🔍 [FindCafe] Searching for cafe: '\(mapItem.name ?? "Unknown")'")
        
        guard let location = mapItem.placemark.location?.coordinate else {
            // If no location, create a transient cafe (NOT added to AppData)
            print("🔍 [FindCafe] No location - creating transient cafe")
            let cafe = Cafe(
                name: mapItem.name ?? "Unknown Cafe",
                address: formatAddress(from: mapItem.placemark),
                mapItemURL: mapItem.url?.absoluteString,
                websiteURL: mapItem.url?.absoluteString,
                placeCategory: mapItem.pointOfInterestCategory?.rawValue
            )
            return cafe
        }
        
        // Check if a cafe exists at this location (within ~50 meters)
        let threshold: Double = 0.0005 // approximately 50 meters
        
        if let existingCafe = appData.cafes.first(where: { cafe in
            guard let cafeLocation = cafe.location else { return false }
            let latDiff = abs(cafeLocation.latitude - location.latitude)
            let lonDiff = abs(cafeLocation.longitude - location.longitude)
            return latDiff < threshold && lonDiff < threshold
        }) {
            print("🔍 [FindCafe] ✅ Found existing cafe: '\(existingCafe.name)'")
            // Update existing cafe with mapItem data if missing
            if let index = appData.cafes.firstIndex(where: { $0.id == existingCafe.id }) {
                var updatedCafe = appData.cafes[index]
                if updatedCafe.mapItemURL == nil {
                    updatedCafe.mapItemURL = mapItem.url?.absoluteString
                }
                if updatedCafe.websiteURL == nil {
                    updatedCafe.websiteURL = mapItem.url?.absoluteString
                }
                if updatedCafe.placeCategory == nil {
                    updatedCafe.placeCategory = mapItem.pointOfInterestCategory?.rawValue
                }
                appData.cafes[index] = updatedCafe
                save()
            }
            return existingCafe
        }
        
        // Extract website URL from placemark if available
        var websiteURL: String? = nil
        if let url = mapItem.url, url.scheme == "http" || url.scheme == "https" {
            websiteURL = url.absoluteString
        }
        
        // Create new transient cafe (NOT added to AppData yet)
        // Will be added to AppData only when visit is posted or user favorites it
        print("🔍 [FindCafe] ⚠️ Creating NEW transient cafe (not added to AppData)")
        let cafe = Cafe(
            name: mapItem.name ?? "Unknown Cafe",
            location: location,
            address: formatAddress(from: mapItem.placemark),
            mapItemURL: mapItem.url?.absoluteString,
            websiteURL: websiteURL,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
        )
        return cafe
    }
    
    // MARK: - Recent Searches
    
    func addRecentSearch(from mapItem: MKMapItem, query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let recordedQuery = trimmedQuery.isEmpty ? (mapItem.name ?? "Search") : trimmedQuery
        let subtitle = MapSearchClassifier.subtitle(from: mapItem.placemark)
        let streetComponents = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare
        ].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let entry = RecentSearchEntry(
            query: recordedQuery,
            name: mapItem.name ?? recordedQuery,
            subtitle: subtitle,
            street: streetComponents.isEmpty ? nil : streetComponents,
            city: mapItem.placemark.locality ?? mapItem.placemark.subLocality,
            administrativeArea: mapItem.placemark.administrativeArea,
            country: mapItem.placemark.country,
            postalCode: mapItem.placemark.postalCode,
            latitude: mapItem.placemark.location?.coordinate.latitude,
            longitude: mapItem.placemark.location?.coordinate.longitude,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue,
            isCoffeeDestination: MapSearchClassifier.isCoffeeDestination(mapItem: mapItem),
            urlString: mapItem.url?.absoluteString
        )
        upsertRecentSearch(entry)
    }
    
    func promoteRecentSearch(_ entry: RecentSearchEntry) {
        upsertRecentSearch(entry.updatingTimestamp())
    }
    
    private func upsertRecentSearch(_ entry: RecentSearchEntry) {
        appData.recentSearches.removeAll { existing in
            if let entryCoordinate = entry.coordinate, let existingCoordinate = existing.coordinate {
                let latDiff = abs(entryCoordinate.latitude - existingCoordinate.latitude)
                let lonDiff = abs(entryCoordinate.longitude - existingCoordinate.longitude)
                if latDiff < 0.00025 && lonDiff < 0.00025 {
                    return true
                }
            }
            return existing.name.lowercased() == entry.name.lowercased() &&
            existing.query.lowercased() == entry.query.lowercased()
        }
        
        appData.recentSearches.insert(entry, at: 0)
        if appData.recentSearches.count > maxRecentSearches {
            appData.recentSearches = Array(appData.recentSearches.prefix(maxRecentSearches))
        }
        save()
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Visit Operations
    
    /// Creates a visit in Supabase
    /// Flow: LogVisitView → DataManager.createVisit(...) → SupabaseVisitService.createVisit(...) → Supabase /rest/v1/visits
    /// Requirements:
    /// - User must be authenticated (valid session with access token)
    /// - User must exist in public.users (foreign key constraint)
    /// - RLS policy requires auth.uid() = user_id
    func createVisit(
        cafe: Cafe,
        drinkType: DrinkType,
        customDrinkType: String?,
        caption: String,
        notes: String?,
        photoImages: [UIImage],
        posterPhotoIndex: Int,
        ratings: [String: Double],
        overallScore: Double,
        visibility: VisitVisibility,
        mentions: [Mention]
    ) async throws -> Visit {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("❌ [Visit] ERROR: Missing supabaseUserId in appData")
            throw SupabaseError.invalidSession
        }
        
        // Ensure we have a valid session with access token
        guard let session = authService.restoreSession() else {
            print("❌ [Visit] ERROR: No Supabase session found")
            throw SupabaseError.invalidSession
        }
        
        // Ensure the shared client has the access token set (all services use the same client)
        let sharedClient = SupabaseClientProvider.shared
        sharedClient.accessToken = session.accessToken
        print("[Visit] Session restored - userId=\(session.userId), accessToken present=\(!session.accessToken.isEmpty)")
        
        // Verify the session userId matches the appData userId
        guard session.userId == supabaseUserId else {
            print("❌ [Visit] ERROR: Session userId (\(session.userId)) does not match appData userId (\(supabaseUserId))")
            throw SupabaseError.invalidSession
        }
        
        // Log cafe details at start of visit creation
        print("📝 [CreateVisit] ===== STARTING VISIT CREATION =====")
        print("📝 [CreateVisit] Cafe: '\(cafe.name)' (id: \(cafe.id), supabaseId: \(cafe.supabaseId?.uuidString ?? "nil"))")
        print("📝 [CreateVisit] Cafe has location: \(cafe.location != nil ? "✅ (\(cafe.location!.latitude), \(cafe.location!.longitude))" : "❌ nil")")
        
        // Verify user exists in public.users (required for foreign key constraint)
        // This should already be true if user completed profile setup, but let's log it
        print("📝 [CreateVisit] Verifying user exists in public.users...")
        
        // Find or create cafe in Supabase, preserving location from local cafe
        let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        // Upsert the cafe, ensuring location is preserved if remote doesn't have it
        let upsertedCafe = upsertCafe(from: remoteCafe)
        
        // If the remote cafe doesn't have a location but our local cafe does, preserve it
        if upsertedCafe.location == nil && cafe.location != nil {
            if let cafeIndex = appData.cafes.firstIndex(where: { ($0.supabaseId ?? $0.id) == upsertedCafe.id }) {
                appData.cafes[cafeIndex].location = cafe.location
                print("[Visit] Preserved cafe location from local cafe: \(cafe.location!)")
                save()
            }
        }
        
        let uploads = try await uploadVisitImages(photoImages, supabaseUserId: supabaseUserId)
        let posterURL: String?
        if posterPhotoIndex >= 0 && posterPhotoIndex < uploads.count {
            posterURL = uploads[posterPhotoIndex].photoURL
        } else {
            posterURL = uploads.first?.photoURL
        }
        
        // Validate userId is a valid UUID
        guard UUID(uuidString: supabaseUserId) != nil else {
            print("❌ [Visit] ERROR: Invalid userId format - not a valid UUID: \(supabaseUserId)")
            throw SupabaseError.invalidSession
        }
        
        // Validate overallScore is not NaN or infinite
        let validOverallScore: Double
        if overallScore.isNaN || overallScore.isInfinite {
            print("⚠️ [CreateVisit] overallScore is invalid (\(overallScore)), defaulting to 0.0")
            validOverallScore = 0.0
        } else {
            validOverallScore = overallScore
        }
        
        // Validate and clean ratings - remove any NaN or infinite values
        var validRatings: [String: Double] = [:]
        for (key, value) in ratings {
            if !value.isNaN && !value.isInfinite && value >= 0 && value <= 5 {
                validRatings[key] = value
            } else {
                print("⚠️ [CreateVisit] Invalid rating for '\(key)': \(value), skipping")
            }
        }
        
        // Ensure caption is not empty (should already be validated, but double-check)
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCaption.isEmpty else {
            print("❌ [CreateVisit] Caption is empty after trimming")
            throw SupabaseError.server(status: 400, message: "Caption cannot be empty")
        }
        
        // Validate drinkType - if other, customDrinkType must be provided
        let finalDrinkType: String?
        let finalDrinkTypeCustom: String?
        if drinkType == .other {
            if let custom = customDrinkType?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
                finalDrinkType = nil
                finalDrinkTypeCustom = custom
            } else {
                print("❌ [CreateVisit] Drink type is 'other' but customDrinkType is empty")
                throw SupabaseError.server(status: 400, message: "Custom drink type is required when 'Other' is selected")
            }
        } else {
            finalDrinkType = drinkType.rawValue
            finalDrinkTypeCustom = nil
        }
        
        print("📝 [CreateVisit] Final drinkType: \(finalDrinkType ?? "nil"), custom: \(finalDrinkTypeCustom ?? "nil")")
        
        let payload = VisitInsertPayload(
            userId: supabaseUserId,
            cafeId: remoteCafe.id,
            drinkType: finalDrinkType,
            drinkTypeCustom: finalDrinkTypeCustom,
            caption: trimmedCaption,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: visibility.supabaseValue,
            ratings: validRatings,
            overallScore: validOverallScore,
            posterPhotoURL: posterURL
        )
        
        do {
            print("[Visit] ===== Creating Visit =====")
            print("[Visit] userId = \(supabaseUserId)")
            print("[Visit] cafeId = \(remoteCafe.id)")
            print("[Visit] cafeName = \(remoteCafe.name)")
            print("[Visit] drinkType = \(payload.drinkType ?? "nil")")
            print("[Visit] drinkTypeCustom = \(payload.drinkTypeCustom ?? "nil")")
            print("[Visit] caption = \(payload.caption.prefix(100))...")
            print("[Visit] notes = \(payload.notes ?? "nil")")
            print("[Visit] visibility = \(payload.visibility)")
            print("[Visit] ratings = \(payload.ratings)")
            print("[Visit] overallScore = \(payload.overallScore) (valid: \(!payload.overallScore.isNaN && !payload.overallScore.isInfinite))")
            print("[Visit] posterPhotoURL = \(payload.posterPhotoURL ?? "nil")")
            print("[Visit] photoCount = \(uploads.count)")
            
            // Log the encoded payload (excluding binary data)
            if let payloadJSON = try? JSONEncoder().encode(payload),
               let payloadString = String(data: payloadJSON, encoding: .utf8) {
                print("[Visit] Payload JSON: \(payloadString)")
            }
            
            let remoteVisit = try await visitService.createVisit(
                payload: payload,
                photos: uploads.map { VisitPhotoUpload(photoURL: $0.photoURL, sortOrder: $0.sortOrder) }
            )
            
            print("[Visit] Visit created in Supabase - id=\(remoteVisit.id)")
            
            cacheUploadedImages(uploads, remotePhotos: remoteVisit.photos ?? [])
            
            var visit = mapRemoteVisit(remoteVisit)
            visit.mentions = mentions
            
            print("[Visit] ===== UPDATING CAFE STATS AFTER VISIT CREATION =====")
            print("[Visit] Visit cafeId=\(visit.cafeId), supabaseCafeId=\(visit.supabaseCafeId?.uuidString ?? "nil")")
            
            // CRITICAL: Update cafe's visitCount BEFORE merging visits
            // This ensures the map shows the pin immediately
            updateCafeStatsForVisit(visit)
            
            // Now merge the visit into AppData
            mergeVisits([visit])
            
            print("[Visit] Visit created successfully - visitId=\(visit.id), userId=\(visit.userId), supabaseUserId=\(visit.supabaseUserId ?? "nil")")
            return visit
        } catch let error as SupabaseError {
            print("❌ [Visit] DataManager.createVisit SupabaseError: \(error)")
            switch error {
            case .server(let status, let message):
                print("❌ [Visit] Server error - status: \(status), message: \(message ?? "nil")")
            case .invalidSession:
                print("❌ [Visit] Invalid session - user may not be authenticated")
            case .decoding(let message):
                print("❌ [Visit] Decoding error: \(message)")
            case .network(let message):
                print("❌ [Visit] Network error: \(message)")
            }
            throw error
        } catch let decodingError as DecodingError {
            print("❌ [Visit] DataManager.createVisit DecodingError:")
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("  Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("  Context: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("  Value not found: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("  Context: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("  Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("  Context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("  Data corrupted: \(context.debugDescription)")
                if let underlyingError = context.underlyingError {
                    print("  Underlying error: \(underlyingError)")
                }
            @unknown default:
                print("  Unknown decoding error")
            }
            throw decodingError
        } catch {
            print("❌ [Visit] DataManager.createVisit unexpected error: \(error)")
            print("❌ [Visit] Error type: \(type(of: error))")
            throw error
        }
    }
    
    func addVisit(_ visit: Visit) {
        var visitWithMetadata = visit
        if let currentUser = appData.currentUser, currentUser.id == visit.userId {
            visitWithMetadata.authorDisplayName = currentUser.displayNameOrUsername
            visitWithMetadata.authorUsername = currentUser.username
            visitWithMetadata.authorAvatarURL = appData.currentUserAvatarURL
        }
        appData.visits.append(visitWithMetadata)
        
        // Preload images for the new visit
        PhotoCache.shared.preloadImages(for: visit.photos)
        
        // Update cafe stats
        if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == visit.cafeId }) {
            let cafeVisits = visits(for: visit.userId).filter { $0.cafeId == visit.cafeId }
            appData.cafes[cafeIndex].visitCount = cafeVisits.count
            
            // Recalculate average rating for the cafe
            let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
            appData.cafes[cafeIndex].averageRating = totalRating / Double(cafeVisits.count)
        }
        
        save()
        
        // Sync widget data after adding a visit
        syncWidgetData()
    }
    
    /// Sync data to widgets
    /// Includes current user's visits and friends' recent visits for the widget
    func syncWidgetData() {
        // Get friends' visits for the Friends' Latest Sips widget
        let friendsVisits = getFriendsVisitsForWidget()
        
        #if DEBUG
        print("[WidgetSync] Syncing widget data...")
        print("[WidgetSync] Friends count: \(appData.friendsSupabaseUserIds.count)")
        print("[WidgetSync] Friends visits for widget: \(friendsVisits.count)")
        if let latestFriendVisit = friendsVisits.first {
            print("[WidgetSync] Latest friend visit: '\(latestFriendVisit.authorDisplayNameOrUsername)' at '\(appData.cafes.first { $0.id == latestFriendVisit.cafeId }?.name ?? "Unknown")' on \(latestFriendVisit.createdAt)")
        }
        #endif
        
        WidgetSyncService.shared.syncWidgetData(
            dataManager: self,
            friendsVisits: friendsVisits
        )
    }
    
    /// Returns visits from friends for the widget (sorted by date, most recent first)
    /// Only includes visits that are visible to the current user (everyone or friends visibility)
    private func getFriendsVisitsForWidget() -> [Visit] {
        #if DEBUG
        print("[WidgetSync:Friends] ========== GET FRIENDS VISITS FOR WIDGET ==========")
        #endif
        
        guard let supabaseUserId = appData.supabaseUserId else {
            #if DEBUG
            print("[WidgetSync:Friends] ❌ No supabaseUserId - cannot get friends visits")
            #endif
            return []
        }
        
        // Normalize IDs to uppercase for case-insensitive comparison
        let normalizedCurrentUserId = supabaseUserId.uppercased()
        let normalizedFriendIds = Set(appData.friendsSupabaseUserIds.map { $0.uppercased() })
        
        #if DEBUG
        print("[WidgetSync:Friends] Current user ID: \(supabaseUserId.prefix(8))...")
        print("[WidgetSync:Friends] Friends IDs: \(appData.friendsSupabaseUserIds.map { $0.prefix(8).description })")
        print("[WidgetSync:Friends] Total visits in appData: \(appData.visits.count)")
        #endif
        
        guard !normalizedFriendIds.isEmpty else {
            #if DEBUG
            print("[WidgetSync:Friends] ❌ No friends - friendsSupabaseUserIds is empty")
            print("[WidgetSync:Friends] ================================================")
            #endif
            return []
        }
        
        // Debug: Analyze all visits to understand why filtering might fail
        #if DEBUG
        var visitsByAuthor: [String: Int] = [:]
        var visitsWithoutAuthor = 0
        for visit in appData.visits {
            if let authorId = visit.supabaseUserId {
                visitsByAuthor[authorId, default: 0] += 1
            } else {
                visitsWithoutAuthor += 1
            }
        }
        print("[WidgetSync:Friends] Visits by author ID:")
        for (authorId, count) in visitsByAuthor {
            let normalizedAuthorId = authorId.uppercased()
            let isFriend = normalizedFriendIds.contains(normalizedAuthorId)
            let isCurrentUser = normalizedAuthorId == normalizedCurrentUserId
            print("[WidgetSync:Friends]   - \(authorId.prefix(8))...: \(count) visits (friend: \(isFriend), current user: \(isCurrentUser))")
        }
        if visitsWithoutAuthor > 0 {
            print("[WidgetSync:Friends]   - (no author ID): \(visitsWithoutAuthor) visits")
        }
        #endif
        
        // Filter visits from friends only (not current user)
        // Include visits with visibility = everyone or friends
        // Use case-insensitive comparison for IDs
        let friendsVisits = appData.visits.filter { visit in
            guard let authorId = visit.supabaseUserId else { return false }
            let normalizedAuthorId = authorId.uppercased()
            
            // Must be from a friend (not current user)
            guard normalizedFriendIds.contains(normalizedAuthorId) && normalizedAuthorId != normalizedCurrentUserId else { return false }
            
            // Must be visible (everyone or friends)
            return visit.visibility == .everyone || visit.visibility == .friends
        }
        
        // Sort by date, most recent first
        let sorted = friendsVisits.sorted { $0.createdAt > $1.createdAt }
        
        #if DEBUG
        print("[WidgetSync:Friends] ✅ Found \(sorted.count) visible friend visits")
        if let latest = sorted.first {
            print("[WidgetSync:Friends] Latest: '\(latest.authorDisplayNameOrUsername)' - visibility: \(latest.visibility.rawValue)")
        }
        print("[WidgetSync:Friends] ================================================")
        #endif
        
        return sorted
    }
    
    func getVisit(id: UUID) -> Visit? {
        return appData.visits.first(where: { $0.id == id })
    }
    
    func getOrFetchVisit(id: UUID) async -> Visit? {
        if let local = getVisit(id: id) {
            return local
        }
        // Fetch from remote
        do {
            // Assuming visitService has a fetch method. If not, we might need to add it or use a query.
            // Since I don't have visibility into visitService fully, I'll assume I can use a direct query via service or similar.
            // Actually, I should check SupabaseVisitService.
            // For now, I'll try to rely on refreshing all visits if possible, or implement single fetch.
            // Let's assume refreshVisits() fetches everything (which it usually does for Alpha).
            // But for deep linking specific content, we might need a direct fetch.
            // I'll add a placeholder that refreshes all visits for now, which is safer given the "Refresh" pattern in this app.
            
            // Try refreshing user's visits + friends visits
            // This is heavy but ensures consistency
            // Better: implement fetchVisit(id:) in DataManager if SupabaseVisitService supports it.
            
            if let remoteVisit = try await visitService.fetchVisitById(id) {
                let visit = mapRemoteVisit(remoteVisit)
                // Cache it locally so subsequent lookups are fast
                mergeVisits([visit])
                return visit
            }
            return nil
        } catch {
            print("⚠️ [DataManager] Failed to fetch visit \(id): \(error)")
            return nil
        }
    }
        
        // Update an existing visit and refresh related cafe stats
        func updateVisit(_ updatedVisit: Visit) {
            guard let index = appData.visits.firstIndex(where: { $0.id == updatedVisit.id }) else { return }
            appData.visits[index] = updatedVisit
            
            // Recalculate cafe stats
            if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == updatedVisit.cafeId }) {
                let cafeVisits = visits(for: updatedVisit.userId).filter { $0.cafeId == updatedVisit.cafeId }
                appData.cafes[cafeIndex].visitCount = cafeVisits.count
                let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
                appData.cafes[cafeIndex].averageRating = cafeVisits.isEmpty ? 0.0 : (totalRating / Double(cafeVisits.count))
            }
            save()
        }
    
    /// Update visit notes and sync to Supabase
    /// - Parameters:
    ///   - visitId: The local visit ID
    ///   - notes: The new notes text (can be nil or empty to clear notes)
    /// - Throws: SupabaseError if the remote update fails
    func updateVisitNotes(visitId: UUID, notes: String?) async throws {
        guard let index = appData.visits.firstIndex(where: { $0.id == visitId }) else {
            print("[DataManager] updateVisitNotes: Visit not found for id \(visitId)")
            return
        }
        
        let visit = appData.visits[index]
        
        // Update remote if we have a Supabase ID
        if let supabaseId = visit.supabaseId {
            try await visitService.updateVisitNotes(visitId: supabaseId, notes: notes)
        }
        
        // Update local state
        appData.visits[index].notes = notes
        save()
        
        print("[DataManager] Visit notes updated successfully for visit \(visitId)")
    }
    
    /// Update visit details and sync to Supabase
    /// - Parameter visit: The updated visit with new values
    /// - Throws: SupabaseError if the remote update fails
    func updateVisitRemote(_ visit: Visit) async throws {
        guard let supabaseId = visit.supabaseId else {
            print("[DataManager] updateVisitRemote: No Supabase ID for visit \(visit.id)")
            return
        }
        
        try await visitService.updateVisit(
            visitId: supabaseId,
            drinkType: visit.drinkType.rawValue,
            customDrinkType: visit.customDrinkType,
            caption: visit.caption,
            notes: visit.notes,
            visibility: visit.visibility.supabaseValue,
            ratings: visit.ratings,
            overallScore: visit.overallScore,
            posterPhotoURL: visit.posterPhotoURL
        )
        
        print("[DataManager] Visit updated successfully in Supabase for visit \(visit.id)")
    }
        
        // Delete a visit and update cafe stats accordingly
        func deleteVisit(id: UUID) {
            guard let visit = getVisit(id: id) else { return }
            appData.visits.removeAll { $0.id == id }
            
            // Update cafe stats
            if let cafeIndex = appData.cafes.firstIndex(where: { $0.id == visit.cafeId }) {
                let cafeVisits = visits(for: visit.userId).filter { $0.cafeId == visit.cafeId }
                appData.cafes[cafeIndex].visitCount = cafeVisits.count
                let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
                appData.cafes[cafeIndex].averageRating = cafeVisits.isEmpty ? 0.0 : (totalRating / Double(cafeVisits.count))
            }
            save()
        }
    
    func getVisitsForCafe(_ cafeId: UUID) -> [Visit] {
        let sourceVisits = visitsForCurrentUser()
        return sourceVisits
            .filter { $0.cafeId == cafeId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Fetches app-wide aggregated statistics for a cafe from Supabase
    /// Returns total visits, average rating, and top 5 drinks across ALL users
    func getCafeAggregateStats(for cafeId: UUID) async -> CafeAggregateStats? {
        // Use supabaseId if available (preferred), otherwise use local id
        let targetCafeId: UUID
        if let cafe = getCafe(id: cafeId), let supabaseId = cafe.supabaseId {
            targetCafeId = supabaseId
        } else {
            targetCafeId = cafeId
        }
        
        do {
            let stats = try await SupabaseVisitService.shared.fetchCafeAggregateStats(cafeId: targetCafeId)
            return stats
        } catch {
            print("❌ [DataManager] Failed to fetch cafe aggregate stats: \(error)")
            return nil
        }
    }
    
    // MARK: - Saved Tab Helpers
    
    /// Get the most recent visit date for a cafe
    func lastVisitDate(for cafeId: UUID) -> Date? {
        getVisitsForCafe(cafeId).first?.createdAt
    }
    
    /// Get the date when cafe was added to wishlist (approximated by first visit or favorite date)
    /// For now, uses the cafe's first visit date or current date if no visits
    func dateAddedToWishlist(for cafeId: UUID) -> Date {
        // In a full implementation, you'd track this separately
        // For now, use the earliest visit date or current date
        getVisitsForCafe(cafeId).last?.createdAt ?? Date()
    }
    
    /// Get the most frequently ordered drink type at a cafe
    func favoriteDrink(for cafeId: UUID) -> String? {
        let visits = getVisitsForCafe(cafeId)
        guard !visits.isEmpty else { return nil }
        
        let drinkCounts = Dictionary(grouping: visits) { $0.drinkType }
            .mapValues { $0.count }
        
        guard let (topDrink, count) = drinkCounts.max(by: { $0.value < $1.value }),
              count >= 2 else { return nil } // Only show if ordered 2+ times
        
        return topDrink.rawValue
    }
    
    /// Get cafe distance from user location (for sorting)
    func distance(to cafe: Cafe, from location: CLLocation?) -> Double? {
        guard let userLocation = location,
              let cafeLocation = cafe.location else { return nil }
        
        let cafeCLLocation = CLLocation(latitude: cafeLocation.latitude,
                                         longitude: cafeLocation.longitude)
        return userLocation.distance(from: cafeCLLocation)
    }
    
    /// Get the image path for a cafe from its most recent visit
    func cafeImageInfo(for cafeId: UUID) -> (path: String?, remoteURL: String?) {
        let visits = getVisitsForCafe(cafeId)
        guard let visit = visits.first,
              let path = visit.posterImagePath else {
            return (nil, nil)
        }
        return (path, visit.remoteURL(for: path))
    }
    
    // MARK: - Like Operations
    func toggleVisitLike(_ visitId: UUID) async {
        guard
            let supabaseUserId = appData.supabaseUserId,
            let currentUser = appData.currentUser,
            let index = appData.visits.firstIndex(where: { $0.id == visitId }),
            let remoteVisitId = appData.visits[index].supabaseId
        else {
            return
        }
        
        // Capture initial state for potential rollback
        let originalVisit = appData.visits[index]
        let wasLiked = originalVisit.isLikedBy(userId: currentUser.id)
        
        // OPTIMISTIC UPDATE: Update UI immediately on MainActor
        await MainActor.run {
            var optimisticVisit = originalVisit
            if wasLiked {
                optimisticVisit.likedByUserIds.removeAll { $0 == currentUser.id }
                optimisticVisit.likeCount = max(0, optimisticVisit.likeCount - 1)
            } else {
                optimisticVisit.likedByUserIds.append(currentUser.id)
                optimisticVisit.likeCount += 1
            }
            appData.visits[index] = optimisticVisit // Trigger UI update
            save()
        }
        
        do {
            if wasLiked {
                try await visitService.removeLike(visitId: remoteVisitId, userId: supabaseUserId)
            } else {
                _ = try await visitService.addLike(visitId: remoteVisitId, userId: supabaseUserId)
                
                 if let ownerId = originalVisit.supabaseUserId, ownerId != supabaseUserId {
                     let payload = NotificationInsertPayload(
                         userId: ownerId,
                         actorUserId: supabaseUserId,
                         type: "like",
                         visitId: remoteVisitId,
                         commentId: nil
                     )
                     try? await notificationService.createNotification(payload)
                 }
            }
        } catch {
            print("Supabase like toggle failed: \(error.localizedDescription)")
            
            // ROLLBACK: Revert to original state on failure
            await MainActor.run {
                if let safeIndex = appData.visits.firstIndex(where: { $0.id == visitId }) {
                    appData.visits[safeIndex] = originalVisit
                    save()
                }
            }
        }
    }
    
    // MARK: - Friend Operations
    
    func sendFriendRequest(to targetUserId: String) async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        // Prevent self-friending
        guard supabaseUserId != targetUserId else {
            throw SupabaseError.server(status: 400, message: "Cannot send friend request to yourself")
        }
        
        do {
            let request = try await socialGraphService.sendFriendRequest(from: supabaseUserId, to: targetUserId)
            print("[Friends] Friend request sent - id: \(request.id), from: \(supabaseUserId), to: \(targetUserId)")
            
            // Update pending request tracking
            appData.outgoingRequestsByUserId[targetUserId] = request.id.uuidString
            save()
            
            // Create a notification for the recipient
            let payload = NotificationInsertPayload(
                userId: targetUserId,
                actorUserId: supabaseUserId,
                type: "friend_request",
                visitId: nil,
                commentId: nil
            )
            try? await notificationService.createNotification(payload)
        } catch {
            print("❌ [Friends] Failed to send friend request: \(error.localizedDescription)")
            // Convert technical errors to user-friendly messages
            if let supabaseError = error as? SupabaseError {
                switch supabaseError {
                case .server(let status, let message):
                    if status == 409 || (message?.lowercased().contains("duplicate") ?? false) {
                        throw SupabaseError.server(status: status, message: "Friend request already exists")
                    }
                default:
                    break
                }
            }
            throw error
        }
    }
    
    func acceptFriendRequest(requestId: UUID) async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("❌ [Friends] Cannot accept request - no supabaseUserId")
            throw SupabaseError.invalidSession
        }
        
        print("[Friends] Accepting friend request id=\(requestId) for user=\(supabaseUserId)")
        
        do {
            // First, fetch the request to get fromUserId and toUserId
            let incomingRequests = try await socialGraphService.fetchIncomingFriendRequests(for: supabaseUserId)
            print("[Friends] Found \(incomingRequests.count) incoming requests")
            
            guard let request = incomingRequests.first(where: { $0.id == requestId }) else {
                print("❌ [Friends] Friend request \(requestId) not found in incoming requests")
                throw SupabaseError.decoding("Friend request not found")
            }
            
            print("[Friends] Accepting request from=\(request.fromUserId) to=\(request.toUserId)")
            
            try await socialGraphService.acceptFriendRequest(
                requestId: requestId,
                fromUserId: request.fromUserId,
                toUserId: request.toUserId
            )
            
            print("[Friends] Backend accept successful, refreshing friends list...")
            
            // Refresh friends list
            let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
            let previousCount = appData.friendsSupabaseUserIds.count
            appData.friendsSupabaseUserIds = Set(friends)
            print("[Friends] Friends list updated: \(previousCount) -> \(appData.friendsSupabaseUserIds.count) friends")
            print("[Friends] Current friends: \(appData.friendsSupabaseUserIds)")
            
            // Remove from pending requests tracking
            appData.incomingRequestsByUserId.removeValue(forKey: request.fromUserId)
            
            // Create notification for the requester that their request was accepted
            let payload = NotificationInsertPayload(
                userId: request.fromUserId,
                actorUserId: supabaseUserId,
                type: "friend_accept",
                visitId: nil,
                commentId: nil
            )
            try? await notificationService.createNotification(payload)
            
            save()
            
            print("[Friends] Friend request accepted successfully - id: \(requestId)")
            save()
            
            // WIDGET REFRESH: New friend added - refresh widget to show their visits
            // Fetch friend visits in background to populate widget data
            Task {
                await fetchSipSquadVisitsIfNeeded()
            }
            
        } catch {
            print("❌ [Friends] Failed to accept friend request: \(error.localizedDescription)")
            throw error
        }
    }
    
    func rejectFriendRequest(requestId: UUID) async throws {
        do {
            try await socialGraphService.rejectFriendRequest(requestId: requestId)
            print("[Friends] Friend request rejected - id: \(requestId)")
        } catch {
            print("❌ [Friends] Failed to reject friend request: \(error.localizedDescription)")
            throw error
        }
    }
    
    func cancelFriendRequest(requestId: UUID) async throws {
        do {
            try await socialGraphService.cancelFriendRequest(requestId: requestId)
            print("[FriendsRequests] Canceled outgoing request id=\(requestId)")
            
            // Remove from pending requests tracking
            // Find the user ID associated with this request
            if let (userId, _) = appData.outgoingRequestsByUserId.first(where: { $0.value == requestId.uuidString }) {
                appData.outgoingRequestsByUserId.removeValue(forKey: userId)
                save()
            }
        } catch {
            print("❌ [Friends] Failed to cancel friend request: \(error.localizedDescription)")
            throw error
        }
    }
    
    func removeFriend(userId: String) async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        do {
            try await socialGraphService.removeFriend(userId: supabaseUserId, friendUserId: userId)
            
            // Update local friends list
            appData.friendsSupabaseUserIds.remove(userId)
            
            print("[Friends] Friend removed - userId: \(userId)")
            save()
        } catch {
            print("❌ [Friends] Failed to remove friend: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchFriends(for userId: String) async throws -> [User] {
        let friendIds = try await socialGraphService.fetchFriends(for: userId)
        var friends: [User] = []
        
        // Fetch user profiles for each friend
        for friendId in friendIds {
            if let profile = try? await profileService.fetchUserProfile(userId: friendId) {
                let userUUID = UUID(uuidString: friendId) ?? UUID()
                let friend = profile.toLocalUser(existing: nil, overridingId: userUUID)
                friends.append(friend)
            }
        }
        
        return friends
    }
    
    /// Fetch friend profiles as RemoteUserProfile for autocomplete and mentions
    func fetchFriendProfiles() async throws -> [RemoteUserProfile] {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        let friendIds = try await socialGraphService.fetchFriends(for: supabaseUserId)
        var profiles: [RemoteUserProfile] = []
        
        for friendId in friendIds {
            if let profile = try? await profileService.fetchUserProfile(userId: friendId) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }
    
    func fetchFriendRequests() async throws -> (incoming: [FriendRequest], outgoing: [FriendRequest]) {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        let incoming = try await socialGraphService.fetchIncomingFriendRequests(for: supabaseUserId)
        let outgoing = try await socialGraphService.fetchOutgoingFriendRequests(for: supabaseUserId)
        
        // Update pending request tracking dictionaries for quick status lookups
        // Maps userId -> requestId for easy lookup when displaying friendship state
        appData.incomingRequestsByUserId = Dictionary(uniqueKeysWithValues: incoming.map { ($0.fromUserId, $0.id.uuidString) })
        appData.outgoingRequestsByUserId = Dictionary(uniqueKeysWithValues: outgoing.map { ($0.toUserId, $0.id.uuidString) })
        save()
        
        return (
            incoming: incoming.map { FriendRequest(from: $0) },
            outgoing: outgoing.map { FriendRequest(from: $0) }
        )
    }
    
    func checkFriendshipStatus(for userId: String) async throws -> FriendshipStatus {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        return try await socialGraphService.checkFriendshipStatus(
            currentUserId: supabaseUserId,
            otherUserId: userId
        )
    }
    
    func fetchMutualFriends(userId: String) async throws -> [User] {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        // Fetch friends for both users
        let currentUserFriends = try await socialGraphService.fetchFriends(for: supabaseUserId)
        let otherUserFriends = try await socialGraphService.fetchFriends(for: userId)
        
        // Compute intersection
        let currentFriendsSet = Set(currentUserFriends)
        let mutualIds = otherUserFriends.filter { currentFriendsSet.contains($0) }
        
        // Fetch user profiles for mutual friends
        var mutualFriends: [User] = []
        for friendId in mutualIds {
            if let profile = try? await profileService.fetchUserProfile(userId: friendId) {
                let userUUID = UUID(uuidString: friendId) ?? UUID()
                let friend = profile.toLocalUser(existing: nil, overridingId: userUUID)
                mutualFriends.append(friend)
            }
        }
        
        return mutualFriends
    }
    
    func fetchOtherUserProfile(userId: String) async throws -> RemoteUserProfile? {
        return try await profileService.fetchUserProfile(userId: userId)
    }
    
    func fetchOtherUserVisits(userId: String) async throws {
        print("[DataManager] fetchOtherUserVisits: Fetching visits for userId: \(userId)")
        let remoteVisits = try await visitService.fetchVisitsForUserProfile(userId: userId)
        print("[DataManager] fetchOtherUserVisits: Fetched \(remoteVisits.count) remote visits")
        
        let mapped = remoteVisits.map { mapRemoteVisit($0) }
        print("[DataManager] fetchOtherUserVisits: Mapped \(mapped.count) visits, checking supabaseUserId...")
        for visit in mapped {
            print("[DataManager] fetchOtherUserVisits: Visit id=\(visit.id), supabaseUserId=\(visit.supabaseUserId ?? "nil"), userId=\(userId)")
        }
        
        mergeVisits(mapped)
        print("[DataManager] fetchOtherUserVisits: Merged visits. Total visits in appData: \(appData.visits.count)")
        
        // Update cafe stats
        let uniqueCafeIds = Set(mapped.map { $0.cafeId })
        for cafeId in uniqueCafeIds {
            if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                updateCafeStatsForVisit(sampleVisit)
            }
        }
    }
    
    func refreshFriendsList() async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        do {
            let friendIds = try await socialGraphService.fetchFriends(for: supabaseUserId)
            appData.friendsSupabaseUserIds = Set(friendIds)
            save()
        } catch {
            print("[DataManager] Error refreshing friends list: \(error.localizedDescription)")
        }
    }
    
    func getIncomingFriendRequestCount() async -> Int {
        guard let supabaseUserId = appData.supabaseUserId else { return 0 }
        do {
            let requests = try await socialGraphService.fetchIncomingFriendRequests(for: supabaseUserId)
            return requests.count
        } catch {
            print("[DataManager] Error fetching friend request count: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Search for users by username or display name
    func searchUsers(query: String) async throws -> [RemoteUserProfile] {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        return try await profileService.searchUsers(
            query: query,
            excludingUserId: supabaseUserId
        )
    }
    
    // MARK: - Feed Operations
    // PERFORMANCE: Optimized to filter first, then sort (reduces sort workload)
    func getFeedVisits(scope: FeedScope, currentUserId: UUID) -> [Visit] {
        switch scope {
        case .everyone:
            // Show visits with visibility == .everyone
            // PERFORMANCE: Filter first, then sort only the filtered results
            return appData.visits
                .filter { $0.visibility == .everyone }
                .sorted { $0.createdAt > $1.createdAt }
                
        case .friends:
            // PERFORMANCE: Build friend set once for O(1) lookups
            let friendIds = appData.friendsSupabaseUserIds
            return appData.visits.filter { visit in
                // Private visits only visible to author
                guard visit.visibility != .private else {
                    return visit.userId == currentUserId
                }
                
                // Author's own visits always visible
                if visit.userId == currentUserId {
                    return true
                }
                
                // Check if author is a friend
                guard let authorSupabaseId = visit.supabaseUserId else {
                    return false
                }
                
                return friendIds.contains(authorSupabaseId)
            }.sorted { $0.createdAt > $1.createdAt }
            
        case .discover:
            // Discover scope doesn't show a traditional feed - returns empty
            // The DiscoverContentView handles its own data fetching
            return []
        }
    }
    
    func refreshFeed(scope: FeedScope) async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        #if DEBUG
        print("🔄 [RefreshFeed] Starting feed refresh - scope: \(scope)")
        #endif
        do {
            let remoteVisits: [RemoteVisit]
            switch scope {
            case .everyone:
                remoteVisits = try await visitService.fetchEveryoneFeed()
            case .friends:
                let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
                appData.friendsSupabaseUserIds = Set(friends)
                remoteVisits = try await visitService.fetchFriendsFeed(currentUserId: supabaseUserId, followingIds: friends)
            case .discover:
                // Discover scope uses local data; just refresh friends list for Social Radar
                let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
                appData.friendsSupabaseUserIds = Set(friends)
                return
            }
            
            let mapped = remoteVisits.map { mapRemoteVisit($0) }
            mergeVisits(mapped)
            
            // CRITICAL: Recalculate visitCount for all cafes after fetching feed
            let uniqueCafeIds = Set(mapped.map { $0.cafeId })
            for cafeId in uniqueCafeIds {
                if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                    updateCafeStatsForVisit(sampleVisit)
                }
            }
            
            // WIDGET REFRESH: Sync widget data after loading friend visits
            // This ensures the Friends' Latest Sips widget gets updated
            if scope == .friends {
                #if DEBUG
                print("[RefreshFeed] Syncing widget data after friends feed refresh")
                #endif
                syncWidgetData()
            }
        } catch {
            #if DEBUG
            print("❌ [RefreshFeed] Failed to refresh feed: \(error.localizedDescription)")
            #endif
        }
    }
    
    func refreshProfileVisits() async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            return
        }
        
        let remoteVisits = try await visitService.fetchVisitsForUserProfile(userId: supabaseUserId)
        let mapped = remoteVisits.map { mapRemoteVisit($0) }
        mergeVisits(mapped)
        
        // CRITICAL: Recalculate visitCount for all cafes after fetching visits
        let uniqueCafeIds = Set(mapped.map { $0.cafeId })
        for cafeId in uniqueCafeIds {
            if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                updateCafeStatsForVisit(sampleVisit)
            }
        }
    }
    
    /// Delete a comment authored by the current user.
    /// Removes the comment locally and from Supabase.
    func deleteComment(_ comment: Comment, from visitId: UUID) async {
        guard
            let index = appData.visits.firstIndex(where: { $0.id == visitId }),
            let remoteCommentId = comment.supabaseId ?? comment.id as UUID?
        else {
            print("[Comments] Delete failed - visit or comment not found")
            return
        }
        
        do {
            try await visitService.deleteComment(commentId: remoteCommentId)
            appData.visits[index].comments.removeAll { $0.id == comment.id }
            save()
            print("[Comments] Deleted comment id=\(comment.id) by currentUser")
        } catch {
            print("[Comments] Failed to delete comment: \(error.localizedDescription)")
        }
    }
    
    /// Edit a comment authored by the current user.
    /// Updates the comment text in Supabase and local state.
    func editComment(_ comment: Comment, in visitId: UUID, newText: String) async {
        guard
            let index = appData.visits.firstIndex(where: { $0.id == visitId }),
            let remoteCommentId = comment.supabaseId ?? comment.id as UUID?
        else {
            print("[Comments] Edit failed - visit or comment not found")
            return
        }
        
        do {
            let remote = try await visitService.updateComment(commentId: remoteCommentId, newText: newText)
            
            // Build updated local comment
            var updated = comment
            updated.text = newText
            updated.createdAt = remote.createdAt ?? comment.createdAt
            updated.mentions = MentionParser.parseMentions(from: newText)
            
            if let localIndex = appData.visits[index].comments.firstIndex(where: { $0.id == comment.id }) {
                appData.visits[index].comments[localIndex] = updated
            }
            save()
            print("[Comments] Edited comment id=\(comment.id) by currentUser")
        } catch {
            print("[Comments] Failed to edit comment: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Comment Operations
    func addComment(to visitId: UUID, text: String) async {
        guard
            let supabaseUserId = appData.supabaseUserId,
            let currentUser = appData.currentUser,
            let index = appData.visits.firstIndex(where: { $0.id == visitId }),
            let remoteVisitId = appData.visits[index].supabaseId
        else {
            return
        }
        
        do {
            let remoteComment = try await visitService.addComment(
                visitId: remoteVisitId,
                userId: supabaseUserId,
                text: text
            )
            
            let comment = Comment(
                id: remoteComment.id,
                supabaseId: remoteComment.id,
                visitId: visitId,
                userId: currentUser.id,
                supabaseUserId: supabaseUserId,
                text: text,
                createdAt: remoteComment.createdAt ?? Date(),
                mentions: MentionParser.parseMentions(from: text)
            )

            // Update state on MainActor to ensure UI sees the change immediately
            await MainActor.run {
                // Safety: Re-lookup index in case visits array changed during network call
                if let safeIndex = appData.visits.firstIndex(where: { $0.id == visitId }) {
                    var updatedVisit = appData.visits[safeIndex]
                    updatedVisit.comments.append(comment)
                    appData.visits[safeIndex] = updatedVisit // Triggers @Published
                    save()
                }
            }
            
            // Re-fetch index for notification logic
            if let safeIndex = appData.visits.firstIndex(where: { $0.id == visitId }),
               let ownerId = appData.visits[safeIndex].supabaseUserId,
               ownerId != supabaseUserId {
                let payload = NotificationInsertPayload(
                    userId: ownerId,
                    actorUserId: supabaseUserId,
                    type: "comment",
                    visitId: remoteVisitId,
                    commentId: remoteComment.id
                )
                try? await notificationService.createNotification(payload)
            }
        } catch {
            print("Supabase comment failed: \(error.localizedDescription)")
        }
    }
    
    func getComments(for visitId: UUID) -> [Comment] {
        guard let visit = appData.visits.first(where: { $0.id == visitId }) else {
            return []
        }
        return visit.comments.sorted { $0.createdAt < $1.createdAt } // Oldest first
    }
    
    // MARK: - Notifications
    func refreshNotifications() async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        do {
            let remote = try await notificationService.fetchNotifications(for: supabaseUserId)
            var mapped = remote.map { mapRemoteNotification($0) }
            
            // If the user has cleared notifications before, hide anything created at or before that point
            if let cutoff = appData.notificationsClearedAt {
                mapped = mapped.filter { $0.createdAt > cutoff }
            }
            
            appData.notifications = mapped
            save()
        } catch {
            print("Failed to refresh notifications: \(error.localizedDescription)")
        }
    }
    
    /// Clear all notifications for the current user, both locally and in Supabase.
    func clearAllNotifications() async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        do {
            try await notificationService.clearAllNotifications(for: supabaseUserId)
            appData.notificationsClearedAt = Date()
            appData.notifications.removeAll()
            save()
        } catch {
            print("Failed to clear notifications: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Push Notifications
    /// Register for push notifications if user is authenticated and hasn't registered yet
    /// Should be called after sign-in or profile setup completion
    func registerPushNotificationsIfNeeded() async {
        guard appData.isUserAuthenticated,
              appData.hasEmailVerified else {
            print("[Push] User not authenticated or email not verified, skipping push registration")
            return
        }
        
        print("[Push] Requesting push notification authorization...")
        await PushNotificationManager.shared.requestAuthorizationAndRegister()
        
        // Re-register token if we have one stored but user wasn't authenticated when it was received
        await PushNotificationManager.shared.reRegisterTokenIfNeeded()
    }
    
    /// Register a push token with Supabase (called by PushNotificationManager)
    func registerPushToken(token: String, platform: String = "ios") async {
        guard let userId = appData.supabaseUserId else {
            print("⚠️ [Push] No userId available, cannot register token")
            return
        }
        
        print("[Push] Registering device token for userId=\(userId.prefix(8))...")
        do {
            try await SupabaseUserDeviceService.shared.upsertDeviceToken(
                userId: userId,
                token: token,
                platform: platform
            )
            print("✅ [Push] Device token registered successfully")
        } catch {
            print("❌ [Push] Error registering device token: \(error.localizedDescription)")
        }
    }
    
    func markNotificationRead(_ notification: MugshotNotification) async {
        do {
            try await notificationService.markNotificationRead(id: notification.supabaseId ?? notification.id)
            if let index = appData.notifications.firstIndex(where: { $0.id == notification.id }) {
                appData.notifications[index].isRead = true
                save()
            }
        } catch {
            print("Failed to mark notification read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Rating Template Operations
    func updateRatingTemplate(_ template: RatingTemplate) {
        appData.ratingTemplate = template
        save()
        
        // Sync to Supabase in background
        Task {
            guard let userId = appData.supabaseUserId else {
                print("[DataManager] updateRatingTemplate: No supabaseUserId, skipping remote sync")
                return
            }
            do {
                let remoteTemplate = RemoteRatingTemplate.fromLocal(userId: userId, template: template)
                _ = try await profileService.upsertRatingTemplate(remoteTemplate)
                print("[DataManager] Rating template synced to Supabase successfully")
            } catch {
                print("[DataManager] Failed to sync rating template to Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Onboarding
    func completeOnboarding() {
        appData.hasCompletedOnboarding = true
        save()
    }
    
    // MARK: - Statistics
    func getUserStats() -> (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        let visits = visitsForCurrentUser()
        let cafes = Set(visits.map { $0.cafeId })
        let totalScore = visits.reduce(0.0) { $0 + $1.overallScore }
        let averageScore = visits.isEmpty ? 0.0 : totalScore / Double(visits.count)
        
        // Find favorite drink type
        let drinkTypeCounts = Dictionary(grouping: visits, by: { $0.drinkType })
            .mapValues { $0.count }
        let favoriteDrinkType = drinkTypeCounts.max(by: { $0.value < $1.value })?.key
        
        return (
            totalVisits: visits.count,
            totalCafes: cafes.count,
            averageScore: averageScore,
            favoriteDrinkType: favoriteDrinkType
        )
    }
    
    // Get most visited cafe
    func getMostVisitedCafe() -> (cafe: Cafe, visitCount: Int)? {
        let visitsByCafe = Dictionary(grouping: visitsForCurrentUser(), by: { $0.cafeId })
        guard let (cafeId, visits) = visitsByCafe.max(by: { $0.value.count < $1.value.count }),
              let cafe = getCafe(id: cafeId) else {
            return nil
        }
        return (cafe: cafe, visitCount: visits.count)
    }
    
    // Get favorite cafe (highest average rating)
    func getFavoriteCafe() -> (cafe: Cafe, avgScore: Double)? {
        let visitsByCafe = Dictionary(grouping: visitsForCurrentUser(), by: { $0.cafeId })
        var cafeScores: [(cafeId: UUID, avgScore: Double)] = []
        
        for (cafeId, visits) in visitsByCafe {
            let avgScore = visits.reduce(0.0) { $0 + $1.overallScore } / Double(visits.count)
            cafeScores.append((cafeId: cafeId, avgScore: avgScore))
        }
        
        guard let topCafe = cafeScores.max(by: { $0.avgScore < $1.avgScore }),
              let cafe = getCafe(id: topCafe.cafeId) else {
            return nil
        }
        return (cafe: cafe, avgScore: topCafe.avgScore)
    }
    
    // Get beverage breakdown (percentage of each drink type)
    func getBeverageBreakdown() -> [(drinkType: DrinkType, count: Int, fraction: Double)] {
        let userVisits = visitsForCurrentUser()
        let totalVisits = userVisits.count
        guard totalVisits > 0 else { return [] }
        
        let drinkTypeCounts = Dictionary(grouping: userVisits, by: { $0.drinkType })
            .mapValues { $0.count }
        
        return drinkTypeCounts.map { (drinkType: $0.key, count: $0.value, fraction: Double($0.value) / Double(totalVisits)) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Supabase Synchronization
    
    private func uploadVisitImages(_ images: [UIImage], supabaseUserId: String) async throws -> [UploadedVisitPhoto] {
        guard !images.isEmpty else { return [] }
        
        // Limit number of photos to prevent payload size issues
        let maxPhotos = 10
        let imagesToUpload = Array(images.prefix(maxPhotos))
        if images.count > maxPhotos {
            print("⚠️ [Visit] Limiting photos to \(maxPhotos) (selected \(images.count))")
        }
        
        var uploads: [UploadedVisitPhoto] = []
        for (index, image) in imagesToUpload.enumerated() {
            do {
                let fileName = "\(UUID().uuidString).jpg"
                let path = "\(supabaseUserId)/visits/\(fileName)"
                print("[Visit] Uploading photo \(index + 1)/\(imagesToUpload.count)")
                let url = try await storageService.uploadImage(image, path: path)
                uploads.append(UploadedVisitPhoto(photoURL: url, sortOrder: index, image: image))
            } catch let error as SupabaseError {
                // If upload fails due to size, provide helpful error
                if case .server(let status, _) = error, status == 413 {
                    throw SupabaseError.server(
                        status: status,
                        message: "Photo \(index + 1) is too large. Please try a smaller image."
                    )
                }
                throw error
            }
        }
        return uploads
    }
    
    private func cacheUploadedImages(_ uploads: [UploadedVisitPhoto], remotePhotos: [RemoteVisitPhoto]) {
        guard !uploads.isEmpty else { return }
        let sortedUploads = uploads.sorted { $0.sortOrder < $1.sortOrder }
        let sortedRemote = remotePhotos.sorted { $0.sortOrder < $1.sortOrder }
        for (upload, remote) in zip(sortedUploads, sortedRemote) {
            let key = "remote-\(remote.id.uuidString)"
            PhotoCache.shared.store(upload.image, forKey: key)
        }
    }
    
    private func upsertCafe(from remote: RemoteCafe) -> Cafe {
        print("🏪 [CafeUpsert] Upserting cafe from Supabase - id: \(remote.id), name: '\(remote.name)'")
        print("🏪 [CafeUpsert] Remote has location: lat=\(remote.latitude ?? 0), lon=\(remote.longitude ?? 0)")
        
        // Find existing cafe by Supabase ID
        if let index = appData.cafes.firstIndex(where: { ($0.supabaseId ?? $0.id) == remote.id }) {
            let existing = appData.cafes[index]
            print("🏪 [CafeUpsert] Found existing cafe at index \(index): '\(existing.name)'")
            print("🏪 [CafeUpsert] Existing - visitCount: \(existing.visitCount), hasLocation: \(existing.location != nil), favorite: \(existing.isFavorite)")
            
            // Merge remote data with existing, but PRESERVE critical local state
            let finalCafe = Cafe(
                id: existing.id, // Keep local ID
                supabaseId: remote.id, // Ensure Supabase ID is set
                name: remote.name, // Update name from remote
                location: remote.toLocalCafe().location ?? existing.location, // Prefer remote location, fallback to existing
                address: remote.address ?? existing.address,
                city: remote.city ?? existing.city,
                country: remote.country ?? existing.country,
                isFavorite: existing.isFavorite, // PRESERVE local state
                wantToTry: existing.wantToTry, // PRESERVE local state
                averageRating: existing.averageRating, // PRESERVE (calculated locally)
                visitCount: existing.visitCount, // PRESERVE (calculated locally, updated separately)
                mapItemURL: existing.mapItemURL,
                websiteURL: remote.websiteURL ?? existing.websiteURL,
                applePlaceId: remote.applePlaceId ?? existing.applePlaceId,
                placeCategory: existing.placeCategory
            )
            
            appData.cafes[index] = finalCafe
            print("🏪 [CafeUpsert] ✅ Updated existing cafe:")
            print("   - name: '\(finalCafe.name)'")
            print("   - location: \(finalCafe.location != nil ? "✅ (\(finalCafe.location!.latitude), \(finalCafe.location!.longitude))" : "❌ nil")")
            print("   - visitCount: \(finalCafe.visitCount) (preserved)")
            print("   - supabaseId: \(finalCafe.supabaseId?.uuidString ?? "nil")")
            return finalCafe
        } else {
            // New cafe from Supabase
            let cafe = remote.toLocalCafe()
            appData.cafes.append(cafe)
            print("🏪 [CafeUpsert] ✅ Added NEW cafe:")
            print("   - name: '\(cafe.name)'")
            print("   - location: \(cafe.location != nil ? "✅ (\(cafe.location!.latitude), \(cafe.location!.longitude))" : "❌ nil")")
            print("   - visitCount: \(cafe.visitCount) (initial)")
            print("   - supabaseId: \(cafe.supabaseId?.uuidString ?? "nil")")
            return cafe
        }
    }
    
    private func mergeVisits(_ visits: [Visit]) {
        guard !visits.isEmpty else { return }
        for visit in visits {
            let key = visit.supabaseId ?? visit.id
            if let index = appData.visits.firstIndex(where: { ($0.supabaseId ?? $0.id) == key }) {
                appData.visits[index] = visit
            } else {
                appData.visits.append(visit)
            }
        }
        appData.visits.sort { $0.createdAt > $1.createdAt }
        save()
    }
    
    /// Updates cafe statistics (visitCount, averageRating) for a given visit
    /// This ensures the map shows pins immediately after visit creation
    private func updateCafeStatsForVisit(_ visit: Visit) {
        print("📊 [CafeStats] Updating stats for visit - cafeId: \(visit.cafeId), supabaseCafeId: \(visit.supabaseCafeId?.uuidString ?? "nil")")
        print("📊 [CafeStats] Total cafes in AppData: \(appData.cafes.count)")
        
        // Find the cafe - match by supabaseCafeId first (most reliable), then by cafeId
        let targetCafeId = visit.supabaseCafeId ?? visit.cafeId
        
        if let cafeIndex = appData.cafes.firstIndex(where: { cafe in
            // Match by Supabase ID first (most reliable)
            if let supabaseId = cafe.supabaseId, supabaseId == targetCafeId {
                return true
            }
            // Fall back to local ID match
            if cafe.id == targetCafeId || cafe.id == visit.cafeId {
                return true
            }
            return false
        }) {
            let cafe = appData.cafes[cafeIndex]
            print("📊 [CafeStats] Found cafe at index \(cafeIndex): '\(cafe.name)' (id: \(cafe.id), supabaseId: \(cafe.supabaseId?.uuidString ?? "nil"))")
            
            // Count ALL visits for this cafe across all users (to match Supabase reality)
            // Match visits by supabaseCafeId first, then cafeId
            let cafeVisits = appData.visits.filter { v in
                if let supabaseCafeId = v.supabaseCafeId, supabaseCafeId == targetCafeId {
                    return true
                }
                if v.cafeId == targetCafeId || v.cafeId == cafe.id {
                    return true
                }
                return false
            }
            
            let oldVisitCount = appData.cafes[cafeIndex].visitCount
            appData.cafes[cafeIndex].visitCount = cafeVisits.count
            
            // Recalculate average rating for the cafe
            if !cafeVisits.isEmpty {
                let totalRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore }
                appData.cafes[cafeIndex].averageRating = totalRating / Double(cafeVisits.count)
            }
            
            print("📊 [CafeStats] ✅ Updated '\(appData.cafes[cafeIndex].name)':")
            print("   - visitCount: \(oldVisitCount) → \(appData.cafes[cafeIndex].visitCount)")
            print("   - averageRating: \(appData.cafes[cafeIndex].averageRating)")
            print("   - hasLocation: \(appData.cafes[cafeIndex].location != nil)")
            print("   - location: \(appData.cafes[cafeIndex].location?.latitude ?? 0), \(appData.cafes[cafeIndex].location?.longitude ?? 0)")
            print("   - isFavorite: \(appData.cafes[cafeIndex].isFavorite)")
            print("   - wantToTry: \(appData.cafes[cafeIndex].wantToTry)")
            save()
        } else {
            print("❌ [CafeStats] Could not find cafe with targetCafeId: \(targetCafeId)")
            print("❌ [CafeStats] Available cafe IDs:")
            for (index, cafe) in appData.cafes.enumerated() {
                print("   [\(index)] '\(cafe.name)' - id: \(cafe.id), supabaseId: \(cafe.supabaseId?.uuidString ?? "nil")")
            }
        }
    }
    
    private func mapRemoteVisit(_ remote: RemoteVisit) -> Visit {
        print("🗺️ [MapVisit] Mapping RemoteVisit - id: \(remote.id), cafeId: \(remote.cafeId)")
        
        let cafe: Cafe
        if let embeddedCafe = remote.cafe {
            // Visit includes cafe data - upsert it
            print("🗺️ [MapVisit] Visit has embedded cafe: '\(embeddedCafe.name)' (id: \(embeddedCafe.id))")
            cafe = upsertCafe(from: embeddedCafe)
        } else if let existing = appData.cafes.first(where: { ($0.supabaseId ?? $0.id) == remote.cafeId }) {
            // Cafe already exists locally
            print("🗺️ [MapVisit] Found existing cafe: '\(existing.name)'")
            cafe = existing
        } else {
            // Shouldn't happen in production, but create placeholder
            print("⚠️ [MapVisit] WARNING: No cafe data for visit - creating placeholder")
            let placeholder = Cafe(
                id: remote.cafeId,
                supabaseId: remote.cafeId,
                name: "Unknown Cafe",
                address: "",
                city: nil,
                country: nil
            )
            appData.cafes.append(placeholder)
            cafe = placeholder
        }
        
        let sortedPhotos = (remote.photos ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let photoKeys = sortedPhotos.map { "remote-\($0.id.uuidString)" }
        var remoteURLMap: [String: String] = [:]
        for (index, photo) in sortedPhotos.enumerated() {
            remoteURLMap[photoKeys[index]] = photo.photoURL
        }
        
        let likeUsers = (remote.likes ?? []).compactMap { UUID(uuidString: $0.userId) }
        let comments = (remote.comments ?? []).map { remoteComment -> Comment in
            let commentUserId = UUID(uuidString: remoteComment.userId) ?? UUID()
            return Comment(
                id: remoteComment.id,
                supabaseId: remoteComment.id,
                visitId: remoteComment.visitId,
                userId: commentUserId,
                supabaseUserId: remoteComment.userId,
                text: remoteComment.text,
                createdAt: remoteComment.createdAt ?? Date(),
                mentions: MentionParser.parseMentions(from: remoteComment.text)
            )
        }
        
        let mappedDrinkType: DrinkType
        if let remoteDrinkType = remote.drinkType,
           let drinkEnum = DrinkType(rawValue: remoteDrinkType) {
            mappedDrinkType = drinkEnum
        } else if let custom = remote.drinkTypeCustom,
                  !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mappedDrinkType = .other
        } else {
            mappedDrinkType = .coffee
        }
        
        var visit = Visit(
            id: remote.id,
            supabaseId: remote.id,
            supabaseCafeId: remote.cafeId,
            supabaseUserId: remote.userId,
            cafeId: cafe.id,
            userId: UUID(uuidString: remote.userId) ?? UUID(),
            createdAt: remote.createdAt ?? Date(),
            drinkType: mappedDrinkType,
            customDrinkType: remote.drinkTypeCustom,
            caption: remote.caption,
            notes: remote.notes,
            photos: photoKeys,
            posterPhotoIndex: 0,
            posterPhotoURL: remote.posterPhotoURL,
            remotePhotoURLByKey: remoteURLMap,
            ratings: remote.ratings,
            overallScore: remote.overallScore,
            visibility: VisitVisibility(remoteValue: remote.visibility),
            likeCount: remote.likes?.count ?? 0,
            likedByUserIds: likeUsers,
            comments: comments,
            mentions: MentionParser.parseMentions(from: remote.caption)
        )
        
        if let posterURL = remote.posterPhotoURL,
           let index = sortedPhotos.firstIndex(where: { $0.photoURL == posterURL }) {
            visit.posterPhotoIndex = index
        }
        
        if let author = remote.author {
            visit.authorDisplayName = author.displayName ?? author.username
            visit.authorUsername = author.username
            visit.authorAvatarURL = author.avatarURL
        }
        
        return visit
    }
    
    private func mapRemoteNotification(_ remote: RemoteNotification) -> MugshotNotification {
        let type = NotificationType(rawValue: remote.type) ?? .system
        
        // Prefer rich actor profile data when available
        let actorLabel: String
        if let displayName = remote.actorDisplayName, !displayName.isEmpty {
            actorLabel = displayName
        } else if let username = remote.actorUsername, !username.isEmpty {
            actorLabel = username
        } else {
            // Fallback to a short id prefix if we truly have no profile info
            actorLabel = String(remote.actorUserId.prefix(6))
        }
        
        let message: String
        switch type {
        case .newVisitFromFriend:
            message = "\(actorLabel) posted a new visit"
        case .like:
            message = "\(actorLabel) liked your visit"
        case .comment:
            message = "\(actorLabel) commented on your visit"
        case .mention:
            message = "\(actorLabel) mentioned you"
        case .follow:
            message = "\(actorLabel) followed you"
        case .friendRequest:
            message = "\(actorLabel) sent you a friend request"
        case .friendAccept:
            message = "\(actorLabel) accepted your friend request"
        case .friendJoin:
            message = "\(actorLabel) joined Mugshot"
        default:
            message = "You have a new notification"
        }
        
        return MugshotNotification(
            id: remote.id,
            supabaseId: remote.id,
            type: type,
            supabaseUserId: remote.userId,
            actorSupabaseUserId: remote.actorUserId,
            actorUsername: remote.actorUsername,
            actorDisplayName: remote.actorDisplayName,
            // Use the remote avatar URL as the cache key; PhotoCache will use this to store/load the image
            actorAvatarKey: remote.actorAvatarURL,
            targetVisitId: remote.visitId,
            visitSupabaseId: remote.visitId,
            targetCafeName: nil,
            commentSupabaseId: remote.commentId,
            message: message,
            createdAt: remote.createdAt ?? Date(),
            isRead: remote.readAt != nil
        )
    }
}

private struct UploadedVisitPhoto {
    let photoURL: String
    let sortOrder: Int
    let image: UIImage
}

extension DataManager {
    private func visitsForCurrentUser() -> [Visit] {
        guard let userId = appData.currentUser?.id else {
            return appData.visits
        }
        return visits(for: userId)
    }
    
    private func visits(for userId: UUID) -> [Visit] {
        appData.visits.filter { $0.userId == userId }
    }
}

// MARK: - Feature Flags

extension DataManager {
    /// Toggles between classic single-page post flow and new onboarding-style multi-step flow
    func togglePostFlowStyle() {
        appData.useOnboardingStylePostFlow.toggle()
        save()
        print("[FeatureFlag] Post flow style: \(appData.useOnboardingStylePostFlow ? "Onboarding-style" : "Classic")")
    }
    
    /// Sets the post flow style directly
    func setPostFlowStyle(useOnboardingStyle: Bool) {
        appData.useOnboardingStylePostFlow = useOnboardingStyle
        save()
        print("[FeatureFlag] Post flow style set to: \(useOnboardingStyle ? "Onboarding-style" : "Classic")")
    }
    
    /// Resets onboarding state to force the full onboarding flow to start
    /// This does NOT affect authentication status or Supabase session
    /// Use this for testing onboarding scenarios without logging out
    func resetOnboardingState() {
        print("[DeveloperTool] Resetting onboarding state - forcing onboarding flow")
        appData.hasSeenMarketingOnboarding = false
        appData.hasCompletedProfileSetup = false
        appData.isNewAccountSignup = true
        save()
        print("[DeveloperTool] Onboarding state reset complete:")
        print("  - hasSeenMarketingOnboarding: \(appData.hasSeenMarketingOnboarding)")
        print("  - hasCompletedProfileSetup: \(appData.hasCompletedProfileSetup)")
        print("  - isNewAccountSignup: \(appData.isNewAccountSignup)")
        print("  - isUserAuthenticated: \(appData.isUserAuthenticated) (preserved)")
        print("  - hasEmailVerified: \(appData.hasEmailVerified) (preserved)")
    }
    
    /// Toggles Sip Squad simplified style (mint pins with rating, no legend)
    /// OFF (default): Standard color-coded pins (green/yellow/red) with legend
    /// ON: Mugshot Mint colored pins with rating displayed, no legend
    func toggleSipSquadSimplifiedStyle() {
        appData.useSipSquadSimplifiedStyle.toggle()
        save()
        print("[FeatureFlag] Sip Squad style: \(appData.useSipSquadSimplifiedStyle ? "Simplified (mint)" : "Standard (color-coded)")")
    }
    
    /// Sets Sip Squad simplified style directly
    func setSipSquadSimplifiedStyle(enabled: Bool) {
        appData.useSipSquadSimplifiedStyle = enabled
        save()
        print("[FeatureFlag] Sip Squad style set to: \(enabled ? "Simplified (mint)" : "Standard (color-coded)")")
    }
}

// MARK: - Sip Squad Map Mode

extension DataManager {
    /// Toggles Sip Squad mode on/off and persists the state
    func toggleSipSquadMode() {
        appData.isSipSquadModeEnabled.toggle()
        save()
        print("[SipSquad] Mode toggled: \(appData.isSipSquadModeEnabled ? "ON" : "OFF")")
        
        // If enabling, fetch friend visits
        if appData.isSipSquadModeEnabled {
            Task {
                await fetchSipSquadVisitsIfNeeded()
            }
        }
    }
    
    /// Sets Sip Squad mode directly
    func setSipSquadMode(enabled: Bool) {
        guard appData.isSipSquadModeEnabled != enabled else { return }
        appData.isSipSquadModeEnabled = enabled
        save()
        print("[SipSquad] Mode set: \(enabled ? "ON" : "OFF")")
        
        if enabled {
            Task {
                await fetchSipSquadVisitsIfNeeded()
            }
        }
    }
    
    /// Fetches friend visits for Sip Squad mode if not already loaded
    func fetchSipSquadVisitsIfNeeded() async {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("[SipSquad] No authenticated user, skipping fetch")
            return
        }
        
        print("[SipSquad] ========== FETCHING SIP SQUAD DATA ==========")
        
        // Step 1: Refresh friends list
        do {
            let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
            appData.friendsSupabaseUserIds = Set(friends)
            print("[SipSquad] Friends count: \(friends.count) (ids: \(friends.prefix(3).map { $0.prefix(8) })...)")
        } catch {
            print("[SipSquad] Error fetching friends list: \(error.localizedDescription)")
        }
        
        guard !appData.friendsSupabaseUserIds.isEmpty else {
            print("[SipSquad] No friends found - Sip Squad will only show user's own visits")
            return
        }
        
        // Step 2: Fetch friend visits
        do {
            let remoteVisits = try await visitService.fetchFriendsFeed(
                currentUserId: supabaseUserId,
                followingIds: Array(appData.friendsSupabaseUserIds)
            )
            
            print("[SipSquad] Fetched \(remoteVisits.count) visits from friends")
            
            // Map and merge visits (this also upserts cafes via mapRemoteVisit)
            let mapped = remoteVisits.map { mapRemoteVisit($0) }
            mergeVisits(mapped)
            
            // Ensure cafes are saved
            save()
            
            // Update cafe stats for all fetched visits
            let uniqueCafeIds = Set(mapped.map { $0.cafeId })
            for cafeId in uniqueCafeIds {
                if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                    updateCafeStatsForVisit(sampleVisit)
                }
            }
            
            print("[SipSquad] Visits merged - total cafes in appData: \(appData.cafes.count)")
            print("[SipSquad] ========================================")
            
            // WIDGET REFRESH: Sync widget data after loading friend visits
            // This ensures the Friends' Latest Sips widget gets updated
            syncWidgetData()
            
        } catch {
            print("[SipSquad] Error fetching friend visits: \(error.localizedDescription)")
        }
    }
    
    /// Returns cafes for Sip Squad mode with aggregated ratings from user + friends
    /// Each returned cafe has its averageRating set to the Sip Squad average
    /// Includes cafes visited by the user OR any of their friends
    func getSipSquadCafes() -> [Cafe] {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("[SipSquad] No supabaseUserId, cannot get Sip Squad cafes")
            return []
        }
        
        let friendIds = appData.friendsSupabaseUserIds
        let currentUserId = appData.currentUser?.id
        
        print("[SipSquad] ========== AGGREGATING SIP SQUAD CAFES ==========")
        print("[SipSquad] Current user supabaseUserId: \(supabaseUserId.prefix(8))...")
        print("[SipSquad] Friends count: \(friendIds.count)")
        print("[SipSquad] Total visits in appData: \(appData.visits.count)")
        
        // STEP 1: Collect all Sip Squad visits (user + friends)
        // Use multiple matching strategies to ensure we don't miss visits
        var sipSquadVisits: [Visit] = []
        var userVisitIds = Set<UUID>()
        var friendVisitIds = Set<UUID>()
        
        for visit in appData.visits {
            var isCurrentUser = false
            var isFriend = false
            
            // Match current user's visits by supabaseUserId or userId
            if visit.supabaseUserId == supabaseUserId {
                isCurrentUser = true
            } else if let userId = currentUserId, visit.userId == userId {
                isCurrentUser = true
            }
            
            // Match friend visits by supabaseUserId
            if let visitAuthorId = visit.supabaseUserId, 
               friendIds.contains(visitAuthorId),
               visitAuthorId != supabaseUserId {
                isFriend = true
            }
            
            if isCurrentUser || isFriend {
                sipSquadVisits.append(visit)
                if isCurrentUser {
                    userVisitIds.insert(visit.id)
                }
                if isFriend {
                    friendVisitIds.insert(visit.id)
                }
            }
        }
        
        print("[SipSquad] Matched visits - User: \(userVisitIds.count), Friends: \(friendVisitIds.count), Total: \(sipSquadVisits.count)")
        
        // If still no visits and user has a current user ID, try fallback
        if sipSquadVisits.isEmpty, let userId = currentUserId {
            print("[SipSquad] No visits matched, trying fallback match by userId only...")
            sipSquadVisits = appData.visits.filter { $0.userId == userId }
            print("[SipSquad] Fallback matched: \(sipSquadVisits.count) visits")
        }
        
        guard !sipSquadVisits.isEmpty else {
            print("[SipSquad] ERROR: No visits found!")
            if !appData.visits.isEmpty {
                let sample = appData.visits.first!
                print("[SipSquad] Sample visit: userId=\(sample.userId), supabaseUserId=\(sample.supabaseUserId ?? "nil")")
            }
            return []
        }
        
        // STEP 2: Group visits by normalized cafe key
        // Use supabaseCafeId when available for consistent grouping across devices
        var visitsByNormalizedCafeKey: [UUID: [Visit]] = [:]
        
        for visit in sipSquadVisits {
            let cafeKey = visit.supabaseCafeId ?? visit.cafeId
            visitsByNormalizedCafeKey[cafeKey, default: []].append(visit)
        }
        
        print("[SipSquad] Grouped into \(visitsByNormalizedCafeKey.count) unique cafes")
        
        // STEP 3: Build cafe list with aggregated ratings
        var resultCafes: [Cafe] = []
        var cafesProcessed: Set<UUID> = []
        
        for (cafeKey, visits) in visitsByNormalizedCafeKey {
            let firstVisit = visits.first!
            
            // Find the cafe using multiple strategies
            var foundCafe: Cafe? = nil
            
            // Strategy 1: Match by supabaseId
            foundCafe = appData.cafes.first { $0.supabaseId == cafeKey }
            
            // Strategy 2: Match by local id
            if foundCafe == nil {
                foundCafe = appData.cafes.first { $0.id == cafeKey }
            }
            
            // Strategy 3: Match by visit's cafeId
            if foundCafe == nil {
                foundCafe = appData.cafes.first { $0.id == firstVisit.cafeId }
            }
            
            // Strategy 4: Match by supabaseCafeId -> cafe.supabaseId
            if foundCafe == nil, let visitSupabaseCafeId = firstVisit.supabaseCafeId {
                foundCafe = appData.cafes.first { $0.supabaseId == visitSupabaseCafeId }
            }
            
            guard let cafe = foundCafe else {
                print("[SipSquad] ⚠️ Could not find cafe for key \(cafeKey)")
                continue
            }
            
            // Skip if we've already processed this cafe (handles duplicates)
            guard !cafesProcessed.contains(cafe.id) else {
                // Merge visits for duplicate cafe entry
                if let existingIndex = resultCafes.firstIndex(where: { $0.id == cafe.id }) {
                    // Recalculate rating with additional visits
                    let allVisitsForCafe = visitsByNormalizedCafeKey.values.flatMap { $0 }.filter {
                        ($0.supabaseCafeId ?? $0.cafeId) == cafeKey || $0.cafeId == cafe.id
                    }
                    let newAvg = computeSipSquadAverageRating(from: allVisitsForCafe)
                    var updatedCafe = resultCafes[existingIndex]
                    updatedCafe = createCafeWithUpdatedRating(updatedCafe, rating: newAvg, visitCount: allVisitsForCafe.count)
                    resultCafes[existingIndex] = updatedCafe
                }
                continue
            }
            
            cafesProcessed.insert(cafe.id)
            
            // Calculate aggregated rating from all visits for this cafe
            let avgRating = computeSipSquadAverageRating(from: visits)
            
            // Count user vs friend contributions for this cafe
            let userVisits = visits.filter { userVisitIds.contains($0.id) }
            let friendVisits = visits.filter { friendVisitIds.contains($0.id) }
            
            // Log sample cafe details (first 3 cafes)
            if resultCafes.count < 3 {
                print("[SipSquad] Cafe '\(cafe.name)' - \(visits.count) visits (user: \(userVisits.count), friends: \(friendVisits.count)), avgRating: \(avgRating)")
            }
            
            // Create cafe copy with Sip Squad aggregated rating
            let sipSquadCafe = createCafeWithUpdatedRating(cafe, rating: avgRating, visitCount: visits.count)
            resultCafes.append(sipSquadCafe)
        }
        
        print("[SipSquad] Aggregated cafes: \(resultCafes.count)")
        print("[SipSquad] ================================================")
        return resultCafes
    }
    
    /// Helper to create a cafe copy with updated rating and visit count
    private func createCafeWithUpdatedRating(_ cafe: Cafe, rating: Double, visitCount: Int) -> Cafe {
        return Cafe(
            id: cafe.id,
            supabaseId: cafe.supabaseId,
            name: cafe.name,
            location: cafe.location,
            address: cafe.address,
            city: cafe.city,
            country: cafe.country,
            isFavorite: cafe.isFavorite,
            wantToTry: cafe.wantToTry,
            averageRating: rating,
            visitCount: visitCount,
            mapItemURL: cafe.mapItemURL,
            websiteURL: cafe.websiteURL,
            applePlaceId: cafe.applePlaceId,
            placeCategory: cafe.placeCategory
        )
    }
    
    /// Computes the Sip Squad average rating from a list of visits
    /// Simple arithmetic mean, rounded to 1 decimal place
    func computeSipSquadAverageRating(from visits: [Visit]) -> Double {
        guard !visits.isEmpty else { return 0.0 }
        let sum = visits.reduce(0.0) { $0 + $1.overallScore }
        let avg = sum / Double(visits.count)
        // Round to 1 decimal place
        return (avg * 10).rounded() / 10
    }
    
    /// Computes the Sip Squad average rating for a specific cafe
    func computeSipSquadAverageRating(for cafeId: UUID) -> Double {
        guard let supabaseUserId = appData.supabaseUserId else { return 0.0 }
        let friendIds = appData.friendsSupabaseUserIds
        
        // Get all visits for this cafe from user + friends
        let cafeVisits = appData.visits.filter { visit in
            guard visit.cafeId == cafeId || visit.supabaseCafeId == cafeId else { return false }
            guard let authorId = visit.supabaseUserId else { return false }
            return authorId == supabaseUserId || friendIds.contains(authorId)
        }
        
        return computeSipSquadAverageRating(from: cafeVisits)
    }
    
    /// Returns whether the user has friends for Sip Squad mode
    var hasFriendsForSipSquad: Bool {
        !appData.friendsSupabaseUserIds.isEmpty
    }
    
    /// Returns the number of cafes visited by friends (excluding user's own visits)
    func getFriendVisitedCafeCount() -> Int {
        guard let supabaseUserId = appData.supabaseUserId else { return 0 }
        let friendIds = appData.friendsSupabaseUserIds
        
        // Get visits from friends only (not the current user)
        let friendVisits = appData.visits.filter { visit in
            guard let authorId = visit.supabaseUserId else { return false }
            return friendIds.contains(authorId) && authorId != supabaseUserId
        }
        
        // Count unique cafes
        let uniqueCafeIds = Set(friendVisits.map { $0.cafeId })
        return uniqueCafeIds.count
    }
    
    // MARK: - Map Data: Solo Mode vs Sip Squad Mode
    
    /// Returns cafes for SOLO map mode (only current user's visits)
    /// This ensures friends' visits do NOT appear on the map in solo mode
    /// Includes cafes that have been visited by current user, or marked as favorite/wantToTry
    func getCurrentUserCafesForMap() -> [Cafe] {
        guard let supabaseUserId = appData.supabaseUserId else {
            #if DEBUG
            print("[Map:Solo] No supabaseUserId - returning empty cafes")
            #endif
            return []
        }
        
        let currentUserId = appData.currentUser?.id
        
        // Get cafe IDs where the current user has logged visits
        let currentUserVisitedCafeIds = Set(
            appData.visits
                .filter { visit in
                    // Match current user by supabaseUserId or local userId
                    if visit.supabaseUserId == supabaseUserId {
                        return true
                    }
                    if let userId = currentUserId, visit.userId == userId {
                        return true
                    }
                    return false
                }
                .map { $0.cafeId }
        )
        
        // Filter cafes to only those visited by current user OR marked as favorite/wantToTry
        let currentUserCafes = appData.cafes.filter { cafe in
            // Include if current user has visited
            if currentUserVisitedCafeIds.contains(cafe.id) {
                return true
            }
            
            // Also check by supabaseId (for cafes synced from remote)
            if let supabaseId = cafe.supabaseId, currentUserVisitedCafeIds.contains(supabaseId) {
                return true
            }
            
            // Include if marked as favorite or want to try (these are always user's own)
            if cafe.isFavorite || cafe.wantToTry {
                return true
            }
            
            return false
        }
        
        // Recalculate ratings based on current user's visits only
        var resultCafes: [Cafe] = []
        for cafe in currentUserCafes {
            let userVisitsForCafe = appData.visits.filter { visit in
                // Check if visit is for this cafe
                let isForCafe = visit.cafeId == cafe.id || visit.supabaseCafeId == cafe.id || visit.supabaseCafeId == cafe.supabaseId
                guard isForCafe else { return false }
                
                // Check if visit is by current user
                if visit.supabaseUserId == supabaseUserId {
                    return true
                }
                if let userId = currentUserId, visit.userId == userId {
                    return true
                }
                return false
            }
            
            if userVisitsForCafe.isEmpty && !cafe.isFavorite && !cafe.wantToTry {
                // Skip cafes with no user visits unless they're favorite/wantToTry
                continue
            }
            
            // Calculate rating from user's visits only
            let avgRating: Double
            if !userVisitsForCafe.isEmpty {
                let sum = userVisitsForCafe.reduce(0.0) { $0 + $1.overallScore }
                avgRating = (sum / Double(userVisitsForCafe.count) * 10).rounded() / 10
            } else {
                avgRating = cafe.averageRating // Keep existing for favorite/wantToTry without visits
            }
            
            let updatedCafe = createCafeWithUpdatedRating(
                cafe,
                rating: avgRating,
                visitCount: userVisitsForCafe.count
            )
            resultCafes.append(updatedCafe)
        }
        
        #if DEBUG
        print("[Map:Solo] ========== SOLO MODE CAFES ==========")
        print("[Map:Solo] Current user supabaseUserId: \(supabaseUserId.prefix(8))...")
        print("[Map:Solo] Total visits in appData: \(appData.visits.count)")
        print("[Map:Solo] Current user visited cafe IDs: \(currentUserVisitedCafeIds.count)")
        print("[Map:Solo] Filtered cafes for solo map: \(resultCafes.count)")
        if resultCafes.count <= 5 {
            for cafe in resultCafes {
                print("[Map:Solo]   - '\(cafe.name)' (visits: \(cafe.visitCount), rating: \(cafe.averageRating), fav: \(cafe.isFavorite), want: \(cafe.wantToTry))")
            }
        }
        print("[Map:Solo] ======================================")
        #endif
        
        return resultCafes
    }
}

// MARK: - Favorites & Wishlist Persistence

extension DataManager {
    /// Syncs a cafe's favorite/wantToTry state to Supabase
    /// Ensures the cafe exists in Supabase first, then updates user_cafe_states
    func syncCafeStateToSupabase(cafe: Cafe) async {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("[Favorites] Cannot sync - no authenticated user")
            return
        }
        
        // Determine the Supabase cafe ID
        var supabaseCafeId = cafe.supabaseId
        
        // If cafe doesn't have a Supabase ID, we need to find or create it
        if supabaseCafeId == nil {
            do {
                let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
                supabaseCafeId = remoteCafe.id
                
                // Update local cafe with the Supabase ID
                if let index = appData.cafes.firstIndex(where: { $0.id == cafe.id }) {
                    appData.cafes[index].supabaseId = remoteCafe.id
                    save()
                    print("[Favorites] Updated cafe '\(cafe.name)' with supabaseId: \(remoteCafe.id)")
                }
            } catch {
                print("[Favorites] Failed to find/create cafe in Supabase: \(error.localizedDescription)")
                return
            }
        }
        
        guard let cafeId = supabaseCafeId else {
            print("[Favorites] Cannot sync - cafe has no Supabase ID")
            return
        }
        
        // Sync the state
        do {
            try await userCafeStateService.upsertCafeState(
                userId: supabaseUserId,
                cafeId: cafeId,
                isFavorite: cafe.isFavorite,
                wantToTry: cafe.wantToTry
            )
            print("[Favorites] Synced state to Supabase - cafe: '\(cafe.name)', favorite: \(cafe.isFavorite), wantToTry: \(cafe.wantToTry)")
        } catch {
            print("[Favorites] Failed to sync state to Supabase: \(error.localizedDescription)")
        }
    }
    
    /// Fetches and applies user's cafe states (favorites/wishlist) from Supabase
    /// Called after login to restore persisted state
    func fetchAndApplyUserCafeStates() async {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("[Favorites] Cannot fetch states - no authenticated user")
            return
        }
        
        print("[Favorites] Fetching favorites and wishlist from Supabase for userId=\(supabaseUserId.prefix(8))...")
        
        do {
            let states = try await userCafeStateService.fetchUserCafeStates(userId: supabaseUserId)
            
            if states.isEmpty {
                print("[Favorites] No favorites or wishlist items found in Supabase")
                return
            }
            
            var appliedFavorites = 0
            var appliedWantToTry = 0
            var cafesCreated = 0
            
            for state in states {
                // Find the cafe by supabaseId
                if let index = appData.cafes.firstIndex(where: { $0.supabaseId == state.cafeId || $0.id == state.cafeId }) {
                    // Update existing cafe
                    if state.isFavorite {
                        appData.cafes[index].isFavorite = true
                        appliedFavorites += 1
                    }
                    if state.wantToTry {
                        appData.cafes[index].wantToTry = true
                        appliedWantToTry += 1
                    }
                    print("[Favorites] Applied state to existing cafe: '\(appData.cafes[index].name)' - favorite: \(state.isFavorite), wantToTry: \(state.wantToTry)")
                } else {
                    // Cafe not in local list - fetch it from Supabase
                    do {
                        let remoteCafes = try await cafeService.fetchCafes(ids: [state.cafeId])
                        if let remoteCafe = remoteCafes.first {
                            var localCafe = Cafe(
                                id: remoteCafe.id,
                                supabaseId: remoteCafe.id,
                                name: remoteCafe.name,
                                location: (remoteCafe.latitude != nil && remoteCafe.longitude != nil) 
                                    ? CLLocationCoordinate2D(latitude: remoteCafe.latitude!, longitude: remoteCafe.longitude!)
                                    : nil,
                                address: remoteCafe.address ?? "",
                                city: remoteCafe.city,
                                country: remoteCafe.country,
                                isFavorite: state.isFavorite,
                                wantToTry: state.wantToTry,
                                websiteURL: remoteCafe.websiteURL,
                                applePlaceId: remoteCafe.applePlaceId
                            )
                            appData.cafes.append(localCafe)
                            cafesCreated += 1
                            if state.isFavorite { appliedFavorites += 1 }
                            if state.wantToTry { appliedWantToTry += 1 }
                            print("[Favorites] Created local cafe from Supabase: '\(localCafe.name)' - favorite: \(state.isFavorite), wantToTry: \(state.wantToTry)")
                        }
                    } catch {
                        print("[Favorites] Failed to fetch cafe \(state.cafeId) from Supabase: \(error.localizedDescription)")
                    }
                }
            }
            
            save()
            syncWidgetData()
            
            print("[Favorites] ✅ Loaded \(appliedFavorites) favorites, \(appliedWantToTry) want_to_try from Supabase for userId=\(supabaseUserId.prefix(8))...")
            if cafesCreated > 0 {
                print("[Favorites] Created \(cafesCreated) new local cafes from Supabase data")
            }
        } catch {
            print("[Favorites] Failed to fetch cafe states from Supabase: \(error.localizedDescription)")
        }
    }
}
