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
        let session = try await authService.signUp(
            email: email,
            password: password,
            displayName: displayName,
            username: username
        )

        print("[Auth] signUp: Signup successful - userId: \(session.userId)")
        appData.supabaseUserId = session.userId
        // User has a session but email is not verified yet
        appData.isUserAuthenticated = true
        appData.hasEmailVerified = false
        appData.currentUserEmail = email
        appData.currentUserDisplayName = displayName
        appData.currentUserUsername = username

        let localUser = User(
            id: UUID(uuidString: session.userId) ?? UUID(),
            supabaseUserId: session.userId,
            username: username,
            displayName: displayName,
            location: appData.currentUserLocation ?? "",
            bio: appData.currentUserBio ?? ""
        )
        appData.currentUser = localUser
        save()
        print("[Auth] signUp: Auth state set - isUserAuthenticated=true, hasEmailVerified=false")
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
            let isVerified: Bool
            if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                isVerified = true
                print("[Auth] refreshAuthStatusFromSupabase: Email is verified (confirmed_at=\(confirmedAtString))")
            } else if emailConfirmedAt is NSNull {
                isVerified = false
                print("[Auth] refreshAuthStatusFromSupabase: Email not verified (email_confirmed_at is NSNull)")
            } else if emailConfirmedAt == nil {
                isVerified = false
                print("[Auth] refreshAuthStatusFromSupabase: Email not verified (email_confirmed_at is nil)")
            } else {
                // Handle any other type (shouldn't happen, but be safe)
                isVerified = false
                print("[Auth] refreshAuthStatusFromSupabase: Email not verified (email_confirmed_at is unexpected type)")
            }
            
            print("[Auth] refreshAuthStatusFromSupabase: email_confirmed_at=\(String(describing: emailConfirmedAt)), isVerified=\(isVerified)")
            
            if let email = email {
                appData.currentUserEmail = email
            }
            
            // Step 3: If email is verified, ensure profile exists and load it
            if isVerified {
                print("[Auth] refreshAuthStatusFromSupabase: Email verified - checking profile")
                appData.hasEmailVerified = true
                
                // Fetch or create profile in public.users
                if let profile = try await profileService.fetchUserProfile(userId: userId) {
                    print("[Auth] refreshAuthStatusFromSupabase: Profile found - mapping to local user")
                    mapRemoteUserProfile(profile)
                } else {
                    print("[Auth] refreshAuthStatusFromSupabase: No profile found - will be created during profile setup")
                    // Profile doesn't exist yet - user needs to complete profile setup
                    // But we still have the signup data in appData, so we can create a basic user
                    if appData.currentUser == nil {
                        let userUUID = UUID(uuidString: userId) ?? UUID()
                        let username = appData.currentUserUsername ?? email?.components(separatedBy: "@").first ?? "user"
                        let displayName = appData.currentUserDisplayName ?? username.capitalized
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
            if case .invalidSession = error {
                // Session expired - clear auth state
                print("[Auth] refreshAuthStatusFromSupabase: Session expired - clearing auth state")
                appData.isUserAuthenticated = false
                appData.hasEmailVerified = false
                appData.supabaseUserId = nil
            } else {
                // On other errors, assume email is not verified to be safe
                appData.hasEmailVerified = false
            }
            save()
        } catch {
            print("[Auth] refreshAuthStatusFromSupabase: Error - \(error.localizedDescription)")
            // On error, assume email is not verified to be safe
            appData.hasEmailVerified = false
            save()
        }
    }
    
    /// Called when user taps "I've verified my email" button
    /// Verifies email status with Supabase and advances the flow if verified
    @MainActor
    func confirmEmailAndAdvanceFlow() async {
        print("[Auth] confirmEmailAndAdvanceFlow: Button tapped")
        isCheckingEmailVerification = true
        authErrorMessage = nil
        
        guard let session = authService.restoreSession() else {
            print("[Auth] confirmEmailAndAdvanceFlow: No session found")
            authErrorMessage = "No active session. Please sign in again."
            isCheckingEmailVerification = false
            return
        }
        
        do {
            // Fetch current user to check verification status
            let userDict = try await authService.fetchCurrentUser()
            let userId = userDict["id"] as? String ?? session.userId
            let email = userDict["email"] as? String
            let emailConfirmedAt = userDict["email_confirmed_at"]
            
            print("[Auth] confirmEmailAndAdvanceFlow: userId=\(userId), email=\(email ?? "nil"), email_confirmed_at=\(String(describing: emailConfirmedAt))")
            
            // Check if email is verified - handle all possible cases
            let isVerified: Bool
            if let confirmedAtString = emailConfirmedAt as? String, !confirmedAtString.isEmpty {
                isVerified = true
                print("[Auth] confirmEmailAndAdvanceFlow: Email is verified (confirmed_at=\(confirmedAtString))")
            } else if emailConfirmedAt is NSNull {
                isVerified = false
                print("[Auth] confirmEmailAndAdvanceFlow: Email not verified (email_confirmed_at is NSNull)")
            } else if emailConfirmedAt == nil {
                isVerified = false
                print("[Auth] confirmEmailAndAdvanceFlow: Email not verified (email_confirmed_at is nil)")
            } else {
                // Handle any other type (shouldn't happen, but be safe)
                isVerified = false
                print("[Auth] confirmEmailAndAdvanceFlow: Email not verified (email_confirmed_at is unexpected type)")
            }
            
            if !isVerified {
                print("[Auth] confirmEmailAndAdvanceFlow: Email not verified yet")
                authErrorMessage = "Looks like your email isn't verified yet. Tap the link in your inbox, then try again."
                isCheckingEmailVerification = false
                return
            }
            
            // Email is verified - update state immediately
            print("[Auth] confirmEmailAndAdvanceFlow: Email verified - updating state")
            appData.hasEmailVerified = true
            if let email = email {
                appData.currentUserEmail = email
            }
            save()
            
            // Refresh auth status (this will load profile, etc.)
            print("[Auth] confirmEmailAndAdvanceFlow: Refreshing auth status")
            await refreshAuthStatusFromSupabase()
            
            // Ensure state is saved after refresh
            save()
            
            isCheckingEmailVerification = false
            print("[Auth] confirmEmailAndAdvanceFlow: Complete - hasEmailVerified=\(appData.hasEmailVerified), user can proceed")
        } catch let error as SupabaseError {
            print("[Auth] confirmEmailAndAdvanceFlow: SupabaseError - \(error.localizedDescription)")
            if case .invalidSession = error {
                authErrorMessage = "Your session expired. Please sign in again."
                // Clear auth state
                appData.isUserAuthenticated = false
                appData.hasEmailVerified = false
                save()
            } else {
                authErrorMessage = "Failed to verify email. Please try again."
            }
            isCheckingEmailVerification = false
        } catch {
            print("[Auth] confirmEmailAndAdvanceFlow: Error - \(error.localizedDescription)")
            authErrorMessage = "Failed to verify email. Please try again."
            isCheckingEmailVerification = false
        }
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
        // If sign-in succeeds, email must be verified
        appData.hasEmailVerified = true
        appData.currentUserEmail = email
        print("[Identity] Sign in authenticated - userId=\(session.userId), email=\(email)")
        print("[DataManager] Auth state updated")

        // Step 3: Fetch user profile from public.users by Supabase user ID
        print("[DataManager] Fetching profile for user id: \(session.userId)")
        do {
            if let profile = try await profileService.fetchUserProfile(userId: session.userId) {
                print("[DataManager] Profile found - displayName: \(profile.displayName), username: \(profile.username)")
                mapRemoteUserProfile(profile)
            } else {
                print("[DataManager] No profile found in public.users - using email fallback identity")
                applyEmailFallbackIdentity(email: email)
            }
        } catch {
            print("[DataManager] Error fetching profile: \(error.localizedDescription) - using email fallback identity")
            // Don't fail sign-in if profile fetch fails - use fallback identity
            applyEmailFallbackIdentity(email: email)
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
    }

    func bootstrapAuthStateOnLaunch() async {
        print("[Auth] bootstrapAuthStateOnLaunch: Starting")
        // Use the single source of truth method to refresh auth status
        await refreshAuthStatusFromSupabase()
        print("[Auth] bootstrapAuthStateOnLaunch: Complete")
    }

    func completeProfileSetupWithSupabase() async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            throw SupabaseError.invalidSession
        }

        var avatarURL = appData.currentUserAvatarURL
        if let profileId = appData.currentUserProfileImageId,
           let image = PhotoCache.shared.retrieve(forKey: profileId) {
            let path = "\(supabaseUserId)/avatar-\(profileId).jpg"
            avatarURL = try await storageService.uploadImage(image, path: path)
        }

        var bannerURL = appData.currentUserBannerURL
        if let bannerId = appData.currentUserBannerImageId,
           let image = PhotoCache.shared.retrieve(forKey: bannerId) {
            let path = "\(supabaseUserId)/banner-\(bannerId).jpg"
            bannerURL = try await storageService.uploadImage(image, path: path)
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
    }
    
    private func mapRemoteUserProfile(_ profile: RemoteUserProfile) {
        appData.supabaseUserId = profile.id
        appData.currentUserDisplayName = profile.displayName
        appData.currentUserUsername = profile.username
        appData.currentUserBio = profile.bio
        appData.currentUserLocation = profile.location
        appData.currentUserFavoriteDrink = profile.favoriteDrink
        appData.currentUserInstagramHandle = profile.instagramHandle
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
            let path = "\(supabaseUserId)/avatar-\(UUID().uuidString).jpg"
            avatarURL = try await storageService.uploadImage(avatarImage, path: path)
        }
        
        var bannerURL = appData.currentUserBannerURL
        if let bannerImage = bannerImage {
            let path = "\(supabaseUserId)/banner-\(UUID().uuidString).jpg"
            bannerURL = try await storageService.uploadImage(bannerImage, path: path)
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
    func findOrCreateCafe(from mapItem: MKMapItem) -> Cafe {
        guard let location = mapItem.placemark.location?.coordinate else {
            // If no location, just create a new cafe
            let cafe = Cafe(
                name: mapItem.name ?? "Unknown Cafe",
                address: formatAddress(from: mapItem.placemark),
                mapItemURL: mapItem.url?.absoluteString,
                websiteURL: mapItem.url?.absoluteString, // For now, use mapItem URL as fallback
                placeCategory: mapItem.pointOfInterestCategory?.rawValue
            )
            addCafe(cafe)
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
        
        // Create new cafe with Apple Maps data
        let cafe = Cafe(
            name: mapItem.name ?? "Unknown Cafe",
            location: location,
            address: formatAddress(from: mapItem.placemark),
            mapItemURL: mapItem.url?.absoluteString,
            websiteURL: websiteURL,
            placeCategory: mapItem.pointOfInterestCategory?.rawValue
        )
        addCafe(cafe)
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
            throw SupabaseError.invalidSession
        }
        
        let remoteCafe = try await cafeService.findOrCreateCafe(from: cafe)
        _ = upsertCafe(from: remoteCafe)
        
        let uploads = try await uploadVisitImages(photoImages, supabaseUserId: supabaseUserId)
        let posterURL: String?
        if posterPhotoIndex >= 0 && posterPhotoIndex < uploads.count {
            posterURL = uploads[posterPhotoIndex].photoURL
        } else {
            posterURL = uploads.first?.photoURL
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
            print("[Visit] Creating visit for userId=\(supabaseUserId), cafeId=\(remoteCafe.id)")
            print("[Visit] Payload: drinkType=\(payload.drinkType ?? "nil"), caption=\(payload.caption.prefix(50))..., photos=\(uploads.count)")
            
            let remoteVisit = try await visitService.createVisit(
                payload: payload,
                photos: uploads.map { VisitPhotoUpload(photoURL: $0.photoURL, sortOrder: $0.sortOrder) }
            )
            
            print("[Visit] Visit created in Supabase - id=\(remoteVisit.id)")
            
            cacheUploadedImages(uploads, remotePhotos: remoteVisit.photos ?? [])
            
            var visit = mapRemoteVisit(remoteVisit)
            visit.mentions = mentions
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
                
                return appData.followingSupabaseUserIds.contains(authorSupabaseId)
            }
        }
    }
    
    func refreshFeed(scope: FeedScope) async {
        guard let supabaseUserId = appData.supabaseUserId else { return }
        do {
            let remoteVisits: [RemoteVisit]
            switch scope {
            case .everyone:
                remoteVisits = try await visitService.fetchEveryoneFeed()
            case .friends:
                let following = try await socialGraphService.fetchFollowingIds(for: supabaseUserId)
                appData.followingSupabaseUserIds = Set(following)
                remoteVisits = try await visitService.fetchFriendsFeed(currentUserId: supabaseUserId, followingIds: following)
            }
            let mapped = remoteVisits.map { mapRemoteVisit($0) }
            mergeVisits(mapped)
        } catch {
            print("Failed to refresh feed: \(error.localizedDescription)")
        }
    }
    
    func refreshProfileVisits() async throws {
        guard let supabaseUserId = appData.supabaseUserId else {
            print("[DataManager] refreshProfileVisits: No supabaseUserId, skipping")
            return
        }
        print("[DataManager] refreshProfileVisits: Fetching visits for userId: \(supabaseUserId)")
        let remoteVisits = try await visitService.fetchVisitsForUserProfile(userId: supabaseUserId)
        print("[DataManager] refreshProfileVisits: Fetched \(remoteVisits.count) visits")
        let mapped = remoteVisits.map { mapRemoteVisit($0) }
        mergeVisits(mapped)
        print("[DataManager] refreshProfileVisits: Visits merged into appData")
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
        var uploads: [UploadedVisitPhoto] = []
        for (index, image) in images.enumerated() {
            let fileName = "\(UUID().uuidString).jpg"
            let path = "\(supabaseUserId)/visits/\(fileName)"
            let url = try await storageService.uploadImage(image, path: path)
            uploads.append(UploadedVisitPhoto(photoURL: url, sortOrder: index, image: image))
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
        if let index = appData.cafes.firstIndex(where: { ($0.supabaseId ?? $0.id) == remote.id }) {
            let merged = remote.toLocalCafe(existing: appData.cafes[index])
            appData.cafes[index] = merged
            return merged
        } else {
            let cafe = remote.toLocalCafe()
            appData.cafes.append(cafe)
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
    
    private func mapRemoteVisit(_ remote: RemoteVisit) -> Visit {
        let cafe: Cafe
        if let embeddedCafe = remote.cafe {
            cafe = upsertCafe(from: embeddedCafe)
        } else if let existing = appData.cafes.first(where: { ($0.supabaseId ?? $0.id) == remote.cafeId }) {
            cafe = existing
        } else {
            let placeholder = Cafe(
                id: remote.cafeId,
                supabaseId: remote.cafeId,
                name: "Cafe",
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
        case .like:
            message = "\(actorLabel) liked your visit"
        case .comment:
            message = "\(actorLabel) commented on your visit"
        case .mention:
            message = "\(actorLabel) mentioned you"
        case .follow:
            message = "\(actorLabel) followed you"
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

