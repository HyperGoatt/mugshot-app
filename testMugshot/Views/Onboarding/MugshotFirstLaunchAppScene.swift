import SwiftUI

/// Presents the approved onboarding artwork at its authored aspect ratio while
/// keeping navigation and authentication actions native, accessible, and testable.
struct MugshotFirstLaunchArtworkView: View {
    let step: MugshotFirstLaunchStep
    let onContinue: () -> Void
    let onSkipToAccountSetup: () -> Void
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void

    private let artworkAspectRatio: CGFloat = 853.0 / 1844.0

    var body: some View {
        GeometryReader { proxy in
            let artworkFrame = fittedArtworkFrame(in: proxy.size)

            ZStack {
                Color.creamWhite
                    .ignoresSafeArea()

                Image(step.artworkName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: artworkFrame.width, height: artworkFrame.height)
                    .position(x: artworkFrame.midX, y: artworkFrame.midY)
                    .accessibilityLabel(
                        "Step \(step.number) of \(MugshotFirstLaunchStep.allCases.count). " +
                        step.title + " " + step.message
                    )

                if step.isAuthenticationStep {
                    accountActions(in: artworkFrame)
                } else {
                    educationActions(in: artworkFrame)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func fittedArtworkFrame(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let containerRatio = size.width / size.height

        if containerRatio > artworkAspectRatio {
            let height = size.height
            let width = height * artworkAspectRatio
            return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: height)
        }

        let width = size.width
        let height = width / artworkAspectRatio
        return CGRect(x: 0, y: (size.height - height) / 2, width: width, height: height)
    }

    @ViewBuilder
    private func educationActions(in frame: CGRect) -> some View {
        normalizedButton(
            label: "Skip",
            identifier: "mugshot.firstLaunch.skip",
            frame: frame,
            region: .init(x: 0.78, y: 0.005, width: 0.21, height: 0.075),
            action: onSkipToAccountSetup
        )

        normalizedButton(
            label: "Continue",
            identifier: "mugshot.firstLaunch.continue",
            frame: frame,
            region: step.continueTapRegion,
            action: onContinue
        )

        normalizedButton(
            label: "Skip to account setup",
            identifier: "mugshot.firstLaunch.accountSetup",
            frame: frame,
            region: step.accountSetupTapRegion,
            action: onSkipToAccountSetup
        )
    }

    @ViewBuilder
    private func accountActions(in frame: CGRect) -> some View {
        normalizedButton(
            label: "Create account",
            identifier: "mugshot.firstLaunch.createAccount",
            frame: frame,
            region: .init(x: 0.08, y: 0.81, width: 0.84, height: 0.075),
            action: onCreateAccount
        )

        normalizedButton(
            label: "Sign in",
            identifier: "mugshot.firstLaunch.signIn",
            frame: frame,
            region: .init(x: 0.08, y: 0.875, width: 0.84, height: 0.075),
            action: onSignIn
        )
    }

    private func normalizedButton(
        label: String,
        identifier: String,
        frame: CGRect,
        region: CGRect,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(
            width: frame.width * region.width,
            height: frame.height * region.height
        )
        .position(
            x: frame.minX + frame.width * (region.minX + region.width / 2),
            y: frame.minY + frame.height * (region.minY + region.height / 2)
        )
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private extension MugshotFirstLaunchStep {
    var continueTapRegion: CGRect {
        switch self {
        case .welcome:
            .init(x: 0.07, y: 0.835, width: 0.86, height: 0.09)
        case .map, .feed, .googleMaps:
            .init(x: 0.07, y: 0.855, width: 0.86, height: 0.09)
        case .friends, .saved, .journal, .tastePassport:
            .init(x: 0.07, y: 0.875, width: 0.86, height: 0.08)
        case .add:
            .zero
        }
    }

    var accountSetupTapRegion: CGRect {
        switch self {
        case .welcome:
            .init(x: 0.18, y: 0.92, width: 0.64, height: 0.07)
        case .map, .feed, .googleMaps:
            .init(x: 0.18, y: 0.93, width: 0.64, height: 0.065)
        case .friends, .saved, .journal, .tastePassport:
            .init(x: 0.18, y: 0.945, width: 0.64, height: 0.055)
        case .add:
            .zero
        }
    }
}

#if DEBUG
#Preview("First-launch marketing onboarding") {
    MugshotFirstLaunchArtworkView(
        step: .welcome,
        onContinue: {},
        onSkipToAccountSetup: {},
        onCreateAccount: {},
        onSignIn: {}
    )
}
#endif
