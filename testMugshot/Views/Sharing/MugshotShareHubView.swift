import Photos
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
    @State private var successMessage: String?
    @State private var isPreparing = false

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
            VStack(alignment: .leading, spacing: 22) {
                header
                exportPreview
                formatAndTemplateControls
                if photos.count > 1 {
                    photoControls
                }
                destinationSection
                secondaryActions
                if isPostPublish {
                    passportReceipt
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
        .background(Color.creamWhite)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
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
                presentSystemShare()
            }
        } message: {
            Text("Anyone with this unlisted share link can view the post, even if they are not signed in or are not yet your friend. Changing the post to Private stops link access.")
        }
        .alert(
            "Sharing is still here",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try sharing again or save the image.")
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

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isPostPublish ? "Mugshot published" : "Share your Mugshot")
                    .mugshotDisplay(size: 34)
                    .foregroundStyle(Color.espressoBrown)
                Text(
                    isPostPublish
                        ? "Your branded share is ready."
                        : "Choose your look, then share it anywhere."
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

            MugshotShareArtworkPreview(
                content: content,
                photos: orderedPhotos,
                photoLayout: selectedPhotoLayout,
                template: selectedTemplate,
                format: selectedFormat
            )
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
            HStack(spacing: 8) {
                ForEach(values) { value in
                    Button {
                        withAnimation(reduceMotion ? nil : DesignSystem.Motion.fast) {
                            selection.wrappedValue = value
                        }
                    } label: {
                        Text(value[keyPath: label])
                            .font(.system(size: 13, weight: .bold))
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
            }
        }
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedPhotoLayout == .smartCollage ? "Lead photo" : "Published photo")
                Spacer()
                if selectedPhotoLayout == .smartCollage {
                    Text("Uses up to 4 photos")
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
                            selectedPhotoLayout == .smartCollage
                                ? "Use photo \(index + 1) as the lead photo"
                                : "Use published photo \(index + 1)"
                        )
                        .accessibilityAddTraits(index == selectedPhotoIndex ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share anywhere")
                .mugshotDisplay(size: 23)
                .foregroundStyle(Color.espressoBrown)

            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.espressoBrown)
                    .frame(width: 48, height: 48)
                    .background(Color.mugshotMint.opacity(0.62), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Instagram, Stories, Messages & more")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(
                        publicURL == nil
                            ? "Mugshot sends one finished image to Apple’s share menu. Installed apps appear automatically."
                            : "Mugshot sends your finished image and a clickable post link. The link opens the iOS app first, with the web as a fallback."
                    )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )

            if isPreparing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.mugshotSage)
                    Text("Preparing the exact export…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
                .accessibilityElement(children: .combine)
            } else if let successMessage {
                Text(successMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mugshotSage)
            }
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    saveCurrentArtwork()
                } label: {
                    Label("Save image", systemImage: "arrow.down.to.line")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    copyCurrentArtwork()
                } label: {
                    Label("Copy image", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                Button {
                    copyCaption()
                } label: {
                    Label("Copy caption", systemImage: "text.quote")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())

                if publicURL != nil {
                    Button {
                        copyPublicLink()
                    } label: {
                        Label("Copy link", systemImage: "link")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var passportReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Mugshot Passport updated", systemImage: "book.closed.fill")
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
                    Label("Pour another one", systemImage: "plus.circle")
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
                    Text(isPreparing ? "Preparing…" : "Share Mugshot")
                        .font(.system(size: 15, weight: .bold))
                    Text("Instagram, Stories, Messages & more")
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
        if content.mayHavePublicLink,
           let client = try? SupabaseClientProvider.shared.client() {
            publicURL = try? await MugshotShareLinkService(client: client)
                .createOwnerLink(visitID: content.visitID)
        }
        rebuildPackage()
    }

    private func rebuildPackage() {
        let story = renderArtwork(format: .story)
        let post = renderArtwork(format: .post)
        guard let story, let post else {
            sharePackage = nil
            return
        }
        sharePackage = MugshotSharePackage(
            content: content,
            storyArtwork: story,
            postArtwork: post,
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

    private func beginSystemShare() {
        record(
            .destinationTapped,
            destination: .more,
            format: selectedFormat
        )
        if content.requiresExternalAudienceWarning, !hasAcknowledgedExternalAudience {
            isAwaitingAudienceAcknowledgement = true
            return
        }
        presentSystemShare()
    }

    @MainActor
    private func presentSystemShare() {
        isPreparing = true
        successMessage = nil
        defer { isPreparing = false }

        rebuildPackage()
        guard let package = sharePackage else {
            errorMessage = MugshotShareHandoffError.artworkEncodingFailed.localizedDescription
            record(.handoffFailed, destination: .more, format: selectedFormat)
            return
        }

        systemSharePresentation = MugshotSystemSharePresentation(
            items: package.activityItems(for: selectedFormat),
            format: selectedFormat
        )
        successMessage = "Share again anytime—your export stays ready."
        record(.handoffOpened, destination: .more, format: selectedFormat)
    }

    private func saveCurrentArtwork() {
        if sharePackage == nil {
            rebuildPackage()
        }
        guard let image = sharePackage?.artwork(for: selectedFormat) else {
            errorMessage = MugshotShareHandoffError.artworkEncodingFailed.localizedDescription
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    errorMessage = "Allow photo access to save this export, or use Share Mugshot."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { saved, _ in
                Task { @MainActor in
                    successMessage = saved ? "Image saved to Photos." : nil
                    if !saved {
                        errorMessage = "The image could not be saved. Try Share Mugshot instead."
                    }
                }
            }
        }
    }

    private func copyPublicLink() {
        guard let publicURL else { return }
        UIPasteboard.general.url = publicURL
        successMessage = "Mugshot share link copied."
    }

    private func copyCurrentArtwork() {
        if sharePackage == nil {
            rebuildPackage()
        }
        guard let image = sharePackage?.artwork(for: selectedFormat) else {
            errorMessage = MugshotShareHandoffError.artworkEncodingFailed.localizedDescription
            return
        }
        UIPasteboard.general.image = image
        successMessage = "Branded image copied."
    }

    private func copyCaption() {
        var caption = content.shareText
        if let publicURL {
            caption += "\n\n\(publicURL.absoluteString)"
        }
        UIPasteboard.general.string = caption
        successMessage = "Caption copied."
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

private struct MugshotShareArtworkPreview: View {
    let content: MugshotShareContent
    let photos: [UIImage]
    let photoLayout: MugshotSharePhotoLayout
    let template: MugshotShareTemplate
    let format: MugshotShareFormat

    var body: some View {
        GeometryReader { proxy in
            let size = format.pixelSize
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            MugshotShareArtworkView(
                content: content,
                photos: photos,
                photoLayout: photoLayout,
                template: template,
                format: format
            )
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale, anchor: .topLeading)
        }
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
        ZStack {
            Color.creamWhite
            Image("V3TastePassportBackdrop")
                .resizable()
                .scaledToFill()
                .opacity(0.10)

            VStack(alignment: .leading, spacing: format == .story ? 48 : 30) {
                HStack(alignment: .top) {
                    signature(color: .espressoBrown)
                    Spacer()
                    fieldStamp
                }

                sharePhoto
                    .frame(
                        height: format == .story ? 790 : 610
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.foamWhite, lineWidth: 18)
                    )
                    .shadow(color: Color.espressoBrown.opacity(0.12), radius: 24, y: 14)

                routeDetail(color: .mugshotSage)

                HStack(alignment: .bottom, spacing: 40) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(content.drinkName)
                            .font(.system(size: format == .story ? 86 : 70, weight: .bold, design: .serif))
                            .foregroundStyle(Color.espressoBrown)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                        Text(content.contextName)
                            .font(.system(size: 31, weight: .semibold))
                            .foregroundStyle(Color.roastBrown)
                            .lineLimit(2)
                        if let caption = content.caption {
                            Text(caption)
                                .font(.system(size: 28, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(format == .story ? 4 : 2)
                        }
                    }
                    Spacer(minLength: 10)
                    score(color: .espressoBrown)
                }
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
            }
            .padding(.horizontal, format == .story ? 86 : 70)
            .padding(.top, format == .story ? 210 : 64)
            .padding(.bottom, format == .story ? 230 : 64)
        }
    }

    @ViewBuilder
    private var sharePhoto: some View {
        if let photo = photos.first {
            if photoLayout == .smartCollage, photos.count > 1 {
                MugshotSmartCollageView(photos: Array(photos.prefix(4)))
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

    private func score(color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(content.rating, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 98, weight: .bold, design: .serif))
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
                .font(.system(size: 31, weight: .semibold))
            Text("FIELD NOTE")
                .font(.system(size: 17, weight: .heavy))
                .tracking(2)
        }
        .foregroundStyle(Color.mugshotSage)
        .frame(width: 164, height: 118)
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

private struct MugshotSmartCollageView: View {
    let photos: [UIImage]

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 14
            HStack(spacing: spacing) {
                collagePhoto(at: 0)
                    .frame(
                        width: proxy.size.width * (photos.count == 2 ? 0.58 : 0.62),
                        height: proxy.size.height
                    )

                if photos.count == 2 {
                    collagePhoto(at: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: spacing) {
                        ForEach(1..<min(photos.count, 4), id: \.self) { index in
                            collagePhoto(at: index)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.foamWhite)
        }
    }

    private func collagePhoto(at index: Int) -> some View {
        Image(uiImage: photos[index])
            .resizable()
            .scaledToFill()
            .clipped()
    }
}

private struct MugshotSystemSharePresentation: Identifiable {
    let id = UUID()
    let items: [Any]
    let format: MugshotShareFormat
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
