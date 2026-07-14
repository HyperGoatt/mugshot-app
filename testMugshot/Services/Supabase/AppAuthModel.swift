//
//  AppAuthModel.swift
//  testMugshot
//

import Foundation
import UIKit

@MainActor
final class AppAuthModel: ObservableObject {
    enum Status: Equatable {
        case checking
        case configurationRequired(String)
        case signedOut(message: String? = nil)
        case working
        case signedIn
        case failed(String)
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var authenticatedUser: AuthenticatedUser?
    @Published private(set) var profile: SupabaseUserProfile?
    @Published private(set) var isUpdatingProfile = false
    @Published private(set) var profileUpdateError: String?
    @Published private(set) var pendingGuestSavedCafes: [Cafe] = []
    @Published private(set) var isMergingGuestSaved = false
    @Published private(set) var guestSavedMergeError: String?
    @Published private(set) var capturePreferences: CapturePreferences = .empty
    @Published private(set) var shouldOfferCapturePreferences = false
    @Published private(set) var isSavingCapturePreferences = false
    @Published private(set) var capturePreferencesError: String?

    private let authService: AuthService?
    private let profileService: ProfileService?
    private let accountDeletionService: AccountDeletionService?
    private let capturePreferencesService: CapturePreferencesService?

    init(provider: SupabaseClientProvider = .shared) {
        do {
            let client = try provider.client()
            self.authService = AuthService(client: client)
            self.profileService = ProfileService(client: client)
            self.accountDeletionService = AccountDeletionService(client: client)
            self.capturePreferencesService = CapturePreferencesService(client: client)
        } catch {
            self.authService = nil
            self.profileService = nil
            self.accountDeletionService = nil
            self.capturePreferencesService = nil
            self.status = .configurationRequired(error.localizedDescription)
        }
    }

    func restoreSession(dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        status = .checking

        do {
            guard let user = try await authService.restoreSession() else {
                authenticatedUser = nil
                profile = nil
                dataManager.prepareGuestSession()
                status = .signedOut()
                return
            }

            try await finishAuthentication(
                user: user,
                profileService: profileService,
                dataManager: dataManager
            )
        } catch {
            authenticatedUser = nil
            profile = nil
            status = .failed(safeMessage(for: error))
        }
    }

    func signIn(email: String, password: String, dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        status = .working

        do {
            let user = try await authService.signIn(email: email, password: password)
            try await finishAuthentication(
                user: user,
                profileService: profileService,
                dataManager: dataManager
            )
        } catch {
            authenticatedUser = nil
            profile = nil
            status = .failed(safeMessage(for: error))
        }
    }

    func signUp(email: String, password: String, dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        status = .working

        do {
            let result = try await authService.signUp(email: email, password: password)
            if let user = result.user, !result.requiresEmailConfirmation {
                try await finishAuthentication(
                    user: user,
                    profileService: profileService,
                    dataManager: dataManager
                )
            } else {
                authenticatedUser = nil
                profile = nil
                status = .signedOut(message: "Account created. Check your email to confirm, then sign in.")
            }
        } catch {
            authenticatedUser = nil
            profile = nil
            status = .failed(safeMessage(for: error))
        }
    }

    func signInWithApple(
        idToken: String,
        nonce: String,
        dataManager: DataManager
    ) async {
        guard let authService, let profileService else { return }
        status = .working

        do {
            let user = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            try await finishAuthentication(
                user: user,
                profileService: profileService,
                dataManager: dataManager
            )
        } catch {
            authenticatedUser = nil
            profile = nil
            status = .failed(safeMessage(for: error))
        }
    }

    func signOut(dataManager: DataManager) async {
        guard let authService else { return }
        status = .working

        do {
            try await authService.signOut()
            authenticatedUser = nil
            profile = nil
            pendingGuestSavedCafes = []
            capturePreferences = .empty
            shouldOfferCapturePreferences = false
            dataManager.prepareGuestSession()
            status = .signedOut()
        } catch {
            status = .failed(safeMessage(for: error))
        }
    }

    func updateProfile(
        displayName: String,
        username: String,
        bio: String,
        location: String,
        favoriteDrink: String,
        instagramHandle: String,
        websiteURL: String,
        dataManager: DataManager
    ) async -> Bool {
        guard let authenticatedUser, let profileService else { return false }
        isUpdatingProfile = true
        profileUpdateError = nil

        let update = SupabaseUserProfileUpdate(
            displayName: displayName.trimmed,
            username: username.normalizedUsername,
            bio: bio.nilIfBlank,
            location: location.nilIfBlank,
            favoriteDrink: favoriteDrink.nilIfBlank,
            instagramHandle: instagramHandle.nilIfBlank,
            websiteURL: websiteURL.nilIfBlank
        )

        do {
            let updatedProfile = try await profileService.updateProfile(
                userId: authenticatedUser.id,
                update: update
            )
            profile = updatedProfile
            dataManager.applyAuthenticatedProfile(updatedProfile)
            isUpdatingProfile = false
            return true
        } catch {
            profileUpdateError = safeMessage(for: error)
            isUpdatingProfile = false
            return false
        }
    }

