//
//  AppAuthModel.swift
//  testMugshot
//

import Foundation
import AuthenticationServices
import Supabase
import UIKit

@MainActor
final class AppAuthModel: ObservableObject {
    enum Status: Equatable {
        case checking
        case configurationRequired(String)
        case signedOut(message: String? = nil)
        case working
        case signedIn
        case sessionUnavailable(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var authenticatedUser: AuthenticatedUser?
    @Published private(set) var profile: SupabaseUserProfile?
    @Published private(set) var isUpdatingProfile = false
    @Published private(set) var profileUpdateError: String?
    @Published private(set) var isCompletingProfileSetup = false
    @Published private(set) var profileSetupError: String?
    @Published private(set) var pendingGuestSavedCafes: [Cafe] = []
    @Published private(set) var isMergingGuestSaved = false
    @Published private(set) var guestSavedMergeError: String?
    @Published private(set) var capturePreferences: CapturePreferences = .empty
    @Published private(set) var shouldOfferCapturePreferences = false
    @Published private(set) var isSavingCapturePreferences = false
    @Published private(set) var capturePreferencesError: String?
    @Published private(set) var isPerformingAccountRecovery = false
    @Published private(set) var accountRecoveryMessage: String?
    @Published private(set) var accountRecoveryError: String?
    @Published private(set) var requiresNewPassword = false

    private let authService: AuthService?
    private let profileService: ProfileService?
    private let accountDeletionService: AccountDeletionService?
    private let capturePreferencesService: CapturePreferencesService?
    private let authenticationMutationGate = AuthenticationMutationGate()
    private var authenticationEpoch = AuthenticationOperationEpoch()
    private var profileMutationID: UUID?
    private var guestMergeMutationID: UUID?
    private var capturePreferencesMutationID: UUID?
    private var passwordMutationID: UUID?

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
        let operationID = beginAuthenticationOperation(status: .checking)

        do {
            try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)

                // A deletion response may be lost after Auth has already been
                // removed. Resume the capability-bound job before trusting a
                // persisted session, and purge local account data only after a
                // server receipt confirms the exact deleted subject.
                if let accountDeletionService,
                   accountDeletionService.hasPendingRecovery {
                    let resolution = try await accountDeletionService.resumePendingDeletion()
                    try requireCurrentAuthenticationOperation(operationID)
                    if case let .resolved(deletedUserID, outcome) = resolution {
                        switch outcome {
                        case .identityDeleted(let cleanup):
                            let attributableLegacyPhotoKeys = Set(
                                dataManager.appData.visits
                                    .filter { $0.userId == deletedUserID }
                                    .flatMap(\.photos)
                            ).union(
                                accountDeletionService.pendingLocalPurgePhotoKeys(
                                    subjectID: deletedUserID
                                )
                            )
                            let localCleanupCompleted = purgeLocalAccountData(
                                userID: deletedUserID,
                                attributableLegacyPhotoKeys: attributableLegacyPhotoKeys,
                                dataManager: dataManager
                            )
                            if localCleanupCompleted {
                                try? await accountDeletionService.acknowledgeLocalDeletion(
                                    subjectID: deletedUserID
                                )
                            }

                            // A different account on a shared device remains
                            // eligible for normal restoration below.
                            if authService.currentUserID == nil
                                || authService.currentUserID == deletedUserID {
                                clearAuthenticatedAccountState(dataManager: dataManager)
                                var message = deletionCompletionMessage(cleanup: cleanup)
                                if !localCleanupCompleted {
                                    message += " Some files on this device could not be removed. Mugshot will retry the private cleanup next time the app opens."
                                }
                                status = .signedOut(message: message)
                                return
                            }
                        case .supportRequired(let reason):
                            if authService.currentUserID == nil
                                || authService.currentUserID == deletedUserID {
                                clearAuthenticatedAccountState(dataManager: dataManager)
                                status = .signedOut(message: reason.userMessage)
                                return
                            }
                        }
                    }
                }

                guard let user = try await authService.restoreSession() else {
                    try requireCurrentAuthenticationOperation(operationID)
                    guard authService.currentUserID == nil else {
                        throw AppAuthenticationOperationError.sessionMismatch
                    }
                    clearAuthenticatedAccountState(dataManager: dataManager)
                    status = .signedOut()
                    return
                }

                try await finishAuthentication(
                    user: user,
                    profileService: profileService,
                    authService: authService,
                    dataManager: dataManager,
                    operationID: operationID
                )
                MugshotAnalytics.shared.capture(
                    .authenticationCompleted(
                        flow: .sessionRestore,
                        method: .persistedSession
                    )
                )
            }
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            MugshotAnalytics.shared.capture(
                .authenticationFailed(
                    flow: .sessionRestore,
                    method: .persistedSession,
                    errorCode: MugshotAnalyticsErrorCode(error: error)
                )
            )
            guard authenticationEpoch.isCurrent(operationID) else { return }
            if let preservedUser = TransientSessionAccountResolver.accountToPreserve(
                cachedUser: authService.cachedAuthenticatedUser,
                establishedUser: authenticatedUser
            ) {
                authenticatedUser = preservedUser
                if profile?.id != preservedUser.id { profile = nil }
                dataManager.preserveAuthenticatedAccountScope(
                    userID: preservedUser.id
                )
            }
            // A network or refresh failure does not prove that the person signed out.
            // Preserve the cached account scope and expose a retry state until
            // Supabase authoritatively reports a missing session or sign-out.
            status = .sessionUnavailable("Mugshot couldn’t verify your session. Check your connection and try again. Your local journal is still safe on this device.")
        }
    }

    func signIn(email: String, password: String, dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        let operationID = beginAuthenticationOperation(status: .working)

        do {
            try await performInteractiveAuthentication(
                operationID: operationID,
                authService: authService,
                profileService: profileService,
                dataManager: dataManager
            ) {
                try await authService.signIn(
                    email: email.normalizedEmail,
                    password: password
                )
            }
            MugshotAnalytics.shared.capture(
                .authenticationCompleted(flow: .signIn, method: .email)
            )
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            MugshotAnalytics.shared.capture(
                .authenticationFailed(
                    flow: .signIn,
                    method: .email,
                    errorCode: MugshotAnalyticsErrorCode(error: error)
                )
            )
            guard authenticationEpoch.isCurrent(operationID) else { return }
            clearAuthenticatedAccountState(dataManager: dataManager)
            status = .failed(safeMessage(for: error))
        }
    }

    func signUp(email: String, password: String, dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        let operationID = beginAuthenticationOperation(status: .working)

        do {
            try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)
                do {
                    let result = try await authService.signUp(
                        email: email.normalizedEmail,
                        password: password
                    )
                    try requireCurrentAuthenticationOperation(operationID)
                    if let user = result.user, !result.requiresEmailConfirmation {
                        try await finishAuthentication(
                            user: user,
                            profileService: profileService,
                            authService: authService,
                            dataManager: dataManager,
                            operationID: operationID
                        )
                    } else {
                        guard authService.currentUserID == nil else {
                            throw AppAuthenticationOperationError.sessionMismatch
                        }
                        clearAuthenticatedAccountState(dataManager: dataManager)
                        status = .signedOut(message: "Account created. Check your email to confirm, then sign in.")
                    }
                    MugshotAnalytics.shared.capture(
                        .authenticationCompleted(flow: .signUp, method: .email)
                    )
                } catch {
                    try await removeUnexpectedAuthenticationSession(
                        operationID: operationID,
                        authService: authService
                    )
                    throw error
                }
            }
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            MugshotAnalytics.shared.capture(
                .authenticationFailed(
                    flow: .signUp,
                    method: .email,
                    errorCode: MugshotAnalyticsErrorCode(error: error)
                )
            )
            guard authenticationEpoch.isCurrent(operationID) else { return }
            clearAuthenticatedAccountState(dataManager: dataManager)
            status = .failed(safeMessage(for: error))
        }
    }

    func signInWithApple(
        idToken: String,
        nonce: String,
        preferredDisplayName: String? = nil,
        dataManager: DataManager
    ) async {
        guard let authService, let profileService else { return }
        let operationID = beginAuthenticationOperation(status: .working)

        do {
            try await performInteractiveAuthentication(
                operationID: operationID,
                authService: authService,
                profileService: profileService,
                dataManager: dataManager
            ) {
                try await authService.signInWithApple(
                    idToken: idToken,
                    nonce: nonce,
                    preferredDisplayName: preferredDisplayName
                )
            }
            MugshotAnalytics.shared.capture(
                .authenticationCompleted(flow: .signIn, method: .apple)
            )
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            MugshotAnalytics.shared.capture(
                .authenticationFailed(
                    flow: .signIn,
                    method: .apple,
                    errorCode: MugshotAnalyticsErrorCode(error: error)
                )
            )
            guard authenticationEpoch.isCurrent(operationID) else { return }
            clearAuthenticatedAccountState(dataManager: dataManager)
            status = .failed(safeMessage(for: error))
        }
    }

    func signInWithGoogle(dataManager: DataManager) async {
        guard let authService, let profileService else { return }
        let operationID = beginAuthenticationOperation(status: .working)

        do {
            try await performInteractiveAuthentication(
                operationID: operationID,
                authService: authService,
                profileService: profileService,
                dataManager: dataManager
            ) {
                try await authService.signInWithGoogle()
            }
            MugshotAnalytics.shared.capture(
                .authenticationCompleted(flow: .signIn, method: .google)
            )
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            MugshotAnalytics.shared.capture(
                .authenticationFailed(
                    flow: .signIn,
                    method: .google,
                    errorCode: MugshotAnalyticsErrorCode(error: error)
                )
            )
            guard authenticationEpoch.isCurrent(operationID) else { return }
            clearAuthenticatedAccountState(dataManager: dataManager)
            status = isCanceledWebAuthentication(error)
                ? .signedOut()
                : .failed(safeMessage(for: error))
        }
    }

    func requestPasswordReset(email: String) async {
        guard let authService else { return }
        isPerformingAccountRecovery = true
        accountRecoveryError = nil
        accountRecoveryMessage = nil

        do {
            try await authService.requestPasswordReset(email: email.normalizedEmail)
            accountRecoveryMessage = "If that address belongs to a Mugshot account, a password reset link is on its way."
        } catch {
            accountRecoveryError = safeMessage(for: error)
        }
        isPerformingAccountRecovery = false
    }

    func resendSignupConfirmation(email: String) async {
        guard let authService else { return }
        isPerformingAccountRecovery = true
        accountRecoveryError = nil
        accountRecoveryMessage = nil

        do {
            try await authService.resendSignupConfirmation(email: email.normalizedEmail)
            accountRecoveryMessage = "If that address is waiting for confirmation, a fresh link is on its way."
        } catch {
            accountRecoveryError = safeMessage(for: error)
        }
        isPerformingAccountRecovery = false
    }

    @discardableResult
    func handleAuthCallback(
        _ url: URL,
        dataManager: DataManager
    ) async -> MugshotAuthCallbackHandlingResult {
        guard let route = MugshotAuthCallbackRoute.resolve(url),
              let authService,
              let profileService else { return .ignored }

        let establishedUser = authenticatedUser
        let establishedStatus = status
        let establishedRequiresNewPassword = requiresNewPassword
        let operationID = beginAuthenticationOperation(status: .working)
        accountRecoveryError = nil
        accountRecoveryMessage = nil
        var didExchangeSession = false

        do {
            try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)
                let user: AuthenticatedUser
                do {
                    user = try await authService.restoreSession(from: url)
                    didExchangeSession = true
                } catch {
                    try await removeUnexpectedAuthenticationSession(
                        operationID: operationID,
                        authService: authService
                    )
                    throw error
                }

                try requireCurrentAuthenticationOperation(operationID)
                guard authService.currentUserID == user.id else {
                    throw AppAuthenticationOperationError.sessionMismatch
                }

                if route == .passwordRecovery {
                    stageAuthenticatedSession(
                        user,
                        dataManager: dataManager,
                        status: .signedIn
                    )
                    requiresNewPassword = true
                    return
                }

                do {
                    try await finishAuthentication(
                        user: user,
                        profileService: profileService,
                        authService: authService,
                        dataManager: dataManager,
                        operationID: operationID
                    )
                    accountRecoveryMessage = "Email confirmed. Welcome to Mugshot."
                } catch AppAuthenticationOperationError.superseded {
                    throw AppAuthenticationOperationError.superseded
                } catch {
                    try requireCurrentAuthenticationOperation(operationID)
                    guard authService.currentUserID == user.id else {
                        throw AppAuthenticationOperationError.sessionMismatch
                    }
                    stageAuthenticatedSession(
                        user,
                        dataManager: dataManager,
                        status: .sessionUnavailable(
                            "Your email is confirmed and your sign-in is safe, but Mugshot couldn’t finish loading your journal. Try again when your connection is stable."
                        )
                    )
                    accountRecoveryMessage = "Email confirmed. Your journal still needs to finish loading."
                }
            }
        } catch AppAuthenticationOperationError.superseded {
            return didExchangeSession ? .consumed : .retry
        } catch {
            guard authenticationEpoch.isCurrent(operationID) else {
                return didExchangeSession ? .consumed : .retry
            }
            let message = "That sign-in link could not be completed. It may have expired; request a fresh link and try again."
            if let establishedUser,
               authService.currentUserID == establishedUser.id {
                authenticatedUser = establishedUser
                if profile?.id != establishedUser.id { profile = nil }
                dataManager.preserveAuthenticatedAccountScope(
                    userID: establishedUser.id
                )
                requiresNewPassword = establishedRequiresNewPassword
                accountRecoveryError = message
                switch establishedStatus {
                case .signedIn, .sessionUnavailable:
                    status = establishedStatus
                default:
                    status = .signedIn
                }
            } else if let currentUserID = authService.currentUserID {
                let cachedUser = authService.cachedAuthenticatedUser
                let quarantinedUser: AuthenticatedUser
                if let cachedUser, cachedUser.id == currentUserID {
                    quarantinedUser = cachedUser
                } else {
                    quarantinedUser = AuthenticatedUser(
                        id: currentUserID,
                        email: nil
                    )
                }
                stageAuthenticatedSession(
                    quarantinedUser,
                    dataManager: dataManager,
                    status: .sessionUnavailable(
                        "Mugshot couldn’t safely finish that sign-in attempt. The authenticated account remains isolated; retry session verification or sign out before continuing."
                    )
                )
                requiresNewPassword = false
                accountRecoveryError = message
            } else {
                clearAuthenticatedAccountState(dataManager: dataManager)
                requiresNewPassword = false
                accountRecoveryError = message
                status = .failed(message)
            }
        }
        return .consumed
    }

    func updateRecoveredPassword(
        _ password: String,
        dataManager: DataManager
    ) async -> Bool {
        guard let authService,
              let profileService,
              let expectedAccountID = authenticatedUser?.id else { return false }
        let operationID = beginAuthenticationOperation(status: .working)
        let mutationID = UUID()
        passwordMutationID = mutationID
        isPerformingAccountRecovery = true
        accountRecoveryError = nil
        var passwordWasUpdated = false

        do {
            try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)
                guard passwordMutationID == mutationID,
                      isCurrentAccount(expectedAccountID, authService: authService) else {
                    throw AppAuthenticationOperationError.sessionMismatch
                }

                try await authService.updatePassword(password)
                passwordWasUpdated = true
                try requireCurrentAuthenticationOperation(operationID)
                guard passwordMutationID == mutationID,
                      isCurrentAccount(expectedAccountID, authService: authService),
                      let user = authenticatedUser else {
                    throw AppAuthenticationOperationError.sessionMismatch
                }

                do {
                    try await finishAuthentication(
                        user: user,
                        profileService: profileService,
                        authService: authService,
                        dataManager: dataManager,
                        operationID: operationID
                    )
                    requiresNewPassword = false
                    accountRecoveryMessage = "Your password has been updated."
                } catch AppAuthenticationOperationError.superseded {
                    throw AppAuthenticationOperationError.superseded
                } catch {
                    try requireCurrentAuthenticationOperation(operationID)
                    guard authService.currentUserID == expectedAccountID else {
                        throw AppAuthenticationOperationError.sessionMismatch
                    }
                    stageAuthenticatedSession(
                        user,
                        dataManager: dataManager,
                        status: .sessionUnavailable(
                            "Your password was updated, but Mugshot couldn’t finish loading your journal. Your new password is safe; retry the journal load when your connection is stable."
                        )
                    )
                    requiresNewPassword = false
                    accountRecoveryMessage = "Your password was updated. Your journal still needs to finish loading."
                }
            }
            isPerformingAccountRecovery = false
            return true
        } catch AppAuthenticationOperationError.superseded {
            return false
        } catch {
            guard authenticationEpoch.isCurrent(operationID) else { return false }
            if authService.currentUserID == expectedAccountID,
               authenticatedUser?.id == expectedAccountID {
                requiresNewPassword = !passwordWasUpdated
                accountRecoveryError = passwordWasUpdated
                    ? "Your password was updated, but your session changed before Mugshot could finish. Sign in with your new password to continue."
                    : safeMessage(for: error)
                status = passwordWasUpdated ? .sessionUnavailable(
                    "Your password was updated, but Mugshot couldn’t finish restoring your account. Sign in with your new password to continue."
                ) : .signedIn
            } else {
                clearAuthenticatedAccountState(dataManager: dataManager)
                requiresNewPassword = false
                accountRecoveryError = passwordWasUpdated
                    ? "Your password was updated. Sign in again with your new password."
                    : safeMessage(for: error)
                status = .signedOut(message: accountRecoveryError)
            }
            isPerformingAccountRecovery = false
            return false
        }
    }

    func clearAccountRecoveryFeedback() {
        accountRecoveryMessage = nil
        accountRecoveryError = nil
    }

    func signOut(dataManager: DataManager) async {
        guard let authService else { return }
        let signingOutUserID = authenticatedUser?.id
        let wasRecoveringPassword = requiresNewPassword
        let operationID = beginAuthenticationOperation(status: .working)
        var usedLocalFallback = false

        do {
            try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)
                // The caller-bound unregister RPC requires the live session.
                // Keep it best effort so an offline cleanup issue never traps
                // someone in their account; token reassignment also removes
                // stale ownership on login.
                await NotificationDeviceCoordinator.shared.unregisterForSignOut()
                try requireCurrentAuthenticationOperation(operationID)
                do {
                    try await authService.signOut()
                } catch {
                    let discardedLocally = await authService.discardCurrentLocalSession()
                    guard discardedLocally else { throw error }
                    usedLocalFallback = true
                }
                try requireCurrentAuthenticationOperation(operationID)
                if authService.currentUserID != nil {
                    let discardedLocally = await authService.discardCurrentLocalSession()
                    guard discardedLocally else {
                        throw AppAuthenticationOperationError.sessionMismatch
                    }
                    usedLocalFallback = true
                }
            }
            try requireCurrentAuthenticationOperation(operationID)
            if let signingOutUserID {
                ActivityDeepLinkRouter.shared.clear(accountID: signingOutUserID)
            }
            clearAuthenticatedAccountState(dataManager: dataManager)
            requiresNewPassword = false
            clearAccountRecoveryFeedback()
            status = .signedOut(message: usedLocalFallback
                ? "Signed out on this device. Mugshot couldn’t confirm the server sign-out while offline."
                : nil)
            MugshotAnalytics.shared.capture(
                .accountSignedOut(usedLocalFallback: usedLocalFallback)
            )
        } catch AppAuthenticationOperationError.superseded {
            return
        } catch {
            guard authenticationEpoch.isCurrent(operationID) else { return }
            await NotificationDeviceCoordinator.shared.activate(accountID: signingOutUserID)
            let message = safeMessage(for: error)
            if wasRecoveringPassword {
                accountRecoveryError = "Mugshot couldn’t sign out on this device. Your recovery session is still protected; try again."
            }
            status = .failed(message)
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
        guard let authenticatedUser,
              let profileService,
              let authService else { return false }
        let expectedAccountID = authenticatedUser.id
        let mutationID = UUID()
        profileMutationID = mutationID
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
                userId: expectedAccountID,
                update: update
            )
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profile = updatedProfile
            dataManager.applyAuthenticatedProfile(updatedProfile)
            isUpdatingProfile = false
            return true
        } catch {
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profileUpdateError = safeMessage(for: error)
            isUpdatingProfile = false
            return false
        }
    }

    func clearError() {
        if case .failed = status {
            status = .signedOut()
        }
        clearAccountRecoveryFeedback()
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
              let authService,
              !pendingGuestSavedCafes.isEmpty else { return true }
        let mutationID = UUID()
        let cafesToMerge = pendingGuestSavedCafes
        guestMergeMutationID = mutationID

        isMergingGuestSaved = true
        guestSavedMergeError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            for cafe in cafesToMerge {
                guard guestMergeMutationID == mutationID,
                      isCurrentAccount(userId, authService: authService) else {
                    return false
                }
                let summary = try await service.setCafeState(
                    userId: userId,
                    cafe: cafe,
                    isFavorite: cafe.isFavorite,
                    wantToTry: cafe.wantToTry
                )
                guard guestMergeMutationID == mutationID,
                      isCurrentAccount(userId, authService: authService) else {
                    return false
                }
                dataManager.applyRemoteCafeState(summary)
            }
            guard guestMergeMutationID == mutationID,
                  isCurrentAccount(userId, authService: authService) else {
                return false
            }
            dataManager.clearMergedGuestSavedCafes()
            pendingGuestSavedCafes = []
            isMergingGuestSaved = false
            return true
        } catch {
            guard guestMergeMutationID == mutationID,
                  isCurrentAccount(userId, authService: authService) else {
                return false
            }
            guestSavedMergeError = "Your guest saves are still safe on this device. Try merging again when you are online."
            isMergingGuestSaved = false
            return false
        }
    }

    func saveCapturePreferences(_ preferences: CapturePreferences) async -> Bool {
        guard let userId = authenticatedUser?.id,
              let authService,
              let capturePreferencesService else { return false }
        let mutationID = UUID()
        capturePreferencesMutationID = mutationID
        isSavingCapturePreferences = true
        capturePreferencesError = nil

        do {
            let savedPreferences = try await capturePreferencesService.save(
                userId: userId,
                preferences: preferences
            )
            guard capturePreferencesMutationID == mutationID,
                  isCurrentAccount(userId, authService: authService) else {
                return false
            }
            capturePreferences = savedPreferences
            shouldOfferCapturePreferences = false
            isSavingCapturePreferences = false
            return true
        } catch {
            guard capturePreferencesMutationID == mutationID,
                  isCurrentAccount(userId, authService: authService) else {
                return false
            }
            capturePreferencesError = "We couldn’t save those preferences yet. Your journal still works normally."
            isSavingCapturePreferences = false
            return false
        }
    }

    func skipCapturePreferences() async -> Bool {
        await saveCapturePreferences(capturePreferences)
    }

    func deferCapturePreferencesForSession() {
        capturePreferencesError = nil
        shouldOfferCapturePreferences = false
    }

    func updateAvatar(_ image: UIImage, dataManager: DataManager) async -> Bool {
        guard let authenticatedUser,
              let profileService,
              let authService else { return false }
        let expectedAccountID = authenticatedUser.id
        let mutationID = UUID()
        profileMutationID = mutationID
        isUpdatingProfile = true
        profileUpdateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let mediaService = ProfileMediaService(client: client)
            let previousAvatarURL = profile?.avatarURL
            let avatarURL = try await mediaService.uploadAvatar(userId: expectedAccountID, image: image)
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            let updatedProfile = try await profileService.updateAvatar(
                userId: expectedAccountID,
                avatarURL: avatarURL
            )
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profile = updatedProfile
            dataManager.applyAuthenticatedProfile(updatedProfile)
            isUpdatingProfile = false
            await mediaService.removeAvatar(at: previousAvatarURL)
            return true
        } catch {
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profileUpdateError = MugshotUserFacingError.message(for: error, context: .account)
            isUpdatingProfile = false
            return false
        }
    }

    func updateBanner(_ image: UIImage, dataManager: DataManager) async -> Bool {
        guard let authenticatedUser,
              let profileService,
              let authService else { return false }
        let expectedAccountID = authenticatedUser.id
        let mutationID = UUID()
        profileMutationID = mutationID
        isUpdatingProfile = true
        profileUpdateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let mediaService = ProfileMediaService(client: client)
            let previousBannerURL = profile?.bannerURL
            let bannerURL = try await mediaService.uploadBanner(
                userId: expectedAccountID,
                image: image
            )
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            let updatedProfile = try await profileService.updateBanner(
                userId: expectedAccountID,
                bannerURL: bannerURL
            )
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profile = updatedProfile
            dataManager.applyAuthenticatedProfile(updatedProfile)
            isUpdatingProfile = false
            await mediaService.removeBanner(at: previousBannerURL)
            return true
        } catch {
            guard profileMutationID == mutationID,
                  isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profileUpdateError = MugshotUserFacingError.message(for: error, context: .account)
            isUpdatingProfile = false
            return false
        }
    }

    func completeProfileSetup(
        displayName: String,
        username: String,
        bio: String,
        location: String,
        instagramHandle: String,
        websiteURL: String,
        favoriteDrink: String,
        dataManager: DataManager
    ) async -> Bool {
        guard let authenticatedUser,
              let authService else { return false }
        let expectedAccountID = authenticatedUser.id
        isCompletingProfileSetup = true
        profileSetupError = nil
        defer {
            if self.authenticatedUser?.id == expectedAccountID {
                isCompletingProfileSetup = false
            }
        }

        do {
            let service = ProfileSetupService(
                client: try SupabaseClientProvider.shared.client()
            )
            let completedProfile = try await service.complete(
                displayName: displayName,
                username: username,
                bio: bio,
                location: location,
                instagramHandle: instagramHandle,
                websiteURL: websiteURL,
                favoriteDrink: favoriteDrink
            )
            guard isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profile = completedProfile
            dataManager.applyAuthenticatedProfile(completedProfile)
            return true
        } catch {
            guard isCurrentAccount(expectedAccountID, authService: authService) else {
                return false
            }
            profileSetupError = MugshotUserFacingError.message(for: error, context: .account)
            return false
        }
    }

    func clearProfileSetupError() {
        profileSetupError = nil
    }

    func deleteAccount(
        password: String,
        dataManager: DataManager
    ) async -> Bool {
        guard let authService,
              let email = authenticatedUser?.email?.normalizedEmail,
              !email.isEmpty else { return false }
        return await deleteAccount(dataManager: dataManager) {
            try await authService.createFreshAccountDeletionSession(
                email: email,
                password: password
            )
        }
    }

    func deleteAccountWithApple(
        idToken: String,
        nonce: String,
        dataManager: DataManager
    ) async -> Bool {
        guard let authService else { return false }
        return await deleteAccount(dataManager: dataManager) {
            try await authService.createFreshAccountDeletionSessionWithApple(
                idToken: idToken,
                nonce: nonce
            )
        }
    }

    func deleteAccountWithGoogle(dataManager: DataManager) async -> Bool {
        guard let authService else { return false }
        return await deleteAccount(dataManager: dataManager) {
            try await authService.createFreshAccountDeletionSessionWithGoogle()
        }
    }

    private func deleteAccount(
        dataManager: DataManager,
        authenticateFreshSession: () async throws -> AuthenticatedUser
    ) async -> Bool {
        guard let accountDeletionService,
              let authService,
              let userID = authenticatedUser?.id else { return false }
        let operationID = beginAuthenticationOperation(status: .working)
        profileUpdateError = nil
        let attributableLegacyPhotoKeys = Set(
            dataManager.appData.visits
                .filter { $0.userId == userID }
                .flatMap(\.photos)
        )

        do {
            let outcome = try await withSerializedAuthenticationMutation {
                try requireCurrentAuthenticationOperation(operationID)
                guard isCurrentAccount(userID, authService: authService) else {
                    throw AppAuthenticationOperationError.sessionMismatch
                }
                // A newer sign-in waits at the auth gate. If it was requested
                // while deletion was in flight, the server receipt below still
                // proves exactly which account must be purged locally.
                return try await accountDeletionService.deleteCurrentAccount(
                    expectedUserID: userID,
                    attributableLegacyPhotoKeys: attributableLegacyPhotoKeys,
                    authenticateFreshSession: authenticateFreshSession
                )
            }
            guard case let .identityDeleted(cleanup) = outcome else {
                if case let .supportRequired(reason) = outcome {
                    if authenticationEpoch.isCurrent(operationID),
                       authenticatedUser?.id == userID {
                        switch reason {
                        case .identityDeletionPending:
                            // The destructive request revoked this account's
                            // sessions before the identity delete attempt.
                            clearAuthenticatedAccountState(dataManager: dataManager)
                            status = .signedOut(message: reason.userMessage)
                        case .upgradeRequired, .capabilityUnavailable:
                            // No destructive request was accepted. Preserve
                            // both the active session and account-scoped data.
                            profileUpdateError = reason.userMessage
                            status = .signedIn
                        }
                    }
                }
                return false
            }

            let localCleanupCompleted = purgeLocalAccountData(
                userID: userID,
                attributableLegacyPhotoKeys: attributableLegacyPhotoKeys,
                dataManager: dataManager
            )
            if localCleanupCompleted {
                try? await accountDeletionService.acknowledgeLocalDeletion(subjectID: userID)
            }
            // The server receipt is explicitly bound to `userID`. If another
            // account became active while deletion was in flight, purge only
            // the deleted account's local stores and leave the new session/UI
            // untouched.
            guard authenticationEpoch.isCurrent(operationID),
                  authenticatedUser?.id == userID else { return true }
            clearAuthenticatedAccountState(dataManager: dataManager)
            requiresNewPassword = false
            clearAccountRecoveryFeedback()

            var message = deletionCompletionMessage(cleanup: cleanup)
            if !localCleanupCompleted {
                message += " Some files on this device could not be removed. Mugshot will retry the private cleanup next time the app opens."
            }
            status = .signedOut(message: message)
            return true
        } catch AppAuthenticationOperationError.superseded {
            return false
        } catch {
            if authenticationEpoch.isCurrent(operationID),
               authenticatedUser?.id == userID {
                guard authService.currentUserID == userID else {
                    // A credential for another account must never replace the
                    // presented account after a failed destructive check.
                    await authService.discardCurrentLocalSession()
                    clearAuthenticatedAccountState(dataManager: dataManager)
                    status = .signedOut(
                        message: "The fresh sign-in didn’t match the account being managed. Nothing was deleted. Sign in to the account you want to manage and try again."
                    )
                    return false
                }
                status = accountDeletionService.hasPendingRecovery
                    ? .sessionUnavailable("Mugshot is still confirming your deletion request. Your local journal remains safe on this device; try again when you’re online.")
                    : .signedIn
                profileUpdateError = safeMessage(for: error)
            }
            return false
        }
    }

    private func deletionCompletionMessage(
        cleanup: AccountDeletionCleanupState
    ) -> String {
        switch cleanup {
        case .completed:
            return "Your account and Mugshot data have been deleted."
        case .pending(let jobID):
            return "Your account identity and database data have been deleted. Encrypted media cleanup will continue automatically. Reference \(jobID.uuidString.lowercased()) if you contact support."
        }
    }

    /// Purges only the identity proven deleted by the server receipt. Every
    /// store is account-scoped so guest data and other signed-in accounts on a
    /// shared device remain intact. Failures do not stop the remaining purge.
    private func purgeLocalAccountData(
        userID: UUID,
        attributableLegacyPhotoKeys: Set<String>,
        dataManager: DataManager
    ) -> Bool {
        var completed = true
        do {
            try SipDraftStore.shared.purge(ownerUserID: userID)
        } catch {
            completed = false
        }
        do {
            try PendingVisitSubmissionStore.shared.purge(userId: userID)
        } catch {
            completed = false
        }
        do {
            try PhotoCache.shared.purge(
                ownerUserID: userID,
                attributableLegacyKeys: attributableLegacyPhotoKeys
            )
        } catch {
            completed = false
        }

        MapSearchService.removeRecents(ownerUserID: userID)
        CafeVisibilityPreferenceStore.shared.remove(ownerUserID: userID)
        CafeSessionContinuationStore.shared.remove(ownerUserID: userID)
        V3PublishedCompletionStore.shared.remove(ownerUserID: userID)
        PinnedCriterionStore.shared.removeAll(ownerUserID: userID)
        RecentCriterionSetupStore.shared.removeAll(ownerUserID: userID)
        HomeLibraryStore.shared.removeAll(ownerUserID: userID)
        TastingLensPreferencesStore().removeAll(userID: userID)
        VisitMediaCleanupStore.shared.removeAll(userId: userID)
        DrinkAnalysisRetryStore.shared.removeAll(userId: userID)
        do {
            try SafetyReportReceiptStore.shared.purge(accountID: userID)
        } catch {
            completed = false
        }
        do {
            try ModerationAppealReceiptStore.shared.purge(accountID: userID)
        } catch {
            completed = false
        }
        EnforcementNoticeStore().removeAll(accountID: userID)
        NotificationDeviceCoordinator.shared.deactivateAfterAccountDeletion(accountID: userID)
        ActivityDeepLinkRouter.shared.clear(accountID: userID)
        dataManager.clearLocalReleaseState(for: userID)
        return completed
    }

    private func finishAuthentication(
        user: AuthenticatedUser,
        profileService: ProfileService,
        authService: AuthService,
        dataManager: DataManager,
        operationID: UUID
    ) async throws {
        try requireCurrentAuthenticationOperation(operationID)
        guard authService.currentUserID == user.id else {
            throw AppAuthenticationOperationError.sessionMismatch
        }
        let guestSavedCafes = dataManager.guestSavedCafes()
        let provenLocalUser = dataManager.appData.currentUser?.id == user.id
            ? dataManager.appData.currentUser
            : nil
        let bootstrappedProfile = try await profileService.bootstrapProfile(
            for: user,
            localUser: provenLocalUser
        )
        try requireCurrentAuthenticationOperation(operationID)
        guard authService.currentUserID == user.id else {
            throw AppAuthenticationOperationError.sessionMismatch
        }

        var storedCapturePreferences: CapturePreferences?
        if let capturePreferencesService {
            storedCapturePreferences = try? await capturePreferencesService.fetch(userId: user.id)
        }
        try requireCurrentAuthenticationOperation(operationID)
        guard authService.currentUserID == user.id else {
            throw AppAuthenticationOperationError.sessionMismatch
        }

        resetScopedMutationState()
        authenticatedUser = user
        profile = bootstrappedProfile
        dataManager.applyAuthenticatedProfile(bootstrappedProfile)
        pendingGuestSavedCafes = guestSavedCafes
        capturePreferences = storedCapturePreferences ?? .empty
        shouldOfferCapturePreferences = storedCapturePreferences?.setupCompletedAt == nil
        status = .signedIn
    }

    private func performInteractiveAuthentication(
        operationID: UUID,
        authService: AuthService,
        profileService: ProfileService,
        dataManager: DataManager,
        authenticate: () async throws -> AuthenticatedUser
    ) async throws {
        try await withSerializedAuthenticationMutation {
            try requireCurrentAuthenticationOperation(operationID)
            do {
                let user = try await authenticate()
                try await finishAuthentication(
                    user: user,
                    profileService: profileService,
                    authService: authService,
                    dataManager: dataManager,
                    operationID: operationID
                )
            } catch {
                try await removeUnexpectedAuthenticationSession(
                    operationID: operationID,
                    authService: authService
                )
                throw error
            }
        }
    }

    /// Records a proven Auth identity before optional profile data is ready.
    /// This keeps one-time confirmation and recovery exchanges usable through
    /// transient profile failures without borrowing another account's local
    /// data or pretending that a remote profile was loaded.
    private func stageAuthenticatedSession(
        _ user: AuthenticatedUser,
        dataManager: DataManager,
        status newStatus: Status
    ) {
        let previousUserID = authenticatedUser?.id
        resetScopedMutationState()
        authenticatedUser = user
        if previousUserID != user.id {
            profile = nil
            pendingGuestSavedCafes = []
            capturePreferences = .empty
            shouldOfferCapturePreferences = false
        }
        dataManager.preserveAuthenticatedAccountScope(userID: user.id)
        status = newStatus
    }

    private func removeUnexpectedAuthenticationSession(
        operationID: UUID,
        authService: AuthService
    ) async throws {
        try requireCurrentAuthenticationOperation(operationID)
        guard authService.currentUserID != authenticatedUser?.id else { return }
        do {
            try await authService.signOut()
        } catch {
            _ = await authService.discardCurrentLocalSession()
        }
        try requireCurrentAuthenticationOperation(operationID)
        if authService.currentUserID != nil {
            _ = await authService.discardCurrentLocalSession()
        }
        try requireCurrentAuthenticationOperation(operationID)
        guard authService.currentUserID == nil else {
            throw AppAuthenticationOperationError.unexpectedSessionCleanupFailed
        }
    }

    private func beginAuthenticationOperation(status newStatus: Status) -> UUID {
        let operationID = authenticationEpoch.begin()
        resetScopedMutationState()
        status = newStatus
        return operationID
    }

    private func requireCurrentAuthenticationOperation(_ operationID: UUID) throws {
        guard authenticationEpoch.isCurrent(operationID) else {
            throw AppAuthenticationOperationError.superseded
        }
    }

    private func withSerializedAuthenticationMutation<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        await authenticationMutationGate.acquire()
        do {
            let value = try await operation()
            await authenticationMutationGate.release()
            return value
        } catch {
            await authenticationMutationGate.release()
            throw error
        }
    }

    private func isCurrentAccount(
        _ expectedAccountID: UUID,
        authService: AuthService
    ) -> Bool {
        MugshotAccountOperationScope.matches(
            expectedAccountID: expectedAccountID,
            presentedAccountID: authenticatedUser?.id,
            authenticatedSessionID: authService.currentUserID
        )
    }

    private func clearAuthenticatedAccountState(dataManager: DataManager) {
        authenticatedUser = nil
        profile = nil
        pendingGuestSavedCafes = []
        capturePreferences = .empty
        shouldOfferCapturePreferences = false
        resetScopedMutationState()
        dataManager.prepareGuestSession()
    }

    private func resetScopedMutationState() {
        profileMutationID = nil
        guestMergeMutationID = nil
        capturePreferencesMutationID = nil
        passwordMutationID = nil
        isUpdatingProfile = false
        profileUpdateError = nil
        isMergingGuestSaved = false
        guestSavedMergeError = nil
        isSavingCapturePreferences = false
        capturePreferencesError = nil
        isPerformingAccountRecovery = false
    }

    private func safeMessage(for error: Error) -> String {
        if isCanceledWebAuthentication(error) {
            return "Sign-in was canceled. Nothing changed."
        }

        if error as? MugshotAuthValidationError == .weakNewPassword {
            return "Use at least eight characters for your new password."
        }

        if let authError = error as? AuthError {
            switch authError.errorCode.rawValue {
            case "invalid_credentials":
                return "That email and password don’t match. Check them or reset your password."
            case "email_not_confirmed", "provider_email_needs_verification":
                return "Confirm your email before signing in. You can request a fresh confirmation link below."
            case "weak_password":
                return "Choose a stronger password and try again."
            case "email_exists", "user_already_exists":
                return "If you already use that email with Mugshot, sign in or reset your password."
            case "provider_disabled", "oauth_provider_not_supported":
                return "That sign-in method isn’t available yet. Use another sign-in option for now."
            case "signup_disabled", "email_provider_disabled":
                return "Email account creation isn’t available right now. Try another sign-in option."
            case "over_request_rate_limit", "over_email_send_rate_limit":
                return "Too many attempts were made. Wait a little, then try again."
            case "flow_state_not_found", "flow_state_expired", "bad_code_verifier", "otp_expired":
                return "That sign-in link expired or was already used. Request a fresh link and try again."
            case "session_not_found", "session_expired", "refresh_token_not_found", "refresh_token_already_used":
                return "Your session ended. Sign in again to continue."
            default:
                break
            }
        }
        return MugshotUserFacingError.message(for: error, context: .account)
    }

    private func isCanceledWebAuthentication(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASWebAuthenticationSessionErrorDomain
            && error.code == 1
    }
}

struct AuthenticationOperationEpoch {
    private var currentID = UUID()

    mutating func begin() -> UUID {
        let operationID = UUID()
        currentID = operationID
        return operationID
    }

    func isCurrent(_ operationID: UUID) -> Bool {
        currentID == operationID
    }
}

enum MugshotAccountOperationScope {
    static func matches(
        expectedAccountID: UUID,
        presentedAccountID: UUID?,
        authenticatedSessionID: UUID?
    ) -> Bool {
        presentedAccountID == expectedAccountID
            && authenticatedSessionID == expectedAccountID
    }
}

private enum AppAuthenticationOperationError: Error {
    case superseded
    case sessionMismatch
    case unexpectedSessionCleanupFailed
}

enum MugshotAuthCallbackHandlingResult: Equatable {
    case ignored
    case retry
    case consumed
}

private actor AuthenticationMutationGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
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

    var normalizedEmail: String {
        trimmed.lowercased()
    }
}
