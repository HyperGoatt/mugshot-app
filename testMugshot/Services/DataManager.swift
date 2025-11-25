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
    
    @Published var appData: AppData
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
    
    private init(
        authService: SupabaseAuthService = .shared,
        profileService: SupabaseUserProfileService = .shared,
        storageService: SupabaseStorageService = .shared,
        cafeService: SupabaseCafeService = .shared,
        visitService: SupabaseVisitService = .shared,
        socialGraphService: SupabaseSocialGraphService = .shared,
        notificationService: SupabaseNotificationService = .shared
    ) {
        self.authService = authService
        self.profileService = profileService
        self.storageService = storageService
        self.cafeService = cafeService
        self.visitService = visitService
        self.socialGraphService = socialGraphService
        self.notificationService = notificationService
        // Try to load existing data, otherwise start fresh
        if let data = UserDefaults.standard.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data) {
            self.appData = decoded
            // Preload images for all visits
            preloadVisitImages()
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

    func signUp(
        displayName: String,
        username: String,
        email: String,
        password: String
    ) async throws {
        print("[Auth] signUp: Starting signup for email: \(email)")
        
        // Tuple return type change
        let (session, userId) = try await authService.signUp(
            email: email,
            password: password,
            displayName: displayName,
            username: username
        )

        print("[Auth] signUp: Signup successful - userId: \(userId)")
        appData.supabaseUserId = userId
        appData.currentUserEmail = email
        appData.currentUserDisplayName = displayName
        appData.currentUserUsername = username
        appData.hasEmailVerified = false

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
        print("[Auth] signUp: Auth state set - isUserAuthenticated=\(appData.isUserAuthenticated), hasEmailVerified=false")
    }
    
    func resendVerificationEmail() async throws {
        guard let email = appData.currentUserEmail else {
            throw SupabaseError.invalidSession
        }
        try await authService.resendVerificationEmail(email: email)
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
    }

    func bootstrapAuthStateOnLaunch() async {
        print("[Auth] bootstrapAuthStateOnLaunch: Starting")
        isBootstrapping = true
        // Use the single source of truth method to refresh auth status
        await refreshAuthStatusFromSupabase()
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
        } else if let username = appData.currentUserUsername, !username.isEmpty {
            finalDisplayName = username.capitalized
        } else {
            finalDisplayName = "User"
        }
        
        let finalUsername: String
        if let username = appData.currentUserUsername, !username.isEmpty {
            finalUsername = username.lowercased()
        } else {
            finalUsername = "user"
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
        try await refreshProfileVisits()
        save()
        
        // Request push notification permissions after profile setup
        await registerPushNotificationsIfNeeded()
    }
    
    private func mapRemoteUserProfile(_ profile: RemoteUserProfile) {
        appData.supabaseUserId = profile.id
        appData.currentUserDisplayName = profile.displayName
        appData.currentUserUsername = profile.username
        appData.currentUserBio = profile.bio
        appData.currentUserLocation = profile.location
        appData.currentUserFavoriteDrink = profile.favoriteDrink
        appData.currentUserInstagramHandle = profile.instagramHandle
        appData.currentUserWebsite = profile.websiteURL
        appData.currentUserAvatarURL = profile.avatarURL
        appData.currentUserBannerURL = profile.bannerURL

        let remoteUUID = UUID(uuidString: profile.id) ?? appData.currentUser?.id ?? UUID()
        var localUser = profile.toLocalUser(existing: appData.currentUser, overridingId: remoteUUID)
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
        Task {
            await authService.signOut()
        }
        // Clear all data and reset to initial state
        appData = AppData()
        save()
        // Clear photo cache
        PhotoCache.shared.clear()
        // Note: We don't delete the device token on logout - it will be cleaned up
        // when the user logs in again or if they uninstall the app
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
            appData.cafes[index].isFavorite.toggle()
            save()
        }
    }
    
    func toggleCafeWantToTry(_ cafeId: UUID) {
        if let index = appData.cafes.firstIndex(where: { $0.id == cafeId }) {
            appData.cafes[index].wantToTry.toggle()
            save()
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
        
        let payload = VisitInsertPayload(
            userId: supabaseUserId,
            cafeId: remoteCafe.id,
            drinkType: drinkType.rawValue,
            drinkTypeCustom: customDrinkType,
            caption: caption,
            notes: notes,
            visibility: visibility.supabaseValue,
            ratings: ratings,
            overallScore: overallScore,
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
            print("[Visit] overallScore = \(payload.overallScore)")
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
    }
    
    func getVisit(id: UUID) -> Visit? {
        return appData.visits.first(where: { $0.id == id })
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
        
        var visit = appData.visits[index]
        
        do {
            if visit.isLikedBy(userId: currentUser.id) {
                try await visitService.removeLike(visitId: remoteVisitId, userId: supabaseUserId)
                visit.likedByUserIds.removeAll { $0 == currentUser.id }
                visit.likeCount = max(0, visit.likeCount - 1)
            } else {
                _ = try await visitService.addLike(visitId: remoteVisitId, userId: supabaseUserId)
                visit.likedByUserIds.append(currentUser.id)
                visit.likeCount += 1
                
                 if let ownerId = visit.supabaseUserId, ownerId != supabaseUserId {
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
            appData.visits[index] = visit
            save()
        } catch {
            print("Supabase like toggle failed: \(error.localizedDescription)")
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
            throw SupabaseError.invalidSession
        }
        
        do {
            // First, fetch the request to get fromUserId and toUserId
            let incomingRequests = try await socialGraphService.fetchIncomingFriendRequests(for: supabaseUserId)
            guard let request = incomingRequests.first(where: { $0.id == requestId }) else {
                throw SupabaseError.decoding("Friend request not found")
            }
            
            try await socialGraphService.acceptFriendRequest(
                requestId: requestId,
                fromUserId: request.fromUserId,
                toUserId: request.toUserId
            )
            
            // Refresh friends list
            let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
            appData.friendsSupabaseUserIds = Set(friends)
            
            // Create notification for the requester that their request was accepted
            let payload = NotificationInsertPayload(
                userId: request.fromUserId,
                actorUserId: supabaseUserId,
                type: "friend_accept",
                visitId: nil,
                commentId: nil
            )
            try? await notificationService.createNotification(payload)
            
            print("[Friends] Friend request accepted - id: \(requestId)")
            save()
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
    
    func fetchFriendRequests() async throws -> (incoming: [FriendRequest], outgoing: [FriendRequest]) {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }
        
        let incoming = try await socialGraphService.fetchIncomingFriendRequests(for: supabaseUserId)
        let outgoing = try await socialGraphService.fetchOutgoingFriendRequests(for: supabaseUserId)
        
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
        let remoteVisits = try await visitService.fetchVisitsForUserProfile(userId: userId)
        let mapped = remoteVisits.map { mapRemoteVisit($0) }
        mergeVisits(mapped)
        
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
    
    // MARK: - Feed Operations
    func getFeedVisits(scope: FeedScope, currentUserId: UUID) -> [Visit] {
        let allVisits = appData.visits.sorted { $0.createdAt > $1.createdAt }
        
        switch scope {
        case .everyone:
            // Show visits with visibility == .everyone
            return allVisits.filter { $0.visibility == .everyone }
        case .friends:
            return allVisits.filter { visit in
                guard visit.visibility != .private else {
                    return visit.userId == currentUserId
                }
                
                if visit.userId == currentUserId {
                    return true
                }
                
                guard let authorSupabaseId = visit.supabaseUserId else {
                    return false
                }
                
                return appData.friendsSupabaseUserIds.contains(authorSupabaseId)
            }
        }
    }
    
    func refreshFeed(scope: FeedScope) async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        print("🔄 [RefreshFeed] Starting feed refresh - scope: \(scope)")
        do {
            let remoteVisits: [RemoteVisit]
            switch scope {
            case .everyone:
                remoteVisits = try await visitService.fetchEveryoneFeed()
            case .friends:
                let friends = try await socialGraphService.fetchFriends(for: supabaseUserId)
                appData.friendsSupabaseUserIds = Set(friends)
                remoteVisits = try await visitService.fetchFriendsFeed(currentUserId: supabaseUserId, followingIds: friends)
            }
            print("🔄 [RefreshFeed] Fetched \(remoteVisits.count) remote visits")
            
            let mapped = remoteVisits.map { mapRemoteVisit($0) }
            mergeVisits(mapped)
            print("🔄 [RefreshFeed] Visits merged into appData")
            
            // CRITICAL: Recalculate visitCount for all cafes after fetching feed
            print("🔄 [RefreshFeed] Recalculating cafe stats for all feed visits...")
            let uniqueCafeIds = Set(mapped.map { $0.cafeId })
            for cafeId in uniqueCafeIds {
                if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                    updateCafeStatsForVisit(sampleVisit)
                }
            }
            print("🔄 [RefreshFeed] Cafe stats recalculation complete")
        } catch {
            print("❌ [RefreshFeed] Failed to refresh feed: \(error.localizedDescription)")
        }
    }
    
    func refreshProfileVisits() async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("🔄 [RefreshVisits] No supabaseUserId, skipping")
            return
        }
        print("🔄 [RefreshVisits] Fetching profile visits for userId: \(supabaseUserId)")
        let remoteVisits = try await visitService.fetchVisitsForUserProfile(userId: supabaseUserId)
        print("🔄 [RefreshVisits] Fetched \(remoteVisits.count) remote visits")
        
        let mapped = remoteVisits.map { mapRemoteVisit($0) }
        mergeVisits(mapped)
        print("🔄 [RefreshVisits] Visits merged into appData")
        
        // CRITICAL: Recalculate visitCount for all cafes after fetching visits
        print("🔄 [RefreshVisits] Recalculating cafe stats for all visits...")
        let uniqueCafeIds = Set(mapped.map { $0.cafeId })
        for cafeId in uniqueCafeIds {
            if let sampleVisit = mapped.first(where: { $0.cafeId == cafeId }) {
                updateCafeStatsForVisit(sampleVisit)
            }
        }
        print("🔄 [RefreshVisits] Cafe stats recalculation complete")
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
            
            appData.visits[index].comments.append(comment)
            save()
            
            if let ownerId = appData.visits[index].supabaseUserId,
               ownerId != supabaseUserId {
                let payload = NotificationInsertPayload(
                    userId: ownerId,
                    actorUserId: supabaseUserId,
                    type: "comment",
                    visitId: appData.visits[index].supabaseId,
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
            appData.notifications = remote.map { mapRemoteNotification($0) }
            save()
        } catch {
            print("Failed to refresh notifications: \(error.localizedDescription)")
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
    
    // Get most visited café
    func getMostVisitedCafe() -> (cafe: Cafe, visitCount: Int)? {
        let visitsByCafe = Dictionary(grouping: visitsForCurrentUser(), by: { $0.cafeId })
        guard let (cafeId, visits) = visitsByCafe.max(by: { $0.value.count < $1.value.count }),
              let cafe = getCafe(id: cafeId) else {
            return nil
        }
        return (cafe: cafe, visitCount: visits.count)
    }
    
    // Get favorite café (highest average rating)
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
                address: remote.address ?? existing.address ?? "",
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
        
        var visit = Visit(
            id: remote.id,
            supabaseId: remote.id,
            supabaseCafeId: remote.cafeId,
            supabaseUserId: remote.userId,
            cafeId: cafe.id,
            userId: UUID(uuidString: remote.userId) ?? UUID(),
            createdAt: remote.createdAt ?? Date(),
            drinkType: DrinkType(rawValue: remote.drinkType ?? DrinkType.coffee.rawValue) ?? .coffee,
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
        let actorLabel = remote.actorUserId.prefix(6)
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
}
