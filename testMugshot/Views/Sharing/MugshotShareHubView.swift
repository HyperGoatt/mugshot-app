import SwiftUI
import UIKit

struct MugshotShareHubView: View {
    let summary: LogASipV3PassportSummary
    let isOpeningMugshot: Bool
    let statusMessage: String?
    let onViewMugshot: () -> Void
    let onViewPassport: () -> Void
    let onFinish: () -> Void
    let onStartAnother: (() -> Void)?
    var startAnotherTitle = "Pour another one"
    var isPostPublish = true

    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedFormat: MugshotShareFormat = .story
    @State private var selectedTemplate: MugshotShareTemplate = .fullBleed
    @State private var selectedPhotoLayout: MugshotSharePhotoLayout = .singlePhoto
    @State private var selectedPhotoIndex = 0
    @State private var sharePackage: MugshotSharePackage?
    @State private var publicURL: URL?
    @State private var isAwaitingAudienceAcknowledgement = false
    @State private var hasAcknowledgedExternalAudience = false
    @State private var systemSharePresentation: MugshotSystemSharePresentation?
    @State private var errorMessage: String?
    @State private var isPreparing = false
    @State private var showsShareCustomization = false

    private var content: MugshotShareContent {
        MugshotShareContent(
            visitID: summary.visitID,
            isOwner: summary.isOwner,
            isRemote: summary.isRemote,
            visibility: summary.visibility,
            authorName: summary.displayName,
            drinkName: summary.drinkName,
            contextName: summary.contextName,
            rating: summary.mugshotScore,
            createdAt: summary.createdAt,
            caption: summary.publicCaption
        )
    }

    private var photos: [UIImage] {
        if !summary.photoImages.isEmpty {
            return summary.photoImages
        }
        return summary.coverImage.map { [$0] } ?? []
    }

    private var orderedPhotos: [UIImage] {
        guard !photos.isEmpty else { return [] }
        let selectedIndex = min(max(selectedPhotoIndex, 0), photos.count - 1)
        return [photos[selectedIndex]]
            + photos.enumerated().compactMap { index, image in
                index == selectedIndex ? nil : image
            }
    }

    var body: some View {
        ScrollView {
            if isPostPublish && !showsShareCustomization {
                postPublishReceipt
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    exportPreview
                    formatAndTemplateControls
                    if photos.count > 1 {
                        photoControls
                    }
                    if isPostPublish {
                        completionActions
                    } else {
                        Button("Done", action: dismissHub)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
        }
        .background(Color.creamWhite)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isPostPublish || showsShareCustomization {
                bottomAction
            }
        }
        .task(id: summary.visitID) {
            await prepareInitialPackage()
        }
        .onChange(of: selectedFormat) { _, newValue in
            record(.formatSelected, format: newValue)
        }
        .onChange(of: selectedTemplate) { _, newValue in
            record(.templateSelected, template: newValue)
            rebuildPackage()
        }
        .onChange(of: selectedPhotoLayout) { _, newValue in
            record(.photoLayoutSelected, photoLayout: newValue)
            rebuildPackage()
        }
        .onChange(of: selectedPhotoIndex) { _, _ in
            rebuildPackage()
        }
        .alert(
            "Share beyond your Mugshot audience?",
            isPresented: $isAwaitingAudienceAcknowledgement
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                hasAcknowledgedExternalAudience = true
                presentPrimarySystemShare()
            }
        } message: {
            Text(privacyConfirmationMessage)
        }
        .alert(
            "Couldn’t prepare sharing",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try sharing again.")
        }
        .sheet(item: $systemSharePresentation) { presentation in
            MugshotSystemShareView(
                items: presentation.items,
                onCompletion: { completed in
                    if completed {
                        record(
                            .systemShareCompleted,
                            destination: .more,
                            format: presentation.format
                        )
                    }
                    systemSharePresentation = nil
                }
            )
        }
        .accessibilityIdentifier("logASipV3.shareHub")
    }

