//
//  AppAuthModel.swift
//  testMugshot
//

import Foundation

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

    private let authService: AuthService?
    private let profileService: ProfileService?

    init(provider: SupabaseClientProvider = .shared) {
        do {
            let client = try provider.client()
            self.authService = AuthService(client: client)
            self.profileService = ProfileService(client: client)
        } catch {
            self.authService = nil
            self.profileService = nil
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

    func signOut() async {
        guard let authService else { return }
        status = .working

        do {
            try await authService.signOut()
            authenticatedUser = nil
            profile = nil
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

    private func finishAuthentication(
        user: AuthenticatedUser,
        profileService: ProfileService,
        dataManager: DataManager
    ) async throws {
        let bootstrappedProfile = try await profileService.bootstrapProfile(
            for: user,
            localUser: dataManager.appData.currentUser
        )

        authenticatedUser = user
        profile = bootstrappedProfile
        dataManager.applyAuthenticatedProfile(bootstrappedProfile)
        SampleDataSeeder.seedSampleData(dataManager: dataManager)
        status = .signedIn
    }

    private func safeMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Something went wrong. Please try again."
        }
        return message
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
