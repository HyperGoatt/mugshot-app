import SwiftUI

enum TastePassportPresentationContext: Equatable {
    case owner
    case viewer(displayName: String)
}

struct TastePassportProjectionSection: View {
    let state: TastePassportLoadState
    let context: TastePassportPresentationContext
    var onRetry: (() -> Void)?

    var body: some View {
        Group {
            switch state {
            case .loading:
                passportStateCard(
                    title: "Loading Taste Passport",
                    message: "Checking the latest Passport safely.",
                    systemImage: "sparkles",
                    showsProgress: true
                )
                .accessibilityLabel("Loading Taste Passport")

            case .loaded(.hidden):
                unavailableCard

            case .loaded(.insufficient(let visibility)):
                formingCard(visibility: visibility)

            case .loaded(.compatibilityInsufficient):
                compatibilityFormingCard

            case .loaded(.visible(let projection)):
                visibleCard(projection)

            case .failed(let message):
                failedCard(message: message)
            }
        }
        .accessibilityIdentifier("tastePassport.section")
    }

    private func visibleCard(_ projection: TastePassportProjection) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .frame(width: 42, height: 42)
                    .background(Color.mugshotSage, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TASTE PASSPORT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.mugshotSageText)
                    Text(projection.confidenceBand.cautiousLabel)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(.espressoBrown)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(projection.descriptors) { descriptor in
                        Text(descriptor.displayLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.mugshotMint.opacity(0.48), in: Capsule())
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Taste descriptors: \(projection.descriptors.map(\.displayLabel).joined(separator: ", "))")

            Text(projection.summaryDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Color.mugshotLine)

            Label(
                audienceExplanation(for: projection),
                systemImage: projection.visibility.systemImage
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                projection.isCompatibilityPreview
                    ? "This preview uses only sips already visible to you; private notes and hidden sips are excluded."
                    : "Taste Passport visibility is independent from every sip, recipe, and private note audience."
            )
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            explanationLink(
                visibility: projection.visibility,
                isForming: false,
                isCompatibilityPreview: projection.isCompatibilityPreview
            )
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.foamWhite, Color.mugshotMint.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            passportStateHeader(
                title: "Taste Passport unavailable",
                systemImage: "person.crop.circle.badge.questionmark"
            )
            Text("This Taste Passport is not available to you. Mugshot does not reveal whether it is private, still forming, or otherwise unavailable.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                TastePassportExplanationView(
                    context: context,
                    visibility: nil,
                    isForming: nil,
                    isCompatibilityPreview: false
                )
            } label: {
                Label("About Taste Passports", systemImage: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.mugshotSageText)
            .accessibilityHint("Explains what Taste Passports share and protect")
        }
        .padding(18)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private func formingCard(visibility: TastePassportVisibility) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            passportStateHeader(
                title: "Taste Passport is still forming",
                systemImage: "sparkles"
            )
            Text("Mugshot waits for recurring patterns before showing descriptors. Early guesses and exact evidence counts stay hidden.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if context == .owner {
                Label(visibility.ownerExplanation, systemImage: visibility.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
            }

            explanationLink(
                visibility: visibility,
                isForming: true,
                isCompatibilityPreview: false
            )
        }
        .padding(18)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private var compatibilityFormingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            passportStateHeader(
                title: "Taste Passport is still forming",
                systemImage: "sparkles"
            )
            Text("Mugshot does not have enough recurring patterns in the sips available on this profile yet. Private notes, hidden sips, early guesses, and exact evidence counts stay hidden.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private func failedCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            passportStateHeader(
                title: "Taste Passport unavailable",
                systemImage: "exclamationmark.arrow.triangle.2.circlepath"
            )
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let onRetry {
                Button("Try again", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Reloads the Taste Passport from Mugshot")
            }
        }
        .padding(18)
        .cardStyle()
    }

    private func passportStateCard(
        title: String,
        message: String,
        systemImage: String,
        showsProgress: Bool
    ) -> some View {
        HStack(spacing: 13) {
            if showsProgress {
                ProgressView().tint(.mugshotSage)
            } else {
                Image(systemName: systemImage)
                    .foregroundColor(.mugshotSage)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
    }

    private func passportStateHeader(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundColor(.espressoBrown)
    }

    private func explanationLink(
        visibility: TastePassportVisibility,
        isForming: Bool,
        isCompatibilityPreview: Bool
    ) -> some View {
        NavigationLink {
            TastePassportExplanationView(
                context: context,
                visibility: visibility,
                isForming: isForming,
                isCompatibilityPreview: isCompatibilityPreview
            )
        } label: {
            Label("Why am I seeing this?", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.mugshotSageText)
        .accessibilityLabel("Why am I seeing this Taste Passport?")
        .accessibilityHint("Explains its audience and evidence protections")
    }

    private func audienceExplanation(for projection: TastePassportProjection) -> String {
        if projection.isCompatibilityPreview {
            switch context {
            case .owner:
                return "You can review this compatibility preview as the Passport owner."
            case .viewer(let displayName):
                return "This preview uses only sips \(displayName) already shares with you."
            }
        }

        let visibility = projection.visibility
        switch context {
        case .owner:
            return visibility.ownerExplanation
        case .viewer(let displayName):
            switch visibility {
            case .everyone:
                return "You can see this because \(displayName) shares their Taste Passport with everyone."
            case .friends:
                return "You can see this because \(displayName) shares their Taste Passport with confirmed friends."
            case .privateOnly:
                return "Mugshot confirmed that you can see this Taste Passport."
            }
        }
    }
}

struct TastePassportExplanationView: View {
    let context: TastePassportPresentationContext
    let visibility: TastePassportVisibility?
    let isForming: Bool?
    let isCompatibilityPreview: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                explanationSection(
                    title: "Why it appears",
                    systemImage: "eye.fill",
                    message: reasonMessage
                )
                explanationSection(
                    title: "How it forms",
                    systemImage: "sparkles",
                    message: formationMessage
                )
                explanationSection(
                    title: "What stays private",
                    systemImage: "lock.shield.fill",
                    message: "A Taste Passport never reveals private notes, exact evidence counts, or the individual sips behind a descriptor."
                )
                explanationSection(
                    title: "A separate audience",
                    systemImage: "person.2.badge.gearshape.fill",
                    message: audienceSeparationMessage
                )
            }
            .padding(20)
        }
        .background(Color.creamWhite)
        .navigationTitle("About Taste Passport")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reasonMessage: String {
        if isCompatibilityPreview {
            switch context {
            case .owner:
                return "Mugshot built this temporary preview only from your available sip history. It does not claim that a separate Passport audience has been confirmed."
            case .viewer(let displayName):
                return "Mugshot built this temporary preview only from sips \(displayName) already shares with you. It does not reveal or infer a separate Passport audience."
            }
        }

        guard let visibility else {
            return "This Passport is not available to you. Mugshot intentionally does not say whether that is because of an audience setting, insufficient evidence, or another privacy rule."
        }
        switch context {
        case .owner:
            return "You can always review your own Passport. Its current audience is \(visibility.title), which controls only who else can see it."
        case .viewer(let displayName):
            switch visibility {
            case .everyone:
                return "\(displayName) shares their Taste Passport with everyone on Mugshot."
            case .friends:
                return "\(displayName) shares their Taste Passport with confirmed friends, and Mugshot confirmed that audience includes you."
            case .privateOnly:
                return "Mugshot confirmed that you are allowed to see this Passport without exposing any broader privacy setting."
            }
        }
    }

    private var formationMessage: String {
        if isForming == true {
            return "This Passport has not reached Mugshot’s evidence threshold. It shows no early descriptors, inferred traits, or evidence counts while it forms."
        }
        return "Descriptors summarize recurring patterns from supported journal signals. They are cautious observations, not diagnoses, scores, or permanent labels."
    }

    private var audienceSeparationMessage: String {
        if isCompatibilityPreview {
            return "The completed Taste Passport has its own audience. A preview never changes who can see any sip, recipe, photo, caption, or private note."
        }
        return "Changing a Taste Passport audience never changes who can see a sip, recipe, photo, caption, or private note."
    }

    private func explanationSection(
        title: String,
        systemImage: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

struct TastePassportVisibilitySettingsSection: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var visibility: TastePassportVisibility = .everyone
    @State private var isLoading = true
    @State private var hasLoadedVisibility = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Taste Passport") {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading audience…")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading Taste Passport audience")
            } else if hasLoadedVisibility {
                Picker("Who can see it", selection: visibilityBinding) {
                    ForEach(TastePassportVisibility.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .disabled(isSaving || authModel.authenticatedUser == nil)
                .accessibilityHint("Controls only your Taste Passport audience")

                Label(visibility.ownerExplanation, systemImage: visibility.systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)

                if isSaving {
                    Label("Saving audience…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.mugshotSageText)
                }
            } else {
                Label("Audience unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
            }

            Text("This setting is independent from every sip, recipe, photo, caption, and private note. Taste Passports start as Everyone unless you change them.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.roastBrown)
                    Button("Try again") {
                        Task { await loadVisibility() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            await loadVisibility()
        }
    }

    private var visibilityBinding: Binding<TastePassportVisibility> {
        Binding(
            get: { visibility },
            set: { newVisibility in
                guard newVisibility != visibility, !isSaving else { return }
                let previous = visibility
                visibility = newVisibility
                Task { await saveVisibility(newVisibility, revertingTo: previous) }
            }
        )
    }

    @MainActor
    private func loadVisibility() async {
        isSaving = false
        hasLoadedVisibility = false
        visibility = .everyone
        guard let accountID = authModel.authenticatedUser?.id else {
            isLoading = false
            errorMessage = "Sign in to manage your Taste Passport audience."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            let loaded = try await TastePassportService(client: client)
                .fetchVisibility(accountID: accountID)
            guard authModel.authenticatedUser?.id == accountID,
                  !Task.isCancelled else { return }
            visibility = loaded
            hasLoadedVisibility = true
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == accountID else { return }
            isLoading = false
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func saveVisibility(
        _ newVisibility: TastePassportVisibility,
        revertingTo previousVisibility: TastePassportVisibility
    ) async {
        guard let accountID = authModel.authenticatedUser?.id else {
            visibility = previousVisibility
            errorMessage = "Sign in to change your Taste Passport audience."
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            let confirmed = try await TastePassportService(client: client).setVisibility(
                newVisibility,
                accountID: accountID
            )
            guard authModel.authenticatedUser?.id == accountID else { return }
            visibility = confirmed
            isSaving = false
        } catch is CancellationError {
            return
        } catch {
            guard authModel.authenticatedUser?.id == accountID else { return }
            visibility = previousVisibility
            isSaving = false
            errorMessage = MugshotUserFacingError.message(for: error, context: .account)
        }
    }
}