    private var postPublishReceipt: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Mugshot published.")
                        .mugshotDisplay(size: 34)
                        .foregroundStyle(Color.espressoBrown)
                    Text(
                        startAnotherTitle == "Brew Again"
                            ? "Your attempt is saved in your Home journal."
                            : "Your sip is live and safely in your journal."
                    )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 10)
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.foamWhite)
                    .frame(width: 38, height: 38)
                    .background(Color.mugshotSage, in: Circle())
                    .accessibilityLabel("Published")
            }

            MugshotAdaptivePostMedia(
                ratioCacheKey: "publish-receipt:\(summary.visitID.uuidString)",
                drinkName: summary.drinkName,
                locationName: summary.contextName,
                score: summary.mugshotScore,
                cornerRadius: 22
            ) {
                if let coverImage = summary.coverImage {
                    MugshotInMemoryPostImage(image: coverImage)
                } else {
                    ZStack {
                        Color.sandBeige
                        MugsyModelView(configuration: MugsyPlacement.ritual.configuration)
                            .padding(54)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }

            VStack(spacing: 10) {
                Button(action: onViewMugshot) {
                    Label(
                        isOpeningMugshot ? "Opening Mugshot…" : "View Mugshot",
                        systemImage: "checkmark.seal"
                    )
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isOpeningMugshot)

                Button {
                    withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                        showsShareCustomization = true
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Done", action: onFinish)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(SecondaryButtonStyle())

                if let onStartAnother {
                    Button(action: onStartAnother) {
                        Label(startAnotherTitle, systemImage: "arrow.clockwise.circle")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isPostPublish ? "Mugshot published" : "Share your Mugshot")
                    .mugshotDisplay(size: 34)
                    .foregroundStyle(Color.espressoBrown)
                Text(
                    isPostPublish
                        ? "Your branded share is ready."
                        : "Choose a look for your Mugshot post."
                )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.foamWhite)
                .frame(width: 38, height: 38)
                .background(Color.mugshotSage, in: Circle())
                .accessibilityLabel("Published")
        }
    }

    private var exportPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your export")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                Spacer()
                Text("\(Int(selectedFormat.pixelSize.width)) × \(Int(selectedFormat.pixelSize.height))")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.tertiaryText)
            }

            Group {
                if let image = sharePackage?.artwork(for: selectedFormat) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Color.sandBeige.opacity(0.35)
                        ProgressView()
                            .tint(.mugshotSage)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(selectedFormat.pixelSize.width / selectedFormat.pixelSize.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
            .shadow(color: DesignSystem.cardShadow.color, radius: 18, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(selectedTemplate.title) \(selectedFormat.title) preview for \(content.drinkName) at \(content.contextName), rated \(content.rating.formatted(.number.precision(.fractionLength(1)))) out of 5"
            )
        }
    }

    private var formatAndTemplateControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            sharePicker(
                title: "Format",
                values: MugshotShareFormat.allCases,
                selection: $selectedFormat,
                label: \.title
            )
            sharePicker(
                title: "Template",
                values: MugshotShareTemplate.allCases,
                selection: $selectedTemplate,
                label: \.title
            )
            if photos.count > 1 {
                sharePicker(
                    title: "Photos",
                    values: MugshotSharePhotoLayout.availableLayouts(photoCount: photos.count),
                    selection: $selectedPhotoLayout,
                    label: \.title
                )
            }
        }
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private func sharePicker<Value: Identifiable & Hashable>(
        title: String,
        values: [Value],
        selection: Binding<Value>,
        label: KeyPath<Value, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.8)
            if values.count > 3 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(values) { value in
                            sharePickerOption(
                                value: value,
                                selection: selection,
                                title: value[keyPath: label]
                            )
                            .frame(width: 118)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(values) { value in
                        sharePickerOption(
                            value: value,
                            selection: selection,
                            title: value[keyPath: label]
                        )
                    }
                }
            }
        }
    }

    private func sharePickerOption<Value: Identifiable & Hashable>(
        value: Value,
        selection: Binding<Value>,
        title: String
    ) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.fast) {
                selection.wrappedValue = value
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selection.wrappedValue == value
                        ? Color.mugshotMint.opacity(0.62)
                        : Color.creamWhite
                )
                .foregroundStyle(Color.espressoBrown)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        selection.wrappedValue == value
                            ? Color.mugshotSage.opacity(0.5)
                            : Color.mugshotLine,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedPhotoLayout.isCollage ? "Lead photo" : "Published photo")
                Spacer()
                if selectedPhotoLayout.isCollage {
                    Text("Uses \(min(selectedPhotoLayout.photoLimit, photos.count)) photos")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.tertiaryText)
                }
            }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.espressoBrown)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
                        Button {
                            selectedPhotoIndex = index
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 68, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(
                                            index == selectedPhotoIndex
                                                ? Color.mugshotSage
                                                : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            selectedPhotoLayout.isCollage
                                ? "Use photo \(index + 1) as the lead photo"
                                : "Use published photo \(index + 1)"
                        )
                        .accessibilityAddTraits(index == selectedPhotoIndex ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var passportReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Taste Passport updated", systemImage: "book.closed.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                Spacer()
                Text(summary.memoryCount > 0 ? "\(summary.memoryCount) memories" : "Still learning")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
            }
            Text(summary.identityTitle)
                .mugshotDisplay(size: 25)
                .foregroundStyle(Color.espressoBrown)
            Text(summary.identityDetail)
                .font(.system(size: 13))
                .foregroundStyle(Color.secondaryText)
                .lineLimit(3)
            Button("View in Passport", action: onViewPassport)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .frame(minHeight: 44)
        }
        .padding(16)
        .background(Color.mugshotMint.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.25), lineWidth: 1)
        )
    }

    private var completionActions: some View {
        VStack(spacing: 2) {
            Button(action: onViewMugshot) {
                Label(
                    isOpeningMugshot ? "Opening Mugshot…" : "View Mugshot",
                    systemImage: "checkmark.seal"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isOpeningMugshot)

            Button(action: dismissHub) {
                Text("Not now")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryButtonStyle())

            if let onStartAnother {
                Button(action: onStartAnother) {
                    Label(startAnotherTitle, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomAction: some View {
        Button(action: beginSystemShare) {
            HStack(spacing: 10) {
                if isPreparing {
                    ProgressView()
                        .tint(Color.foamWhite)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        isPreparing
                            ? "Preparing…"
                            : "Share Mugshot post"
                    )
                        .font(.system(size: 15, weight: .bold))
                    Text(
                        content.visibility == .private
                            ? "Artwork only · your post stays Private"
                            : "Artwork and its Mugshot link"
                    )
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.78)
                }
                Spacer()
            }
            .foregroundStyle(Color.foamWhite)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .background(Color.mugshotSage)
            .clipShape(Capsule())
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
    }

    private func prepareInitialPackage() async {
        record(.hubViewed)
        if let coverImage = summary.coverImage,
           let coverIndex = photos.firstIndex(where: { $0 === coverImage }) {
            selectedPhotoIndex = coverIndex
        }
        selectedPhotoLayout = MugshotSharePhotoLayout.defaultLayout(photoCount: photos.count)
        rebuildPackage()
        if content.mayHavePublicLink,
           let client = try? SupabaseClientProvider.shared.client() {
            publicURL = try? await MugshotShareLinkService(client: client)
                .createOwnerLink(visitID: content.visitID)
            attachCurrentLinkToPackage()
        }
    }

    private func rebuildPackage() {
        let story = renderArtwork(format: .story)
        let post = renderArtwork(format: .post)
        let linkPreview = renderLinkPreview()
        guard let story, let post, let linkPreview else {
            sharePackage = nil
            return
        }
        sharePackage = MugshotSharePackage(
            content: content,
            storyArtwork: story,
            postArtwork: post,
            linkPreviewArtwork: linkPreview,
            publicURL: publicURL
        )
    }

    private func attachCurrentLinkToPackage() {
        guard let package = sharePackage else { return }
        sharePackage = MugshotSharePackage(
            content: package.content,
            storyArtwork: package.storyArtwork,
            postArtwork: package.postArtwork,
            linkPreviewArtwork: package.linkPreviewArtwork,
            publicURL: publicURL
        )
    }

    private func renderArtwork(format: MugshotShareFormat) -> UIImage? {
        let size = format.pixelSize
        let artwork = MugshotShareArtworkView(
            content: content,
            photos: orderedPhotos,
            photoLayout: selectedPhotoLayout,
            template: selectedTemplate,
            format: format
        )
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func renderLinkPreview() -> UIImage? {
        let size = CGSize(width: 1_200, height: 630)
        let preview = MugshotShareLinkPreviewView(
            content: content,
            photo: orderedPhotos.first
        )
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: preview)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func beginSystemShare() {
        record(
            .destinationTapped,
            destination: .more,
            format: selectedFormat
        )
        if content.requiresExternalAudienceWarning,
           !hasAcknowledgedExternalAudience {
            isAwaitingAudienceAcknowledgement = true
            return
        }
        presentPrimarySystemShare()
    }

    private var privacyConfirmationMessage: String {
        switch content.visibility {
        case .private:
            return "This post stays Private in Mugshot. The share sheet will receive only the finished artwork, which anyone you send it to may keep or reshare."
        case .friends:
            return "The post link remains limited to confirmed friends. The finished artwork can still be kept or reshared outside Mugshot."
        case .everyone:
            return ""
        }
    }

    @MainActor
    private func presentPrimarySystemShare() {
        isPreparing = true
        defer { isPreparing = false }

        rebuildPackage()
        guard let package = sharePackage else {
            errorMessage = MugshotShareHandoffError.artworkEncodingFailed.localizedDescription
            record(.handoffFailed, destination: .more, format: selectedFormat)
            return
        }

        systemSharePresentation = MugshotSystemSharePresentation(
            items: package.primaryActivityItems(for: selectedFormat),
            format: selectedFormat,
            mode: publicURL == nil ? .artwork : .link
        )
        record(.handoffOpened, destination: .more, format: selectedFormat)
    }

    private func dismissHub() {
        record(.hubDismissed)
        onFinish()
    }

    private func record(
        _ event: MugshotShareAnalyticsEvent,
        destination: MugshotShareDestination? = nil,
        format: MugshotShareFormat? = nil,
        template: MugshotShareTemplate? = nil,
        photoLayout: MugshotSharePhotoLayout? = nil
    ) {
        MugshotShareAnalytics.shared.record(
            event,
            content: content,
            destination: destination,
            format: format ?? selectedFormat,
            template: template ?? selectedTemplate,
            photoLayout: photoLayout ?? selectedPhotoLayout,
            hasPublicLink: publicURL != nil,
            userID: authModel.authenticatedUser?.id
        )
    }
}

struct MugshotShareLinkPreviewView: View {
    let content: MugshotShareContent
    let photo: UIImage?

    var body: some View {
        ZStack {
            Color.creamWhite

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 22) {
                        Image("MugshotAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 82, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        Text("MUGSHOT")
                            .font(.system(size: 30, weight: .heavy))
                            .tracking(9)
                            .foregroundStyle(Color.espressoBrown)
                    }

                    Text("CAPTURE EVERY SIP")
                        .font(.system(size: 21, weight: .heavy))
                        .tracking(2.6)
                        .foregroundStyle(Color.mugshotSage)
                        .padding(.top, 48)

                    Text(content.drinkName)
                        .font(.system(size: 70, weight: .bold, design: .serif))
                        .foregroundStyle(Color.espressoBrown)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .padding(.top, 16)

                    Text(content.contextName)
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.top, 18)

                    Text("Shared by \(content.authorName)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 10)

                    Spacer()

                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.mugshotMint)
                            .frame(width: 10, height: 10)
                        Text("Remember the sip, not just the place.")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)
                    }
                }
                .frame(width: photo == nil ? 1_200 : 732, alignment: .leading)
                .padding(.horizontal, 64)
                .padding(.vertical, 54)

                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 468, height: 630)
                        .clipped()
                        .overlay(alignment: .leading) {
                            LinearGradient(
                                colors: [Color.creamWhite.opacity(0.34), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 110)
                        }
                }
            }

            Circle()
                .stroke(Color(red: 201 / 255, green: 132 / 255, blue: 50 / 255).opacity(0.55), lineWidth: 3)
                .frame(width: 236, height: 236)
                .offset(x: photo == nil ? 420 : 240, y: 270)
        }
        .frame(width: 1_200, height: 630)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

struct MugshotShareArtworkView: View {
    let content: MugshotShareContent
    let photos: [UIImage]
    let photoLayout: MugshotSharePhotoLayout
    let template: MugshotShareTemplate
    let format: MugshotShareFormat

    var body: some View {
        Group {
            switch template {
            case .fullBleed:
                fullBleed
            case .fieldNote:
                fieldNote
            }
        }
        .frame(width: format.pixelSize.width, height: format.pixelSize.height)
        .clipped()
        .environment(\.colorScheme, .light)
    }

    private var fullBleed: some View {
        ZStack {
            sharePhoto
                .frame(width: format.pixelSize.width, height: format.pixelSize.height)
                .clipped()

            LinearGradient(
                colors: [
                    Color.espressoBrown.opacity(0.08),
                    Color.espressoBrown.opacity(0.14),
                    Color.espressoBrown.opacity(0.86)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                signature(color: .foamWhite)
                Spacer()
                HStack(alignment: .bottom, spacing: 44) {
                    VStack(alignment: .leading, spacing: 22) {
                        routeDetail(color: .mugshotMint)
                        Text(content.drinkName)
                            .font(.system(size: format == .story ? 92 : 78, weight: .bold, design: .serif))
                            .foregroundStyle(Color.foamWhite)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                        Text("\(content.contextName)  ·  \(formattedDate)")
                            .font(.system(size: 31, weight: .semibold))
                            .foregroundStyle(Color.foamWhite.opacity(0.86))
                            .lineLimit(2)
                        Text("Remembered by \(content.authorName)")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(Color.foamWhite.opacity(0.72))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 20)
                    score(color: .foamWhite)
                }
            }
            .padding(.horizontal, format == .story ? 86 : 70)
            .padding(.top, format == .story ? 210 : 70)
            .padding(.bottom, format == .story ? 250 : 84)
        }
    }

    private var fieldNote: some View {
        let layout = MugshotFieldNoteLayout.layout(for: format)
        return ZStack {
            Color.creamWhite

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    signature(color: .espressoBrown)
                    Spacer()
                    fieldStamp
                }
                .frame(height: layout.headerHeight, alignment: .top)

                Spacer().frame(height: layout.headerToMediaSpacing)

                sharePhoto
                    .frame(height: layout.mediaHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.foamWhite, lineWidth: 18)
                    )
                    .shadow(color: Color.espressoBrown.opacity(0.12), radius: 24, y: 14)

                Spacer().frame(height: layout.mediaToRouteSpacing)

                routeDetail(color: .mugshotSage)
                    .frame(height: layout.routeHeight, alignment: .leading)

                Spacer().frame(height: layout.routeToBodySpacing)

                HStack(alignment: .bottom, spacing: 40) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(content.drinkName)
                            .font(.system(size: layout.drinkFontSize, weight: .bold, design: .serif))
                            .foregroundStyle(Color.espressoBrown)
                            .lineLimit(layout.drinkLineLimit)
                            .minimumScaleFactor(0.62)
                        Text(content.contextName)
                            .font(.system(size: layout.contextFontSize, weight: .semibold))
                            .foregroundStyle(Color.roastBrown)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        if let caption = content.caption {
                            Text(caption)
                                .font(.system(size: layout.captionFontSize, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(layout.captionLineLimit)
                                .minimumScaleFactor(0.78)
                        }
                    }
                    Spacer(minLength: 10)
                    score(color: .espressoBrown, fontSize: layout.scoreFontSize)
                }
                .frame(height: layout.bodyHeight, alignment: .top)

                Spacer(minLength: 0)

                HStack {
                    Text(formattedDate.uppercased())
                    Spacer()
                    Text("REMEMBERED BY \(content.authorName.uppercased())")
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .font(.system(size: 23, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color.mugshotSage)
                .frame(height: layout.footerHeight, alignment: .bottom)
            }
            .padding(.horizontal, layout.horizontalMargin)
            .padding(.top, layout.topMargin)
            .padding(.bottom, layout.bottomMargin)
        }
    }

    @ViewBuilder
    private var sharePhoto: some View {
        if let photo = photos.first {
            if photoLayout.isCollage, photos.count > 1 {
                MugshotCollageView(
                    photos: Array(photos.prefix(min(photoLayout.photoLimit, photos.count))),
                    composition: collageComposition
                )
            } else {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            ZStack {
                Color.sandBeige
                MugsyModelView(
                    configuration: MugsyModelConfiguration(
                        expression: .delighted,
                        prop: .camera,
                        pose: .leaningRight
                    )
                )
                .padding(format == .story ? 190 : 130)
            }
        }
    }

    private var collageComposition: MugshotCollageComposition {
        switch photoLayout {
        case .smartCollage:
            return MugshotCollageComposition.smart(for: photos)
        case .twoPhoto:
            return .sideBySide
        case .threePhoto:
            return .leadBesideStack
        case .fourPhoto:
            return .grid
        case .singlePhoto:
            return .sideBySide
        }
    }

    private func signature(color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 27, weight: .semibold))
            Text("MUGSHOT")
                .font(.system(size: 25, weight: .heavy))
                .tracking(5)
        }
        .foregroundStyle(color)
    }

    private func routeDetail(color: Color) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 15, height: 15)
            Capsule()
                .fill(color.opacity(0.78))
                .frame(width: 112, height: 5)
            Image(systemName: "arrow.right")
                .font(.system(size: 21, weight: .bold))
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    private func score(color: Color, fontSize: CGFloat = 98) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(content.rating, format: .number.precision(.fractionLength(1)))
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .monospacedDigit()
            Text("OUT OF 5")
                .font(.system(size: 19, weight: .bold))
                .tracking(2)
        }
        .foregroundStyle(color)
    }

    private var fieldStamp: some View {
        VStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: format == .story ? 27 : 21, weight: .semibold))
            Text("FIELD NOTE")
                .font(.system(size: format == .story ? 15 : 13, weight: .heavy))
                .tracking(2)
        }
        .foregroundStyle(Color.mugshotSage)
        .frame(
            width: format == .story ? 150 : 132,
            height: format == .story ? 96 : 72
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.7), lineWidth: 3)
        )
        .rotationEffect(.degrees(2))
    }

    private var formattedDate: String {
        content.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}

