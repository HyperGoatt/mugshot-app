//
//  AuthEntryView.swift
//  testMugshot
//

import AuthenticationServices
import SwiftUI

struct AuthEntryView: View {
    @ObservedObject var dataManager: DataManager
    var contextTitle: String? = nil
    var contextMessage: String? = nil
    var showsCloseButton = false
    var startsCreatingAccount = false
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCreatingAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var appleNonce: String?
    @State private var providerMessage: String?
    
    private var isBusy: Bool {
        if case .working = authModel.status {
            return true
        }
        return authModel.isPerformingAccountRecovery
    }
    
    private var message: String? {
        if let providerMessage {
            return providerMessage
        }
        if let error = authModel.accountRecoveryError {
            return error
        }
        if let message = authModel.accountRecoveryMessage {
            return message
        }
        switch authModel.status {
        case .signedOut(let message):
            return message
        case .failed(let message):
            return message
        case .sessionUnavailable(let message):
            return message
        default:
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if showsCloseButton {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                                    .frame(width: 44, height: 44)
                                    .background(Color.foamWhite)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.mugshotLine))
                            }
                            .accessibilityLabel("Keep exploring")
                        }
                        .padding(.horizontal, 24)
                    } else {
                        Spacer(minLength: 42)
                    }
                    
                    VStack(spacing: 10) {
                        MugsyAnimatedView(
                            configuration: MugsyPlacement.authentication.configuration,
                            action: .entering,
                            tapBehavior: MugsyPlacement.authentication.tapBehavior
                        )
                        .frame(width: 108, height: 108)
                        .accessibilityHidden(true)

                        Text("Mugshot")
                            .mugshotDisplay(size: 42)
                            .foregroundColor(.espressoBrown)
                        
                        Text(contextTitle ?? (isCreatingAccount ? "Start your sip journal." : "Savor more. Share better."))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    SignedOutJournalPreview(message: contextMessage)

                    VStack(spacing: 12) {
                        MugshotGoogleSignInButton(
                            title: "Continue with Google",
                            isDisabled: isBusy
                        ) {
                            providerMessage = nil
                            authModel.clearAccountRecoveryFeedback()
                            MugshotAnalytics.shared.capture(
                                .authenticationStarted(
                                    flow: isCreatingAccount ? .signUp : .signIn,
                                    method: .google
                                )
                            )
                            Task {
                                await authModel.signInWithGoogle(dataManager: dataManager)
                            }
                        }

                        SignInWithAppleButton(.continue) { request in
                            do {
                                let nonce = try AppleSignInNonce.random()
                                appleNonce = nonce
                                providerMessage = nil
                                request.requestedScopes = [.email, .fullName]
                                request.nonce = AppleSignInNonce.sha256(nonce)
                                MugshotAnalytics.shared.capture(
                                    .authenticationStarted(
                                        flow: isCreatingAccount ? .signUp : .signIn,
                                        method: .apple
                                    )
                                )
                            } catch {
                                appleNonce = nil
                                providerMessage = "Mugshot couldn’t prepare Apple sign-in. Please try again."
                            }
                        } onCompletion: { result in
                            handleAppleAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                        .disabled(isBusy)

                        HStack(spacing: 10) {
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                            Text("or use email")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.tertiaryText)
                            Rectangle().fill(Color.mugshotLine).frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        MugshotSectionTitle(
                            title: isCreatingAccount ? "Create your account" : "Welcome back",
                            subtitle: "Your photo-backed sips, saved cafes, notes, and ratings stay with you."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .authFieldStyle()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            
                            SecureField("Password", text: $password)
                                .textContentType(isCreatingAccount ? .newPassword : .password)
                                .authFieldStyle()

                            if isCreatingAccount {
                                Text("Use at least eight characters.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.tertiaryText)
                            }
                        }
                        
                        if let message {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundColor(messageColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Button(action: submit) {
                            HStack {
                                if isBusy {
                                    ProgressView()
                                        .tint(.foamWhite)
                                }
                                
                                Text(isCreatingAccount ? "Create account" : "Sign in")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSubmit || isBusy)
                        .opacity(!canSubmit || isBusy ? 0.6 : 1)

                        if !isCreatingAccount {
                            HStack(spacing: 18) {
                                Button("Forgot password?") {
                                    Task {
                                        await authModel.requestPasswordReset(email: email)
                                    }
                                }

                                Button("Resend confirmation") {
                                    Task {
                                        await authModel.resendSignupConfirmation(email: email)
                                    }
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.roastBrown)
                            .frame(maxWidth: .infinity)
                            .disabled(!canSendEmailAction || isBusy)
                            .opacity(!canSendEmailAction || isBusy ? 0.5 : 1)
                        }
                        
                        Button {
                            authModel.clearError()
                            providerMessage = nil
                            isCreatingAccount.toggle()
                        } label: {
                            Text(isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Create one")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.roastBrown)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isBusy)
                    }
                    .padding(22)
                    .cardStyle(radius: DesignSystem.Radius.heroCard)
                    .padding(.horizontal, 24)
                    
                    HStack(spacing: 6) {
                        MugshotTagChip(title: "Photo sips", icon: "camera.fill")
                        MugshotTagChip(title: "Private notes", icon: "lock.fill")
                        MugshotTagChip(title: "Cafe saves", icon: "bookmark.fill")
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear {
            if startsCreatingAccount {
                isCreatingAccount = true
            }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, userId in
            if userId != nil, showsCloseButton {
                dismiss()
            }
        }
    }
    
    private var canSubmit: Bool {
        let acceptsPassword = isCreatingAccount
            ? MugshotPasswordPolicy.acceptsNewPassword(password)
            : MugshotPasswordPolicy.acceptsExistingPassword(password)
        return email.contains("@") && acceptsPassword
    }

    private var canSendEmailAction: Bool {
        email.contains("@") && email.contains(".")
    }
    
    private var messageColor: Color {
        if providerMessage != nil {
            return .red.opacity(0.85)
        }
        if authModel.accountRecoveryError != nil {
            return .red.opacity(0.85)
        }
        if authModel.accountRecoveryMessage != nil {
            return .espressoBrown.opacity(0.7)
        }
        if case .signedOut = authModel.status {
            return .espressoBrown.opacity(0.7)
        }
        return .red.opacity(0.85)
    }
    
    private func submit() {
        providerMessage = nil
        authModel.clearAccountRecoveryFeedback()
        MugshotAnalytics.shared.capture(
            .authenticationStarted(
                flow: isCreatingAccount ? .signUp : .signIn,
                method: .email
            )
        )
        Task {
            if isCreatingAccount {
                await authModel.signUp(email: email, password: password, dataManager: dataManager)
                if case .signedOut(let message?) = authModel.status,
                   message.contains("Check your email") {
                    isCreatingAccount = false
                }
            } else {
                await authModel.signIn(email: email, password: password, dataManager: dataManager)
            }
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            appleNonce = nil
            if (error as? ASAuthorizationError)?.code != .canceled {
                providerMessage = "Apple sign-in couldn’t be completed. Please try again."
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                appleNonce = nil
                providerMessage = "Apple returned an invalid sign-in credential. Please try again."
                return
            }

            appleNonce = nil
            let preferredDisplayName = credential.fullName.flatMap { components in
                let value = PersonNameComponentsFormatter()
                    .string(from: components)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

            Task {
                await authModel.signInWithApple(
                    idToken: idToken,
                    nonce: nonce,
                    preferredDisplayName: preferredDisplayName,
                    dataManager: dataManager
                )
            }
        }
    }
}

struct MugshotGoogleSignInButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                HStack {
                    Text("G")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.roastBrown)
                        .frame(width: 28, height: 28)
                        .background(Color.sandBeige.opacity(0.55))
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.foamWhite)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignSystem.Radius.control,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignSystem.Radius.control,
                    style: .continuous
                )
                .stroke(Color.mugshotLine)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .accessibilityLabel(title)
    }
}

struct PasswordRecoveryView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject var dataManager: DataManager
    @State private var password = ""
    @State private var confirmation = ""

    private var validationMessage: String? {
        if !confirmation.isEmpty, password != confirmation {
            return "Passwords do not match."
        }
        return authModel.accountRecoveryError
    }

    private var canSubmit: Bool {
        MugshotPasswordPolicy.acceptsNewPassword(password)
            && password == confirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MugsyAnimatedView(
                        configuration: MugsyPlacement.recovery.configuration,
                        action: .recovering,
                        isPaused: true
                    )
                    .frame(width: 92, height: 92)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                    MugshotSectionTitle(
                        title: "Choose a new password",
                        subtitle: "Use at least eight characters. This change applies to your Mugshot email sign-in."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("New password")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        SecureField("New password", text: $password)
                            .textContentType(.newPassword)
                            .authFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm password")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        SecureField("Confirm password", text: $confirmation)
                            .textContentType(.newPassword)
                            .authFieldStyle()
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("passwordRecoveryError")
                    }

                    Button {
                        Task {
                            _ = await authModel.updateRecoveredPassword(
                                password,
                                dataManager: dataManager
                            )
                        }
                    } label: {
                        HStack {
                            if authModel.isPerformingAccountRecovery {
                                ProgressView().tint(.foamWhite)
                            }
                            Text("Update password")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit || authModel.isPerformingAccountRecovery)
                    .opacity(!canSubmit || authModel.isPerformingAccountRecovery ? 0.6 : 1)

                    Button("Cancel and sign out", role: .destructive) {
                        Task {
                            await authModel.signOut(dataManager: dataManager)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .disabled(authModel.isPerformingAccountRecovery)
                }
                .padding(24)
            }
            .background(Color.creamWhite.ignoresSafeArea())
            .navigationTitle("Password recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(authModel.requiresNewPassword)
    }
}

struct SupabaseConfigurationRequiredView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            VStack(spacing: 18) {
                MugsyAnimatedView(
                    configuration: MugsyPlacement.recovery.configuration,
                    action: .recovering,
                    isPaused: true
                )
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

                Text("Mugshot")
                    .mugshotDisplay(size: 40)
                    .foregroundColor(.espressoBrown)
                
                Text("Sign-in is unavailable")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Text(releaseMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Try again in a moment, or contact support@mugshot.app.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }

    private var releaseMessage: String {
        #if DEBUG
        return message
        #else
        return "Mugshot is temporarily unavailable."
        #endif
    }
}

struct AuthLoadingView: View {
    @State private var showsMugsy = false

    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            
            VStack(spacing: 16) {
                MugsyAnimatedView(
                    configuration: MugsyModelConfiguration(expression: .delighted),
                    action: .resting,
                    isPaused: true
                )
                .frame(width: 92, height: 92)
                .opacity(showsMugsy ? 1 : 0)
                .accessibilityHidden(true)

                ProgressView()
                    .tint(.mugshotSage)
                
                Text("Opening your journal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                showsMugsy = true
            }
        }
    }
}

private struct SignedOutJournalPreview: View {
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Your first sip, saved with care", systemImage: "book.closed.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)

            HStack(spacing: 10) {
                previewStep(icon: "camera.fill", title: "Photograph", detail: "Add a cover")
                previewStep(icon: "star.fill", title: "Rate", detail: "Remember the taste")
                previewStep(icon: "lock.fill", title: "Keep", detail: "Private notes stay yours")
            }

            Text(message ?? "Create an account to keep your photo-backed sips, saved cafes, and personal tasting notes together.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.sandBeige.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func previewStep(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func authFieldStyle() -> some View {
        mugshotFormField()
    }
}
