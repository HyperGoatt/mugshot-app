import SwiftUI

struct AutomaticSipRecoveryBanner: View {
    let state: AutomaticSipRecoveryState
    let retry: () -> Void
    let review: () -> Void
    @State private var isDismissed = false

    var body: some View {
        Group {
            if state != .idle, !isDismissed {
                HStack(alignment: .top, spacing: 10) {
                    statusIcon
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)
                        Text(message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    if state.canRetry {
                        Button(state.retryTitle, action: retry)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.roastBrown)
                            .accessibilityHint(retryHint)
                    }

                    if state.canReview {
                        Button("Review", action: review)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.roastBrown)
                            .accessibilityHint("Shows the exact protected MugShot and what it needs")
                    }

                    if state.canDismiss {
                        Button {
                            isDismissed = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.espressoBrown.opacity(0.72))
                        .accessibilityLabel("Hide recovery message")
                        .accessibilityHint(
                            "Hides this message without deleting the published MugShot or its protected recovery copy"
                        )
                        .accessibilityIdentifier("automaticSipRecoveryBanner.dismiss")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.sandBeige)
                .overlay(alignment: .bottom) {
                    Divider().overlay(Color.mugshotLine)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("automaticSipRecoveryBanner")
            }
        }
        .onChange(of: state) { _, nextState in
            switch nextState {
            case .idle, .recovering:
                isDismissed = false
            case .pending, .waitingForNetwork, .failed, .localDataUnavailable:
                break
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .recovering:
            ProgressView()
                .controlSize(.small)
                .tint(.espressoBrown)
        case .waitingForNetwork:
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
        case .failed(_, let published, _):
            Image(systemName: published ? "checkmark.circle.fill" : "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
        case .localDataUnavailable:
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
        case .pending:
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.espressoBrown)
        case .idle:
            EmptyView()
        }
    }

    private var title: String {
        switch state {
        case .idle: ""
        case .pending: "Protected MugShot waiting"
        case .waitingForNetwork: "Waiting for a connection"
        case .recovering: "Finishing your MugShot"
        case .failed(_, let published, _):
            published ? "MugShot is already posted" : "MugShot still needs to finish"
        case .localDataUnavailable: "Protected MugShots need attention"
        }
    }

    private var message: String {
        switch state {
        case .idle:
            ""
        case .pending(let count):
            countMessage(count, suffix: "will retry while Mugshot is active.")
        case .waitingForNetwork(let count):
            countMessage(count, suffix: "will retry when you’re online.")
        case .recovering(let count):
            countMessage(count, suffix: "is using its original post ID and saved details.")
        case .failed(let count, _, let message):
            count == 1
                ? message
                : "\(count) protected MugShots need attention. \(message)"
        case .localDataUnavailable(let message):
            message
        }
    }

    private func countMessage(_ count: Int, suffix: String) -> String {
        let noun = count == 1 ? "MugShot" : "MugShots"
        let verb = count == 1 ? suffix : suffix.replacingOccurrences(of: "is ", with: "are ")
        return "\(count) protected \(noun) \(verb)"
    }

    private var retryHint: String {
        if case .localDataUnavailable = state {
            return "Checks the protected local queue again without changing stored data"
        }
        return "Retries the protected MugShot without creating another post"
    }
}

private extension AutomaticSipRecoveryState {
    var canRetry: Bool {
        switch self {
        case .failed, .localDataUnavailable:
            return true
        case .idle, .pending, .waitingForNetwork, .recovering:
            return false
        }
    }

    var canDismiss: Bool {
        switch self {
        case .failed, .localDataUnavailable:
            return true
        case .idle, .pending, .waitingForNetwork, .recovering:
            return false
        }
    }

    var canReview: Bool {
        switch self {
        case .failed, .localDataUnavailable: true
        case .idle, .pending, .waitingForNetwork, .recovering: false
        }
    }

    var retryTitle: String {
        if case .failed(_, let published, _) = self, published {
            return "Finish"
        }
        return "Retry"
    }
}

struct AutomaticSipRecoveryReviewView: View {
    let state: AutomaticSipRecoveryState
    let issues: [AutomaticSipRecoveryIssue]
    let onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Mugshot keeps each protected submission under its original account, visit ID, and media plan. Retry reconciles that exact visit before continuing.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }

                if issues.isEmpty {
                    Section("Protected queue") {
                        Label(
                            "Mugshot couldn’t read the local recovery summary. The stored queue was left unchanged.",
                            systemImage: "externaldrive.badge.exclamationmark"
                        )
                    }
                } else {
                    Section("MugShots needing attention") {
                        ForEach(issues) { issue in
                            VStack(alignment: .leading, spacing: 7) {
                                Label(issue.category.title, systemImage: icon(for: issue.category))
                                    .font(.headline)
                                    .foregroundStyle(Color.espressoBrown)
                                Text(issue.message)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                Text(issue.visitID.uuidString.lowercased())
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Color.tertiaryText)
                                    .textSelection(.enabled)
                                Text(issue.isPublished ? "Server publication confirmed" : "Publication not yet confirmed")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.mugshotSage)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    Button("Retry eligible work", action: onRetry)
                        .fontWeight(.semibold)
                } footer: {
                    Text("Missing media and invalid saves remain available for review instead of retrying forever.")
                }
            }
            .navigationTitle("Publication recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func icon(for category: SipRecoveryFailureCategory) -> String {
        switch category {
        case .authentication: "person.crop.circle.badge.exclamationmark"
        case .network: "wifi.exclamationmark"
        case .missingMedia: "photo.badge.exclamationmark"
        case .invalidPayload: "doc.badge.ellipsis"
        case .publicationSetup: "arrow.trianglehead.2.clockwise.rotate.90"
        case .localStorage: "externaldrive.badge.exclamationmark"
        }
    }
}

#if DEBUG
struct AutomaticSipRecoveryBannerPreviewHost: View {
    @State private var showsReview = false

    private let previewState = AutomaticSipRecoveryState.failed(
        count: 1,
        published: true,
        message: "This MugShot is already published. Mugshot couldn’t finish clearing its local recovery copy."
    )

    var body: some View {
        VStack(spacing: 0) {
            AutomaticSipRecoveryBanner(
                state: previewState,
                retry: {},
                review: { showsReview = true }
            )
            Spacer()
        }
        .background(Color.creamWhite)
        .sheet(isPresented: $showsReview) {
            AutomaticSipRecoveryReviewView(
                state: previewState,
                issues: [
                    AutomaticSipRecoveryIssue(
                        visitID: UUID(uuidString: "6b50780a-0fd1-4182-93ea-8a33befea2ff")!,
                        category: .localStorage,
                        isPublished: true,
                        message: "The server publication is complete, but local cleanup still needs to finish."
                    )
                ],
                onRetry: {}
            )
        }
    }
}
#endif