struct MugshotFieldNoteLayout: Equatable {
    let horizontalMargin: CGFloat
    let topMargin: CGFloat
    let bottomMargin: CGFloat
    let headerHeight: CGFloat
    let headerToMediaSpacing: CGFloat
    let mediaHeight: CGFloat
    let mediaToRouteSpacing: CGFloat
    let routeHeight: CGFloat
    let routeToBodySpacing: CGFloat
    let bodyHeight: CGFloat
    let footerHeight: CGFloat
    let drinkFontSize: CGFloat
    let contextFontSize: CGFloat
    let captionFontSize: CGFloat
    let scoreFontSize: CGFloat
    let drinkLineLimit: Int
    let captionLineLimit: Int

    static let story = MugshotFieldNoteLayout(
        horizontalMargin: 78,
        topMargin: 170,
        bottomMargin: 170,
        headerHeight: 100,
        headerToMediaSpacing: 34,
        mediaHeight: 690,
        mediaToRouteSpacing: 28,
        routeHeight: 26,
        routeToBodySpacing: 22,
        bodyHeight: 400,
        footerHeight: 32,
        drinkFontSize: 82,
        contextFontSize: 30,
        captionFontSize: 27,
        scoreFontSize: 92,
        drinkLineLimit: 3,
        captionLineLimit: 4
    )

