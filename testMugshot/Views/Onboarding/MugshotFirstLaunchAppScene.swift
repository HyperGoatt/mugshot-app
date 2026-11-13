import SwiftUI

/// Presents the approved onboarding artwork at its authored aspect ratio while
/// keeping navigation and authentication actions native, accessible, and testable.
struct MugshotFirstLaunchArtworkView: View {
    let step: MugshotFirstLaunchStep
    let onContinue: () -> Void
    let onSkipToAccountSetup: () -> Void
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    let onExploreWithoutAccount: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private let artworkAspectRatio: CGFloat = 853.0 / 1844.0

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize || voiceOverEnabled {
            accessibleContent
        } else {
            artworkContent
        }
    }

    private var artworkContent: some View {
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

                Text("\(step.number) of \(MugshotFirstLaunchStep.allCases.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(width: artworkFrame.width * 0.22, height: artworkFrame.height * 0.047)
                    .background(Color.creamWhite, in: Capsule())
                    .position(x: artworkFrame.minX + artworkFrame.width * 0.14,
                              y: artworkFrame.minY + artworkFrame.height * 0.039)
                    .accessibilityHidden(true)

                if step.isAuthenticationStep {
                    accountActions(in: artworkFrame)
                } else {
                    educationActions(in: artworkFrame)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var accessibleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Step \(step.number) of \(MugshotFirstLaunchStep.allCases.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("mugshot.firstLaunch.progress")

                MugsyAnimatedView(
                    configuration: MugsyPlacement.onboarding.configuration,
                    action: .entering,
                    tapBehavior: MugsyPlacement.onboarding.tapBehavior
                )
                .frame(width: 112, height: 112)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

                Text(step.title)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("mugshot.firstLaunch.title")
                Text(step.message)
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if step.isAuthenticationStep {
                    Button("Create account", action: onCreateAccount)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("mugshot.firstLaunch.createAccount")
                    Button("Sign in", action: onSignIn)
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("mugshot.firstLaunch.signIn")
                    Button("Explore Map without an account", action: onExploreWithoutAccount)
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("mugshot.firstLaunch.exploreWithoutAccount")
                } else {
                    Button("Continue", action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("mugshot.firstLaunch.continue")
                    Button("Skip to account setup", action: onSkipToAccountSetup)
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("mugshot.firstLaunch.skip")
                }
            }
            .padding(24)
        }
        .background(Color.creamWhite.ignoresSafeArea())
        .accessibilityIdentifier("mugshot.firstLaunch.accessibleScroll")
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
            region: .init(x: 0.08, y: 0.81, width: 0.84, height: 0.06),
            action: onCreateAccount
        )

        normalizedButton(
            label: "Sign in",
            identifier: "mugshot.firstLaunch.signIn",
            frame: frame,
            region: .init(x: 0.08, y: 0.88, width: 0.84, height: 0.055),
            action: onSignIn
        )

        Button("Explore Map without an account", action: onExploreWithoutAccount)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.mugshotSage)
            .frame(width: frame.width, height: max(44, frame.height * 0.065))
            .background(Color(red: 245.0 / 255.0, green: 242.0 / 255.0, blue: 237.0 / 255.0))
            .position(x: frame.midX, y: frame.minY + frame.height * 0.967)
            .accessibilityIdentifier("mugshot.firstLaunch.exploreWithoutAccount")
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
        case .friends, .saved, .journal:
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
        case .friends, .saved, .journal:
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
        onSignIn: {},
        onExploreWithoutAccount: {}
    )
}
#endif
