import SwiftUI
import UIKit

enum MugshotPostAspectRatioPolicy {
    static let minimum: CGFloat = 3.0 / 4.0
    static let maximum: CGFloat = 1.91
    static let fallback: CGFloat = minimum

    static func clamped(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite, ratio > 0 else { return fallback }
        return min(max(ratio, minimum), maximum)
    }

    static func ratio(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return fallback }
        return clamped(size.width / size.height)
    }

    static func carouselRatio(for imageSizes: [CGSize]) -> CGFloat {
        guard let first = imageSizes.first else { return fallback }
        return ratio(for: first)
    }
}

enum MugshotPostLocationLine {
    static func locality(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let components = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = components.first else { return nil }

        if components.count >= 3,
           first.contains(where: \.isNumber) {
            return components[1]
        }
        return first
    }

    static func displayName(name: String, locality: String?) -> String {
        guard let locality = locality?.trimmingCharacters(in: .whitespacesAndNewlines),
              !locality.isEmpty,
              locality.caseInsensitiveCompare(name) != .orderedSame else {
            return name
        }
        return "\(name) · \(locality)"
    }
}

final class MugshotPostAspectRatioCache: @unchecked Sendable {
    static let shared = MugshotPostAspectRatioCache()
    private let cache = NSCache<NSString, NSNumber>()

    func ratio(for key: String) -> CGFloat? {
        cache.object(forKey: key as NSString).map { CGFloat(truncating: $0) }
    }

    func store(_ ratio: CGFloat, for key: String) {
        cache.setObject(NSNumber(value: Double(ratio)), forKey: key as NSString)
    }
}

private struct MugshotImageSizeReporterKey: EnvironmentKey {
    static let defaultValue: ((CGSize) -> Void)? = nil
}

extension EnvironmentValues {
    var mugshotImageSizeReporter: ((CGSize) -> Void)? {
        get { self[MugshotImageSizeReporterKey.self] }
        set { self[MugshotImageSizeReporterKey.self] = newValue }
    }
}

enum MugshotPostMediaSource: Hashable {
    case local(String)
    case remote(String)
    case asset(String)
    case placeholder(usesMugsyFallback: Bool, stableID: String)

    var cacheKey: String {
        switch self {
        case .local(let path): return "local:\(path)"
        case .remote(let url): return "remote:\(url)"
        case .asset(let name): return "asset:\(name)"
        case .placeholder(let usesMugsyFallback, let stableID):
            return "placeholder:\(usesMugsyFallback):\(stableID)"
        }
    }
}

struct MugshotPostMediaImage: View {
    let source: MugshotPostMediaSource
    @Environment(\.mugshotImageSizeReporter) private var reportImageSize