    static let post = MugshotFieldNoteLayout(
        horizontalMargin: 58,
        topMargin: 60,
        bottomMargin: 60,
        headerHeight: 76,
        headerToMediaSpacing: 22,
        mediaHeight: 460,
        mediaToRouteSpacing: 18,
        routeHeight: 24,
        routeToBodySpacing: 14,
        bodyHeight: 340,
        footerHeight: 28,
        drinkFontSize: 68,
        contextFontSize: 27,
        captionFontSize: 24,
        scoreFontSize: 78,
        drinkLineLimit: 2,
        captionLineLimit: 2
    )

    static func layout(for format: MugshotShareFormat) -> MugshotFieldNoteLayout {
        format == .story ? .story : .post
    }

    var fixedVerticalContent: CGFloat {
        topMargin
            + headerHeight
            + headerToMediaSpacing
            + mediaHeight
            + mediaToRouteSpacing
            + routeHeight
            + routeToBodySpacing
            + bodyHeight
            + footerHeight
            + bottomMargin
    }
}

enum MugshotCollageComposition: Equatable {
    case stacked
    case sideBySide
    case leadAbovePair
    case leadBesideStack
    case grid

    static func smart(for photos: [UIImage]) -> MugshotCollageComposition {
        switch photos.count {
        case 2:
            return photos.allSatisfy { $0.size.width > $0.size.height }
                ? .stacked
                : .sideBySide
        case 3:
            guard let lead = photos.first else { return .leadBesideStack }
            return lead.size.width > lead.size.height
                ? .leadAbovePair
                : .leadBesideStack
        case 4...:
            return .grid
        default:
            return .sideBySide
        }
    }
}

