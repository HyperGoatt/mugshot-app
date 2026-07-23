import SwiftUI

struct EnforcementStatusBanner: View {
    let action: ModerationEnforcementAction
    let additionalActiveCount: Int
    let review: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: action.actionKind.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.actionKind.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Text(bannerMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button("Review", action: review)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.roastBrown)
                .accessibilityHint("Opens safety status and appeal options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.sandBeige)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.mugshotLine)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("enforcementStatusBanner")
    }

    private var bannerMessage: String {
        let suffix = additionalActiveCount > 0
            ? " There \(additionalActiveCount == 1 ? "is" : "are") \(additionalActiveCount) more active \(additionalActiveCount == 1 ? "decision" : "decisions")."
            : ""
        return switch action.actionKind {
        case .warning:
            "Review this safety notice. No feature is limited by the warning itself.\(suffix)"
        case .contentHidden:
            "One of your shared items is hidden. Your private journal is unchanged.\(suffix)"
        case .socialRestricted, .accountSuspended:
            "Your private journal, export, account controls, and appeal access remain available.\(suffix)"
        }
    }
}

struct EnforcementCenterView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var actions: [ModerationEnforcementAction] = []
    @State private var reportReceipts: [SafeReportReceipt] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var enforcementLoadError: String?
    @State private var reportsLoadError: String?
    @State private var statusMessage: String?
    @State private var appealRequest: ModerationEnforcementAction?
    @State private var appealText = ""
    @State private var submittingActionID: UUID?
    @State private var loadedAccountID: UUID?
    @State private var appealMutationID: UUID?

    var body: some View {
        Form {
            Section {
                Label {
                    Text("Safety decisions never remove your private journal. You can still export your data, manage your account, and appeal an enforcement decision.")
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.mugshotSageText)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("Your account")
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.mugshotSageText)
                        .accessibilityElement(children: .combine)
                }
            }

            if let errorMessage, !actions.isEmpty || !reportReceipts.isEmpty {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .accessibilityElement(children: .combine)
                }
            }

            enforcementSection
            reportsSection
        }
        .tint(.mugshotSage)
        .scrollContentBackground(.hidden)
        .background(Color.creamWhite)
        .navigationTitle("Safety and Account Status")
        .onChange(of: authModel.authenticatedUser?.id) { _, accountID in
            resetAccountBoundState(for: accountID)
        }
        .task(id: authModel.authenticatedUser?.id) { await load() }
        .refreshable { await load() }
        .sheet(item: $appealRequest) { action in
            ModerationAppealSheet(
                action: action,
                statement: $appealText,
                isSubmitting: submittingActionID == action.id,
                onCancel: { appealRequest = nil },
                onSubmit: { Task { await submitAppeal(for: action) } }
            )
        }
    }

    @ViewBuilder
    private var enforcementSection: some View {
        Section {
            if authModel.authenticatedUser == nil {
                ContentUnavailableView(
                    "Sign in required",
                    systemImage: "person.badge.key.fill",
                    description: Text("Sign in to view your account status and appeals.")
                )
            } else if isLoading && actions.isEmpty {
                loadingRow("Checking account status…")
            } else if let enforcementLoadError, actions.isEmpty {
                retryState(
                    title: "Couldn’t check account status",
                    message: enforcementLoadError
                )
            } else if actions.isEmpty {
                ContentUnavailableView(
                    "No enforcement decisions",
                    systemImage: "checkmark.shield.fill",
                    description: Text("There are no current or recent safety decisions on your account or content.")
                )
            } else {
                if let enforcementLoadError {
                    staleRefreshState(
                        title: "Couldn’t refresh account status",
                        message: enforcementLoadError
                    )
                }
                ForEach(actions) { action in
                    enforcementRow(action)
                }
            }
        } header: {
            Text("Enforcement decisions")
        } footer: {
            Text("Appeals are reviewed by Mugshot. Status and any user-facing resolution appear here; reporter identity, evidence, and internal review notes stay private. There is no guaranteed response time during alpha.")
        }
    }

    @ViewBuilder
    private var reportsSection: some View {
        Section {
            if authModel.authenticatedUser == nil {
                EmptyView()
            } else if isLoading && reportReceipts.isEmpty {
                loadingRow("Loading your reports…")
            } else if let reportsLoadError, reportReceipts.isEmpty {
                retryState(
                    title: "Couldn’t load report history",
                    message: reportsLoadError
                )
            } else if reportReceipts.isEmpty {
                Text("Reports you submit will appear here with their review status.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .padding(.vertical, 4)
            } else {
                if let reportsLoadError {
                    staleRefreshState(
                        title: "Couldn’t refresh report history",
                        message: reportsLoadError
                    )
                }
                ForEach(reportReceipts) { receipt in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(reportTargetTitle(receipt.targetKind))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.espressoBrown)
                            Spacer(minLength: 8)
                            Text(reportStatusTitle(receipt.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.mugshotSageText)
                        }
                        Text(receipt.reason.title)
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                        if let date = ModerationDateParser.date(from: receipt.createdAt) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(Color.tertiaryText)
                        }
                        if let resolution = receipt.resolutionCode,
                           !resolution.isEmpty {
                            Text("Resolution: \(friendlyCode(resolution))")
                                .font(.footnote)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Reports you submitted")
        } footer: {
            Text("Mugshot shows the status of your report without revealing private moderation details or action taken on another person’s account.")
        }
    }

    private func enforcementRow(_ action: ModerationEnforcementAction) -> some View {
        let pending = pendingAppeal(for: action)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: action.actionKind.systemImage)
                    .foregroundStyle(action.isActive ? Color.red : Color.tertiaryText)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.actionKind.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(action.isActive ? "Active" : "No longer active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(action.isActive ? Color.red : Color.secondaryText)
                }
                Spacer(minLength: 8)
                Text(action.subjectTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }

            Text("Reason: \(action.reasonTitle)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.espressoBrown)
            Text(action.actionKind.impact)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)

            if let endsAt = ModerationDateParser.date(from: action.endsAt) {
                Text("Scheduled to end \(endsAt.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }

            if let status = action.appealStatus {
                Divider()
                Label("Appeal: \(status.title)", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.mugshotSageText)
                if let summary = action.appealResolutionSummary,
                   !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
            } else if let pending {
                Divider()
                Label(
                    "Appeal delivery is unconfirmed",
                    systemImage: "wifi.exclamationmark"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.orange)
                Text("Retry sends the exact saved appeal with the same receipt, so it cannot create a duplicate.")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                Button(submittingActionID == action.id ? "Retrying…" : "Retry Appeal") {
                    Task { await retryAppeal(pending, for: action) }
                }
                .disabled(submittingActionID != nil)
            } else if action.canAppeal {
                Divider()
                Button("Appeal Decision") {
                    appealText = ""
                    appealRequest = action
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func loadingRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private func retryState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
            Button("Try again") { Task { await load() } }
        }
        .padding(.vertical, 8)
    }

    private func staleRefreshState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "wifi.exclamationmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.orange)
            Text("Showing the last information loaded for this account. \(message)")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            Button("Try again") { Task { await load() } }
                .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func resetAccountBoundState(for accountID: UUID?) {
        actions = []
        reportReceipts = []
        isLoading = false
        errorMessage = nil
        enforcementLoadError = nil
        reportsLoadError = nil
        statusMessage = nil
        appealRequest = nil
        appealText = ""
        submittingActionID = nil
        appealMutationID = nil
        loadedAccountID = nil
    }

    @MainActor
    private func load() async {
        guard let expectedAccountID = authModel.authenticatedUser?.id else {
            actions = []
            reportReceipts = []
            errorMessage = nil
            enforcementLoadError = nil
            reportsLoadError = nil
            loadedAccountID = nil
            isLoading = false
            return
        }
        if loadedAccountID != expectedAccountID {
            actions = []
            reportReceipts = []
            errorMessage = nil
            enforcementLoadError = nil
            reportsLoadError = nil
        }
        errorMessage = nil
        isLoading = true
        defer {
            if authModel.authenticatedUser?.id == expectedAccountID {
                isLoading = false
            }
        }
        let service: SocialSafetyService
        do {
            service = SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            )
        } catch {
            let message = MugshotUserFacingError.message(for: error, context: .loading)
            enforcementLoadError = message
            reportsLoadError = message
            return
        }

        do {
            let loadedActions = try await service.enforcementState(
                accountID: expectedAccountID
            )
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == expectedAccountID else { return }
            actions = loadedActions
            enforcementLoadError = nil
            loadedAccountID = expectedAccountID
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            enforcementLoadError = MugshotUserFacingError.message(for: error, context: .loading)
        }

        do {
            let loadedReports = try await service.reportReceipts(
                accountID: expectedAccountID
            )
            guard !Task.isCancelled,
                  authModel.authenticatedUser?.id == expectedAccountID else { return }
            reportReceipts = loadedReports
            reportsLoadError = nil
            loadedAccountID = expectedAccountID
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == expectedAccountID else { return }
            reportsLoadError = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func submitAppeal(for action: ModerationEnforcementAction) async {
        await deliverAppeal(for: action, statement: appealText)
    }

    @MainActor
    private func retryAppeal(
        _ pending: PendingModerationAppeal,
        for action: ModerationEnforcementAction
    ) async {
        await deliverAppeal(for: action, statement: pending.statement)
    }

    @MainActor
    private func deliverAppeal(
        for action: ModerationEnforcementAction,
        statement: String
    ) async {
        guard let accountID = authModel.authenticatedUser?.id,
              submittingActionID == nil,
              actions.contains(where: { $0.id == action.id }) else { return }
        let normalized = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 10 else { return }

        let mutationID = UUID()
        appealMutationID = mutationID
        submittingActionID = action.id
        errorMessage = nil
        let outcome: ModerationAppealSubmissionOutcome
        do {
            outcome = try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).submitAppeal(
                accountID: accountID,
                actionID: action.id,
                statement: normalized
            )
        } catch {
            guard appealMutationID == mutationID,
                  authModel.authenticatedUser?.id == accountID,
                  actions.contains(where: { $0.id == action.id }) else { return }
            appealMutationID = nil
            submittingActionID = nil
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
            return
        }

        guard appealMutationID == mutationID,
              authModel.authenticatedUser?.id == accountID,
              actions.contains(where: { $0.id == action.id }) else { return }
        appealMutationID = nil
        submittingActionID = nil
        appealRequest = nil
        switch outcome {
        case .submitted:
            statusMessage = "Appeal submitted. You can follow its status here."
            await load()
        case .deliveryUnconfirmed:
            errorMessage = "Appeal delivery couldn’t be confirmed. It is saved on this device for a safe retry."
        }
    }

    private func pendingAppeal(
        for action: ModerationEnforcementAction
    ) -> PendingModerationAppeal? {
        guard let accountID = authModel.authenticatedUser?.id else { return nil }
        return ModerationAppealReceiptStore.shared.pending(
            accountID: accountID,
            actionID: action.id
        )
    }

    private func reportTargetTitle(_ targetKind: String) -> String {
        switch targetKind {
        case "visit": "MugShot report"
        case "comment": "Comment report"
        default: "Account report"
        }
    }

    private func reportStatusTitle(_ status: String) -> String {
        switch status {
        case "pending": "Submitted"
        case "reviewing": "Under review"
        case "resolved": "Resolved"
        case "dismissed": "Closed"
        default: friendlyCode(status)
        }
    }

    private func friendlyCode(_ code: String) -> String {
        code
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private struct ModerationAppealSheet: View {
    let action: ModerationEnforcementAction
    @Binding var statement: String
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Decision") {
                    LabeledContent("Action", value: action.actionKind.title)
                    LabeledContent("Reason", value: action.reasonTitle)
                    LabeledContent("Applies to", value: action.subjectTitle)
                }

                Section {
                    TextEditor(text: $statement)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Appeal statement")
                    Text("\(statement.count) of 2,000 characters")
                        .font(.caption)
                        .foregroundStyle(
                            statement.count > 2000 ? Color.red : Color.tertiaryText
                        )
                } header: {
                    Text("What should the reviewer know?")
                } footer: {
                    Text("Include context that may change the decision. Do not include passwords, payment details, or other sensitive information.")
                }

                Section {
                    Text("Submitting does not pause an active decision. You can return to Safety and Account Status to see the outcome.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Appeal Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Submitting…" : "Submit", action: onSubmit)
                        .disabled(
                            isSubmitting
                                || statement.trimmingCharacters(in: .whitespacesAndNewlines).count < 10
                                || statement.count > 2000
                        )
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }
}