    var body: some View {
        Group {
            switch source {
            case .local(let path):
                PhotoImageView(photoPath: path)
            case .remote(let url):
                RemotePhotoImageView(urlString: url, placeholderSystemName: "photo.on.rectangle")
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onAppear {
                        if let size = UIImage(named: name)?.size {
                            reportImageSize?(size)
                        }
                    }
            case .placeholder(let usesMugsyFallback, let stableID):
                RemoteFeedNoPhotoPoster(
                    usesMugsyFallback: usesMugsyFallback,
                    stableID: stableID
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

struct MugshotAdaptivePostMedia<Content: View>: View {
    let ratioCacheKey: String
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let cornerRadius: CGFloat
    let onLocationTap: (() -> Void)?
    private let content: Content
    @State private var aspectRatio: CGFloat

    init(
        ratioCacheKey: String,
        drinkName: String,
        locationName: String,
        locationDetail: String? = nil,
        score: Double,
        cornerRadius: CGFloat = 18,
        onLocationTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.ratioCacheKey = ratioCacheKey
        self.drinkName = drinkName
        self.locationName = locationName
        self.locationDetail = locationDetail
        self.score = score
        self.cornerRadius = cornerRadius
        self.onLocationTap = onLocationTap
        self.content = content()
        _aspectRatio = State(
            initialValue: MugshotPostAspectRatioCache.shared.ratio(for: ratioCacheKey)
                ?? MugshotPostAspectRatioPolicy.fallback
        )
    }

    var body: some View {
        content
            .environment(\.mugshotImageSizeReporter, reportImageSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.38),
                        .init(color: .black.opacity(0.16), location: 0.60),
                        .init(color: .black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                MugshotPostArtworkOverlay(
                    drinkName: drinkName,
                    locationName: locationName,
                    locationDetail: locationDetail,
                    score: score,
                    onLocationTap: onLocationTap
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 17)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityElement(children: onLocationTap == nil ? .ignore : .contain)
            .accessibilityLabel("\(drinkName) at \(displayLocationName), Mugshot score \(score.formatted(.number.precision(.fractionLength(1)))) out of 5")
    }

    private var displayLocationName: String {
        MugshotPostLocationLine.displayName(name: locationName, locality: locationDetail)
    }

    private func reportImageSize(_ size: CGSize) {
        let nextRatio = MugshotPostAspectRatioPolicy.ratio(for: size)
        MugshotPostAspectRatioCache.shared.store(nextRatio, for: ratioCacheKey)
        guard abs(aspectRatio - nextRatio) > 0.001 else { return }
        aspectRatio = nextRatio
    }
}

struct MugshotPostArtworkOverlay: View {
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let onLocationTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(drinkName)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .tracking(-0.35)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)

                if let onLocationTap {
                    Button(action: onLocationTap) {
                        HStack(spacing: 5) {
                            Text(MugshotPostLocationLine.displayName(name: locationName, locality: locationDetail))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sip.detail.cafe")
                    .accessibilityLabel("Open \(locationName) cafe details")
                    .accessibilityHint("Opens this cafe")
                } else {
                    Text(MugshotPostLocationLine.displayName(name: locationName, locality: locationDetail))
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(0.92)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(score.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .monospacedDigit()
                Text("OUT OF 5")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.3)
            }
            .fixedSize()
            .accessibilityHidden(true)
        }
        .foregroundStyle(Color.white)
        .shadow(color: .black.opacity(0.42), radius: 5, x: 0, y: 2)
    }
}

enum MugshotCaptionTruncation {
    static let suffix = "… more"

    static func truncatedText(
        _ text: String,
        width: CGFloat,
        font: UIFont,
        lineLimit: Int = 2
    ) -> String? {
        guard width > 0, lineLimit > 0 else { return nil }
        let fullHeight = measuredHeight(text, width: width, font: font)
        let allowedHeight = ceil(font.lineHeight * CGFloat(lineLimit))
        guard fullHeight > allowedHeight + 0.5 else { return nil }

        let characters = Array(text)
        var lower = 0
        var upper = characters.count
        var best = ""

        while lower <= upper {
            let midpoint = (lower + upper) / 2
            let prefix = String(characters.prefix(midpoint))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = prefix + suffix
            if measuredHeight(candidate, width: width, font: font) <= allowedHeight + 0.5 {
                best = prefix
                lower = midpoint + 1
            } else {
                upper = midpoint - 1
            }
        }

        return best + suffix
    }

    private static func measuredHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height)
    }
}

struct MugshotExpandableCaption: View {
    let caption: String
    var mentions: [Mention] = []
    var alwaysExpanded = false
    @State private var isExpanded = false
    @State private var availableWidth: CGFloat = 0

    private let font = UIFont.preferredFont(forTextStyle: .subheadline)

    private var truncatedCaption: String? {
        guard !alwaysExpanded, !isExpanded else { return nil }
        return MugshotCaptionTruncation.truncatedText(
            caption,
            width: availableWidth,
            font: font
        )
    }

    var body: some View {
        Group {
            if let truncatedCaption {
                Button {
                    isExpanded = true
                } label: {
                    Text(MentionTextFormatter.attributedString(for: truncatedCaption))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(caption)
                .accessibilityHint("Expands the full caption")
                .accessibilityIdentifier("feed.caption.more")
            } else {
                Text(MentionTextFormatter.attributedString(for: caption))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(caption)
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.espressoBrown.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in
                        availableWidth = width
                    }
            }
        }
    }
}

struct MugshotFeedPostPresentation {
    let visitID: UUID
    let mediaSource: MugshotPostMediaSource
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let caption: String?
    let mentions: [Mention]
    let authorName: String
    let username: String
    let avatarURL: String?
    let timestamp: String
    let authorBadge: String?
    let recommendation: String?
    let recommendationSystemImage: String
}

struct MugshotFeedPostCard<Footer: View>: View {
    let presentation: MugshotFeedPostPresentation
    let onOpen: () -> Void
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                MugshotAdaptivePostMedia(
                    ratioCacheKey: presentation.mediaSource.cacheKey,
                    drinkName: presentation.drinkName,
                    locationName: presentation.locationName,
                    locationDetail: presentation.locationDetail,
                    score: presentation.score
                ) {
                    MugshotPostMediaImage(source: presentation.mediaSource)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(presentation.drinkName) at \(presentation.locationName)")
            .accessibilityHint("Opens post details")

            if let caption = presentation.caption {
                MugshotExpandableCaption(caption: caption, mentions: presentation.mentions)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 9) {
                        MugshotAvatar(
                            name: presentation.authorName,
                            size: 30,
                            imageURL: presentation.avatarURL
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(presentation.authorName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                if let badge = presentation.authorBadge {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.mugshotMint.opacity(0.5), in: Capsule())
                                }
                            }
                            Text("@\(presentation.username) · \(presentation.timestamp)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.tertiaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                    }

                    if let recommendation = presentation.recommendation {
                        Label(recommendation, systemImage: presentation.recommendationSystemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.mugshotSage)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Recommended because \(recommendation)")
                    }
                }
                .foregroundStyle(Color.espressoBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.mugshotLine).frame(height: 1)
            }

            footer()
        }
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.foamWhite.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("feed.visitCard.\(presentation.visitID.uuidString)")
    }
}