private struct MugshotCollageView: View {
    let photos: [UIImage]
    let composition: MugshotCollageComposition

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 14
            Group {
                switch composition {
                case .stacked:
                    VStack(spacing: spacing) {
                        collagePhoto(at: 0)
                        collagePhoto(at: 1)
                    }
                case .sideBySide:
                    HStack(spacing: spacing) {
                        collagePhoto(at: 0)
                        collagePhoto(at: 1)
                    }
                case .leadAbovePair:
                    VStack(spacing: spacing) {
                        collagePhoto(at: 0)
                            .frame(height: (proxy.size.height - spacing) * 0.58)
                        HStack(spacing: spacing) {
                            collagePhoto(at: 1)
                            collagePhoto(at: 2)
                        }
                    }
                case .leadBesideStack:
                    HStack(spacing: spacing) {
                        collagePhoto(at: 0)
                            .frame(width: (proxy.size.width - spacing) * 0.62)
                        VStack(spacing: spacing) {
                            collagePhoto(at: 1)
                            collagePhoto(at: 2)
                        }
                    }
                case .grid:
                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            collagePhoto(at: 0)
                            collagePhoto(at: 1)
                        }
                        HStack(spacing: spacing) {
                            collagePhoto(at: 2)
                            collagePhoto(at: 3)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.foamWhite)
        }
    }

    private func collagePhoto(at index: Int) -> some View {
        Group {
            if photos.indices.contains(index) {
                Image(uiImage: photos[index])
                    .resizable()
                    .scaledToFill()
            } else {
                Color.sandBeige
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private enum MugshotSystemShareMode {
    case link
    case artwork
}

private struct MugshotSystemSharePresentation: Identifiable {
    let id = UUID()
    let items: [Any]
    let format: MugshotShareFormat
    let mode: MugshotSystemShareMode
}

private struct MugshotSystemShareView: UIViewControllerRepresentable {
    let items: [Any]
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onCompletion(completed)
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
