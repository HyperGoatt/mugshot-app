import SwiftUI

struct AutomaticSipRecoveryBanner: View {
    let state: AutomaticSipRecoveryState
    let retry: () -> Void

    var body: some View {
        if state != .idle {
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
                    Button("Retry", action: retry)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.roastBrown)
                        .accessibilityHint(retryHint)
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
        case .failed, .localDataUnavailable:
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
        case .failed: "MugShot still needs to finish"
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
        case .failed(let count, let message):
            "\(countMessage(count, suffix: "is safely preserved.")) \(message)"
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
}