    func clearError() {
        if case .failed = status {
            status = .signedOut()
        }
    }

    func clearProfileUpdateError() {
        profileUpdateError = nil
    }

    func postponeGuestSavedMerge() {
        pendingGuestSavedCafes = []
        guestSavedMergeError = nil
    }

    func mergeGuestSaved(dataManager: DataManager) async -> Bool {
        guard let userId = authenticatedUser?.id,
              !pendingGuestSavedCafes.isEmpty else { return true }

        isMergingGuestSaved = true
        guestSavedMergeError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            for cafe in pendingGuestSavedCafes {
                let summary = try await service.setCafeState(
                    userId: userId,
                    cafe: cafe,
                    isFavorite: cafe.isFavorite,
                    wantToTry: cafe.wantToTry
                )
                dataManager.applyRemoteCafeState(summary)
            }
            dataManager.clearMergedGuestSavedCafes()
            pendingGuestSavedCafes = []
            isMergingGuestSaved = false
            return true
        } catch {
            guestSavedMergeError = "Your guest saves are still safe on this device. Try merging again when you are online."
            isMergingGuestSaved = false
            return false
        }
    }

    func saveCapturePreferences(_ preferences: CapturePreferences) async -> Bool {
        guard let userId = authenticatedUser?.id,
              let capturePreferencesService else { return false }
        isSavingCapturePreferences = true
        capturePreferencesError = nil

        do {
            capturePreferences = try await capturePreferencesService.save(
                userId: userId,
                preferences: preferences
            )
            shouldOfferCapturePreferences = false
            isSavingCapturePreferences = false
            return true
        } catch {
            capturePreferencesError = "We couldn’t save those preferences yet. Your journal still works normally."
            isSavingCapturePreferences = false
            return false
        }
    }

    func skipCapturePreferences() async -> Bool {
        await saveCapturePreferences(.empty)
    }

    func updateAvatar(_ image: UIImage, dataManager: DataManager) async -> Bool {
        guard let authenticatedUser, let profileService else { return false }
        isUpdatingProfile = true
        profileUpdateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let mediaService = ProfileMediaService(client: client)
            let previousAvatarURL = profile?.avatarURL
            let avatarURL = try await mediaService.uploadAvatar(userId: authenticatedUser.id, image: image)
            let updatedProfile = try await profileService.updateAvatar(
                userId: authenticatedUser.id,
                avatarURL: avatarURL
            )
            profile = updatedProfile
            dataManager.applyAuthenticatedProfile(updatedProfile)
            isUpdatingProfile = false
            await mediaService.removeAvatar(at: previousAvatarURL)
            return true
        } catch {
            profileUpdateError = MugshotUserFacingError.message(for: error, context: .account)
            isUpdatingProfile = false
            return false
        }
    }

    func deleteAccount(dataManager: DataManager) async -> Bool {
        guard let accountDeletionService else { return false }
        status = .working

        do {
            try await accountDeletionService.deleteCurrentAccount()
            authenticatedUser = nil
            profile = nil
            dataManager.clearLocalReleaseState()
            status = .signedOut(message: "Your account and Mugshot data have been deleted.")
            return true
        } catch {
            status = .signedIn
            profileUpdateError = MugshotUserFacingError.message(for: error, context: .account)
            return false
        }
    }

    private func finishAuthentication(
        user: AuthenticatedUser,
        profileService: ProfileService,
        dataManager: DataManager
    ) async throws {
        let guestSavedCafes = dataManager.guestSavedCafes()
        let bootstrappedProfile = try await profileService.bootstrapProfile(
            for: user,
            localUser: dataManager.appData.currentUser
        )

        authenticatedUser = user
        profile = bootstrappedProfile
        dataManager.applyAuthenticatedProfile(bootstrappedProfile)
        pendingGuestSavedCafes = guestSavedCafes
        if let capturePreferencesService {
            let stored = try? await capturePreferencesService.fetch(userId: user.id)
            capturePreferences = stored ?? .empty
            shouldOfferCapturePreferences = stored?.setupCompletedAt == nil
        }
        status = .signedIn
    }

    private func safeMessage(for error: Error) -> String {
        MugshotUserFacingError.message(for: error, context: .account)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var normalizedUsername: String {
        trimmed
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
